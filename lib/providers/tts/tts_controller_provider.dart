/// 统一 TTS 控制器 Provider
///
/// 全应用唯一的发音入口。持有纯 Dart [TtsCoordinator]（引擎选择 + 缓存 + 播放 +
/// 防竞态），监听 [ttsSettingsProvider] 在引擎/口音变化时热重配。
///
/// 所有发音调用点（闪卡 / 收藏 / 词典单词 / 词典例句）统一
/// 通用文本朗读应经 `textPlaybackProvider` 分流；本控制器仅承接
/// 离线发音未命中或本地播放失败后的 TTS 缓存/生成。
/// [TtsControllerState.speakingKey] 暴露当前正在朗读项，供发音按钮显激活态。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../database/providers.dart';
import '../../services/app_logger.dart';
import '../../services/pronunciation/local_audio_clip_player.dart';
import '../../services/tts/kokoro_tts_engine.dart';
import '../../services/tts/kokoro_model_catalog.dart';
import '../../services/tts/kokoro_voices.dart';
import '../../services/tts/piper_tts_engine.dart';
import '../../services/tts/piper_model_catalog.dart';
import '../../services/tts/platform_tts_engine.dart';
import '../../services/tts/tts_cache_store.dart';
import '../../services/tts/tts_coordinator.dart';
import '../../services/tts/tts_engine.dart';
import '../../widgets/tts/tts_model_download_prompt_dialog.dart';
import '../short_audio_player_provider.dart';
import 'kokoro_model_provider.dart';
import 'piper_model_provider.dart';
import 'tts_settings_provider.dart';

/// TTS 引擎工厂 Provider。
///
/// 默认按种类创建真实引擎；测试可 override 注入 mock 引擎。
final ttsEngineFactoryProvider = Provider<TtsEngineFactory>((ref) {
  return (kind, config) {
    switch (kind) {
      case TtsEngineKind.platform:
        return PlatformTtsEngine();
      case TtsEngineKind.kokoro:
        // 模型路径在引擎首次合成时惰性解析：按当前选中变体取对应管理器，
        // 仅在该变体模型就绪后才会被构造。
        return KokoroTtsEngine(
          resolvePaths: () {
            final variant = switch (config.modelTag) {
              'int8' => KokoroModelVariant.int8,
              _ => KokoroModelVariant.fp32,
            };
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
    languageTag: switch (voice.language) {
      TtsLanguage.chinese => 'zh-CN',
      TtsLanguage.english => voice.accent == TtsAccent.uk ? 'en-GB' : 'en-US',
    },
    voiceName: voice.id,
    modelTag: kokoroSpecOf(variant).id,
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

  /// 已完成的协调器配置版本；供预热调用方在首次异步配置完成后重新提交可见文本。
  final int configurationVersion;

  const TtsControllerState({this.speakingKey, this.configurationVersion = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsControllerState &&
          runtimeType == other.runtimeType &&
          speakingKey == other.speakingKey &&
          configurationVersion == other.configurationVersion;

  @override
  int get hashCode => Object.hash(speakingKey, configurationVersion);
}

class TtsController extends Notifier<TtsControllerState> {
  late final TtsCoordinator _coordinator;

  /// 直接读取 notifier 时也先触发 provider build，保证协调器已构造。
  TtsCoordinator get _readyCoordinator {
    state;
    return _coordinator;
  }

  /// 试听预热代际：每次发起/取消预热递增，在途循环据此放弃过期任务
  /// （离开页面、切换变体时不再继续预热旧批次）。
  int _prewarmToken = 0;

  /// 当前在跑预热批次的签名（如 `kokoro|fp32` / `platform`）。用于幂等防抖：
  /// 多个触发点（进页 postFrame + 就绪监听 + 变体监听）几乎同时调用时，同签名
  /// 批次只跑一次，避免后一次 [_prewarmToken] 自增把前一个健康批次掐断、反复重启
  /// 导致谁也跑不完。批次结束（正常/异常/取消）置回 null。
  String? _prewarmSignature;

  /// 当前引擎 warmup 屏障。相同配置的播放、试听和后台预热共享一次模型加载。
  Future<bool>? _currentWarmup;
  String? _currentWarmupSignature;

  /// 发音 UI 状态代际。仅比较 speakingKey 无法区分「同一音色连续重播」的新旧调用，
  /// 旧调用完成时会误清掉新调用的小喇叭；每次发音/停止递增以精确归属复位权。
  int _speakingToken = 0;

  /// 每次协调器拿到有效配置递增；不能从 [state] 反推，发音状态会在期间变化。
  int _configurationVersion = 0;

  TtsControllerState _stateWithSpeaking(String? speakingKey) =>
      TtsControllerState(
        speakingKey: speakingKey,
        configurationVersion: _configurationVersion,
      );

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
      player: ref.read(shortAudioPlayerProvider),
    );

    // 设置（引擎/口音/音色）或本地引擎就绪态变化 → 重算有效引擎并热重配。
    ref.listen<TtsSettings>(ttsSettingsProvider, (_, __) => _reconfigure());
    ref.listen<bool>(kokoroReadyProvider, (_, isReady) {
      _reconfigure();
      if (isReady) unawaited(warmUpCurrentEngine());
    });
    ref.listen<bool>(piperReadyProvider, (_, isReady) {
      _reconfigure();
      if (isReady) unawaited(warmUpCurrentEngine());
    });
    // 首次配置只记录目标，不创建引擎/不连库；实际加载统一由模型 ready 门控触发。
    // 延到 build 之后执行，避免在 build 期间修改其它 provider。
    Future.microtask(_reconfigure);

    ref.onDispose(_coordinator.dispose);
    return const TtsControllerState();
  }

  /// 重算有效引擎：尊重用户选择；本地模型未就绪只后台触发下载，不回退平台 TTS。
  void _reconfigure() {
    final settings = ref.read(ttsSettingsProvider);
    final kokoroReady = ref.read(kokoroReadyProvider);
    final piperReady = ref.read(piperReadyProvider);
    // 本地模型只由设置页显式下载或首次用户发音门控触发，不在 controller
    // 创建/重配置时隐式下载，避免预热或页面构建提前改变模型状态。
    final effective = effectiveTtsEngine(
      settings.engine,
      kokoroReady: kokoroReady,
      piperReady: piperReady,
    );
    // Kokoro 变体、Piper 音色和引擎切换均由协调器根据配置目标统一处理。
    // 配置须匹配用户选中的有效引擎；本地引擎即使模型未就绪也保留 voiceName/modelTag，
    // 使下载完成后的后续发音直接落入正确缓存桶。
    final config = TtsSpeechConfig(
      languageTag: settings.languageTag,
      voiceName: switch (effective) {
        TtsEngineKind.kokoro => settings.activeKokoroVoice,
        TtsEngineKind.piper => settings.activePiperVoice,
        TtsEngineKind.platform => null,
      },
      speed: settings.speed,
      modelTag: effective == TtsEngineKind.kokoro
          ? kokoroSpecOf(settings.kokoroVariant).id
          : null,
    );
    _readyCoordinator.configure(effective, config);
    // configure 在第一个 await 前同步记录目标参数；此版本变更通知已创建的可见 tile
    // 再次提交预热，避免首次 post-frame 早于异步初始配置时遗漏。
    _configurationVersion++;
    state = _stateWithSpeaking(state.speakingKey);
  }

  /// 发音 [text] 并返回真实播放终态。[key] 标识发音项。
  ///
  /// 协调器当前返回 bool；控制器结合自身 speaking token 将被新请求抢占的
  /// 旧结果区分为 [AudioPlaybackResult.cancelled]，避免上层把失败误记为完成。
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
  }) async {
    // 必须在模型检查前登记代际：模型加载/弹窗等待期间关闭词典时，stop()
    // 递增代际，旧请求回来后不得再继续设置播放状态或启动协调器。
    final token = ++_speakingToken;
    final k = key ?? text;
    try {
      if (!await ensureTtsModelReadyForPlayback(ref)) {
        return _resultForToken(token, success: false);
      }
      if (token != _speakingToken) return AudioPlaybackResult.cancelled;
      if (!await warmUpCurrentEngine()) {
        return _resultForToken(token, success: false);
      }
      if (token != _speakingToken) return AudioPlaybackResult.cancelled;
      state = _stateWithSpeaking(k);
      final ok = await _readyCoordinator.speak(text);
      final result = _resultForToken(token, success: ok);
      AppLogger.log('TtsController', '用户发音结束：$result 缓存键=$k');
      return result;
    } catch (error, stackTrace) {
      AppLogger.log('TtsController', '✗ 用户发音异常：$error\n$stackTrace');
      return _resultForToken(token, success: false);
    } finally {
      // 仅当未被新发音抢占时才复位，被抢占时 speakingKey 已归新请求所有。
      if (token == _speakingToken && state.speakingKey == k) {
        state = _stateWithSpeaking(null);
      }
    }
  }

  /// 保留普通发音调用方的 fire-and-forget 入口，实际播放逻辑只有结果型实现一套。
  Future<void> speak(String text, {String? key}) async {
    await speakWithResult(text, key: key);
  }

  AudioPlaybackResult _resultForToken(int token, {required bool success}) {
    if (token != _speakingToken) return AudioPlaybackResult.cancelled;
    return success ? AudioPlaybackResult.completed : AudioPlaybackResult.failed;
  }

  /// 暴露统一协调器给需要后台产文件的系统能力（Text → Lesson）。
  ///
  /// UI 仍不得直接依赖 sherpa_onnx；调用方只消费协调器的缓存/调度能力。
  TtsCoordinator get coordinator => _readyCoordinator;

  /// 试听某 Kokoro 音色：用该音色（及其口音、当前模型变体）朗读示范句。
  ///
  /// 命中预热缓存则秒播；未命中则即时合成。设 [speakingKey] 为该音色的试听 key，
  /// 供音色行显播放态。仅 Echo Loop 场景调用（音色弹层只在模型就绪时显示）。
  Future<void> previewVoice(KokoroVoice voice) async {
    final variant = ref.read(ttsSettingsProvider).kokoroVariant;
    final key = ttsVoicePreviewKey(voice.id);
    final token = ++_speakingToken;
    state = _stateWithSpeaking(key);
    if (!await ensureTtsModelReadyForConfig(
      ref,
      engine: TtsEngineKind.kokoro,
      kokoroVariant: variant,
    )) {
      if (token == _speakingToken && state.speakingKey == key) {
        state = _stateWithSpeaking(null);
      }
      return;
    }
    final config = ttsVoicePreviewConfig(voice, variant);
    if (!await _ensureEngineReady(
      TtsEngineKind.kokoro,
      config,
      signature: 'kokoro|${variant.name}',
    )) {
      if (token == _speakingToken && state.speakingKey == key) {
        state = _stateWithSpeaking(null);
      }
      return;
    }
    try {
      await _readyCoordinator.speakWith(
        kTtsPreviewText,
        TtsEngineKind.kokoro,
        config,
      );
    } catch (e, st) {
      AppLogger.log('TtsController', '✗ previewVoice 异常: $e\n$st');
    }
    // 仅当未被新发音抢占时才复位（被抢占时 speakingKey 已变）。
    if (token == _speakingToken && state.speakingKey == key) {
      state = _stateWithSpeaking(null);
    }
  }

  /// 试听某 Piper 音色：用该音色朗读示范句。
  ///
  /// 命中缓存则秒播；未命中即时合成（首字有可感知延迟，Piper RTF≈0.1~0.3）。设
  /// [speakingKey] 为该音色的试听 key（与 Kokoro 复用同一命名空间，voiceId 不冲突），
  /// 供音色行显播放态。调用方须先确保该音色模型已下载（未下载则合成返回 null 静默）。
  Future<void> previewPiperVoice(PiperVoice voice) async {
    final key = ttsVoicePreviewKey(voice.id);
    final token = ++_speakingToken;
    state = _stateWithSpeaking(key);
    if (!await ensureTtsModelReadyForConfig(
      ref,
      engine: TtsEngineKind.piper,
      piperVoiceId: voice.id,
    )) {
      if (token == _speakingToken && state.speakingKey == key) {
        state = _stateWithSpeaking(null);
      }
      return;
    }
    final config = ttsPiperVoicePreviewConfig(voice);
    if (!await _ensureEngineReady(
      TtsEngineKind.piper,
      config,
      signature: 'piper|${voice.id}',
    )) {
      if (token == _speakingToken && state.speakingKey == key) {
        state = _stateWithSpeaking(null);
      }
      return;
    }
    try {
      await _readyCoordinator.speakWith(
        kTtsPreviewText,
        TtsEngineKind.piper,
        config,
      );
    } catch (e, st) {
      AppLogger.log('TtsController', '✗ previewPiperVoice 异常: $e\n$st');
    }
    if (token == _speakingToken && state.speakingKey == key) {
      state = _stateWithSpeaking(null);
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
    state = _stateWithSpeaking(key);
    try {
      await _readyCoordinator.speakWith(
        kTtsPreviewText,
        TtsEngineKind.platform,
        config,
      );
    } catch (e, st) {
      AppLogger.log('TtsController', '✗ previewAccent 异常: $e\n$st');
    }
    // 仅当未被新发音抢占时才复位（被抢占时 speakingKey 已变）。
    if (token == _speakingToken && state.speakingKey == key) {
      state = _stateWithSpeaking(null);
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
          await _readyCoordinator.prewarm(
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
    AppLogger.log(
      'TtsController',
      '预热门控检查 engine=${settings.engine.diagnosticName} '
          'variant=${variant.name} ready=$ready '
          'status=${ref.read(kokoroModelProvider).of(variant).downloadStatus}',
    );
    if (settings.engine != TtsEngineKind.kokoro) {
      AppLogger.log('TtsController', '预热跳过：engine!=kokoro');
      return;
    }
    if (!ready) {
      AppLogger.log('TtsController', '预热跳过：模型未就绪 variant=${variant.name}');
      return;
    }

    if (!await warmUpCurrentEngine()) return;

    // 幂等：同签名（引擎+变体）批次已在跑则不重启，避免触发点竞相 bump token 掐断。
    final signature = 'kokoro|${variant.name}';
    if (_prewarmSignature == signature) {
      AppLogger.log('TtsController', '预热跳过：同批次已在跑 $signature');
      return;
    }
    final token = ++_prewarmToken;
    _prewarmSignature = signature;
    AppLogger.log(
      'TtsController',
      '预热开始 engine=kokoro variant=${variant.name} token=$token '
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
          await _readyCoordinator.prewarm(
            kTtsPreviewText,
            TtsEngineKind.kokoro,
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
    if (!await warmUpCurrentEngine()) return;

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
        await _readyCoordinator.prewarm(
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
    final previousToken = _prewarmToken;
    final previousSignature = _prewarmSignature;
    _prewarmToken++;
    _prewarmSignature = null;
    AppLogger.log(
      'TtsController',
      '取消试听预热：批次=$previousToken→$_prewarmToken '
          '签名=${previousSignature ?? 'none'}',
    );
  }

  /// 批量文本预热代际：每次发起/取消递增，在途循环据此放弃过期批次。
  /// 与试听预热的 [_prewarmToken] **相互独立**。
  ///
  /// 词典弹窗与收藏词汇页共用此 token：二者不会同时可见，且预热仅为优化，
  /// 偶发互相取消可接受（如从收藏页单词打开词典弹窗，弹窗预热接管，关闭后
  /// 收藏页下次 rebuild 重新触发，届时多已缓存）。
  int _textsPrewarmToken = 0;

  /// 已提交过后台预热的文本（增量预热去重，切词/关闭时清空）。
  final Set<String> _incrementalPrewarmed = {};

  /// 后台预热一批文本（如词典「单词 + 例句」、收藏「单词 + 意群」，按显示顺序）。
  ///
  /// fire-and-forget、背景优先、命中缓存即跳过；用当前选中引擎/配置合成（经
  /// [TtsCoordinator.prewarmCurrent]），与点击发音 [speak] 同源，保证 cacheKey 一致、
  /// 点击即命中。顺序 await（worker 本就串行），每轮校验 [_textsPrewarmToken]，页面
  /// 离开后旧批次自动停止。失败静默（与发音一致），不阻塞、不弹窗。
  Future<void> prewarmTexts(List<String> texts) async {
    if (!await warmUpCurrentEngine()) return;
    final token = ++_textsPrewarmToken;
    for (final text in texts) {
      if (token != _textsPrewarmToken) return; // 已取消/被新批次接管：停止旧批次
      if (text.trim().isEmpty) continue;
      try {
        await _readyCoordinator.prewarmCurrent(text);
      } catch (e, st) {
        AppLogger.log('TtsController', '✗ 批量文本预热异常：$e\n$st');
      }
    }
  }

  /// 增量预热：只对尚未提交过的新文本各触发一次幂等合成，不重置批次 token，
  /// 不打断已在推进的预热。供流式词典逐帧调用——每帧传当前完整可发音列表，
  /// 已提交的自动跳过，只有新出现的例句真正进合成队列。
  ///
  /// 与 [prewarmTexts]（一次性全量、`++token` 重置）不同：此处沿用当前 token，
  /// [_incrementalPrewarmed] 在同步段去重（每条只提交一次），多帧并发调用互不
  /// 重复提交；worker 串行由协调器内部排队。取消经 [cancelTextsPrewarm] 统一处理。
  Future<void> prewarmTextsIncremental(List<String> texts) async {
    final token = _textsPrewarmToken; // 沿用当前，不 ++
    if (!_readyCoordinator.isConfigured) {
      AppLogger.log(
        'TtsController',
        '增量文本预热跳过：TTS 尚未配置 '
            '批次=$token 请求数=${texts.length} 已提交=${_incrementalPrewarmed.length}',
      );
      return;
    }
    if (!await warmUpCurrentEngine()) return;
    if (token != _textsPrewarmToken) return;
    var accepted = 0;
    var skipped = 0;
    for (final text in texts) {
      if (text.trim().isEmpty) {
        skipped++;
        continue;
      }
      // 初始配置在 build 后的 microtask 中落定。未配置时不能占用 seen，否则
      // 收藏 tile 即使在配置完成后重提，也会被误判为已提交。
      if (!_readyCoordinator.isConfigured) {
        AppLogger.log(
          'TtsController',
          '增量文本预热跳过：TTS 尚未配置 '
              '批次=$token 请求数=${texts.length} 已提交=${_incrementalPrewarmed.length}',
        );
        return;
      }
      if (!_incrementalPrewarmed.add(text)) {
        skipped++;
        continue;
      }
      accepted++;
      try {
        await _readyCoordinator.prewarmCurrent(text);
      } catch (e, st) {
        AppLogger.log('TtsController', '✗ 增量预热异常: $e\n$st');
      }
      if (token != _textsPrewarmToken) {
        AppLogger.log(
          'TtsController',
          '增量文本预热已取消：旧批次=$token 本次已提交=$accepted '
              '当前已提交=${_incrementalPrewarmed.length}',
        );
        return;
      }
    }
    AppLogger.log(
      'TtsController',
      '增量文本预热处理完成：批次=$token 请求数=${texts.length} '
          '新提交=$accepted 跳过=$skipped 当前已提交=${_incrementalPrewarmed.length}',
    );
  }

  /// 取消在途批量文本预热（页面离开时调用），使预热循环下轮即停。
  ///
  /// 同时清空增量预热去重集合，使切词/关闭后新一轮从头预热。
  void cancelTextsPrewarm() {
    final previousToken = _textsPrewarmToken;
    final seen = _incrementalPrewarmed.length;
    _textsPrewarmToken++;
    _incrementalPrewarmed.clear();
    AppLogger.log(
      'TtsController',
      '取消文本预热：批次=$previousToken→$_textsPrewarmToken 已清除提交记录=$seen',
    );
    _readyCoordinator.cancelPendingPrewarm();
  }

  /// 后台加载当前模型实例，不合成文本；供收藏词汇 Tab 降低首次未命中延迟。
  Future<bool> warmUpCurrentEngine() {
    final settings = ref.read(ttsSettingsProvider);
    final signature = _warmupSignature(settings);
    final inFlight = _currentWarmup;
    if (inFlight != null && _currentWarmupSignature == signature) {
      AppLogger.log('TtsController', '模型预热复用进行中的加载：目标=$signature');
      return inFlight;
    }

    final future = _warmUpCurrentEngine(settings);
    _currentWarmupSignature = signature;
    _currentWarmup = future;
    _trackWarmup(future, signature);
    return future;
  }

  String _warmupSignature(TtsSettings settings) {
    return switch (settings.engine) {
      TtsEngineKind.platform => 'platform',
      TtsEngineKind.kokoro => 'kokoro|${settings.kokoroVariant.name}',
      TtsEngineKind.piper => 'piper|${settings.activePiperVoice}',
    };
  }

  Future<bool> _warmUpCurrentEngine(TtsSettings settings) async {
    AppLogger.log('TtsController', '请求预热当前 TTS 模型（不合成文本）');
    try {
      final ready = await isTtsModelReadyForConfig(
        ref,
        engine: settings.engine,
        kokoroVariant: settings.kokoroVariant,
        piperVoiceId: settings.activePiperVoice,
      );
      if (!ready) {
        AppLogger.log('TtsController', '后台模型预热跳过：当前模型未就绪');
        return false;
      }
      final config = TtsSpeechConfig(
        languageTag: settings.languageTag,
        voiceName: switch (settings.engine) {
          TtsEngineKind.kokoro => settings.activeKokoroVoice,
          TtsEngineKind.piper => settings.activePiperVoice,
          TtsEngineKind.platform => null,
        },
        speed: settings.speed,
        modelTag: settings.engine == TtsEngineKind.kokoro
            ? kokoroSpecOf(settings.kokoroVariant).id
            : null,
      );
      final loaded = await _readyCoordinator.ensureEngineReady(
        settings.engine,
        config,
      );
      AppLogger.log(
        'TtsController',
        '后台模型预热结果 target=${_warmupSignature(settings)} loaded=$loaded',
      );
      return loaded;
    } catch (e, st) {
      AppLogger.log('TtsController', '✗ 模型预热异常：$e\n$st');
      return false;
    }
  }

  Future<bool> _ensureEngineReady(
    TtsEngineKind kind,
    TtsSpeechConfig config, {
    required String signature,
  }) async {
    final inFlight = _currentWarmup;
    if (inFlight != null && _currentWarmupSignature == signature) {
      return inFlight;
    }
    final future = _readyCoordinator.ensureEngineReady(kind, config);
    _currentWarmupSignature = signature;
    _currentWarmup = future;
    _trackWarmup(future, signature);
    return future;
  }

  /// 记录共享的引擎加载任务，并在成功或失败后安全释放引用。
  void _trackWarmup(Future<bool> future, String signature) {
    _currentWarmupSignature = signature;
    _currentWarmup = future;
    future.then<void>(
      (_) => _clearWarmup(future),
      onError: (Object _, StackTrace __) {
        _clearWarmup(future);
      },
    );
  }

  void _clearWarmup(Future<bool> future) {
    if (identical(_currentWarmup, future)) {
      _currentWarmup = null;
      _currentWarmupSignature = null;
    }
  }

  /// 停止当前发音。
  ///
  /// 先停协调器（实际音频），再复位状态——即便复位时遇异常（如离开页面 dispose 期
  /// 的 provider 约束），也已确保音频被停掉，不会让试听例子继续播到尾。
  Future<void> stop() async {
    _speakingToken++;
    await _readyCoordinator.stop();
    state = _stateWithSpeaking(null);
  }

  /// 指定 [key] 是否正在朗读（供发音按钮）。
  bool isSpeaking(String key) => state.speakingKey == key;
}

/// 统一 TTS 控制器 Provider 入口。
final ttsControllerProvider =
    NotifierProvider<TtsController, TtsControllerState>(TtsController.new);
