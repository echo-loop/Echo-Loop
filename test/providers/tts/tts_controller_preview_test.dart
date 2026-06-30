import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart' show TtsCacheData;
import 'package:echo_loop/database/daos/tts_cache_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/tts/kokoro_model_provider.dart';
import 'package:echo_loop/providers/tts/piper_model_provider.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart'
    show AsrModelDownloadStatus;
import 'package:echo_loop/services/tts/kokoro_voices.dart';
import 'package:echo_loop/services/tts/piper_voices.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

/// 受控 Kokoro notifier：注入初值，下载相关方法仅占位（不做真实下载）。
class _FixedKokoroNotifier extends KokoroModelNotifier {
  _FixedKokoroNotifier(this._initial);
  final KokoroModelsState _initial;

  @override
  KokoroModelsState build() => _initial;

  @override
  Future<void> ensureDownloaded(KokoroModelVariant variant) async {}
}

/// 受控 Piper notifier：注入初值，下载相关方法仅占位（不做真实下载）。
class _FixedPiperNotifier extends PiperModelNotifier {
  _FixedPiperNotifier(this._initial);
  final PiperModelsState _initial;

  @override
  PiperModelsState build() => _initial;

  @override
  Future<void> ensureDownloaded(String voiceId) async {}
}

/// 记录是否被调用的引擎工厂；返回空操作引擎（合成返回 null，不播放/不入库）。
class _RecordingFactory {
  int calls = 0;
  TtsEngine make(TtsEngineKind kind) {
    calls++;
    return _NoopEngine();
  }
}

class _NoopEngine implements TtsEngine {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> applyConfig(TtsSpeechConfig config) async {}
  @override
  Future<TtsSynthesisResult?> synthesize(
    String text, {
    required String outputDir,
    required String baseName,
    TtsSpeechConfig? config,
  }) async => null;
  @override
  Future<bool> speakLive(String text) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _GateEngine implements TtsEngine {
  final List<Completer<void>> gates = [];

  @override
  Future<void> initialize() async {}
  @override
  Future<void> applyConfig(TtsSpeechConfig config) async {}
  @override
  Future<TtsSynthesisResult?> synthesize(
    String text, {
    required String outputDir,
    required String baseName,
    TtsSpeechConfig? config,
  }) async {
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return null;
  }

  @override
  Future<bool> speakLive(String text) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _FakeTtsCacheDao implements TtsCacheDao {
  @override
  Future<TtsCacheData?> getByKey(String cacheKey, {Duration? slideTtl}) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.rootPath);
  final String rootPath;

  @override
  Future<String?> getApplicationCachePath() async => rootPath;
}

KokoroModelsState _ready() => const KokoroModelsState({
  KokoroModelVariant.fp32: KokoroModelState(
    downloadStatus: AsrModelDownloadStatus.downloaded,
    localSizeBytes: 1024,
  ),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTtsCacheDao dao;
  late Directory tmpDir;

  setUp(() {
    dao = _FakeTtsCacheDao();
    tmpDir = Directory.systemTemp.createTempSync('tts_preview_test');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer({
    required TtsSettings settings,
    required KokoroModelsState models,
    required _RecordingFactory factory,
    PiperModelsState? piperModels,
  }) {
    return ProviderContainer(
      overrides: [
        initialTtsSettingsProvider.overrideWithValue(settings),
        kokoroModelProvider.overrideWith(() => _FixedKokoroNotifier(models)),
        piperModelProvider.overrideWith(
          () => _FixedPiperNotifier(piperModels ?? PiperModelsState.initial()),
        ),
        ttsEngineFactoryProvider.overrideWithValue(factory.make),
        ttsCacheDaoProvider.overrideWithValue(dao),
      ],
    );
  }

  /// 默认美音音色已就绪的 Piper 状态。
  PiperModelsState piperReadyState() => PiperModelsState({
    piperDefaultVoiceUs: const PiperModelState(
      downloadStatus: AsrModelDownloadStatus.downloaded,
      localSizeBytes: 1024,
    ),
  });

  group('previewVoice', () {
    test('发起时即设 speakingKey 为该音色试听键，完成后复位', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _ready(),
        factory: factory,
      );
      addTearDown(c.dispose);

      final voice = voiceById('am_adam')!;
      final future = c.read(ttsControllerProvider.notifier).previewVoice(voice);

      // 同步阶段（await speakWith 之前）已置 speakingKey。
      expect(
        c.read(ttsControllerProvider).speakingKey,
        ttsVoicePreviewKey('am_adam'),
      );

      await future;
      // 未被抢占 → 完成后复位。
      expect(c.read(ttsControllerProvider).speakingKey, isNull);
    });

    test('同一 speakingKey 连续发音时，旧请求完成不清掉新请求的小喇叭', () async {
      SharedPreferences.setMockInitialValues({});
      final engine = _GateEngine();
      final c = ProviderContainer(
        overrides: [
          initialTtsSettingsProvider.overrideWithValue(
            const TtsSettings(engine: TtsEngineKind.echoLoop),
          ),
          kokoroModelProvider.overrideWith(
            () => _FixedKokoroNotifier(_ready()),
          ),
          piperModelProvider.overrideWith(
            () => _FixedPiperNotifier(PiperModelsState.initial()),
          ),
          ttsEngineFactoryProvider.overrideWithValue((_) => engine),
          ttsCacheDaoProvider.overrideWithValue(dao),
        ],
      );
      addTearDown(c.dispose);

      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      final first = notifier.speak('first text', key: 'same_voice');
      await pumpEventQueue();
      expect(engine.gates, hasLength(1));

      final second = notifier.speak('second text', key: 'same_voice');
      await pumpEventQueue();
      // 第二个用户发音已抢占 UI 状态，但合成任务要等第一个释放后才入队执行。
      expect(engine.gates, hasLength(1));
      expect(c.read(ttsControllerProvider).speakingKey, 'same_voice');

      engine.gates[0].complete();
      await pumpEventQueue();
      expect(engine.gates, hasLength(2));
      await first;
      expect(c.read(ttsControllerProvider).speakingKey, 'same_voice');

      engine.gates[1].complete();
      await second;
      expect(c.read(ttsControllerProvider).speakingKey, isNull);
    });
  });

  group('previewAccent', () {
    test('发起时即设 speakingKey 为该口音试听键，完成后复位', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(), // 平台 TTS
        models: _ready(),
        factory: factory,
      );
      addTearDown(c.dispose);

      final future = c
          .read(ttsControllerProvider.notifier)
          .previewAccent(TtsAccent.uk);

      // 同步阶段（await speakWith 之前）已置 speakingKey。
      expect(
        c.read(ttsControllerProvider).speakingKey,
        ttsAccentPreviewKey(TtsAccent.uk),
      );

      await future;
      // 未被抢占 → 完成后复位。
      expect(c.read(ttsControllerProvider).speakingKey, isNull);
    });
  });

  group('prewarmAccentPreviews 门控', () {
    test('平台 TTS → 触发合成路径（构建引擎）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(), // 平台 TTS
        models: _ready(),
        factory: factory,
      );
      addTearDown(c.dispose);

      await c.read(ttsControllerProvider.notifier).prewarmAccentPreviews();
      expect(factory.calls, greaterThanOrEqualTo(1));
    });

    test('Echo Loop 引擎 → 不触发任何合成（提前返回）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _ready(),
        factory: factory,
      );
      addTearDown(c.dispose);

      await c.read(ttsControllerProvider.notifier).prewarmAccentPreviews();
      expect(factory.calls, 0);
    });
  });

  group('prewarmVoicePreviews 门控', () {
    test('Echo Loop 且就绪 → 触发合成路径（构建引擎）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _ready(),
        factory: factory,
      );
      addTearDown(c.dispose);

      await c.read(ttsControllerProvider.notifier).prewarmVoicePreviews();
      expect(factory.calls, greaterThanOrEqualTo(1));
    });

    test('平台引擎 → 不触发任何合成（提前返回）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(), // 平台 TTS
        models: _ready(),
        factory: factory,
      );
      addTearDown(c.dispose);

      await c.read(ttsControllerProvider.notifier).prewarmVoicePreviews();
      expect(factory.calls, 0);
    });

    test('Echo Loop 但模型未就绪 → 不触发合成（提前返回）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: KokoroModelsState.initial(),
        factory: factory,
      );
      addTearDown(c.dispose);

      await c.read(ttsControllerProvider.notifier).prewarmVoicePreviews();
      expect(factory.calls, 0);
    });

    test('取消后重发 → 旧 token 失效（不报错，可再次预热）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _ready(),
        factory: factory,
      );
      addTearDown(c.dispose);

      final notifier = c.read(ttsControllerProvider.notifier);
      notifier.cancelVoicePreviewPrewarm(); // 取消（无在途任务，安全）
      await notifier.prewarmVoicePreviews(); // 重发仍可执行
      expect(factory.calls, greaterThanOrEqualTo(1));
    });

    test('同签名并发重入 → 只跑一批（幂等），第二次立即返回', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _ready(),
        factory: factory,
      );
      addTearDown(c.dispose);

      final notifier = c.read(ttsControllerProvider.notifier);
      // 不 await 第一批，紧接发第二批（同 engine+variant 签名）。
      final first = notifier.prewarmVoicePreviews();
      final second = notifier.prewarmVoicePreviews();
      await Future.wait([first, second]);
      // 引擎仅构建一次（in-flight 守卫 + 幂等签名共同保证不重复建引擎）。
      expect(factory.calls, 1);
    });
  });

  group('prewarmActivePiperVoice 门控', () {
    test('Piper 且当前音色就绪 → 触发合成路径（构建引擎）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.piper),
        models: _ready(),
        factory: factory,
        piperModels: piperReadyState(),
      );
      addTearDown(c.dispose);

      // 等 build 的 microtask 首次 configure 落定（生产中预热恒在此之后触发）。
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {});
      await notifier.prewarmActivePiperVoice();
      expect(factory.calls, greaterThanOrEqualTo(1));
    });

    test('非 Piper 引擎 → 不触发任何合成（提前返回）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.echoLoop),
        models: _ready(),
        factory: factory,
        piperModels: piperReadyState(),
      );
      addTearDown(c.dispose);

      await c.read(ttsControllerProvider.notifier).prewarmActivePiperVoice();
      expect(factory.calls, 0);
    });

    test('Piper 但当前音色未就绪 → 不触发合成（提前返回）', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.piper),
        models: _ready(),
        factory: factory,
        piperModels: PiperModelsState.initial(),
      );
      addTearDown(c.dispose);

      await c.read(ttsControllerProvider.notifier).prewarmActivePiperVoice();
      expect(factory.calls, 0);
    });

    test('同签名并发重入 → 只跑一批（幂等），引擎仅建一次', () async {
      SharedPreferences.setMockInitialValues({});
      final factory = _RecordingFactory();
      final c = makeContainer(
        settings: const TtsSettings(engine: TtsEngineKind.piper),
        models: _ready(),
        factory: factory,
        piperModels: piperReadyState(),
      );
      addTearDown(c.dispose);

      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      final first = notifier.prewarmActivePiperVoice();
      final second = notifier.prewarmActivePiperVoice();
      await Future.wait([first, second]);
      expect(factory.calls, 1);
    });
  });

  group('ttsVoicePreviewConfig 与试听/预热 cacheKey 对齐', () {
    test('对每个音色：单一来源构造，逐字段确定（口音→语言、音色 id、变体标签）', () {
      for (final voice in kokoroVoices) {
        final cfg = ttsVoicePreviewConfig(voice, KokoroModelVariant.int8);
        expect(
          cfg.languageTag,
          voice.accent == TtsAccent.uk ? 'en-GB' : 'en-US',
        );
        expect(cfg.voiceName, voice.id);
        expect(cfg.modelTag, KokoroModelVariant.int8.name);
        // voiceId（缓存键用）= voiceName，非语言标签。
        expect(cfg.voiceId, voice.id);
      }
    });

    test('变体不同 → modelTag 不同（fp32/int8 分桶，缓存键不串）', () {
      final v = voiceById('am_adam')!;
      final fp32 = ttsVoicePreviewConfig(v, KokoroModelVariant.fp32);
      final int8 = ttsVoicePreviewConfig(v, KokoroModelVariant.int8);
      expect(fp32.modelTag, isNot(int8.modelTag));
      // 其余字段一致（仅 modelTag 分桶）。
      expect(fp32.languageTag, int8.languageTag);
      expect(fp32.voiceName, int8.voiceName);
      // 语速默认一致（cacheKey 的 speed 段）。
      expect(fp32.rate, int8.rate);
    });
  });
}
