// TranscriptionTaskManager 单元测试
//
// 测试转录任务的完整生命周期、状态转换、错误处理和取消逻辑。
// 通过 mock TranscriptionApiClient 和 TranscriptionFileOps 避免真实 I/O。
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/audio_import/audio_finalization_service.dart';
import 'package:echo_loop/features/subscription/models/ai_quota_rejection.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart'
    show entitlementQuotaDivergenceHandlerProvider;
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/transcription_audio_extractor.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/word_timestamp.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/transcription_task_provider.dart';
import 'package:echo_loop/services/subtitle_auto_align_service.dart';
import 'package:echo_loop/services/transcription_api_client.dart';
import 'package:echo_loop/utils/srt_generator.dart';

import '../helpers/mock_providers.dart';

// ─── Mock 类 ──────────────────────────────────────────────

class MockTranscriptionApiClient extends Mock
    implements TranscriptionApiClient {}

class MockTranscriptionFileOps extends Mock implements TranscriptionFileOps {}

class MockSubtitleAutoAlignService extends Mock
    implements SubtitleAutoAlignService {}

class FakeAudioItem extends Fake implements AudioItem {}

/// 转录后转码桩：返回预设结果或抛异常，记录调用次数。
class _FakeFinalizationService extends AudioFinalizationService {
  _FakeFinalizationService({this.result, this.error});

  final FinalizedAudio? result;
  final Object? error;
  int calls = 0;

  @override
  Future<FinalizedAudio> transcodeExisting({
    required Directory dataDir,
    required String relativePath,
  }) async {
    calls++;
    if (error != null) throw error!;
    return result!;
  }
}

/// 视频抽音轨桩：返回预设临时路径（null 表示抽取失败），记录调用与入参。
class _FakeAudioExtractor extends TranscriptionAudioExtractor {
  _FakeAudioExtractor({this.output});

  /// 抽取产物路径；null 模拟抽取失败（调用方回退上传原视频）。
  final String? output;
  int calls = 0;
  String? lastVideoPath;

  @override
  Future<String?> extractAudioTrack({
    required Directory dataDir,
    required String videoAbsolutePath,
  }) async {
    calls++;
    lastVideoPath = videoAbsolutePath;
    return output;
  }
}

// ─── 测试辅助 ──────────────────────────────────────────────

/// 创建测试用 AudioItem
AudioItem _testAudioItem({
  String id = 'test-audio-1',
  String name = 'Test Audio',
  String audioPath = 'audios/test.mp3',
  String? audioSha256,
  String? originalAudioSha256,
}) {
  return AudioItem(
    id: id,
    name: name,
    audioPath: audioPath,
    addedDate: DateTime(2026),
    totalDuration: 120,
    sentenceCount: 0,
    wordCount: 0,
    audioSha256: audioSha256,
    originalAudioSha256: originalAudioSha256,
  );
}

/// 创建 ProviderContainer 并注入 mock
///
/// [audioItems] 初始音频列表，默认包含一个测试音频。
ProviderContainer _createContainer({
  required MockTranscriptionApiClient mockApi,
  required MockTranscriptionFileOps mockFileOps,
  required db.AppDatabase database,
  MockSubtitleAutoAlignService? mockAutoAlignService,
  AudioFinalizationService? finalizationService,
  TranscriptionAudioExtractor? audioExtractor,
  List<AudioItem>? audioItems,
  void Function(String context)? quotaDivergenceHandler,
}) {
  final overrides = <Override>[
    transcriptionApiClientProvider.overrideWithValue(mockApi),
    transcriptionFileOpsProvider.overrideWithValue(mockFileOps),
    appDatabaseProvider.overrideWithValue(database),
    audioLibraryProvider.overrideWith(TestAudioLibrary.new),
    // 避免 402 路径实例化真实订阅栈（E7 收敛信号在测试中默认 no-op）。
    entitlementQuotaDivergenceHandlerProvider.overrideWithValue(
      quotaDivergenceHandler ?? (_) {},
    ),
    analyticsOverride(),
  ];
  if (finalizationService != null) {
    overrides.add(
      transcriptionFinalizationServiceProvider.overrideWithValue(
        finalizationService,
      ),
    );
  }
  if (audioExtractor != null) {
    overrides.add(
      transcriptionAudioExtractorProvider.overrideWithValue(audioExtractor),
    );
  }
  if (mockAutoAlignService != null) {
    overrides.add(
      subtitleAutoAlignServiceProvider.overrideWithValue(mockAutoAlignService),
    );
  }
  final container = ProviderContainer(overrides: overrides);
  // 初始化音频库
  final items = audioItems ?? [_testAudioItem()];
  (container.read(audioLibraryProvider.notifier) as TestAudioLibrary).setItems(
    items,
  );
  return container;
}

/// 把测试音频行插入内存 DB，让 saveTranscriptContent 的 UPDATE 能命中。
Future<void> _seedAudioRows(
  db.AppDatabase database,
  List<AudioItem> items,
) async {
  for (final item in items) {
    await database
        .into(database.audioItems)
        .insert(
          db.AudioItemsCompanion.insert(
            id: item.id,
            name: item.name,
            audioPath: Value(item.audioPath),
            addedDate: item.addedDate,
            audioSha256: Value(item.audioSha256),
            originalAudioSha256: Value(item.originalAudioSha256),
            updatedAt: DateTime(2026),
          ),
        );
  }
}

void main() {
  late MockTranscriptionApiClient mockApi;
  late MockTranscriptionFileOps mockFileOps;
  late MockSubtitleAutoAlignService mockAutoAlignService;
  late db.AppDatabase database;

  setUpAll(() {
    registerFallbackValue(FakeAudioItem());
  });

  setUp(() {
    mockApi = MockTranscriptionApiClient();
    mockFileOps = MockTranscriptionFileOps();
    mockAutoAlignService = MockSubtitleAutoAlignService();
    database = db.AppDatabase(NativeDatabase.memory());

    // 所有调用 startTranscription 的测试都需要 getDataDir
    when(
      () => mockFileOps.getDataDir(),
    ).thenAnswer((_) async => Directory.systemTemp);
    when(
      () => mockAutoAlignService.alignIfPossible(
        audioPath: any(named: 'audioPath'),
        sentences: any(named: 'sentences'),
        words: any(named: 'words'),
      ),
    ).thenAnswer(
      (invocation) async =>
          invocation.namedArguments[#sentences]! as List<TranscriptSentence>,
    );
  });

  tearDown(() async {
    await database.close();
  });

  /// 桩：音频已存在 + 字幕缓存命中（返回「Hello world」），用于直达保存流程。
  void stubCachedTranscript({TranscriptResult? transcript}) {
    when(
      () => mockApi.getUploadUrl(
        sha256: any(named: 'sha256'),
        mimeType: any(named: 'mimeType'),
        fileSize: any(named: 'fileSize'),
        accessToken: any(named: 'accessToken'),
      ),
    ).thenAnswer(
      (_) async => const UploadUrlResponse(
        audioExists: true,
        objectName: 'user-audio/orig-sha.mp3',
        publicUrl: 'https://example.com/orig-sha.mp3',
      ),
    );
    when(
      () => mockApi.submitTranscription(
        sha256: any(named: 'sha256'),
        fileName: any(named: 'fileName'),
        objectName: any(named: 'objectName'),
        publicUrl: any(named: 'publicUrl'),
        mimeType: any(named: 'mimeType'),
        fileSize: any(named: 'fileSize'),
        language: any(named: 'language'),
        accessToken: any(named: 'accessToken'),
      ),
    ).thenAnswer(
      (_) async => SubmitTranscriptionResponse(
        cached: true,
        transcript:
            transcript ??
            TranscriptResult(
              sentences: [
                TranscriptSentence(
                  text: 'Hello world',
                  startTime: Duration.zero,
                  endTime: const Duration(seconds: 2),
                ),
              ],
              fullText: 'Hello world',
            ),
      ),
    );
  }

  group('TranscriptionTaskManager', () {
    test('初始状态为空 Map', () {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
      );
      final state = container.read(transcriptionTaskManagerProvider);
      expect(state, isEmpty);
      container.dispose();
    });

    test('getTaskState 对未知 audioId 返回 Idle', () {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );
      expect(notifier.getTaskState('unknown'), isA<TranscriptionIdle>());
      container.dispose();
    });

    test('防止重复发起 — Hashing 状态下忽略新请求', () async {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      // 手动设置为 Hashing 状态
      notifier.state = {'test-audio-1': const TranscriptionHashing()};

      // SHA256 不应被调用
      verifyNever(() => mockFileOps.computeSha256(any()));

      // 发起请求应被忽略
      await notifier.startTranscription(
        _testAudioItem(),
        'en',
        accessToken: 'token',
      );
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('防止重复发起 — Uploading 状态下忽略新请求', () async {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {'test-audio-1': const TranscriptionUploading()};
      await notifier.startTranscription(
        _testAudioItem(),
        'en',
        accessToken: 'token',
      );
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('防止重复发起 — Compressing 状态下忽略新请求', () async {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {'test-audio-1': const TranscriptionCompressing()};
      await notifier.startTranscription(
        _testAudioItem(),
        'en',
        accessToken: 'token',
      );
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('防止重复发起 — Processing 状态下忽略新请求', () async {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {
        'test-audio-1': const TranscriptionProcessing(jobId: 'j1'),
      };
      await notifier.startTranscription(
        _testAudioItem(),
        'en',
        accessToken: 'token',
      );
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('cancelTranscription 将状态重置为 Idle', () {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {
        'test-audio-1': const TranscriptionProcessing(jobId: 'j1'),
      };
      notifier.cancelTranscription('test-audio-1');

      expect(notifier.getTaskState('test-audio-1'), isA<TranscriptionIdle>());
      container.dispose();
    });

    test('clearState 从 Map 中移除条目', () {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {'test-audio-1': const TranscriptionCompleted()};
      notifier.clearState('test-audio-1');

      expect(container.read(transcriptionTaskManagerProvider), isEmpty);
      container.dispose();
    });

    test('缓存命中 — 跳过上传和轮询，直接完成', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      // mock 文件操作
      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      // mock API: 音频已存在 + 字幕缓存命中
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.mp3',
          publicUrl: 'https://example.com/abc123.mp3',
        ),
      );

      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 2),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      await _seedAudioRows(database, [audioItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      // 记录状态变化
      final states = <TranscriptionTaskState>[];
      container.listen(
        transcriptionTaskManagerProvider.select((m) => m['test-audio-1']),
        (_, next) {
          if (next != null) states.add(next);
        },
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      // 不应调用 uploadToR2
      verifyNever(
        () => mockApi.uploadToR2(
          uploadUrl: any(named: 'uploadUrl'),
          filePath: any(named: 'filePath'),
          contentType: any(named: 'contentType'),
        ),
      );

      // 不应轮询
      verifyNever(
        () =>
            mockApi.getJobStatus(any(), accessToken: any(named: 'accessToken')),
      );

      // 字幕内容应写入 DB transcript_srt 列（含转录文本）
      final savedSrt = await database.audioItemDao.getTranscriptSrt(
        'test-audio-1',
      );
      expect(savedSrt, isNotNull);
      expect(savedSrt!, contains('Hello world'));

      // 最终状态是 Completed
      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );

      // 状态经历: Hashing → Uploading → Processing → Completed
      expect(states.length, greaterThanOrEqualTo(3));
      expect(states.first, isA<TranscriptionHashing>());
      expect(states.last, isA<TranscriptionCompleted>());

      container.dispose();
    });

    test('后端 402（本月额度用尽）→ 进入 TranscriptionQuotaExceeded 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.mp3',
          publicUrl: 'https://example.com/abc123.mp3',
        ),
      );
      // 提交时后端判定额度超限 → 402
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/api/v2/user-audio/submit-transcription',
          ),
          response: Response(
            requestOptions: RequestOptions(
              path: '/api/v2/user-audio/submit-transcription',
            ),
            statusCode: 402,
            data: {
              'code': 'quota_exceeded',
              'quota': {'used': 0, 'limit': 0},
            },
          ),
        ),
      );

      final quotaSignals = <String>[];
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
        quotaDivergenceHandler: quotaSignals.add,
      );
      await _seedAudioRows(database, [audioItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionQuotaExceeded>(),
      );
      expect(
        (notifier.getTaskState('test-audio-1') as TranscriptionQuotaExceeded)
            .reason,
        AiQuotaRejectionReason.unsupportedForFreePlan,
      );
      // E7：402 触发权益分歧收敛信号。
      expect(quotaSignals, ['transcription']);
      container.dispose();
    });

    for (final (backendCode, expectedMessage) in [
      ('file_too_large', 'fileTooLarge'),
      ('audio_not_found', 'audioNotFound'),
      ('audio_expired', 'audioExpired'),
      ('missing_fields', 'requestInvalid'),
      ('api_deprecated', 'apiDeprecated'),
    ]) {
      test('提交返回 $backendCode 时保留可本地化错误码', () async {
        final audioItem = _testAudioItem(audioSha256: 'abc123');

        when(
          () => mockFileOps.computeSha256(any()),
        ).thenAnswer((_) async => 'abc123');
        when(
          () => mockFileOps.getFileSize(any()),
        ).thenAnswer((_) async => 1024);
        when(
          () => mockApi.getUploadUrl(
            sha256: any(named: 'sha256'),
            mimeType: any(named: 'mimeType'),
            fileSize: any(named: 'fileSize'),
            accessToken: any(named: 'accessToken'),
          ),
        ).thenAnswer((_) async => const UploadUrlResponse(audioExists: true));
        when(
          () => mockApi.submitTranscription(
            sha256: any(named: 'sha256'),
            fileName: any(named: 'fileName'),
            objectName: any(named: 'objectName'),
            publicUrl: any(named: 'publicUrl'),
            mimeType: any(named: 'mimeType'),
            fileSize: any(named: 'fileSize'),
            language: any(named: 'language'),
            accessToken: any(named: 'accessToken'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(
              path: '/api/v2/user-audio/submit-transcription',
            ),
            response: Response(
              requestOptions: RequestOptions(
                path: '/api/v2/user-audio/submit-transcription',
              ),
              statusCode: 400,
              data: {'code': backendCode},
            ),
          ),
        );

        final container = _createContainer(
          mockApi: mockApi,
          mockFileOps: mockFileOps,
          database: database,
          audioItems: [audioItem],
        );
        final notifier = container.read(
          transcriptionTaskManagerProvider.notifier,
        );

        await notifier.startTranscription(
          audioItem,
          'en',
          accessToken: 'token',
        );

        final state = notifier.getTaskState('test-audio-1');
        expect(state, isA<TranscriptionFailed>());
        expect((state as TranscriptionFailed).message, expectedMessage);

        container.dispose();
      });
    }

    test('提交转录时使用 AudioItem.name 作为后端文件名', () async {
      final audioItem = _testAudioItem(
        name: 'Original Lecture.mp3',
        audioPath: 'audios/imported/abc123def456.m4a',
        audioSha256: 'abc123',
      );

      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.m4a',
          publicUrl: 'https://example.com/abc123.m4a',
        ),
      );
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 2),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      await _seedAudioRows(database, [audioItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      verify(
        () => mockApi.submitTranscription(
          sha256: 'abc123',
          fileName: 'Original Lecture.mp3',
          objectName: 'user-audio/abc123.m4a',
          publicUrl: 'https://example.com/abc123.m4a',
          mimeType: 'audio/mp4',
          fileSize: 1024,
          language: 'en',
          accessToken: 'token',
        ),
      ).called(1);

      container.dispose();
    });

    test('提交转录时优先使用原始 SHA 作为后端缓存 key', () async {
      final audioItem = _testAudioItem(
        audioSha256: 'final-sha',
        originalAudioSha256: 'source-sha',
      );

      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/source-sha.mp3',
          publicUrl: 'https://example.com/source-sha.mp3',
        ),
      );
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 2),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      await _seedAudioRows(database, [audioItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      verify(
        () => mockApi.getUploadUrl(
          sha256: 'source-sha',
          mimeType: 'audio/mpeg',
          fileSize: 1024,
          accessToken: 'token',
        ),
      ).called(1);
      verify(
        () => mockApi.submitTranscription(
          sha256: 'source-sha',
          fileName: 'Test Audio',
          objectName: 'user-audio/source-sha.mp3',
          publicUrl: 'https://example.com/source-sha.mp3',
          mimeType: 'audio/mpeg',
          fileSize: 1024,
          language: 'en',
          accessToken: 'token',
        ),
      ).called(1);

      final updated = container
          .read(audioLibraryProvider)
          .audioItems
          .singleWhere((item) => item.id == audioItem.id);
      expect(updated.audioSha256, 'final-sha');
      expect(updated.originalAudioSha256, 'source-sha');

      container.dispose();
    });

    test('音频已缓存但字幕未缓存 — 跳过上传，创建 job', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      // 音频已存在
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.mp3',
          publicUrl: 'https://example.com/abc123.mp3',
        ),
      );

      // 字幕未缓存，返回 jobId
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async =>
            const SubmitTranscriptionResponse(cached: false, jobId: 'job-123'),
      );

      // 轮询第一次返回 succeeded
      when(
        () => mockApi.getJobStatus(
          'job-123',
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer((_) async => const JobStatusResponse(status: 'succeeded'));

      // 获取转录结果
      when(
        () => mockApi.getTranscript(
          'abc123',
          'en',
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => TranscriptResult(
          sentences: [
            TranscriptSentence(
              text: 'Test',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 1),
            ),
          ],
          fullText: 'Test',
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      // 不应上传
      verifyNever(
        () => mockApi.uploadToR2(
          uploadUrl: any(named: 'uploadUrl'),
          filePath: any(named: 'filePath'),
          contentType: any(named: 'contentType'),
        ),
      );

      // 应该轮询
      verify(
        () => mockApi.getJobStatus(
          'job-123',
          accessToken: any(named: 'accessToken'),
        ),
      ).called(1);

      // 最终完成
      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );

      container.dispose();
    });

    test('用户自己的 AI 字幕会尝试自动校准', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.mp3',
          publicUrl: 'https://example.com/abc123.mp3',
        ),
      );
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: const Duration(milliseconds: 200),
                endTime: const Duration(milliseconds: 800),
                startWordIndex: 0,
                endWordIndex: 1,
              ),
            ],
            words: const [
              WordTimestamp(
                word: 'Hello',
                startTime: Duration(milliseconds: 250),
                endTime: Duration(milliseconds: 500),
              ),
              WordTimestamp(
                word: 'world',
                startTime: Duration(milliseconds: 520),
                endTime: Duration(milliseconds: 760),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        mockAutoAlignService: mockAutoAlignService,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      verify(
        () => mockAutoAlignService.alignIfPossible(
          audioPath: any(named: 'audioPath'),
          sentences: any(named: 'sentences'),
          words: any(named: 'words'),
        ),
      ).called(1);

      container.dispose();
    });

    test('旧偏好关闭字幕校准时，转录后仍自动校准', () async {
      SharedPreferences.setMockInitialValues({
        'developer_subtitle_auto_align_enabled': false,
        'native_language': 'zh-TW',
      });
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.mp3',
          publicUrl: 'https://example.com/abc123.mp3',
        ),
      );
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: const Duration(milliseconds: 200),
                endTime: const Duration(milliseconds: 800),
                startWordIndex: 0,
                endWordIndex: 1,
              ),
            ],
            words: const [
              WordTimestamp(
                word: 'Hello',
                startTime: Duration(milliseconds: 250),
                endTime: Duration(milliseconds: 500),
              ),
              WordTimestamp(
                word: 'world',
                startTime: Duration(milliseconds: 520),
                endTime: Duration(milliseconds: 760),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      // 加载真实历史偏好，验证旧调试开关不再影响正式转录。
      final audioLibrary = TestAudioLibrary();
      final container = ProviderContainer(
        overrides: [
          transcriptionApiClientProvider.overrideWithValue(mockApi),
          transcriptionFileOpsProvider.overrideWithValue(mockFileOps),
          appDatabaseProvider.overrideWithValue(database),
          audioLibraryProvider.overrideWith(() => audioLibrary),
          subtitleAutoAlignServiceProvider.overrideWithValue(
            mockAutoAlignService,
          ),
          analyticsOverride(),
        ],
      );
      addTearDown(container.dispose);
      final settingsReady = Completer<void>();
      container.listen(appSettingsProvider, (_, next) {
        if (next.nativeLanguage == 'zh-TW' && !settingsReady.isCompleted) {
          settingsReady.complete();
        }
      });
      await settingsReady.future;
      container.read(audioLibraryProvider);
      audioLibrary.setItems([audioItem]);

      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      verify(
        () => mockAutoAlignService.alignIfPossible(
          audioPath: any(named: 'audioPath'),
          sentences: any(named: 'sentences'),
          words: any(named: 'words'),
        ),
      ).called(1);
    });

    for (final hasWords in [false, true]) {
      test(hasWords ? '字幕校准失败仍保存原始句边界并完成转录' : '缺少词级时间戳时跳过校准并保存字幕', () async {
        final audioItem = _testAudioItem(audioSha256: 'abc123');
        await _seedAudioRows(database, [audioItem]);
        final sentences = [
          TranscriptSentence(
            text: 'Hello world',
            startTime: const Duration(milliseconds: 200),
            endTime: const Duration(milliseconds: 800),
            startWordIndex: 0,
            endWordIndex: 0,
          ),
        ];
        stubCachedTranscript(
          transcript: TranscriptResult(
            sentences: sentences,
            words: hasWords
                ? const [
                    WordTimestamp(
                      word: 'Hello',
                      startTime: Duration(milliseconds: 250),
                      endTime: Duration(milliseconds: 500),
                    ),
                  ]
                : null,
            fullText: 'Hello world',
          ),
        );
        when(
          () => mockFileOps.getFileSize(any()),
        ).thenAnswer((_) async => 1024);
        when(
          () => mockAutoAlignService.alignIfPossible(
            audioPath: any(named: 'audioPath'),
            sentences: any(named: 'sentences'),
            words: any(named: 'words'),
          ),
        ).thenThrow(StateError('校准失败'));
        final container = _createContainer(
          mockApi: mockApi,
          mockFileOps: mockFileOps,
          database: database,
          mockAutoAlignService: mockAutoAlignService,
          audioItems: [audioItem],
        );
        addTearDown(container.dispose);
        final notifier = container.read(
          transcriptionTaskManagerProvider.notifier,
        );

        await notifier.startTranscription(
          audioItem,
          'en',
          accessToken: 'token',
        );

        expect(
          notifier.getTaskState(audioItem.id),
          isA<TranscriptionCompleted>(),
        );
        final saved = await (database.select(
          database.audioItems,
        )..where((row) => row.id.equals(audioItem.id))).getSingle();
        expect(saved.transcriptSrt, generateSrtContent(sentences));
        if (hasWords) {
          verify(
            () => mockAutoAlignService.alignIfPossible(
              audioPath: any(named: 'audioPath'),
              sentences: any(named: 'sentences'),
              words: any(named: 'words'),
            ),
          ).called(1);
        } else {
          verifyNever(
            () => mockAutoAlignService.alignIfPossible(
              audioPath: any(named: 'audioPath'),
              sentences: any(named: 'sentences'),
              words: any(named: 'words'),
            ),
          );
        }
      });
    }

    test('社区音频 AI 字幕不会尝试自动校准', () async {
      final audioItem = _testAudioItem(
        audioSha256: 'abc123',
      ).copyWith(remoteAudioId: 'remote-1');

      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.mp3',
          publicUrl: 'https://example.com/abc123.mp3',
        ),
      );
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: const Duration(milliseconds: 200),
                endTime: const Duration(milliseconds: 800),
                startWordIndex: 0,
                endWordIndex: 1,
              ),
            ],
            words: const [
              WordTimestamp(
                word: 'Hello',
                startTime: Duration(milliseconds: 250),
                endTime: Duration(milliseconds: 500),
              ),
              WordTimestamp(
                word: 'world',
                startTime: Duration(milliseconds: 520),
                endTime: Duration(milliseconds: 760),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        mockAutoAlignService: mockAutoAlignService,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      verifyNever(
        () => mockAutoAlignService.alignIfPossible(
          audioPath: any(named: 'audioPath'),
          sentences: any(named: 'sentences'),
          words: any(named: 'words'),
        ),
      );

      container.dispose();
    });

    test('submitTranscription 无 jobId 时进入 Failed 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer((_) async => const UploadUrlResponse(audioExists: true));

      // 返回 cached=false 但无 jobId
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const SubmitTranscriptionResponse(cached: false),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      final state = notifier.getTaskState('test-audio-1');
      expect(state, isA<TranscriptionFailed>());
      expect((state as TranscriptionFailed).message, 'server');

      container.dispose();
    });

    test('网络错误进入 Failed 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      final state = notifier.getTaskState('test-audio-1');
      expect(state, isA<TranscriptionFailed>());
      expect((state as TranscriptionFailed).message, 'connection');

      container.dispose();
    });

    test('DioException cancel 类型不设置 Failed 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.cancel,
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      // Cancel 不应设置 Failed，状态停留在最后一次 _updateState
      final state = notifier.getTaskState('test-audio-1');
      expect(state, isNot(isA<TranscriptionFailed>()));

      container.dispose();
    });

    test('轮询中 job 失败进入 Failed 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer((_) async => const UploadUrlResponse(audioExists: true));

      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async =>
            const SubmitTranscriptionResponse(cached: false, jobId: 'job-fail'),
      );

      when(
        () => mockApi.getJobStatus(
          'job-fail',
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const JobStatusResponse(
          status: 'failed',
          errorMessage: 'Deepgram error: unsupported format',
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      final state = notifier.getTaskState('test-audio-1');
      expect(state, isA<TranscriptionFailed>());
      expect((state as TranscriptionFailed).message, 'server');

      container.dispose();
    });

    test('已有 SHA256 缓存时跳过计算', () async {
      final audioItem = _testAudioItem(audioSha256: 'cached-sha');

      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          message: 'stop here',
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      // 不应调用 computeSha256
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('新导入转录成功 — 触发转码、更新 audioPath/sha 并删除原始文件', () async {
      // 新导入：audioSha256 == originalAudioSha256，存的还是原始文件。
      final dataDir = await Directory.systemTemp.createTemp('tx_transcode_ok_');
      addTearDown(() async {
        if (await dataDir.exists()) await dataDir.delete(recursive: true);
      });
      const originalRel = 'audios/imported/orig-sha.mp3';
      final originalFile = File('${dataDir.path}/$originalRel');
      await originalFile.create(recursive: true);
      await originalFile.writeAsBytes([1, 2, 3]);

      final audioItem = _testAudioItem(
        audioPath: originalRel,
        audioSha256: 'orig-sha',
        originalAudioSha256: 'orig-sha',
      );

      when(() => mockFileOps.getDataDir()).thenAnswer((_) async => dataDir);
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      stubCachedTranscript();

      final fakeFinalization = _FakeFinalizationService(
        result: const FinalizedAudio(
          relativePath: 'audios/imported/new-sha.m4a',
          sha256: 'new-sha',
          originalSha256: 'orig-sha',
          created: true,
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        finalizationService: fakeFinalization,
        audioItems: [audioItem],
      );
      await _seedAudioRows(database, [audioItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      expect(fakeFinalization.calls, 1);
      final updated = container
          .read(audioLibraryProvider)
          .audioItems
          .singleWhere((item) => item.id == audioItem.id);
      expect(updated.audioPath, 'audios/imported/new-sha.m4a');
      expect(updated.audioSha256, 'new-sha');
      // originalAudioSha256 保持原始 sha 不变（转录缓存 key 稳定）。
      expect(updated.originalAudioSha256, 'orig-sha');
      // 字幕已保存、状态完成。
      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );
      final savedSrt = await database.audioItemDao.getTranscriptSrt(
        'test-audio-1',
      );
      expect(savedSrt, contains('Hello world'));
      // 旧原始文件已删除。
      expect(await originalFile.exists(), isFalse);

      container.dispose();
    });

    test('转码成功但原始文件被其他条目共享时不删除原始文件', () async {
      // 同内容导入会复用同一文件：另一条目也指向 originalRel。对当前条目转码后
      // 不能删旧文件，否则会删掉共享条目仍在用的音频。
      final dataDir = await Directory.systemTemp.createTemp('tx_shared_');
      addTearDown(() async {
        if (await dataDir.exists()) await dataDir.delete(recursive: true);
      });
      const originalRel = 'audios/imported/orig-sha.mp3';
      final originalFile = File('${dataDir.path}/$originalRel');
      await originalFile.create(recursive: true);
      await originalFile.writeAsBytes([1, 2, 3]);

      final audioItem = _testAudioItem(
        audioPath: originalRel,
        audioSha256: 'orig-sha',
        originalAudioSha256: 'orig-sha',
      );
      // 共享同一文件的另一条目（不参与本次转录）。
      final sharingItem = _testAudioItem(
        id: 'test-audio-2',
        audioPath: originalRel,
        audioSha256: 'orig-sha',
        originalAudioSha256: 'orig-sha',
      );

      when(() => mockFileOps.getDataDir()).thenAnswer((_) async => dataDir);
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      stubCachedTranscript();

      final fakeFinalization = _FakeFinalizationService(
        result: const FinalizedAudio(
          relativePath: 'audios/imported/new-sha.m4a',
          sha256: 'new-sha',
          originalSha256: 'orig-sha',
          created: true,
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        finalizationService: fakeFinalization,
        audioItems: [audioItem, sharingItem],
      );
      await _seedAudioRows(database, [audioItem, sharingItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      // 当前条目已转码到新路径。
      final updated = container
          .read(audioLibraryProvider)
          .audioItems
          .singleWhere((item) => item.id == audioItem.id);
      expect(updated.audioPath, 'audios/imported/new-sha.m4a');
      // 共享条目仍指向原始文件，且原始文件因仍被引用而保留。
      expect(await originalFile.exists(), isTrue);

      container.dispose();
    });

    test('转码失败 — 静默保留原始：仍完成、字幕已存、audioPath 不变、原始未删', () async {
      final dataDir = await Directory.systemTemp.createTemp(
        'tx_transcode_err_',
      );
      addTearDown(() async {
        if (await dataDir.exists()) await dataDir.delete(recursive: true);
      });
      const originalRel = 'audios/imported/orig-sha.mp3';
      final originalFile = File('${dataDir.path}/$originalRel');
      await originalFile.create(recursive: true);
      await originalFile.writeAsBytes([1, 2, 3]);

      final audioItem = _testAudioItem(
        audioPath: originalRel,
        audioSha256: 'orig-sha',
        originalAudioSha256: 'orig-sha',
      );

      when(() => mockFileOps.getDataDir()).thenAnswer((_) async => dataDir);
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      stubCachedTranscript();

      final fakeFinalization = _FakeFinalizationService(
        error: const AudioImportException(
          AudioImportFailureCode.storage,
          'boom',
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        finalizationService: fakeFinalization,
        audioItems: [audioItem],
      );
      await _seedAudioRows(database, [audioItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      expect(fakeFinalization.calls, 1);
      // 转录仍视为成功。
      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );
      final savedSrt = await database.audioItemDao.getTranscriptSrt(
        'test-audio-1',
      );
      expect(savedSrt, contains('Hello world'));
      final updated = container
          .read(audioLibraryProvider)
          .audioItems
          .singleWhere((item) => item.id == audioItem.id);
      // audioPath/sha 保持原始，下次重新转录会再次尝试（sha 仍相等）。
      expect(updated.audioPath, originalRel);
      expect(updated.audioSha256, 'orig-sha');
      // 原始文件未被删除。
      expect(await originalFile.exists(), isTrue);

      container.dispose();
    });

    test('视频条目转录成功 — 不转码，保留原始 mp4、audioPath/isVideo 不变', () async {
      // 视频不能被转码为 m4a（会丢画面）；转录只写字幕，文件保持视频。
      final dataDir = await Directory.systemTemp.createTemp('tx_video_');
      addTearDown(() async {
        if (await dataDir.exists()) await dataDir.delete(recursive: true);
      });
      const videoRel = 'audios/imported/orig-sha.mp4';
      final videoFile = File('${dataDir.path}/$videoRel');
      await videoFile.create(recursive: true);
      await videoFile.writeAsBytes([1, 2, 3]);

      final videoItem = _testAudioItem(
        audioPath: videoRel,
        audioSha256: 'orig-sha',
        originalAudioSha256: 'orig-sha',
      );
      expect(videoItem.isVideo, isTrue);

      when(() => mockFileOps.getDataDir()).thenAnswer((_) async => dataDir);
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      stubCachedTranscript();

      // 若被误调用会返回一个 m4a，从而让断言失败。
      final fakeFinalization = _FakeFinalizationService(
        result: const FinalizedAudio(
          relativePath: 'audios/imported/new-sha.m4a',
          sha256: 'new-sha',
          originalSha256: 'orig-sha',
          created: true,
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        finalizationService: fakeFinalization,
        // 抽音轨失败 → 回退上传原视频（不触达真实 ffmpeg）。
        audioExtractor: _FakeAudioExtractor(),
        audioItems: [videoItem],
      );
      await _seedAudioRows(database, [videoItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(videoItem, 'en', accessToken: 'token');

      // 关键：转码从未被调用。
      expect(fakeFinalization.calls, 0);
      final updated = container
          .read(audioLibraryProvider)
          .audioItems
          .singleWhere((item) => item.id == videoItem.id);
      // audioPath 仍是 mp4，isVideo 仍为 true。
      expect(updated.audioPath, videoRel);
      expect(updated.isVideo, isTrue);
      // 原始视频文件保留。
      expect(await videoFile.exists(), isTrue);
      // 字幕已保存、状态完成。
      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );
      final savedSrt = await database.audioItemDao.getTranscriptSrt(
        'test-audio-1',
      );
      expect(savedSrt, contains('Hello world'));

      container.dispose();
    });

    test('视频条目转录 — 只上传音轨、但缓存 key 仍用视频 sha、不计算音轨 sha、清理临时文件', () async {
      final dataDir = await Directory.systemTemp.createTemp(
        'tx_video_extract_',
      );
      addTearDown(() async {
        if (await dataDir.exists()) await dataDir.delete(recursive: true);
      });
      const videoRel = 'audios/imported/video-sha.mp4';
      final videoFile = File('${dataDir.path}/$videoRel');
      await videoFile.create(recursive: true);
      await videoFile.writeAsBytes([1, 2, 3]);

      // 抽出的临时音轨（.m4a）。
      final tmpAudio = File('${dataDir.path}/tmp/transcription/video-sha.m4a');
      await tmpAudio.create(recursive: true);
      await tmpAudio.writeAsBytes([4, 5, 6]);

      final videoItem = _testAudioItem(
        audioPath: videoRel,
        audioSha256: 'video-sha',
        originalAudioSha256: 'video-sha',
      );
      expect(videoItem.isVideo, isTrue);

      when(() => mockFileOps.getDataDir()).thenAnswer((_) async => dataDir);
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 512);

      // 音频未存在 → 需要上传。objectName/publicUrl 由服务端按视频 sha 派生。
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: false,
          uploadUrl: 'https://r2.example.com/put',
          objectName: 'user-audio/video-sha.m4a',
          publicUrl: 'https://cdn.example.com/video-sha.m4a',
        ),
      );
      when(
        () => mockApi.uploadToR2(
          uploadUrl: any(named: 'uploadUrl'),
          filePath: any(named: 'filePath'),
          contentType: any(named: 'contentType'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 2),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      final extractor = _FakeAudioExtractor(output: tmpAudio.path);
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioExtractor: extractor,
        audioItems: [videoItem],
      );
      await _seedAudioRows(database, [videoItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(videoItem, 'en', accessToken: 'token');

      // 抽音轨被调用，入参是视频绝对路径。
      expect(extractor.calls, 1);
      expect(extractor.lastVideoPath, videoFile.path);

      // 上传的是临时音轨，而非原视频。
      verify(
        () => mockApi.uploadToR2(
          uploadUrl: 'https://r2.example.com/put',
          filePath: tmpAudio.path,
          contentType: 'audio/mp4',
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);

      // 缓存 key 用稳定的视频 sha，绝不用设备侧音轨 sha；音轨 sha 不参与计算。
      verifyNever(() => mockFileOps.computeSha256(tmpAudio.path));
      verify(
        () => mockApi.getUploadUrl(
          sha256: 'video-sha',
          mimeType: 'audio/mp4',
          fileSize: 512,
          accessToken: 'token',
        ),
      ).called(1);
      verify(
        () => mockApi.submitTranscription(
          sha256: 'video-sha',
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: 'audio/mp4',
          fileSize: 512,
          language: 'en',
          accessToken: 'token',
        ),
      ).called(1);

      // 临时音轨在上传结束后被清理；原视频文件保留。
      expect(await tmpAudio.exists(), isFalse);
      expect(await videoFile.exists(), isTrue);

      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );

      container.dispose();
    });

    test('视频抽音轨失败 — 回退上传原视频', () async {
      final dataDir = await Directory.systemTemp.createTemp('tx_video_fb_');
      addTearDown(() async {
        if (await dataDir.exists()) await dataDir.delete(recursive: true);
      });
      const videoRel = 'audios/imported/video-sha.mp4';
      final videoFile = File('${dataDir.path}/$videoRel');
      await videoFile.create(recursive: true);
      await videoFile.writeAsBytes([1, 2, 3]);

      final videoItem = _testAudioItem(
        audioPath: videoRel,
        audioSha256: 'video-sha',
        originalAudioSha256: 'video-sha',
      );

      when(() => mockFileOps.getDataDir()).thenAnswer((_) async => dataDir);
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 2048);
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: false,
          uploadUrl: 'https://r2.example.com/put',
          objectName: 'user-audio/video-sha.mp4',
          publicUrl: 'https://cdn.example.com/video-sha.mp4',
        ),
      );
      when(
        () => mockApi.uploadToR2(
          uploadUrl: any(named: 'uploadUrl'),
          filePath: any(named: 'filePath'),
          contentType: any(named: 'contentType'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 2),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        // 抽取失败。
        audioExtractor: _FakeAudioExtractor(),
        audioItems: [videoItem],
      );
      await _seedAudioRows(database, [videoItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(videoItem, 'en', accessToken: 'token');

      // 回退：上传原视频、用视频 sha 与 video/mp4 提交。
      verify(
        () => mockApi.uploadToR2(
          uploadUrl: 'https://r2.example.com/put',
          filePath: videoFile.path,
          contentType: 'video/mp4',
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verify(
        () => mockApi.submitTranscription(
          sha256: 'video-sha',
          fileName: any(named: 'fileName'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: 'video/mp4',
          fileSize: 2048,
          language: 'en',
          accessToken: 'token',
        ),
      ).called(1);

      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );

      container.dispose();
    });

    test('音频条目不触发抽音轨', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      stubCachedTranscript();

      final extractor = _FakeAudioExtractor(output: '/should/not/be/used.m4a');
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        database: database,
        audioExtractor: extractor,
        audioItems: [audioItem],
      );
      await _seedAudioRows(database, [audioItem]);
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en', accessToken: 'token');

      // 音频条目不应抽音轨。
      expect(extractor.calls, 0);

      container.dispose();
    });

    test('_getMimeType 正确映射文件扩展名', () {
      // 通过反射测试静态方法（用公开间接方式验证）
      // 验证 .m4a 文件不会硬编码为 audio/mpeg
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.mp3'),
        'audio/mpeg',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.m4a'),
        'audio/mp4',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.wav'),
        'audio/wav',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.flac'),
        'audio/flac',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.ogg'),
        'audio/ogg',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('TEST.MP3'),
        'audio/mpeg',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('unknown.xyz'),
        'audio/mpeg',
      );
    });
  });
}
