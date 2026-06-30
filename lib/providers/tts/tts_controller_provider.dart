/// 统一 TTS 控制器 Provider
///
/// 全应用唯一的发音入口。持有纯 Dart [TtsCoordinator]（引擎选择 + 缓存 + 播放 +
/// 防竞态），监听 [ttsSettingsProvider] 在引擎/口音变化时热重配。
///
/// 所有发音调用点（闪卡 / 收藏 / 词典单词 / 词典例句）统一
/// `ref.read(ttsControllerProvider.notifier).speak(text, key: ...)`。
/// [TtsControllerState.speakingKey] 暴露当前正在朗读项，供发音按钮显激活态。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../database/providers.dart';
import '../../services/app_logger.dart';
import '../../services/tts/kokoro_tts_engine.dart';
import '../../services/tts/kokoro_voices.dart';
import '../../services/tts/piper_tts_engine.dart';
import '../../services/tts/piper_voices.dart';
import '../../services/tts/platform_tts_engine.dart';
import '../../services/tts/tts_cache_store.dart';
import '../../services/tts/tts_coordinator.dart';
import '../../services/tts/tts_engine.dart';
import '../../services/tts/tts_player.dart';
import 'kokoro_model_provider.dart';
import 'piper_model_provider.dart';
import 'tts_settings_provider.dart';

/// TTS 引擎工厂 Provider。
///
/// 默认按种类创建真实引擎；测试可 override 注入 mock 引擎。
final ttsEngineFactoryProvider = Provider<TtsEngineFactory>((ref) {
  return (kind) {
    switch (kind) {
      case TtsEngineKind.platform:
        return PlatformTtsEngine();
      case TtsEngineKind.echoLoop:
        // 模型路径在引擎首次合成时惰性解析：按当前选中变体取对应管理器，
        // 仅在该变体模型就绪后才会被构造。
        return KokoroTtsEngine(
          resolvePaths: () {
            final variant = ref.read(ttsSettingsProvider).kokoroVariant;
            return ref
                .read(kokoroModelManagerProvider(variant))
                .kokoroConfigPaths();
          },
        );
      case TtsEngineKind.piper:
        // 模型按音色惰性解析：合成时按传入的 voiceId 取对应音色管理器的路径，
        // worker 据 voiceId 决定是否重建 OfflineTts（换音色=换模型）。
        return PiperTtsEngine(
          resolvePaths: (voiceId) =>
              ref.read(piperModelManagerProvider(voiceId)).piperConfigPaths(),
        );
    }
  };
});

/// 音色试听示范句：短、音素丰富、自然语调，贴合 App 场景。
const String kTtsPreviewText =
    'Hi, welcome to Echo Loop. Listen, speak, repeat. '
    'Keep going, and fluency will come.';

/// 某音色试听的发音项标识（供发音按钮/音色行显激活态，与普通发音 key 不冲突）。
String ttsVoicePreviewKey(String voiceId) => 'tts_preview:$voiceId';

/// 某音色「试听 / 预热」的发音配置——**单一来源**。
///
/// [previewVoice]（点击试听）与 [TtsController.prewarmVoicePreviews]（后台预热）
/// 必须用同一份配置，否则二者派生的 cacheKey 不一致、预热产物点击时命不中（本次修复
/// 的回归点）。把构造收成此函数，结构性保证 languageTag/voiceName/modelTag 逐字段对齐。
TtsSpeechConfig ttsVoicePreviewConfig(
  KokoroVoice voice,
  KokoroModelVariant variant,
) {
  return TtsSpeechConfig(
    languageTag: voice.accent == TtsAccent.uk ? 'en-GB' : 'en-US',
    voiceName: voice.id,
    modelTag: variant.name,
  );
}

/// 某口音试听的发音项标识（平台 TTS 口音行显激活态，与音色试听 key 不冲突）。
String ttsAccentPreviewKey(TtsAccent accent) =>
    'tts_preview_accent:${accent.name}';

/// Piper 某音色「试听」的发音配置。音色经 voiceName 显式传入（即独立模型 id），
/// 与 [TtsController.prewarmTexts] 无关；无 modelTag（Piper 缓存键按 voiceId 分桶）。
TtsSpeechConfig ttsPiperVoicePreviewConfig(PiperVoice voice) {
  return TtsSpeechConfig(
    languageTag: voice.accent == TtsAccent.uk ? 'en-GB' : 'en-US',
    voiceName: voice.id,
  );
}

/// 计算有效引擎：始终尊重用户选择。
///
/// 本地引擎模型未就绪时只触发下载，不回退系统语音。用户需要兜底时应主动选择
/// 平台 TTS，避免选中 Echo Loop/Balanced 时听到 Apple/System 语音。
TtsEngineKind effectiveTtsEngine(
  TtsEngineKind selected, {
  required bool kokoroReady,
  required bool piperReady,
}) {
  return selected;
}

/// 控制器运行态。
class TtsControllerState {
  /// 当前正在朗读项的标识（供发音按钮显激活态）；空闲为 null。
  final String? speakingKey;

  const TtsControllerState({this.speakingKey});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsControllerState &&
          runtimeType == other.runtimeType &&
          speakingKey == other.speakingKey;

  @override
  int get hashCode => speakingKey.hashCode;
}

class TtsController extends Notifier<TtsControllerState> {
  late final TtsCoordinator _coordinator;

  /// 上次重配时的 Kokoro 变体，用于检测变体切换以作废重建引擎。
  KokoroModelVariant? _lastVariant;

  /// 上次重配时的 Piper 音色，用于检测音色切换以作废重建引擎
  /// （Piper 换音色 = 换模型，必须重建 OfflineTts）。
  String? _lastPiperVoice;

  /// 试听预热代际：每次发起/取消预热递增，在途循环据此放弃过期任务
  /// （离开页面、切换变体时不再继续预热旧批次）。
  int _prewarmToken = 0;

  /// 当前在跑预热批次的签名（如 `echoLoop|fp32` / `platform`）。用于幂等防抖：
  /// 多个触发点（进页 postFrame + 就绪监听 + 变体监听）几乎同时调用时，同签名
  /// 批次只跑一次，避免后一次 [_prewarmToken] 自增把前一个健康批次掐断、反复重启
  /// 导致谁也跑不完。批次结束（正常/异常/取消）置回 null。
  String? _prewarmSignature;

  /// 发音 UI 状态代际。仅比较 speakingKey 无法区分「同一音色连续重播」的新旧调用，
  /// 旧调用完成时会误清掉新调用的小喇叭；每次发音/停止递增以精确归属复位权。
  int _speakingToken = 0;

  @override
  TtsControllerState build() {
    // DAO 惰性解析：渲染发音按钮不连库，首次发音时才触碰数据库。
    final cacheStore = TtsCacheStore(
      resolveDao: () => ref.read(ttsCacheDaoProvider),
      resolveCacheDir: getApplicationCacheDirectory,
    );
    _coordinator = TtsCoordinator(
      factory: ref.read(ttsEngineFactoryProvider),
      cacheStore: cacheStore,
      player: TtsPlayer(),
    );

    // 设置（引擎/口音/音色）或本地引擎就绪态变化 → 重算有效引擎并热重配。
    ref.listen<TtsSettings>(ttsSettingsProvider, (_, __) => _reconfigure());
    ref.listen<bool>(kokoroReadyProvider, (_, __) => _reconfigure());
    ref.listen<bool>(piperReadyProvider, (_, __) => _reconfigure());
    // 首次配置（仅记录目标，不创建引擎/不连库）。延到 build 之后执行：_reconfigure
    // 会触发本地引擎模型 ensureDownloaded（同步修改 kokoro/piperModelProvider 状态），
    // 在 build 期间直接调用会违反 Riverpod「初始化中不得修改其他 provider」。
    Future.microtask(_reconfigure);

    ref.onDispose(_coordinator.dispose);
    return const TtsControllerState();
  }

  /// 重算有效引擎：尊重用户选择；本地模型未就绪只后台触发下载，不回退平台 TTS。
  void _reconfigure() {
    final settings = ref.read(ttsSettingsProvider);
    final kokoroReady = ref.read(kokoroReadyProvider);
    final piperReady = ref.read(piperReadyProvider);
    // 后台自愈：选中本地引擎但模型未就绪（含 App 启动恢复、下载失败后）时，
    // fire-and-forget 触发下载（幂等：下载中/已就绪自动跳过）。发音仍保持用户
    // 选择的本地引擎；失败则静默返回，不用系统语音兜底。
    if (settings.engine == TtsEngineKind.echoLoop && !kokoroReady) {
      unawaited(
        ref
            .read(kokoroModelProvider.notifier)
            .ensureDownloaded(settings.kokoroVariant),
      );
    }
    if (settings.engine == TtsEngineKind.piper && !piperReady) {
      unawaited(
        ref
            .read(piperModelProvider.notifier)
            .ensureDownloaded(settings.activePiperVoice),
      );
    }
    final effective = effectiveTtsEngine(
      settings.engine,
      kokoroReady: kokoroReady,
      piperReady: piperReady,
    );
    // Kokoro 模型变体切换（两变体均已就绪、引擎种类不变）时，作废旧引擎使下次发音
    // 用新变体模型重建（configure 只热更新配置、不会重建引擎）。
    if (effective == TtsEngineKind.echoLoop &&
        _lastVariant != null &&
        _lastVariant != settings.kokoroVariant) {
      unawaited(_coordinator.invalidateEngine());
    }
    _lastVariant = settings.kokoroVariant;
    // Piper 音色切换（引擎种类不变）时同理作废重建——Piper 换音色 = 换独立模型。
    if (effective == TtsEngineKind.piper &&
        _lastPiperVoice != null &&
        _lastPiperVoice != settings.activePiperVoice) {
      unawaited(_coordinator.invalidateEngine());
    }
    _lastPiperVoice = settings.activePiperVoice;
    // 配置须匹配用户选中的有效引擎；本地引擎即使模型未就绪也保留 voiceName/modelTag，
    // 使下载完成后的后续发音直接落入正确缓存桶。
    final config = TtsSpeechConfig(
      languageTag: settings.languageTag,
      voiceName: switch (effective) {
        TtsEngineKind.echoLoop => settings.activeKokoroVoice,
        TtsEngineKind.piper => settings.activePiperVoice,
        TtsEngineKind.platform => null,
      },
      modelTag: effective == TtsEngineKind.echoLoop
          ? settings.kokoroVariant.name
          : null,
    );
    _coordinator.configure(effective, config);
  }

  /// 发音 [text]。[key] 标识发音项（默认用文本本身），供按钮激活态匹配。
  ///
  /// fire-and-forget 调用方无需 await；连续调用由协调器打断重播。
  Future<void> speak(String text, {String? key}) async {
    final k = key ?? text;
    final token = ++_speakingToken;
    state = TtsControllerState(speakingKey: k);
    try {
      final ok = await _coordinator.speak(text);
      AppLogger.log('TtsController', 'speak 返回 $ok key=$k');
    } catch (e, st) {
      // fire-and-forget 调用方不会捕获，必须在此落日志，避免静默吞异常。
      AppLogger.log('TtsController', '✗ speak 异常: $e\n$st');
    }
    // 仅当未被新发音抢占时才复位（被抢占时 speakingKey 已变）。
    if (token == _speakingToken && state.speakingKey == k) {
      state = const TtsControllerState();
    }
  }

  /// 试听某 Kokoro 音色：用该音色（及其口音、当前模型变体）朗读示范句。
  ///
  /// 命中预热缓存则秒播；未命中则即时合成。设 [speakingKey] 为该音色的试听 key，
  /// 供音色行显播放态。仅 Echo Loop 场景调用（音色弹层只在模型就绪时显示）。
  Future<void> previewVoice(KokoroVoice voice) async {
    final variant = ref.read(ttsSettingsProvider).kokoroVariant;
    final config = ttsVoicePreviewConfig(voice, variant);
    final key = ttsVoicePreviewKey(voice.id);
    final token = ++_speakingToken;
    state = TtsControllerState(speakingKey: key);
    try {
      await _coordinator.speakWith(
        kTtsPreviewText,
        TtsEngineKind.echoLoop,
        config,
      );
    } catch (e, st) {
      AppLogger.log('TtsController', '✗ previewVoice 异常: $e\n$st');
    }
    // 仅当未被新发音抢占时才复位（被抢占时 speakingKey 已变）。
    if (token == _speakingToken && state.speakingKey == key) {
      state = const TtsControllerState();
    }
  }

  /// 试听某 Piper 音色：用该音色朗读示范句。
  ///
  /// 命中缓存则秒播；未命中即时合成（首字有可感知延迟，Piper RTF≈0.1~0.3）。设
  /// [speakingKey] 为该音色的试听 key（与 Kokoro 复用同一命名空间，voiceId 不冲突），
  /// 供音色行显播放态。调用方须先确保该音色模型已下载（未下载则合成返回 null 静默）。
  Future<void> previewPiperVoice(PiperVoice voice) async {
    final config = ttsPiperVoicePreviewConfig(voice);
    final key = ttsVoicePreviewKey(voice.id);
    final token = ++_speakingToken;
    state = TtsControllerState(speakingKey: key);
    try {
      await _coordinator.speakWith(
        kTtsPreviewText,
        TtsEngineKind.piper,
        config,
      );
    } catch (e, st) {
      AppLogger.log('TtsController', '✗ previewPiperVoice 异常: $e\n$st');
    }
    if (token == _speakingToken && state.speakingKey == key) {
      state = const TtsControllerState();
    }
  }

  /// 试听某口音（平台 TTS）：用该口音朗读示范句。
  ///
  /// 命中预热缓存秒播；未命中即时合成（macOS 上 synthesize 返回 null → 协调器降级
  /// 实时朗读，口音仍生效）。设 [speakingKey] 为该口音试听 key，供口音行显播放态。
  /// 仅平台 TTS 场景调用（口音行只在平台引擎下显示）。
  Future<void> previewAccent(TtsAccent accent) async {
    final config = TtsSpeechConfig(
      languageTag: accent == TtsAccent.uk ? 'en-GB' : 'en-US',
    );
    final key = ttsAccentPreviewKey(accent);
    final token = ++_speakingToken;
    state = TtsControllerState(speakingKey: key);
    try {
      await _coordinator.speakWith(
        kTtsPreviewText,
        TtsEngineKind.platform,
        config,
      );
    } catch (e, st) {
      AppLogger.log('TtsController', '✗ previewAccent 异常: $e\n$st');
    }
    // 仅当未被新发音抢占时才复位（被抢占时 speakingKey 已变）。
    if (token == _speakingToken && state.speakingKey == key) {
      state = const TtsControllerState();
    }
  }

  /// 后台预热平台 TTS 两个口音的试听片段（fire-and-forget、命中缓存即跳过）。
  ///
  /// 仅在选中平台 TTS 时执行（平台引擎无需模型，恒就绪）。与 [prewarmVoicePreviews]
  /// 共用 [_prewarmToken]：离开页面/切引擎（[cancelVoicePreviewPrewarm] 或重发）后
  /// 旧批次自动停止。失败静默（与发音一致），不阻塞、不弹窗。macOS 上 synthesize 返回
  /// null 不入库（试听时降级实时朗读），属预期。
  Future<void> prewarmAccentPreviews() async {
    final settings = ref.read(ttsSettingsProvider);
    if (settings.engine != TtsEngineKind.platform) {
      AppLogger.log('TtsController', '预热跳过：engine!=platform');
      return;
    }

    // 幂等：同签名批次已在跑则不重启（不 bump token），避免触发点竞相自增掐断。
    const signature = 'platform';
    if (_prewarmSignature == signature) {
      AppLogger.log('TtsController', '预热跳过：同批次已在跑 $signature');
      return;
    }
    final token = ++_prewarmToken;
    _prewarmSignature = signature;
    AppLogger.log(
      'TtsController',
      '预热开始 engine=platform token=$token accents=${TtsAccent.values.length}',
    );
    var done = 0;
    try {
      for (var i = 0; i < TtsAccent.values.length; i++) {
        if (token != _prewarmToken) {
          AppLogger.log('TtsController', '预热被取消 token=$token');
          return; // 已被取消/重发：停止旧批次
        }
        final accent = TtsAccent.values[i];
        final config = TtsSpeechConfig(
          languageTag: accent == TtsAccent.uk ? 'en-GB' : 'en-US',
        );
        AppLogger.log(
          'TtsController',
          '预热[${i + 1}/${TtsAccent.values.length}] accent=${accent.name}',
        );
        try {
          await _coordinator.prewarm(
            kTtsPreviewText,
            TtsEngineKind.platform,
            config,
          );
          done++;
        } catch (e, st) {
          AppLogger.log(
            'TtsController',
            '✗ prewarm accent 异常 ${accent.name}: $e\n$st',
          );
        }
      }
      AppLogger.log('TtsController', '预热完成 $done 个 (platform)');
    } finally {
      // 仅当签名仍是本批次时清空（被新批次接管则不动）。
      if (_prewarmSignature == signature) _prewarmSignature = null;
    }
  }

  /// 后台预热全部音色的试听片段（fire-and-forget、低优先、命中缓存即跳过）。
  ///
  /// 仅在选中 Echo Loop 且模型就绪时执行；按当前模型变体逐个合成入库，供进设置页
  /// 后即时试听。顺序 await（worker 本就串行），每轮校验 [_prewarmToken]，离开页面/
  /// 切变体后旧批次自动停止。失败静默（与发音一致），不阻塞、不弹窗。
  Future<void> prewarmVoicePreviews() async {
    final settings = ref.read(ttsSettingsProvider);
    final ready = ref.read(kokoroReadyProvider);
    final variant = settings.kokoroVariant;
    if (settings.engine != TtsEngineKind.echoLoop) {
      AppLogger.log('TtsController', '预热跳过：engine!=echoLoop');
      return;
    }
    if (!ready) {
      AppLogger.log('TtsController', '预热跳过：模型未就绪 variant=${variant.name}');
      return;
    }

    // 幂等：同签名（引擎+变体）批次已在跑则不重启，避免触发点竞相 bump token 掐断。
    final signature = 'echoLoop|${variant.name}';
    if (_prewarmSignature == signature) {
      AppLogger.log('TtsController', '预热跳过：同批次已在跑 $signature');
      return;
    }
    final token = ++_prewarmToken;
    _prewarmSignature = signature;
    AppLogger.log(
      'TtsController',
      '预热开始 engine=echoLoop variant=${variant.name} token=$token '
          'voices=${kokoroVoices.length}',
    );
    var done = 0;
    try {
      for (var i = 0; i < kokoroVoices.length; i++) {
        if (token != _prewarmToken) {
          AppLogger.log('TtsController', '预热被取消 token=$token');
          return; // 已被取消/重发：停止旧批次
        }
        final voice = kokoroVoices[i];
        final config = ttsVoicePreviewConfig(voice, variant);
        AppLogger.log(
          'TtsController',
          '预热[${i + 1}/${kokoroVoices.length}] voice=${voice.id}',
        );
        try {
          await _coordinator.prewarm(
            kTtsPreviewText,
            TtsEngineKind.echoLoop,
            config,
          );
          done++;
        } catch (e, st) {
          AppLogger.log(
            'TtsController',
            '✗ prewarm 异常 voice=${voice.id}: $e\n$st',
          );
        }
      }
      AppLogger.log('TtsController', '预热完成 $done 个 ($signature)');
    } finally {
      // 仅当签名仍是本批次时清空（被新批次接管则不动）。
      if (_prewarmSignature == signature) _prewarmSignature = null;
    }
  }

  /// 后台预热**当前选中** Piper 音色的试听片段（fire-and-forget、命中缓存即跳过）。
  ///
  /// 与 Kokoro 不同：Piper 每音色是独立模型、换音色需重载，批量预热不经济，故只预热
  /// 当前选中音色（其模型正是引擎已加载的那个）。进页 / 切到 Piper / 模型就绪后调用，
  /// 使点击当前音色行即秒播；其余音色仍走点击 on-demand 合成。
  ///
  /// 仅在选中 Piper 且当前音色就绪时执行。与其它预热共用 [_prewarmToken]/
  /// [_prewarmSignature]：离开页面/切换后旧批次自动停止、同签名不重复跑。
  Future<void> prewarmActivePiperVoice() async {
    final settings = ref.read(ttsSettingsProvider);
    final ready = ref.read(piperReadyProvider);
    if (settings.engine != TtsEngineKind.piper) {
      AppLogger.log('TtsController', '预热跳过：engine!=piper');
      return;
    }
    if (!ready) {
      AppLogger.log(
        'TtsController',
        '预热跳过：Piper 音色未就绪 ${settings.activePiperVoice}',
      );
      return;
    }
    final voice = piperVoiceById(settings.activePiperVoice);
    if (voice == null) return;

    // 幂等：同签名（引擎+音色）批次已在跑则不重启，避免触发点竞相 bump token 掐断。
    final signature = 'piper|${voice.id}';
    if (_prewarmSignature == signature) {
      AppLogger.log('TtsController', '预热跳过：同批次已在跑 $signature');
      return;
    }
    final token = ++_prewarmToken;
    _prewarmSignature = signature;
    AppLogger.log(
      'TtsController',
      '预热开始 engine=piper voice=${voice.id} token=$token',
    );
    try {
      if (token != _prewarmToken) return; // 已被取消/重发
      final config = ttsPiperVoicePreviewConfig(voice);
      try {
        await _coordinator.prewarm(
          kTtsPreviewText,
          TtsEngineKind.piper,
          config,
        );
        AppLogger.log('TtsController', '预热完成 ($signature)');
      } catch (e, st) {
        AppLogger.log(
          'TtsController',
          '✗ prewarm piper 异常 voice=${voice.id}: $e\n$st',
        );
      }
    } finally {
      // 仅当签名仍是本批次时清空（被新批次接管则不动）。
      if (_prewarmSignature == signature) _prewarmSignature = null;
    }
  }

  /// 取消在途试听预热（音色与口音共用，离开设置页时调用），使预热循环下轮即停。
  void cancelVoicePreviewPrewarm() {
    _prewarmToken++;
    _prewarmSignature = null;
  }

  /// 批量文本预热代际：每次发起/取消递增，在途循环据此放弃过期批次。
  /// 与试听预热的 [_prewarmToken] **相互独立**。
  ///
  /// 词典弹窗与收藏词汇页共用此 token：二者不会同时可见，且预热仅为优化，
  /// 偶发互相取消可接受（如从收藏页单词打开词典弹窗，弹窗预热接管，关闭后
  /// 收藏页下次 rebuild 重新触发，届时多已缓存）。
  int _textsPrewarmToken = 0;

  /// 后台预热一批文本（如词典「单词 + 例句」、收藏「单词 + 意群」，按显示顺序）。
  ///
  /// fire-and-forget、背景优先、命中缓存即跳过；用当前选中引擎/配置合成（经
  /// [TtsCoordinator.prewarmCurrent]），与点击发音 [speak] 同源，保证 cacheKey 一致、
  /// 点击即命中。顺序 await（worker 本就串行），每轮校验 [_textsPrewarmToken]，页面
  /// 离开后旧批次自动停止。失败静默（与发音一致），不阻塞、不弹窗。
  Future<void> prewarmTexts(List<String> texts) async {
    final token = ++_textsPrewarmToken;
    for (final text in texts) {
      if (token != _textsPrewarmToken) return; // 已取消/被新批次接管：停止旧批次
      if (text.trim().isEmpty) continue;
      try {
        await _coordinator.prewarmCurrent(text);
      } catch (e, st) {
        AppLogger.log('TtsController', '✗ texts prewarm 异常: $e\n$st');
      }
    }
  }

  /// 取消在途批量文本预热（页面离开时调用），使预热循环下轮即停。
  void cancelTextsPrewarm() {
    _textsPrewarmToken++;
  }

  /// 停止当前发音。
  ///
  /// 先停协调器（实际音频），再复位状态——即便复位时遇异常（如离开页面 dispose 期
  /// 的 provider 约束），也已确保音频被停掉，不会让试听例子继续播到尾。
  Future<void> stop() async {
    _speakingToken++;
    await _coordinator.stop();
    state = const TtsControllerState();
  }

  /// 指定 [key] 是否正在朗读（供发音按钮）。
  bool isSpeaking(String key) => state.speakingKey == key;
}

/// 统一 TTS 控制器 Provider 入口。
final ttsControllerProvider =
    NotifierProvider<TtsController, TtsControllerState>(TtsController.new);
