/// 统一 TTS 协调器（纯 Dart 编排）
///
/// 串起「文本+参数 → cacheKey → 查缓存 → 命中直接播 / 未命中合成产文件并入库 →
/// 播放文件」管线，并处理引擎热切换与防竞态。不依赖 Riverpod/Flutter，可独立单测。
///
/// 防竞态（沿用 CLAUDE.md §7.2 思路）：
/// - 每次 [speak]/[stop]/[configure] 递增 generation，在每个 await 续点校验，
///   不匹配则视为被抢占、静默放弃；
/// - 切换引擎物理新建引擎对象，旧引擎滞后回调作用在已 dispose 的旧对象上，天然隔离。
library;

import 'dart:async';
import 'dart:collection';

import '../app_logger.dart';
import 'tts_cache_store.dart';
import 'tts_engine.dart';
import '../pronunciation/local_audio_clip_player.dart';

/// 单次合成的超时上界，**按引擎 + 文本长度成比例**——仅作「native 永不返回」的安全
/// 上界，不做精确计时，宁可偏松也不误杀长句。计时只覆盖单次合成本身（调度器已串行化，
/// 排队等待不计入，见 [_synthAndStore]）。下限统一 12s（短词快速兜底）。
///
/// 各引擎速度差异大，系数分别取（含冷启动与慢机余量）：
/// - **Kokoro**：CPU 推理 RTF≈3，最慢——基础 10s + 300ms/字符，上限 90s
///   （A06 上一句长例句合成可达 20–30s，固定小值会误判为挂起）。
/// - **piper**：RTF≈0.1~0.3，快，含冷启数秒——基础 10s + 60ms/字符，上限 40s。
/// - **platform（系统 TTS）**：合成近实时、快，主要防其挂起——基础 8s + 80ms/字符，上限 30s。
Duration _synthTimeoutFor(TtsEngineKind kind, String text) {
  final int baseMs;
  final int perCharMs;
  final int maxMs;
  switch (kind) {
    case TtsEngineKind.kokoro:
      baseMs = 10000;
      perCharMs = 300;
      maxMs = 90000;
    case TtsEngineKind.piper:
      baseMs = 10000;
      perCharMs = 60;
      maxMs = 40000;
    case TtsEngineKind.platform:
      baseMs = 8000;
      perCharMs = 80;
      maxMs = 30000;
  }
  final ms = baseMs + text.length * perCharMs;
  return Duration(milliseconds: ms.clamp(12000, maxMs));
}

/// 合成任务优先级。
///
/// 底层引擎（Kokoro worker isolate / 平台 synthesizeToFile）一次只能串行跑一条
/// 合成，且进行中的 native 推理不可中断。故在主 isolate 侧用 [_SynthScheduler]
/// 调度「何时把下一条合成交给引擎」：用户明确发起的发音排在后台预热之前。
enum TtsSynthPriority {
  /// 用户明确发起（发音 / 试听）——最高优先级。
  user,

  /// 后台自动预热（进设置页预生成试听片段）——让位于用户任务。
  background,
}

/// 合成优先级调度器（主 isolate 侧，单线程事件循环，无锁）。
///
/// 维护两条 FIFO 队列：用户队列恒优先于后台队列。worker 同一时刻只跑一条
/// （正在跑的不可抢占），完成后从队列取下一条——先取用户队首，无则取后台队首。
/// 这样「用户任务整体优先 + 同优先级内按提交顺序」两条语义同时满足。
class _SynthScheduler {
  final Queue<_QueuedSynth> _userQueue = Queue<_QueuedSynth>();
  final Queue<_QueuedSynth> _backgroundQueue = Queue<_QueuedSynth>();
  bool _running = false;

  /// 提交一条合成任务，返回其结果 Future（含排队等待时间）。
  Future<String?> submit(
    TtsSynthPriority priority,
    Future<String?> Function() run,
  ) {
    final completer = Completer<String?>();
    final task = _QueuedSynth(run, completer);
    (priority == TtsSynthPriority.user ? _userQueue : _backgroundQueue).add(
      task,
    );
    AppLogger.log(
      'TtsScheduler',
      '已排队${priority == TtsSynthPriority.user ? '用户发音' : '文本预热'}：'
          '用户任务=${_userQueue.length} 文本预热任务=${_backgroundQueue.length} '
          '正在合成=$_running',
    );
    _pump();
    return completer.future;
  }

  /// 丢弃尚未执行的后台任务；正在运行的 native 推理不可可靠中断，必须自然完成。
  void cancelPendingBackground() {
    final cancelled = _backgroundQueue.length;
    while (_backgroundQueue.isNotEmpty) {
      _backgroundQueue.removeFirst().completer.complete(null);
    }
    AppLogger.log(
      'TtsScheduler',
      '已取消未开始的文本预热：取消=$cancelled '
          '保留用户任务=${_userQueue.length} 正在合成=$_running',
    );
  }

  /// 若空闲则取下一条（用户队列优先）执行；完成后递归驱动下一条。
  void _pump() {
    if (_running) return;
    final task = _userQueue.isNotEmpty
        ? _userQueue.removeFirst()
        : (_backgroundQueue.isNotEmpty ? _backgroundQueue.removeFirst() : null);
    if (task == null) return;
    _running = true;
    AppLogger.log(
      'TtsScheduler',
      '开始执行合成：剩余用户任务=${_userQueue.length} '
          '剩余文本预热任务=${_backgroundQueue.length}',
    );
    task
        .run()
        .then(task.completer.complete)
        .catchError((Object e, StackTrace st) {
          task.completer.completeError(e, st);
        })
        .whenComplete(() {
          _running = false;
          _pump();
        });
  }
}

/// 排队中的合成任务：执行闭包 + 结果回投 Completer。
class _QueuedSynth {
  _QueuedSynth(this.run, this.completer);
  final Future<String?> Function() run;
  final Completer<String?> completer;
}

class _EngineKey {
  const _EngineKey(this.kind, this.modelId);
  final TtsEngineKind kind;
  final String? modelId;

  @override
  bool operator ==(Object other) =>
      other is _EngineKey && kind == other.kind && modelId == other.modelId;

  @override
  int get hashCode => Object.hash(kind, modelId);
}

class TtsCoordinator {
  TtsCoordinator({
    required TtsEngineFactory factory,
    required TtsCacheStore cacheStore,
    required LocalAudioClipPlayer player,
  }) : _factory = factory,
       _cacheStore = cacheStore,
       _player = player;

  final TtsEngineFactory _factory;
  final TtsCacheStore _cacheStore;
  final LocalAudioClipPlayer _player;

  TtsEngine? _engine;

  /// 当前可用引擎。旧会话在有合成任务时保留在后台，但不会再被新请求选中。
  TtsEngineKind? _engineKind;

  /// 已应用到引擎的配置。
  TtsSpeechConfig? _appliedConfig;

  /// 目标引擎/配置（由 [configure] 记录）。引擎**惰性**创建：仅渲染发音按钮不
  /// 触碰平台 TTS/数据库，首次 [speak] 才真正建引擎、连库。
  TtsEngineKind? _desiredKind;
  TtsSpeechConfig? _desiredConfig;

  /// 当前引擎和语音参数是否已由 [configure] 写入。
  ///
  /// 这不代表模型或引擎已初始化；它只保证文本预热能够获得正确的缓存键和合成配置。
  bool get isConfigured => _desiredKind != null && _desiredConfig != null;

  /// 播放抢占代际计数。旧播放/渲染在 stop 后据此放弃。
  int _generation = 0;

  /// 引擎构建在途 Future：并发 [speak]/[configure] 共享同一次构建，
  /// 避免 `_engine==null` 窗口内重复建引擎 + worker isolate 泄漏（见 PLAN）。
  final Map<_EngineKey, Future<TtsEngine?>> _ensuring = {};

  /// 配置代际；旧模型加载完成后若代际已变化，不得发布为当前引擎。
  int _configurationGeneration = 0;

  final Map<TtsEngine, int> _engineUsers = {};
  final Set<TtsEngine> _retiredEngines = {};

  /// 按 cacheKey 记录「合成在途」的渲染 Future。
  ///
  /// 同一 cacheKey（同文本+引擎+音色+变体+语速）的并发渲染（如后台预热某音色时
  /// 用户恰好点该音色试听）复用同一 Future——不重复入 worker 队列、不重复合成，
  /// 第二方等同一份产物。完成后自动移除（见 [_render]）。
  final Map<String, Future<String?>> _inFlightRender = {};

  /// 合成优先级调度器：用户发音优先于后台预热（见 [TtsSynthPriority]）。
  final _SynthScheduler _scheduler = _SynthScheduler();

  /// 后台文本预热代际。取消时仅淘汰尚未执行的合成；初始化或 native 推理保持自然结束。
  int _backgroundGeneration = 0;

  /// 记录目标引擎与发音参数。
  ///
  /// 不在此处创建/初始化引擎（避免无谓的平台调用）；若引擎已存在则即时热更新，
  /// 否则留待首次 [speak] 惰性构建。
  Future<void> configure(TtsEngineKind kind, TtsSpeechConfig config) async {
    final hadCurrentEngine = _engine != null;
    final previousKind = _desiredKind;
    final previousConfig = _desiredConfig;
    _desiredKind = kind;
    _desiredConfig = config;
    final key = _engineKey(kind, config);
    final previousKey = previousKind == null || previousConfig == null
        ? null
        : _engineKey(previousKind, previousConfig);
    if (previousKey != key) {
      _configurationGeneration++;
      // 配置目标变化后，旧后台预热不能继续排队或重新拉起旧模型；用户任务
      // 不受影响，仍由播放/配置代际决定最终是否丢弃结果。
      cancelPendingPrewarm();
    }
    AppLogger.log(
      'TtsCoordinator',
      '配置目标变更：${_engineLabel(previousKind, previousConfig)} → '
          '${_engineLabel(kind, config)} 配置代际=$_configurationGeneration',
    );
    final currentKind = _engineKind;
    final currentConfig = _appliedConfig;
    if (_engine != null &&
        (currentKind == null ||
            currentConfig == null ||
            _engineKey(currentKind, currentConfig) != key)) {
      final old = _engine;
      _engine = null;
      _engineKind = null;
      _appliedConfig = null;
      await _retireEngine(old);
    }
    // 配置变更不主动初始化新引擎。模型 ready 门控由 TtsController 统一负责，
    // 真正需要发音或预热时再经 ensureEngineReady() 加载，避免下载完成前访问模型目录。
    if (hadCurrentEngine && _engine != null) {
      final current = _engine!;
      final currentConfig = _appliedConfig;
      if (currentConfig != null && _engineKey(kind, currentConfig) == key) {
        try {
          _appliedConfig = config;
          await current.applyConfig(config);
        } catch (e) {
          AppLogger.log('TtsCoordinator', 'configure 热更新失败: $e');
        }
      }
    }
  }

  _EngineKey _engineKey(TtsEngineKind kind, TtsSpeechConfig config) {
    final modelId = switch (kind) {
      TtsEngineKind.kokoro => config.modelTag,
      TtsEngineKind.piper => config.voiceName,
      TtsEngineKind.platform => null,
    };
    return _EngineKey(kind, modelId);
  }

  String _engineLabel(TtsEngineKind? kind, TtsSpeechConfig? config) {
    if (kind == null || config == null) return '未配置';
    final modelId = _engineKey(kind, config).modelId ?? 'system';
    return '${kind.diagnosticName}/$modelId';
  }

  /// 确保引擎已按目标配置就绪（惰性创建/重建/热更新）。
  ///
  /// 构建/重建走 [_ensuring] in-flight 守卫：并发调用复用同一次构建，杜绝
  /// `_engine==null` 窗口内重复 `_factory`+`initialize`（重复 worker isolate 泄漏）。
  Future<TtsEngine?> _ensureEngine(
    TtsEngineKind kind,
    TtsSpeechConfig config,
  ) async {
    final key = _engineKey(kind, config);
    final currentKind = _engineKind;
    final currentConfig = _appliedConfig;
    if (_engine != null &&
        currentKind == kind &&
        currentConfig != null &&
        _engineKey(kind, currentConfig) == key) {
      AppLogger.log(
        'TtsCoordinator',
        '模型已就绪，无需重复加载：目标=${_engineLabel(kind, config)}',
      );
      if (_appliedConfig != config) {
        _appliedConfig = config;
        await _engine!.applyConfig(config);
      }
      return _engine;
    }

    var future = _ensuring[key];
    if (future == null) {
      final buildGeneration = _configurationGeneration;
      AppLogger.log(
        'TtsCoordinator',
        '模型预热开始加载：目标=${_engineLabel(kind, config)} '
            '配置代际=$_configurationGeneration',
      );
      future = _buildEngine(kind, config, buildGeneration);
      _ensuring[key] = future;
    } else {
      AppLogger.log(
        'TtsCoordinator',
        '模型预热复用进行中的加载：目标=${_engineLabel(kind, config)} '
            '配置代际=$_configurationGeneration',
      );
    }
    TtsEngine? engine;
    try {
      engine = await future;
    } finally {
      // 初始化失败也必须释放 in-flight 记录，否则后续模型下载完成后会永久复用
      // 同一个已失败 Future，表现为模型明明存在却持续报目录不存在。
      if (identical(_ensuring[key], future)) _ensuring.remove(key);
    }
    if (engine == null) return null;
    final old = _engine;
    if (old != null && !identical(old, engine)) _retireEngine(old);
    _engine = engine;
    _engineKind = kind;
    _appliedConfig = config;
    return engine;
  }

  /// 旧引擎不能在仍有 native 合成时强制 dispose；任务结束后再安全释放。
  Future<void> _retireEngine(TtsEngine? engine) {
    if (engine == null) return Future<void>.value();
    _retiredEngines.add(engine);
    if ((_engineUsers[engine] ?? 0) == 0) {
      AppLogger.log('TtsCoordinator', '释放旧 TTS 引擎：当前无活跃合成任务');
      return _disposeRetiredEngine(engine);
    }
    AppLogger.log(
      'TtsCoordinator',
      '延迟释放旧 TTS 引擎：活跃合成任务=${_engineUsers[engine]}',
    );
    return Future<void>.value();
  }

  Future<void> _disposeRetiredEngine(TtsEngine engine) async {
    if (!_retiredEngines.contains(engine)) return;
    _retiredEngines.remove(engine);
    try {
      await engine.stop();
      await engine.dispose();
    } catch (e, st) {
      AppLogger.log('TtsCoordinator', '✗ 过期 TTS 引擎释放失败：$e\n$st');
    }
  }

  void _acquireEngine(TtsEngine engine) {
    _engineUsers[engine] = (_engineUsers[engine] ?? 0) + 1;
  }

  void _releaseEngine(TtsEngine engine) {
    final users = (_engineUsers[engine] ?? 1) - 1;
    if (users == 0) {
      _engineUsers.remove(engine);
      if (_retiredEngines.contains(engine)) {
        AppLogger.log('TtsCoordinator', '旧 TTS 引擎合成任务结束，开始释放');
        unawaited(_disposeRetiredEngine(engine));
      }
    } else {
      _engineUsers[engine] = users;
    }
  }

  /// 物理新建引擎并初始化；过期构建完成后立即释放且不发布。
  Future<TtsEngine?> _buildEngine(
    TtsEngineKind kind,
    TtsSpeechConfig config,
    int buildGeneration,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final engine = _factory(kind, config);
      await engine.initialize();
      await engine.applyConfig(config);
      if (buildGeneration != _configurationGeneration) {
        AppLogger.log(
          'TtsCoordinator',
          '丢弃过期模型：目标=${_engineLabel(kind, config)} '
              '加载代际=$buildGeneration 当前代际=$_configurationGeneration',
        );
        await engine.dispose();
        return null;
      }
      stopwatch.stop();
      AppLogger.log(
        'TtsCoordinator',
        '模型预热完成：目标=${_engineLabel(kind, config)} '
            '配置代际=$buildGeneration 耗时=${stopwatch.elapsedMilliseconds}ms',
      );
      return engine;
    } catch (error) {
      stopwatch.stop();
      AppLogger.log(
        'TtsCoordinator',
        '✗ 模型预热失败：引擎=${kind.diagnosticName} '
            '耗时=${stopwatch.elapsedMilliseconds}ms 错误=$error',
      );
      rethrow;
    }
  }

  /// 发音 [text]（用当前 [configure] 配置）。命中缓存直接播文件；未命中合成产文件并
  /// 入库后播放；合成失败（如 iOS synthesizeToFile 不稳）降级实时朗读（不缓存）。
  ///
  /// 返回 true 表示本次正常播完；被抢占/失败/未配置返回 false。
  Future<bool> speak(String text) async {
    final kind = _desiredKind;
    final config = _desiredConfig;
    if (kind == null || config == null) return false;
    return _renderAndPlay(
      text,
      kind,
      config,
      configurationGeneration: _configurationGeneration,
    );
  }

  /// 用**指定**引擎/配置发音（如音色试听）：与 [speak] 同管线，但用传入配置而非
  /// 当前选中配置，故可朗读任意音色。沿用抢占语义（递增代际、停止当前播放）。
  Future<bool> speakWith(
    String text,
    TtsEngineKind kind,
    TtsSpeechConfig config,
  ) => _renderAndPlay(
    text,
    kind,
    config,
    configurationGeneration: _configurationGeneration,
  );

  /// 预热：为给定引擎/配置合成并入库，**不播放**。已有缓存则跳过（去重）。
  ///
  /// 纯「请求→缓存文件」，不碰播放器、不动代际，供进页面后台预生成各音色试听片段。
  Future<void> prewarm(
    String text,
    TtsEngineKind kind,
    TtsSpeechConfig config,
  ) async {
    await _render(
      text,
      kind,
      config,
      priority: TtsSynthPriority.background,
      backgroundGeneration: _backgroundGeneration,
    );
  }

  /// 预热「当前配置」下的文本：用 [configure] 记录的引擎/配置合成入库，**不播放**。
  ///
  /// 与 [speak] 同源配置（[_desiredKind]/[_desiredConfig]），故预热产物的 cacheKey
  /// 与点击发音逐字段一致、点击即命中（避免 §7.18 的「自建配置致 key 不符」回归）。
  /// 未配置时静默 no-op。供词典弹窗等「按当前设置发音」的场景批量预热。
  Future<void> prewarmCurrent(String text) async {
    final kind = _desiredKind;
    final config = _desiredConfig;
    if (kind == null || config == null) return;
    await _render(
      text,
      kind,
      config,
      priority: TtsSynthPriority.background,
      backgroundGeneration: _backgroundGeneration,
    );
  }

  /// 独立预热当前引擎实例，不读取缓存、不合成、不播放。
  Future<void> warmUpCurrentEngine() async {
    final kind = _desiredKind;
    final config = _desiredConfig;
    if (kind == null || config == null) {
      AppLogger.log('TtsCoordinator', '模型预热跳过：TTS 尚未配置');
      return;
    }
    AppLogger.log('TtsCoordinator', '请求模型预热（不合成文本）：引擎=${kind.diagnosticName}');
    await _ensureEngine(kind, config);
  }

  /// 确保指定配置对应的引擎已加载到内存，供 Controller 在播放和后台预热前复用。
  ///
  /// 实际加载仍由 [_ensureEngine] 按引擎配置去重；调用方只需等待本方法完成即可，
  /// 不必再直接依赖惰性合成流程触发模型初始化。
  Future<bool> ensureEngineReady(
    TtsEngineKind kind,
    TtsSpeechConfig config,
  ) async {
    final engine = await _ensureEngine(kind, config);
    return engine != null;
  }

  /// 将文本渲染为可复用的本地音频文件，不触发播放。
  ///
  /// 供 Text → Lesson 等后台编排使用：仍复用同一缓存键、同一条合成调度器和
  /// 模型实例；调用方按 chunk 边界检查取消，天然避免重复加载模型。
  Future<String?> renderToCache(
    String text, {
    required TtsEngineKind kind,
    required TtsSpeechConfig config,
    TtsSynthPriority priority = TtsSynthPriority.user,
  }) {
    return _render(text, kind, config, priority: priority);
  }

  /// 取消尚未开始的文本预热；运行中的初始化/推理不能被安全打断。
  void cancelPendingPrewarm() {
    _backgroundGeneration++;
    _scheduler.cancelPendingBackground();
  }

  /// 渲染主干：把（文本+引擎+配置）渲染为可播放的本地文件路径。
  ///
  /// cache-first + 幂等：命中缓存返回其路径；未命中则合成产文件、入库后返回新路径；
  /// 合成失败返回 null。**不碰播放器、不动代际**——可被 speak/试听/预热共用。
  Future<String?> _render(
    String text,
    TtsEngineKind kind,
    TtsSpeechConfig config, {
    required TtsSynthPriority priority,
    int? backgroundGeneration,
  }) async {
    if (text.trim().isEmpty) return null;

    final cacheKey = _cacheStore.deriveKey(
      text: text,
      engine: kind,
      voiceId: config.voiceId,
      speed: _effectiveSynthesisSpeed(kind, config),
      modelTag: config.modelTag,
    );

    // 1. 查缓存
    final swLookup = Stopwatch()..start();
    final cached = await _cacheStore.lookup(cacheKey);
    swLookup.stop();
    if (cached != null) {
      AppLogger.log(
        'TtsCoordinator',
        '缓存命中，直接${priority == TtsSynthPriority.background ? '跳过文本预热' : '播放'}：'
            '查询耗时=${swLookup.elapsedMilliseconds}ms 缓存键=$cacheKey',
      );
      return cached.path;
    }

    // 取消发生在缓存查询或模型初始化期间时，不再把过期预热送入合成队列。
    if (priority == TtsSynthPriority.background &&
        backgroundGeneration != _backgroundGeneration) {
      return null;
    }

    // 2. 同 key 合成已在途 → 复用，不重复入队/重复合成（见 [_inFlightRender]）。
    final inFlight = _inFlightRender[cacheKey];
    if (inFlight != null) {
      AppLogger.log(
        'TtsCoordinator',
        '复用进行中的${priority == TtsSynthPriority.background ? '文本预热' : '用户发音'}合成：'
            '音色=${config.voiceId} 缓存键=$cacheKey',
      );
      return inFlight;
    }
    // 3. 在初始化前登记在途：并发 cache miss 会共享模型加载和后续合成，不能让
    //    两条请求都在 await _ensureEngine 后才发现彼此。
    final future = _ensureAndSchedule(
      text,
      kind,
      config,
      cacheKey,
      priority: priority,
      backgroundGeneration: backgroundGeneration,
      lookupElapsed: swLookup.elapsed,
    );
    _inFlightRender[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightRender.remove(cacheKey);
    }
  }

  Future<String?> _ensureAndSchedule(
    String text,
    TtsEngineKind kind,
    TtsSpeechConfig config,
    String cacheKey, {
    required TtsSynthPriority priority,
    required int? backgroundGeneration,
    required Duration lookupElapsed,
  }) async {
    final swEnsure = Stopwatch()..start();
    final engine = await _ensureEngine(kind, config);
    swEnsure.stop();
    if (engine == null ||
        (priority == TtsSynthPriority.background &&
            backgroundGeneration != _backgroundGeneration)) {
      return null;
    }
    AppLogger.log(
      'TtsCoordinator',
      '${priority == TtsSynthPriority.background ? '文本预热' : '用户发音'}缓存未命中，准备合成：'
          '目标=${_engineLabel(kind, config)} 音色=${config.voiceId} '
          '模型确认=${swEnsure.elapsedMilliseconds}ms '
          '缓存查询=${lookupElapsed.inMilliseconds}ms 文本长度=${text.length} '
          '缓存键=$cacheKey',
    );
    _acquireEngine(engine);
    return _scheduler.submit(priority, () async {
      try {
        return await _synthAndStore(engine, text, kind, config, cacheKey);
      } finally {
        _releaseEngine(engine);
      }
    });
  }

  /// 合成产文件并入库，返回文件路径（失败返回 null）。被 [_render] 经在途表去重调用。
  Future<String?> _synthAndStore(
    TtsEngine engine,
    String text,
    TtsEngineKind kind,
    TtsSpeechConfig config,
    String cacheKey,
  ) async {
    final outputDir = await _cacheStore.reserveDir();
    final swSynth = Stopwatch()..start();
    // 给 native 合成设界：部分设备（如三星 A06）platform synthesizeToFile 与 sherpa
    // Piper worker 推理在被打断/争用时会**永不返回**（flutter_tts 在 error/stop 分支
    // 不兑现 Future），无超时会经单槽调度器冻死整条 TTS。超时判失败（返回 null，不抛出），
    // 使调度器 whenComplete 复位、_render 清在途表、_renderAndPlay 降级 speakLive。见 §7.25。
    TtsSynthesisResult? result;
    try {
      result = await engine
          .synthesize(
            text,
            outputDir: outputDir,
            baseName: cacheKey,
            config: config,
          )
          .timeout(_synthTimeoutFor(kind, text));
    } on TimeoutException {
      swSynth.stop();
      AppLogger.log(
        'TtsCoordinator',
        '⏱ 文本合成超时：耗时=${swSynth.elapsedMilliseconds}ms '
            '目标=${_engineLabel(kind, config)} 文本长度=${text.length}，将降级处理',
      );
      return null;
    }
    swSynth.stop();
    AppLogger.log(
      'TtsCoordinator',
      '文本合成结束：耗时=${swSynth.elapsedMilliseconds}ms '
          '结果=${result == null ? '失败' : '成功'}',
    );
    if (result == null) return null;

    await _cacheStore.store(
      cacheKey: cacheKey,
      text: text,
      engine: kind,
      voiceId: config.voiceId,
      languageCode: config.languageTag,
      speed: _effectiveSynthesisSpeed(kind, config),
      result: result,
    );
    AppLogger.log(
      'TtsCoordinator',
      '文本预热/合成已写入缓存：引擎=${kind.diagnosticName} 缓存键=$cacheKey '
          '目标=${_engineLabel(kind, config)} 文本长度=${text.length} '
          '合成耗时=${swSynth.elapsedMilliseconds}ms',
    );
    return result.filePath;
  }

  /// 平台 TTS 的 rate 与本地神经网络 speed 分属两套尺度，缓存必须按实际合成
  /// 参数分桶：平台用 rate，Kokoro/Piper 用 speed。
  double _effectiveSynthesisSpeed(TtsEngineKind kind, TtsSpeechConfig config) {
    return kind == TtsEngineKind.platform ? config.rate : config.speed;
  }

  /// 播放主干：抢占当前播放（递增代际、停止播放/引擎）后渲染并播放。
  ///
  /// 渲染失败时降级实时朗读（[TtsEngine.speakLive]，不缓存；保留 §7.15 macOS 兜底）。
  /// 返回 true 表示正常播完；被抢占/未配置返回 false。
  Future<bool> _renderAndPlay(
    String text,
    TtsEngineKind kind,
    TtsSpeechConfig config, {
    TtsSynthPriority priority = TtsSynthPriority.user,
    int? configurationGeneration,
  }) async {
    if (text.trim().isEmpty) return false;
    // 抢占语义只作用于**播放**：递增代际，并立即停止上一段播放（player.stop 只动
    // 播放器，不影响在途合成，可安全前置）。
    //
    // 注意：此处**不因抢占提前返回**——被后发发音抢占的本次任务，其合成仍要入队
    // 执行并入缓存（用户语义：task1、task2 都执行、按 FIFO 排队，只是最终播放最新的
    // 那个）。代际仅在「渲染完成 → 是否播放」处裁决。
    final myGen = ++_generation;
    await _player.stop();

    // 渲染**先于** engine.stop：本次渲染可能复用「进页预热」登记的在途合成 Future
    // （见 _inFlightRender），而平台引擎 engine.stop()→_tts.stop() 会打断正在进行的
    // synthesizeToFile，其完成回调可能永不到达 → 复用方永久挂起（CLAUDE.md §7.18）。
    // 故先拿到可播放文件，再按需停引擎。
    final path = await _render(text, kind, config, priority: priority);
    if (myGen != _generation ||
        (configurationGeneration != null &&
            configurationGeneration != _configurationGeneration)) {
      AppLogger.log(
        'TtsCoordinator',
        '丢弃过期发音结果：播放代际=$myGen 当前播放代际=$_generation '
            '配置代际=$configurationGeneration 当前配置代际=$_configurationGeneration',
      );
      return false;
    }

    // 仅当无任何在途合成时才停引擎：避免 engine.stop() 误杀其他在途合成（如另一口音
    // 的预热）使其 Future 挂起、后续复用方卡死。有在途合成时跳过——抢占已由 generation
    // 守卫 +（降级分支）speakLive 自带的 stop 保证。
    if (_inFlightRender.isEmpty) {
      await _engine?.stop();
      if (myGen != _generation) return false;
    }

    // 播放前最终代际校验：上面「有在途合成时」会跳过 engine.stop 及其代际复查，
    // 故此处必须再判一次，否则被 stop()（如离开设置页）抢占的本次仍会播出。
    if (myGen != _generation ||
        (configurationGeneration != null &&
            configurationGeneration != _configurationGeneration)) {
      return false;
    }

    if (configurationGeneration != null &&
        configurationGeneration != _configurationGeneration) {
      return false;
    }
    if (path != null) {
      AppLogger.log('TtsCoordinator', '开始播放已生成的语音文件');
      final result = await _player.playFile(path);
      return result == AudioPlaybackResult.completed;
    }

    // 合成失败：降级实时朗读（不缓存）
    AppLogger.log('TtsCoordinator', '文本合成未产出文件，降级为实时朗读');
    final engine = await _ensureEngine(kind, config);
    if (engine == null || myGen != _generation) return false;
    return engine.speakLive(text);
  }

  /// 停止当前发音。
  Future<void> stop() async {
    _generation++;
    await _player.stop();
    await _engine?.stop();
  }

  /// 作废当前引擎，下次 [speak] 重建。
  ///
  /// 用于「同一引擎种类内底层模型已变」的场景（如 Kokoro fp32↔int8 切换）：
  /// [configure] 只热更新配置、不重建引擎，而切换模型变体需重新加载模型，
  /// 故由上层在变体变化时显式调用。
  Future<void> invalidateEngine() async {
    _generation++;
    _configurationGeneration++;
    final old = _engine;
    _engine = null;
    _engineKind = null;
    _appliedConfig = null;
    _retireEngine(old);
  }

  Future<void> dispose() async {
    _generation++;
    final current = _engine;
    _engine = null;
    _engineKind = null;
    _appliedConfig = null;
    _retireEngine(current);
    for (final future in _ensuring.values.toList()) {
      final engine = await future;
      if (engine != null) _retireEngine(engine);
    }
    _engine = null;
  }
}
