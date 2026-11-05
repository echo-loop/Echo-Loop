/// TtsController × Edge 不可用提示
///
/// 覆盖：主动发音每次失败都提示、非主动发音不提示、提示文案类型、设置页试听同样提示。
library;

import 'dart:async';
import 'dart:io';

import 'package:echo_loop/database/app_database.dart' show TtsCacheData;
import 'package:echo_loop/database/daos/tts_cache_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/short_audio_player_provider.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/services/tts/edge_tts_engine.dart';
import 'package:echo_loop/services/tts/edge_voices.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

/// 按开关决定成功（写文件）或失败（记录 network/service）的 Edge 替身引擎。
class _SwitchableEdgeEngine implements TtsEngine {
  _SwitchableEdgeEngine(this.recorder);

  final EdgeTtsFailureRecorder recorder;
  EdgeTtsFailureKind? failWith = EdgeTtsFailureKind.service;
  int synthCount = 0;

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
    synthCount++;
    final failure = failWith;
    if (failure != null) {
      recorder.recordFailure(failure);
      return null;
    }
    final path = '$outputDir/$baseName.mp3';
    File(path).writeAsBytesSync([1]);
    recorder.recordSuccess();
    return TtsSynthesisResult(filePath: path, format: 'mp3');
  }

  @override
  Future<bool> speakLive(String text) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// 缓存恒未命中、写入为空操作的 DAO。
class _MissTtsCacheDao implements TtsCacheDao {
  @override
  Future<TtsCacheData?> getByKey(String cacheKey, {Duration? slideTtl}) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// 打开即播完的播放后端。
class _InstantCompleteBackend implements AudioClipPlayerBackend {
  final _completed = StreamController<void>.broadcast();

  @override
  Stream<void> get completed => _completed.stream;
  @override
  Stream<String> get errors => const Stream<String>.empty();
  @override
  Stream<Duration> get positions => const Stream<Duration>.empty();
  @override
  Duration get position => Duration.zero;
  @override
  Future<void> open(String filePath, {Duration start = Duration.zero}) async {
    scheduleMicrotask(() => _completed.add(null));
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() => _completed.close();
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.rootPath);
  final String rootPath;

  @override
  Future<String?> getApplicationCachePath() async => rootPath;
  @override
  Future<String?> getApplicationSupportPath() async => rootPath;
}

typedef _Prompt = EdgeTtsFailureKind;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late EdgeTtsFailureRecorder recorder;
  late _SwitchableEdgeEngine engine;
  late List<_Prompt> prompts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmpDir = Directory.systemTemp.createTempSync('tts_edge_prompt_test');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);
    recorder = EdgeTtsFailureRecorder();
    engine = _SwitchableEdgeEngine(recorder);
    prompts = [];
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: dedupeOverrides([
        initialTtsSettingsProvider.overrideWithValue(const TtsSettings()),
        ttsEngineFactoryProvider.overrideWithValue((_, __) => engine),
        ttsCacheDaoProvider.overrideWithValue(_MissTtsCacheDao()),
        edgeTtsFailureRecorderProvider.overrideWithValue(recorder),
        edgeTtsUnavailablePromptProvider.overrideWithValue(prompts.add),
        shortAudioPlayerProvider.overrideWithValue(
          LocalAudioClipPlayer(backend: _InstantCompleteBackend()),
        ),
      ]),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<TtsController> readyController(ProviderContainer c) async {
    final notifier = c.read(ttsControllerProvider.notifier);
    await Future<void>(() {}); // 等首次 configure 落定
    return notifier;
  }

  test('主动发音每次失败都提示', () async {
    final notifier = await readyController(makeContainer());

    expect(await notifier.speakWithResult('first'), AudioPlaybackResult.failed);
    await notifier.speakWithResult('second');

    expect(engine.synthCount, 2);
    expect(prompts, [EdgeTtsFailureKind.service, EdgeTtsFailureKind.service]);
  });

  test('网络失败 → 提示类型为 network', () async {
    engine.failWith = EdgeTtsFailureKind.network;
    final notifier = await readyController(makeContainer());

    await notifier.speakWithResult('word');

    expect(prompts.single, EdgeTtsFailureKind.network);
  });

  test('非主动发音（查词自动发音）失败 → 不提示', () async {
    final notifier = await readyController(makeContainer());

    await notifier.speakWithResult('word', promptIfModelMissing: false);

    expect(prompts, isEmpty);
  });

  test('设置页试听失败 → 同样提示', () async {
    final notifier = await readyController(makeContainer());

    await notifier.previewEdgeVoice(edgeDefaultVoice(TtsAccent.uk));

    expect(prompts, [EdgeTtsFailureKind.service]);
  });
}
