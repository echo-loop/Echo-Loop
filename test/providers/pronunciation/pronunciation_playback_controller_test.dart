import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/providers/short_audio_player_provider.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:echo_loop/services/pronunciation/word_audio_identity.dart';
import 'package:echo_loop/services/pronunciation/word_audio_repository.dart';
import 'package:echo_loop/services/reliable_http_downloader.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/mock_providers.dart';

class _FakeBackend implements AudioClipPlayerBackend {
  _FakeBackend({this.failOnOpen = false});

  final bool failOnOpen;
  final openedPaths = <String>[];
  final _completed = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> open(String filePath, {Duration start = Duration.zero}) async {
    openedPaths.add(filePath);
    if (failOnOpen) {
      _errors.add('decode failed');
    } else {
      _completed.add(null);
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _completed.close();
    await _errors.close();
    await _positions.close();
  }
}

/// 按调用方设定的结果响应 CDN 请求，并记录请求数量。
class _FakeCdnDownloader implements ReliableHttpDownloader {
  Object? failure;
  Completer<void>? gate;
  int requestCount = 0;

  @override
  Future<ReliableDownloadResult> download({
    required Uri uri,
    required String savePath,
    Map<String, String> headers = const <String, String>{},
    int? expectedSize,
    String? identityKey,
    bool allowResume = true,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    requestCount++;
    await gate?.future;
    final error = failure;
    if (error != null) throw error;
    File(savePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    return ReliableDownloadResult(
      savePath: savePath,
      bytesWritten: 3,
      resumed: false,
    );
  }
}

const _notFound = ReliableDownloadException(
  'not found',
  kind: ReliableDownloadFailure.httpStatus,
  statusCode: 404,
);

class _FakeTtsController extends TtsController {
  final spoken = <String>[];
  final promptFlags = <bool>[];
  final prewarmed = <String>[];
  AudioPlaybackResult result = AudioPlaybackResult.completed;

  @override
  TtsControllerState build() => const TtsControllerState();

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    spoken.add(text);
    promptFlags.add(promptIfModelMissing);
    return result;
  }

  @override
  Future<void> prewarmTextsIncremental(List<String> texts) async {
    prewarmed.addAll(texts);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  late Directory tempDir;
  late _FakeCdnDownloader cdn;
  late _FakeBackend backend;
  late _FakeTtsController tts;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('playback_controller_');
    cdn = _FakeCdnDownloader();
    backend = _FakeBackend();
    tts = _FakeTtsController();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer container() {
    final router = RuntimeEndpointRouter(
      endpoints: const RegionalServiceEndpoints(
        globalApiBaseUrl: '',
        chinaApiBaseUrl: '',
        globalStaticCdnBaseUrl: 'https://cdn.example.test',
        chinaStaticCdnBaseUrl: '',
      ),
    )..updateFromUserRegion(isChinaUser: false);
    final repository = WordAudioRepository(
      downloader: cdn,
      resolveCacheDir: () async => tempDir,
      endpointRouter: router,
    );
    final result = ProviderContainer(
      overrides: dedupeOverrides([
        wordAudioRepositoryProvider.overrideWithValue(repository),
        shortAudioPlayerProvider.overrideWithValue(
          LocalAudioClipPlayer(backend: backend),
        ),
        ttsControllerProvider.overrideWith(() => tts),
      ]),
    );
    addTearDown(result.dispose);
    return result;
  }

  String cachedPathFor(String word) => p.join(
    tempDir.path,
    'word_audio',
    'en-US',
    wordAudioFileName(word)!,
  );

  group('speakWithResult', () {
    test('CDN 有音频时下载缓存并播放，不调用 TTS', () async {
      final playback = container().read(textPlaybackProvider.notifier);

      final result = await playback.speakWithResult('hello');

      expect(result, AudioPlaybackResult.completed);
      expect(backend.openedPaths, [cachedPathFor('hello')]);
      expect(tts.spoken, isEmpty);
    });

    test('已缓存的单词再次播放不发起 CDN 请求', () async {
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.speakWithResult('hello');
      await playback.speakWithResult('hello');

      expect(cdn.requestCount, 1);
      expect(backend.openedPaths, hasLength(2));
    });

    test('CDN 404 时回退 TTS', () async {
      cdn.failure = _notFound;
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.speakWithResult('hello');

      expect(backend.openedPaths, isEmpty);
      expect(tts.spoken, ['hello']);
    });

    test('多词文本不访问 CDN，直接使用 TTS', () async {
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.speakWithResult('hello world');

      expect(cdn.requestCount, 0);
      expect(tts.spoken, ['hello world']);
    });

    test('缓存文件播放失败时回退 TTS 一次', () async {
      backend = _FakeBackend(failOnOpen: true);
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.speakWithResult('hello');

      expect(backend.openedPaths, [cachedPathFor('hello')]);
      expect(tts.spoken, ['hello']);
    });

    test('自动发音回退 TTS 时透传 promptIfModelMissing=false', () async {
      cdn.failure = _notFound;
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.speak(
        'hello',
        key: 'hello',
        promptIfModelMissing: false,
      );

      expect(tts.spoken, ['hello']);
      expect(tts.promptFlags, [false]);
    });

    test('未指定时 TTS 回退默认允许弹出模型下载提示', () async {
      cdn.failure = _notFound;
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.speak('hello');

      expect(tts.promptFlags, [true]);
    });

    test('CDN 下载期间被新请求抢占时不再播放旧单词', () async {
      cdn.gate = Completer<void>();
      final playback = container().read(textPlaybackProvider.notifier);

      final pending = playback.speakWithResult('hello');
      final preempting = playback.speakWithResult('two words');
      cdn.gate!.complete();

      expect(await pending, AudioPlaybackResult.cancelled);
      expect(await preempting, AudioPlaybackResult.completed);
      expect(backend.openedPaths, isEmpty);
      expect(tts.spoken, ['two words']);
    });
  });

  group('prewarmWord', () {
    test('CDN 命中时只下载到缓存，不预热 TTS', () async {
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.prewarmWord('hello');

      expect(cdn.requestCount, 1);
      expect(tts.prewarmed, isEmpty);
    });

    test('CDN 不存在时交给 TTS 预热', () async {
      cdn.failure = _notFound;
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.prewarmWord('hello');

      expect(tts.prewarmed, ['hello']);
    });

    test('不合规的单词直接交给 TTS 预热，不访问 CDN', () async {
      final playback = container().read(textPlaybackProvider.notifier);

      await playback.prewarmWord('two words');

      expect(cdn.requestCount, 0);
      expect(tts.prewarmed, ['two words']);
    });
  });
}
