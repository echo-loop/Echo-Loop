import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart' show TtsCacheData;
import 'package:echo_loop/database/daos/tts_cache_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/providers/tts/kokoro_model_provider.dart';
import 'package:echo_loop/providers/tts/piper_model_provider.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/providers/short_audio_player_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart'
    show AsrModelDownloadStatus;
import 'package:echo_loop/services/tts/tts_engine.dart';

import '../../helpers/mock_providers.dart';

/// 受控 Kokoro notifier：注入初值，下载方法占位。
class _FixedKokoroNotifier extends KokoroModelNotifier {
  _FixedKokoroNotifier(this._initial);
  final KokoroModelsState _initial;

  @override
  KokoroModelsState build() => _initial;

  @override
  Future<void> ensureDownloaded(KokoroModelVariant variant) async {}

  @override
  Future<void> refreshInstalledStates({bool Function()? shouldCommit}) async {}
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

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;
}

class _NoopShortAudioBackend implements AudioClipPlayerBackend {
  @override
  Stream<void> get completed => const Stream<void>.empty();
  @override
  Stream<String> get errors => const Stream<String>.empty();
  @override
  Stream<Duration> get positions => const Stream<Duration>.empty();
  @override
  Duration get position => Duration.zero;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> open(String filePath, {Duration start = Duration.zero}) async {}
  @override
  Future<void> stop() async {}
}

KokoroModelsState _ready() => const KokoroModelsState({
  KokoroModelVariant.fp32: KokoroModelState(
    downloadStatus: AsrModelDownloadStatus.downloaded,
    localSizeBytes: 1024,
  ),
});

/// 测试用预热所有者，区分不同页面的预热批次。
const _owner = Object();

/// 可由测试切换的布尔开关，用来模拟本地模型的就绪状态变化。
class _FlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final _piperReadyFlagProvider = NotifierProvider<_FlagNotifier, bool>(
  _FlagNotifier.new,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingEngine engine;
  late _FakeTtsCacheDao dao;

  ProviderContainer makeContainer(
    TtsSettings settings, {
    List<Override> extraOverrides = const [],
  }) {
    return ProviderContainer(
      overrides: dedupeOverrides([
        initialTtsSettingsProvider.overrideWithValue(settings),
        kokoroModelProvider.overrideWith(() => _FixedKokoroNotifier(_ready())),
        ttsEngineFactoryProvider.overrideWithValue((_, __) => engine),
        ttsCacheDaoProvider.overrideWithValue(dao),
        shortAudioPlayerProvider.overrideWithValue(
          LocalAudioClipPlayer(backend: _NoopShortAudioBackend()),
        ),
        ...extraOverrides,
      ]),
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
    AppLogger.instance.clear();
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
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);

      // 等 build 的 microtask 首次 configure 落定（生产中预热恒在配置之后触发，
      // 见 §7.14 引擎惰性化：configure 延到 build 之后的 microtask 执行）。
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {});
      await notifier.prewarmTexts([
        'run',
        'I run.',
        'She runs.',
      ], owner: _owner);

      expect(engine.synthTexts, ['run', 'I run.', 'She runs.']);
    });

    test('空串/纯空白文本跳过', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);

      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      await notifier.prewarmTexts(['', '  ', 'go'], owner: _owner);

      expect(engine.synthTexts, ['go']);
    });

    test('cancelTextsPrewarm 中途取消 → 剩余文本不再合成', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      // 拦住第一条合成，制造「批次在途」窗口。
      engine.gate('a');
      final batch = notifier.prewarmTexts(['a', 'b', 'c'], owner: _owner);
      await waitUntil(() => engine.synthTexts.isNotEmpty);
      expect(engine.synthTexts, ['a'], reason: '第一条已进入合成、阻塞在闸门');

      // 取消（bump token），放行第一条 → 下一轮迭代发现 token 失效即停止。
      notifier.cancelTextsPrewarm(owner: _owner);
      engine.release('a');
      await batch;

      expect(engine.synthTexts, ['a'], reason: '取消后 b、c 不再合成');
    });

    test('词典 token 与试听预热 token 独立（取消试听不影响词典批次）', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      engine.gate('a');
      final batch = notifier.prewarmTexts(['a', 'b'], owner: _owner);
      await pumpEventQueue();

      // 取消「试听」预热不应影响「词典」预热批次。
      notifier.cancelVoicePreviewPrewarm();
      engine.release('a');
      await batch;

      expect(engine.synthTexts, ['a', 'b']);
    });
  });

  group('prewarmTextsIncremental（流式逐帧预热）', () {
    test('初始配置前跳过且不占用 seen，配置完成后同文本可预热', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);

      // build 将首次 configure 延到 microtask；模拟 Words tile 比它更早的 post-frame
      // 提交。此时不应建引擎、合成或占用后续增量去重集合。
      await notifier.prewarmTextsIncremental(['tomorrow'], owner: _owner);
      expect(engine.synthTexts, isEmpty);
      expect(
        AppLogger.instance.entries.map((entry) => entry.message),
        contains(contains('增量文本预热跳过：TTS 尚未配置')),
      );

      await Future<void>(() {});
      await notifier.prewarmTextsIncremental(['tomorrow'], owner: _owner);

      expect(engine.synthTexts, ['tomorrow']);
    });

    test('同一文本多帧重复 → 只合成一次', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      // 模拟连续三帧携带同一份可发音列表（后续帧未新增例句）。
      await notifier.prewarmTextsIncremental(['run', 'I run.'], owner: _owner);
      await notifier.prewarmTextsIncremental(['run', 'I run.'], owner: _owner);
      await notifier.prewarmTextsIncremental(['run', 'I run.'], owner: _owner);

      expect(engine.synthTexts, ['run', 'I run.'], reason: '已提交文本不重复合成');
    });

    test('逐帧递增列表 → 只对新出现的例句合成', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      // 帧1：仅单词；帧2：+例句1；帧3：+例句2（模拟流式例句渐显）。
      await notifier.prewarmTextsIncremental(['run'], owner: _owner);
      await notifier.prewarmTextsIncremental(['run', 'I run.'], owner: _owner);
      await notifier.prewarmTextsIncremental([
        'run',
        'I run.',
        'She runs.',
      ], owner: _owner);

      expect(engine.synthTexts, ['run', 'I run.', 'She runs.']);
      final logs = AppLogger.instance.entries.map((entry) => entry.message);
      expect(logs, contains('增量文本预热处理完成：请求数=3 新提交=1 跳过=2 当前已提交=3'));
    });

    test('cancelTextsPrewarm 清空 seen-set → 切词后同一文本可再次预热', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      await notifier.prewarmTextsIncremental(['run'], owner: _owner);
      notifier.cancelTextsPrewarm(owner: _owner); // 切词/关闭：清空去重集合
      await notifier.prewarmTextsIncremental(['run'], owner: _owner);

      expect(engine.synthTexts, [
        'run',
        'run',
      ], reason: '取消后 seen-set 清空，可重新预热');
    });

    test('cancelTextsPrewarm 中途取消 → 已在途例句结束后剩余不再合成', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定

      engine.gate('a');
      final batch = notifier.prewarmTextsIncremental([
        'a',
        'b',
        'c',
      ], owner: _owner);
      await waitUntil(() => engine.synthTexts.isNotEmpty);
      expect(engine.synthTexts, ['a'], reason: '第一条已进入合成、阻塞在闸门');

      notifier.cancelTextsPrewarm(owner: _owner);
      engine.release('a');
      await batch;

      expect(engine.synthTexts, ['a'], reason: '取消后 b、c 不再合成');
    });

    test('取消一个所有者不影响其他所有者排队中的预热', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      // 注意：不能用 const，编译期常量 Object() 会被规范化为同一实例。
      final favoritesOwner = Object();
      final reviewOwner = Object();

      engine.gate('a');
      final favorites = notifier.prewarmTextsIncremental([
        'a',
        'b',
      ], owner: favoritesOwner);
      await waitUntil(() => engine.synthTexts.isNotEmpty);
      final review = notifier.prewarmTextsIncremental([
        'x',
      ], owner: reviewOwner);
      // 让复习页的 x 穿过 TTS 前置步骤并进入合成队列（串行等待 a 释放）。
      for (var i = 0; i < 20; i++) {
        await Future<void>(() {});
      }

      notifier.cancelTextsPrewarm(owner: favoritesOwner);
      engine.release('a');
      await Future.wait([favorites, review]);

      expect(engine.synthTexts, [
        'a',
        'x',
      ], reason: '收藏页取消只丢弃它排队中的 b，复习页的 x 仍应合成');
    });
  });

  group('配置目标去重（设置或模型就绪变化不应打断在途预热）', () {
    test('无关设置变化（同一有效目标）不清空在途批次、不递增版本', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      final batch = notifier.beginTextPrewarmBatch(_owner);
      final versionBefore = c.read(ttsControllerProvider).configurationVersion;

      // 当前引擎是 Kokoro，改 Piper 音色只触发设置监听，有效目标不变。
      await c
          .read(ttsSettingsProvider.notifier)
          .setPiperVoice(TtsAccent.us, 'en_US-lessac-medium');
      expect(
        c.read(ttsSettingsProvider).piperVoiceUs,
        'en_US-lessac-medium',
        reason: '前置条件：设置确实发生了变化',
      );
      await Future<void>(() {});

      expect(notifier.isTextPrewarmBatchCurrent(_owner, batch), isTrue);
      expect(c.read(ttsControllerProvider).configurationVersion, versionBefore);
    });

    test('未选用的本地模型就绪状态变化不触发重配置', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.kokoro),
        extraOverrides: [
          piperReadyProvider.overrideWith(
            (ref) => ref.watch(_piperReadyFlagProvider),
          ),
        ],
      );
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      final batch = notifier.beginTextPrewarmBatch(_owner);
      final versionBefore = c.read(ttsControllerProvider).configurationVersion;

      c.read(_piperReadyFlagProvider.notifier).set(true);
      await Future<void>(() {});

      expect(notifier.isTextPrewarmBatchCurrent(_owner, batch), isTrue);
      expect(c.read(ttsControllerProvider).configurationVersion, versionBefore);
    });

    test('被选用引擎的模型就绪变化也不改变配置目标', () async {
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.piper),
        extraOverrides: [
          piperReadyProvider.overrideWith(
            (ref) => ref.watch(_piperReadyFlagProvider),
          ),
        ],
      );
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      final batch = notifier.beginTextPrewarmBatch(_owner);
      final versionBefore = c.read(ttsControllerProvider).configurationVersion;

      // 有效引擎由设置决定，与模型是否就绪无关：就绪变化不应重配置。
      c.read(_piperReadyFlagProvider.notifier).set(true);
      await Future<void>(() {});

      expect(notifier.isTextPrewarmBatchCurrent(_owner, batch), isTrue);
      expect(c.read(ttsControllerProvider).configurationVersion, versionBefore);
    });

    test('有效引擎真正变化时清空批次并递增版本', () async {
      final c = makeContainer(const TtsSettings(engine: TtsEngineKind.kokoro));
      addTearDown(c.dispose);
      final notifier = c.read(ttsControllerProvider.notifier);
      await Future<void>(() {}); // 等首次 configure 落定
      final batch = notifier.beginTextPrewarmBatch(_owner);
      final versionBefore = c.read(ttsControllerProvider).configurationVersion;

      await c
          .read(ttsSettingsProvider.notifier)
          .setEngine(TtsEngineKind.platform);
      await Future<void>(() {});

      expect(notifier.isTextPrewarmBatchCurrent(_owner, batch), isFalse);
      expect(
        c.read(ttsControllerProvider).configurationVersion,
        greaterThan(versionBefore),
      );
    });
  });
}
