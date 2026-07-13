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
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart'
    show AsrModelDownloadStatus;
import 'package:echo_loop/services/tts/tts_engine.dart';

/// 受控 Kokoro notifier：注入初值，下载方法占位。
class _FixedKokoroNotifier extends KokoroModelNotifier {
  _FixedKokoroNotifier(this._initial);
  final KokoroModelsState _initial;

  @override
  KokoroModelsState build() => _initial;

  @override
  Future<void> ensureDownloaded(KokoroModelVariant variant) async {}
}

/// 记录每次合成文本的引擎；合成返回 null（不入库/不播放），可按文本设闸门拦住。
class _RecordingEngine implements TtsEngine {
  final List<String> synthTexts = [];
  final Map<String, Completer<void>> _gates = {};

  /// 为某文本设置闸门：该文本合成会阻塞直到 [release] 放行。
  void gate(String text) => _gates[text] = Completer<void>();
  void release(String text) => _gates[text]?.complete();

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
    synthTexts.add(text);
    final g = _gates[text];
    if (g != null) await g.future;
    return null;
  }

  @override
  Future<bool> speakLive(String text) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// 假缓存 DAO：lookup 恒未命中（getByKey→null），引擎合成返回 null 故不入库。
/// 用手写 fake（noSuchMethod 返回 Future）而非 mocktail——getByKey 必返回真正的
/// Future（mocktail 对 any() String 偶发返回 sync null 致类型错）。
class _FakeTtsCacheDao implements TtsCacheDao {
  @override
  Future<TtsCacheData?> getByKey(String cacheKey, {Duration? slideTtl}) async =>
      null;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 假路径提供器：缓存目录指向临时目录（reserveDir 需要可用的 cache path）。
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

  late _RecordingEngine engine;
  late _FakeTtsCacheDao dao;

  ProviderContainer makeContainer(TtsSettings settings) {
    return ProviderContainer(
      overrides: [
        initialTtsSettingsProvider.overrideWithValue(settings),
        kokoroModelProvider.overrideWith(() => _FixedKokoroNotifier(_ready())),
        ttsEngineFactoryProvider.overrideWithValue((_) => engine),
        ttsCacheDaoProvider.overrideWithValue(dao),
      ],
    );
  }

  late Directory tmpDir;

  Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('waitUntil timeout');
      }
      await pumpEventQueue();
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    engine = _RecordingEngine();
    dao = _FakeTtsCacheDao();
    tmpDir = Directory.systemTemp.createTempSync('tts_dict_prewarm');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('prewarmTexts', () {
    test('按顺序逐条合成（单词 + 例句）', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
      );
      addTearDown(c.dispose);

      // 等 build 的 microtask 首次 configure 落定（生产中预热恒在配置之后触发，
      // 见 §7.14 引擎惰性化：configure 延到 build 之后的 microtask 执行）。
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {});
      await notifier.prewarmTexts(['run', 'I run.', 'She runs.']);

      expect(engine.synthTexts, ['run', 'I run.', 'She runs.']);
    });

    test('空串/纯空白文本跳过', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
      );
      addTearDown(c.dispose);

      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      await notifier.prewarmTexts(['', '  ', 'go']);

      expect(engine.synthTexts, ['go']);
    });

    test('cancelTextsPrewarm 中途取消 → 剩余文本不再合成', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
      );
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      // 拦住第一条合成，制造「批次在途」窗口。
      engine.gate('a');
      final batch = notifier.prewarmTexts(['a', 'b', 'c']);
      await waitUntil(() => engine.synthTexts.isNotEmpty);
      expect(engine.synthTexts, ['a'], reason: '第一条已进入合成、阻塞在闸门');

      // 取消（bump token），放行第一条 → 下一轮迭代发现 token 失效即停止。
      notifier.cancelTextsPrewarm();
      engine.release('a');
      await batch;

      expect(engine.synthTexts, ['a'], reason: '取消后 b、c 不再合成');
    });

    test('词典 token 与试听预热 token 独立（取消试听不影响词典批次）', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
      );
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      engine.gate('a');
      final batch = notifier.prewarmTexts(['a', 'b']);
      await pumpEventQueue();

      // 取消「试听」预热不应影响「词典」预热批次。
      notifier.cancelVoicePreviewPrewarm();
      engine.release('a');
      await batch;

      expect(engine.synthTexts, ['a', 'b']);
    });
  });

  group('prewarmTextsIncremental（流式逐帧预热）', () {
    test('同一文本多帧重复 → 只合成一次', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
      );
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      // 模拟连续三帧携带同一份可发音列表（后续帧未新增例句）。
      await notifier.prewarmTextsIncremental(['run', 'I run.']);
      await notifier.prewarmTextsIncremental(['run', 'I run.']);
      await notifier.prewarmTextsIncremental(['run', 'I run.']);

      expect(engine.synthTexts, ['run', 'I run.'], reason: '已提交文本不重复合成');
    });

    test('逐帧递增列表 → 只对新出现的例句合成', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
      );
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      // 帧1：仅单词；帧2：+例句1；帧3：+例句2（模拟流式例句渐显）。
      await notifier.prewarmTextsIncremental(['run']);
      await notifier.prewarmTextsIncremental(['run', 'I run.']);
      await notifier.prewarmTextsIncremental(['run', 'I run.', 'She runs.']);

      expect(engine.synthTexts, ['run', 'I run.', 'She runs.']);
    });

    test('cancelTextsPrewarm 清空 seen-set → 切词后同一文本可再次预热', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
      );
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      await notifier.prewarmTextsIncremental(['run']);
      notifier.cancelTextsPrewarm(); // 切词/关闭：清空去重集合
      await notifier.prewarmTextsIncremental(['run']);

      expect(engine.synthTexts, [
        'run',
        'run',
      ], reason: '取消后 seen-set 清空，可重新预热');
    });

    test('cancelTextsPrewarm 中途取消 → 已在途例句结束后剩余不再合成', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
      );
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      engine.gate('a');
      final batch = notifier.prewarmTextsIncremental(['a', 'b', 'c']);
      await waitUntil(() => engine.synthTexts.isNotEmpty);
      expect(engine.synthTexts, ['a'], reason: '第一条已进入合成、阻塞在闸门');

      notifier.cancelTextsPrewarm();
      engine.release('a');
      await batch;

      expect(engine.synthTexts, ['a'], reason: '取消后 b、c 不再合成');
    });
  });
}
