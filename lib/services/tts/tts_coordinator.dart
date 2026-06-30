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
import 'tts_player.dart';

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
    _pump();
    return completer.future;
  }

  /// 若空闲则取下一条（用户队列优先）执行；完成后递归驱动下一条。
  void _pump() {
    if (_running) return;
    final task = _userQueue.isNotEmpty
        ? _userQueue.removeFirst()
        : (_backgroundQueue.isNotEmpty ? _backgroundQueue.removeFirst() : null);
    if (task == null) return;
    _running = true;
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

class TtsCoordinator {
  TtsCoordinator({
    required TtsEngineFactory factory,
    required TtsCacheStore cacheStore,
    required TtsPlayer player,
  }) : _factory = factory,
       _cacheStore = cacheStore,
       _player = player;

  final TtsEngineFactory _factory;
  final TtsCacheStore _cacheStore;
  final TtsPlayer _player;

  TtsEngine? _engine;

  /// 已构建引擎的种类（与 [_desiredKind] 不一致时需重建）。
  TtsEngineKind? _engineKind;

  /// 已应用到引擎的配置。
  TtsSpeechConfig? _appliedConfig;

  /// 目标引擎/配置（由 [configure] 记录）。引擎**惰性**创建：仅渲染发音按钮不
  /// 触碰平台 TTS/数据库，首次 [speak] 才真正建引擎、连库。
  TtsEngineKind? _desiredKind;
  TtsSpeechConfig? _desiredConfig;

  /// 抢占代际计数。speak/stop/configure 递增，过期操作据此放弃。
  int _generation = 0;

  /// 引擎构建在途 Future：并发 [speak]/[configure] 共享同一次构建，
  /// 避免 `_engine==null` 窗口内重复建引擎 + worker isolate 泄漏（见 PLAN）。
  Future<void>? _ensuring;

  /// 按 cacheKey 记录「合成在途」的渲染 Future。
  ///
  /// 同一 cacheKey（同文本+引擎+音色+变体+语速）的并发渲染（如后台预热某音色时
  /// 用户恰好点该音色试听）复用同一 Future——不重复入 worker 队列、不重复合成，
  /// 第二方等同一份产物。完成后自动移除（见 [_render]）。
  final Map<String, Future<String?>> _inFlightRender = {};

  /// 合成优先级调度器：用户发音优先于后台预热（见 [TtsSynthPriority]）。
  final _SynthScheduler _scheduler = _SynthScheduler();

  /// 记录目标引擎与发音参数。
  ///
  /// 不在此处创建/初始化引擎（避免无谓的平台调用）；若引擎已存在则即时热更新，
  /// 否则留待首次 [speak] 惰性构建。
  Future<void> configure(TtsEngineKind kind, TtsSpeechConfig config) async {
    _desiredKind = kind;
    _desiredConfig = config;
    if (_engine != null) {
      try {
        await _ensureEngine(kind, config);
      } catch (e) {
        AppLogger.log('TtsCoordinator', 'configure 热更新失败: $e');
      }
    }
  }

  /// 确保引擎已按目标配置就绪（惰性创建/重建/热更新）。
  ///
  /// 构建/重建走 [_ensuring] in-flight 守卫：并发调用复用同一次构建，杜绝
  /// `_engine==null` 窗口内重复 `_factory`+`initialize`（重复 worker isolate 泄漏）。
  Future<TtsEngine?> _ensureEngine(
    TtsEngineKind kind,
    TtsSpeechConfig config,
  ) async {
    if (_engine == null || _engineKind != kind) {
      // 已有在途构建：等它完成后按需热更新配置再返回。
      final inFlight = _ensuring;
      if (inFlight != null) {
        await inFlight;
        if (_engine == null || _engineKind != kind) {
          return _ensureEngine(kind, config);
        }
      } else {
        final future = _buildEngine(kind, config);
        _ensuring = future;
        try {
          await future;
        } finally {
          if (identical(_ensuring, future)) _ensuring = null;
        }
        return _engine;
      }
    }
    if (_engine != null && _appliedConfig != config) {
      _appliedConfig = config;
      await _engine!.applyConfig(config);
    }
    return _engine;
  }

  /// 物理新建引擎并初始化（仅由 [_ensureEngine] 经 [_ensuring] 串行调用）。
  Future<void> _buildEngine(TtsEngineKind kind, TtsSpeechConfig config) async {
    final old = _engine;
    _engine = null;
    if (old != null) {
      await old.stop();
      await old.dispose();
    }
    final engine = _factory(kind);
    await engine.initialize();
    await engine.applyConfig(config);
    _engine = engine;
    _engineKind = kind;
    _appliedConfig = config;
  }

  /// 发音 [text]（用当前 [configure] 配置）。命中缓存直接播文件；未命中合成产文件并
  /// 入库后播放；合成失败（如 iOS synthesizeToFile 不稳）降级实时朗读（不缓存）。
  ///
  /// 返回 true 表示本次正常播完；被抢占/失败/未配置返回 false。
  Future<bool> speak(String text) async {
    final kind = _desiredKind;
    final config = _desiredConfig;
    if (kind == null || config == null) return false;
    return _renderAndPlay(text, kind, config);
  }

  /// 用**指定**引擎/配置发音（如音色试听）：与 [speak] 同管线，但用传入配置而非
  /// 当前选中配置，故可朗读任意音色。沿用抢占语义（递增代际、停止当前播放）。
  Future<bool> speakWith(
    String text,
    TtsEngineKind kind,
    TtsSpeechConfig config,
  ) => _renderAndPlay(text, kind, config);

  /// 预热：为给定引擎/配置合成并入库，**不播放**。已有缓存则跳过（去重）。
  ///
  /// 纯「请求→缓存文件」，不碰播放器、不动代际，供进页面后台预生成各音色试听片段。
  Future<void> prewarm(
    String text,
    TtsEngineKind kind,
    TtsSpeechConfig config,
  ) async {
    await _render(text, kind, config, priority: TtsSynthPriority.background);
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
    await _render(text, kind, config, priority: TtsSynthPriority.background);
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
  }) async {
    if (text.trim().isEmpty) return null;
    final swEnsure = Stopwatch()..start();
    final engine = await _ensureEngine(kind, config);
    swEnsure.stop();
    if (engine == null) return null;

    final cacheKey = _cacheStore.deriveKey(
      text: text,
      engine: kind,
      voiceId: config.voiceId,
      speed: config.rate,
      modelTag: config.modelTag,
    );

    // 1. 查缓存
    final swLookup = Stopwatch()..start();
    final cached = await _cacheStore.lookup(cacheKey);
    swLookup.stop();
    if (cached != null) {
      AppLogger.log(
        'TtsCoordinator',
        '缓存命中 (lookup=${swLookup.elapsedMilliseconds}ms) → ${cached.path}',
      );
      return cached.path;
    }

    // 2. 同 key 合成已在途 → 复用，不重复入队/重复合成（见 [_inFlightRender]）。
    final inFlight = _inFlightRender[cacheKey];
    if (inFlight != null) {
      AppLogger.log(
        'TtsCoordinator',
        '合成在途复用 key=$cacheKey voice=${config.voiceId}',
      );
      return inFlight;
    }
    AppLogger.log(
      'TtsCoordinator',
      '缓存未命中 (ensure=${swEnsure.elapsedMilliseconds}ms '
          'lookup=${swLookup.elapsedMilliseconds}ms) → 合成 engine=${kind.name} '
          'voice=${config.voiceId}',
    );

    // 3. 未命中且无在途：提交到优先级调度器并登记在途，完成后移除（去重的真相源）。
    //    调度器保证「用户发音优先于后台预热、同优先级内 FIFO」，且 worker 一次只跑一条。
    final future = _scheduler.submit(
      priority,
      () => _synthAndStore(engine, text, kind, config, cacheKey),
    );
    _inFlightRender[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightRender.remove(cacheKey);
    }
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
    final result = await engine.synthesize(
      text,
      outputDir: outputDir,
      baseName: cacheKey,
      config: config,
    );
    swSynth.stop();
    AppLogger.log(
      'TtsCoordinator',
      '⏱ synthesize=${swSynth.elapsedMilliseconds}ms ok=${result != null}',
    );
    if (result == null) return null;

    await _cacheStore.store(
      cacheKey: cacheKey,
      text: text,
      engine: kind,
      voiceId: config.voiceId,
      languageCode: config.languageTag,
      speed: config.rate,
      result: result,
    );
    return result.filePath;
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
  }) async {
    if (text.trim().isEmpty) return false;
    // 先确保引擎就绪（与渲染共用一次构建），再抢占。
    final engine = await _ensureEngine(kind, config);
    if (engine == null) return false;

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
    if (myGen != _generation) return false;

    // 仅当无任何在途合成时才停引擎：避免 engine.stop() 误杀其他在途合成（如另一口音
    // 的预热）使其 Future 挂起、后续复用方卡死。有在途合成时跳过——抢占已由 generation
    // 守卫 +（降级分支）speakLive 自带的 stop 保证。
    if (_inFlightRender.isEmpty) {
      await engine.stop();
      if (myGen != _generation) return false;
    }

    // 播放前最终代际校验：上面「有在途合成时」会跳过 engine.stop 及其代际复查，
    // 故此处必须再判一次，否则被 stop()（如离开设置页）抢占的本次仍会播出。
    if (myGen != _generation) return false;

    if (path != null) {
      AppLogger.log('TtsCoordinator', '播放 $path');
      return _player.playFileToEnd(path);
    }

    // 合成失败：降级实时朗读（不缓存）
    AppLogger.log('TtsCoordinator', '渲染返回 null → 降级 speakLive');
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
    final old = _engine;
    _engine = null;
    _engineKind = null;
    _appliedConfig = null;
    if (old != null) {
      await old.stop();
      await old.dispose();
    }
  }

  Future<void> dispose() async {
    _generation++;
    await _player.dispose();
    await _engine?.dispose();
    _engine = null;
  }
}
