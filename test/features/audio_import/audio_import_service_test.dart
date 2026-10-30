import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_registration_service.dart';
import 'package:echo_loop/features/audio_import/audio_import_service.dart';
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _FakeDownloadRunner implements BackgroundDownloadRunner {
  _FakeDownloadRunner({
    this.bytes = const <int>[1, 2, 3, 4],
    this.result = const BackgroundDownloadResult(
      status: BackgroundDownloadStatus.complete,
    ),
    this.totalBytes,
    this.writePartialOnFailure = false,
  });

  final List<int> bytes;
  final BackgroundDownloadResult result;
  final int? totalBytes;

  /// 模拟系统下载在取消/失败前已落盘一部分数据。
  final bool writePartialOnFailure;
  Uri? lastUri;
  String? lastDisplayName;

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) async {
    lastUri = uri;
    lastDisplayName = displayName;
    onProgress?.call(totalBytes == null ? 0 : bytes.length, totalBytes);
    if (result.status == BackgroundDownloadStatus.complete ||
        writePartialOnFailure) {
      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsBytes(bytes);
    }
    return result;
  }
}

BackgroundFileDownloadService _backgroundDownloader(
  _FakeDownloadRunner runner,
) => BackgroundFileDownloadService(runner: runner);

class _FakeAudioLibrary extends AudioLibrary {
  _FakeAudioLibrary([this.initialState = const AudioLibraryState()]);

  final AudioLibraryState initialState;

  @override
  AudioLibraryState build() => initialState;

  @override
  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(audioItems: [...state.audioItems, item]);
  }

  @override
  Future<void> addAudioItems(List<AudioItem> items) async {
    state = state.copyWith(audioItems: [...state.audioItems, ...items]);
  }
}

class _FakeCollectionList extends CollectionList {
  _FakeCollectionList([this.initialState = const CollectionState()]);

  final CollectionState initialState;

  @override
  CollectionState build() => initialState;

  @override
  Future<void> addAudioToCollection(String collectionId, String audioId) async {
    await addAudiosToCollection(collectionId, [audioId]);
  }

  @override
  Future<void> addAudiosToCollection(
    String collectionId,
    List<String> audioIds,
  ) async {
    final next = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(next[collectionId] ?? const <String>[]);
    for (final audioId in audioIds) {
      if (!ids.contains(audioId)) ids.add(audioId);
    }
    next[collectionId] = ids;
    state = state.copyWith(audioIdsMap: next);
  }
}

void main() {
  group('AudioImportService.resolveUrl', () {
    late _MockDio dio;
    late AudioImportService service;

    setUp(() {
      dio = _MockDio();
      service = AudioImportService(dio: dio);
    });

    test('解析带支持扩展名的音频直链', () async {
      when(
        () => dio.head<Object>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<Object>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['audio/mpeg'],
            Headers.contentLengthHeader: ['1234'],
          }),
        ),
      );

      final resolved = await service.resolveUrl(
        'https://example.com/podcast/episode-1.mp3?token=abc',
      );

      expect(resolved.displayName, 'episode-1');
      expect(resolved.fileName, 'episode-1.mp3');
      expect(resolved.extension, 'mp3');
      expect(resolved.mimeType, 'audio/mpeg');
    });

    test('无扩展名时从 audio content-type 推断格式', () async {
      when(
        () => dio.head<Object>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<Object>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['audio/mp4'],
          }),
        ),
      );

      final resolved = await service.resolveUrl('https://example.com/audio');

      expect(resolved.displayName, 'audio');
      expect(resolved.fileName, 'audio.m4a');
    });

    test('非 http/https URL 被拒绝', () async {
      expect(
        () => service.resolveUrl('ftp://example.com/a.mp3'),
        throwsA(
          isA<AudioImportException>().having(
            (e) => e.code,
            'code',
            AudioImportFailureCode.unsupportedScheme,
          ),
        ),
      );
    });

    test('非音频 content-type 被拒绝', () async {
      when(
        () => dio.head<Object>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<Object>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['text/html'],
          }),
        ),
      );

      expect(
        () => service.resolveUrl('https://example.com/page.mp3'),
        throwsA(
          isA<AudioImportException>().having(
            (e) => e.code,
            'code',
            AudioImportFailureCode.notAudio,
          ),
        ),
      );
    });
  });

  group('AudioRegistrationService', () {
    test('注册 MKV 视频时保存统一媒体探测得到的时长', () async {
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 83,
      );

      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'lesson',
          relativePath: 'videos/lesson.mkv',
          importSourceType: AudioImportSourceType.cloudDrive,
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      final item = switch (result) {
        AudioRegistrationAdded(:final item) => item,
        AudioRegistrationDuplicate() => fail('Expected new MKV registration'),
      };
      expect(item.isVideo, isTrue);
      expect(item.totalDuration, 83);
      expect(
        container.read(audioLibraryProvider).audioItems.single.totalDuration,
        83,
      );
    });

    test('本地导入只记录来源类型，不记录设备原始路径', () async {
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 5,
      );

      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'local',
          relativePath: 'audios/local.mp3',
          importSourceType: AudioImportSourceType.local,
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      final item = (result as AudioRegistrationAdded).item;
      expect(item.importSourceType, AudioImportSourceType.local);
      expect(item.importSourceUrl, isNull);
    });

    test('无合集时相同原始 hash 视为重复并跳过（按内容全局去重）', () async {
      final existing = AudioItem(
        id: 'a1',
        name: 'existing',
        audioPath: 'audios/sha.m4a',
        audioSha256: 'sha',
        originalAudioSha256: 'sha',
        addedDate: DateTime(2026, 1, 1),
      );
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 5,
      );

      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'new-name',
          relativePath: 'audios/sha.m4a',
          importSourceType: AudioImportSourceType.local,
          audioSha256: 'sha',
          originalAudioSha256: 'sha',
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      expect(result, isA<AudioRegistrationDuplicate>());
      // 库中不新建第二个同内容条目。
      expect(container.read(audioLibraryProvider).audioItems, [existing]);
    });

    test('同名但 hash 不同的音频可以共存', () async {
      final existing = AudioItem(
        id: 'a1',
        name: 'lesson',
        audioPath: 'audios/old.m4a',
        audioSha256: 'old-sha',
        originalAudioSha256: 'old-sha',
        addedDate: DateTime(2026, 1, 1),
      );
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 5,
      );

      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'lesson',
          relativePath: 'audios/new.m4a',
          importSourceType: AudioImportSourceType.local,
          audioSha256: 'new-sha',
          originalAudioSha256: 'new-sha',
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      final added = result as AudioRegistrationAdded;
      expect(added.item.name, 'lesson');
      expect(added.item.audioSha256, 'new-sha');
      expect(container.read(audioLibraryProvider).audioItems, [
        existing,
        added.item,
      ]);
    });

    test('同合集内相同原始 hash 视为重复并跳过', () async {
      final existing = AudioItem(
        id: 'a1',
        name: 'existing',
        audioPath: 'audios/sha.m4a',
        audioSha256: 'sha',
        originalAudioSha256: 'orig-sha',
        addedDate: DateTime(2026, 1, 1),
      );
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
          collectionListProvider.overrideWith(
            () => _FakeCollectionList(
              const CollectionState(
                audioIdsMap: {
                  'c1': ['a1'],
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 5,
      );

      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'new-name',
          relativePath: 'audios/sha.m4a',
          importSourceType: AudioImportSourceType.local,
          audioSha256: 'orig-sha',
          originalAudioSha256: 'orig-sha',
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        collectionState: container.read(collectionListProvider),
        collectionId: 'c1',
      );

      expect(result, isA<AudioRegistrationDuplicate>());
      expect((result as AudioRegistrationDuplicate).name, 'existing');
      // 未新建条目
      expect(container.read(audioLibraryProvider).audioItems, [existing]);
    });

    test('相同原始 hash 但不在目标合集时关联已有条目而非新建', () async {
      final existing = AudioItem(
        id: 'a1',
        name: 'existing',
        audioPath: 'audios/sha.m4a',
        audioSha256: 'sha',
        originalAudioSha256: 'orig-sha',
        addedDate: DateTime(2026, 1, 1),
      );
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
          collectionListProvider.overrideWith(_FakeCollectionList.new),
        ],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 5,
      );

      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'new-name',
          relativePath: 'audios/sha.m4a',
          importSourceType: AudioImportSourceType.local,
          audioSha256: 'orig-sha',
          originalAudioSha256: 'orig-sha',
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        collectionState: container.read(collectionListProvider),
        collectionId: 'c2',
      );

      final added = result as AudioRegistrationAdded;
      // 复用已有条目，不新建
      expect(added.item.id, 'a1');
      expect(container.read(audioLibraryProvider).audioItems, [existing]);
      // 已有条目被关联到目标合集
      expect(container.read(collectionListProvider).getAudioIds('c2'), ['a1']);
    });

    test('已 AI 转录（audioSha256 已变）后再导入同一文件仍按原始 hash 去重', () async {
      // 模拟：导入→AI 转录转码后，条目 audioSha256 变成转码后指纹，
      // originalAudioSha256 仍是原始指纹。再次导入同一原始文件应识别为重复。
      final existing = AudioItem(
        id: 'a1',
        name: 'existing',
        audioPath: 'audios/transcoded.m4a',
        audioSha256: 'transcoded-sha',
        originalAudioSha256: 'orig-sha',
        addedDate: DateTime(2026, 1, 1),
      );
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
          collectionListProvider.overrideWith(
            () => _FakeCollectionList(
              const CollectionState(
                audioIdsMap: {
                  'c1': ['a1'],
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 5,
      );

      // 再次导入：finalize 不转码，audioSha256 == originalAudioSha256 == 原始指纹
      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'new-name',
          relativePath: 'audios/orig-sha.mp3',
          importSourceType: AudioImportSourceType.local,
          audioSha256: 'orig-sha',
          originalAudioSha256: 'orig-sha',
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        collectionState: container.read(collectionListProvider),
        collectionId: 'c1',
      );

      expect(result, isA<AudioRegistrationDuplicate>());
      expect(container.read(audioLibraryProvider).audioItems, [existing]);
    });

    test('重复项同时携带本次导入名与已有条目名（内容同、名不同）', () async {
      final existing = AudioItem(
        id: 'a1',
        name: 'TPO-32-L4',
        audioPath: 'audios/sha.m4a',
        audioSha256: 'sha',
        originalAudioSha256: 'orig-sha',
        addedDate: DateTime(2026, 1, 1),
      );
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
          collectionListProvider.overrideWith(
            () => _FakeCollectionList(
              const CollectionState(
                audioIdsMap: {
                  'c1': ['a1'],
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 5,
      );

      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'TPO-32-L4 copy copy',
          relativePath: 'audios/sha.m4a',
          importSourceType: AudioImportSourceType.local,
          audioSha256: 'orig-sha',
          originalAudioSha256: 'orig-sha',
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        collectionState: container.read(collectionListProvider),
        collectionId: 'c1',
      );

      final dup = result as AudioRegistrationDuplicate;
      expect(dup.attemptedName, 'TPO-32-L4 copy copy');
      expect(dup.existingName, 'TPO-32-L4');
      expect(dup.name, 'TPO-32-L4'); // 兼容 getter
    });

    test('按名去重（无原始 hash）重复项 attemptedName 与 existingName 一致', () async {
      final existing = AudioItem(
        id: 'a1',
        name: 'lesson',
        audioPath: 'audios/old.m4a',
        addedDate: DateTime(2026, 1, 1),
      );
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = AudioRegistrationService(
        readDurationSeconds: (_) async => 5,
      );

      final result = await service.registerSandboxedAudio(
        input: const SandboxedAudioRegistrationInput(
          name: 'lesson',
          relativePath: 'audios/lesson.mp3',
          importSourceType: AudioImportSourceType.local,
        ),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      final dup = result as AudioRegistrationDuplicate;
      expect(dup.attemptedName, 'lesson');
      expect(dup.existingName, 'lesson');
    });
  });

  group('AudioImportService.importFromUrl', () {
    late Directory tmpDir;
    late _MockDio dio;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('audio_import_test_');
      dio = _MockDio();
      when(
        () => dio.head<Object>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<Object>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['audio/mpeg'],
            Headers.contentLengthHeader: ['1234'],
          }),
        ),
      );
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('HEAD 大小与落盘大小不一致时仍接受平台报告完成的下载', () async {
      final runner = _FakeDownloadRunner(
        bytes: const <int>[1, 2, 3, 4],
        totalBytes: 8,
      );
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(runner),
        // 导入不再转码：仅对原始 .mp3 计算指纹。
        computeSha256: (path) async {
          expect(path, endsWith('.mp3'));
          return 'sha-original';
        },
        registrationService: AudioRegistrationService(
          readDurationSeconds: (path) async {
            expect(path, endsWith('.mp3'));
            return 42;
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);

      final item = await service.importFromUrl(
        url: 'https://example.com/lesson.mp3',
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      expect(item.name, 'lesson');
      expect(runner.lastDisplayName, item.name);
      // 保留原始格式与扩展名，audioSha256 == originalAudioSha256。
      expect(item.audioPath, 'audios/imported/sha-original.mp3');
      expect(item.totalDuration, 42);
      expect(item.audioSha256, 'sha-original');
      expect(item.originalAudioSha256, 'sha-original');
      expect(item.importSourceType, AudioImportSourceType.directUrl);
      expect(item.importSourceUrl, 'https://example.com/lesson.mp3');
      expect(container.read(audioLibraryProvider).audioItems, [item]);
      expect(await File('${tmpDir.path}/${item.audioPath}').exists(), isTrue);
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });

    test('下载被取消 → AudioImportException(canceled) 且不留临时文件', () async {
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(
          _FakeDownloadRunner(
            result: const BackgroundDownloadResult(
              status: BackgroundDownloadStatus.canceled,
            ),
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);

      await expectLater(
        service.importFromUrl(
          url: 'https://example.com/lesson.mp3',
          audioLibrary: container.read(audioLibraryProvider.notifier),
          audioLibraryState: container.read(audioLibraryProvider),
        ),
        throwsA(
          isA<AudioImportException>().having(
            (e) => e.code,
            'code',
            AudioImportFailureCode.canceled,
          ),
        ),
      );
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });

    test('下载网络失败（404）→ AudioImportException(network) 且不留临时文件', () async {
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(
          _FakeDownloadRunner(
            result: const BackgroundDownloadResult(
              status: BackgroundDownloadStatus.notFound,
              statusCode: 404,
            ),
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);

      await expectLater(
        service.importFromUrl(
          url: 'https://example.com/lesson.mp3',
          audioLibrary: container.read(audioLibraryProvider.notifier),
          audioLibraryState: container.read(audioLibraryProvider),
        ),
        throwsA(
          isA<AudioImportException>().having(
            (e) => e.code,
            'code',
            AudioImportFailureCode.network,
          ),
        ),
      );
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });

    test('合集入口遇到不在合集的相同 hash 音频时关联已有条目而非新建', () async {
      final existing = AudioItem(
        id: 'a1',
        name: 'existing lesson',
        audioPath: 'audios/imported/sha-existing.mp3',
        audioSha256: 'sha-existing',
        originalAudioSha256: 'sha-existing',
        addedDate: DateTime(2026, 1, 1),
      );
      final existingFile = File('${tmpDir.path}/${existing.audioPath}');
      await existingFile.create(recursive: true);
      await existingFile.writeAsBytes([9, 9, 9]);
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
          collectionListProvider.overrideWith(_FakeCollectionList.new),
        ],
      );
      addTearDown(container.dispose);
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(
          _FakeDownloadRunner(bytes: const <int>[1, 2, 3, 4]),
        ),
        computeSha256: (_) async => 'sha-existing',
      );

      final item = await service.importFromUrl(
        url: 'https://example.com/lesson.mp3',
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        collectionId: 'c1',
      );

      // 复用已有条目，不新建
      expect(item.id, existing.id);
      expect(item.name, existing.name);
      expect(item.audioPath, existing.audioPath);
      expect(container.read(audioLibraryProvider).audioItems, [existing]);
      // 已有条目被关联到目标合集
      expect(container.read(collectionListProvider).getAudioIds('c1'), [
        existing.id,
      ]);
      expect(
        await File('${tmpDir.path}/audios/imported/sha-existing.mp3').exists(),
        isTrue,
      );
      expect(await existingFile.readAsBytes(), [9, 9, 9]);
    });
  });

  group('AudioImportService.downloadEpisodeToSandbox', () {
    late Directory tmpDir;
    late _MockDio dio;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('episode_download_test_');
      dio = _MockDio();
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('Podcast 单集手动取消时删除已落盘的部分文件', () async {
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(
          _FakeDownloadRunner(
            bytes: const <int>[1, 2, 3],
            writePartialOnFailure: true,
            result: const BackgroundDownloadResult(
              status: BackgroundDownloadStatus.canceled,
            ),
          ),
        ),
      );

      await expectLater(
        service.downloadEpisodeToSandbox(
          url: 'https://example.com/episode.mp3',
          displayName: 'Episode 1',
          enclosureType: 'audio/mpeg',
        ),
        throwsA(
          isA<AudioImportException>().having(
            (e) => e.code,
            'code',
            AudioImportFailureCode.canceled,
          ),
        ),
      );
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });

    test('Podcast 单集自然失败时保留已落盘的部分文件，供下次继续', () async {
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(
          _FakeDownloadRunner(
            bytes: const <int>[1, 2, 3],
            writePartialOnFailure: true,
            result: const BackgroundDownloadResult(
              status: BackgroundDownloadStatus.failed,
              statusCode: 503,
            ),
          ),
        ),
      );

      await expectLater(
        service.downloadEpisodeToSandbox(
          url: 'https://example.com/episode.mp3',
          displayName: 'Episode 1',
          enclosureType: 'audio/mpeg',
        ),
        throwsA(
          isA<AudioImportException>().having(
            (e) => e.code,
            'code',
            AudioImportFailureCode.network,
          ),
        ),
      );
      expect(await _tmpAudioImportFiles(tmpDir), hasLength(1));
    });

    test('Podcast 单集下载成功后保留原始音频', () async {
      final runner = _FakeDownloadRunner(bytes: const <int>[5, 6, 7, 8]);
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(runner),
        computeSha256: (path) async {
          expect(path, endsWith('.mp3'));
          return 'sha-episode';
        },
        readDurationSeconds: (path) async {
          expect(path, endsWith('.mp3'));
          return 61;
        },
      );

      final result = await service.downloadEpisodeToSandbox(
        url: 'https://example.com/episode.mp3',
        displayName: 'Episode 1: Welcome',
        enclosureType: 'audio/mpeg',
      );

      expect(runner.lastDisplayName, 'Episode 1: Welcome');
      expect(result.relativePath, 'audios/imported/sha-episode.mp3');
      expect(result.durationSeconds, 61);
      expect(result.audioSha256, 'sha-episode');
      expect(result.originalAudioSha256, 'sha-episode');
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });

    test('目标 hash 文件已存在时复用已有文件且不覆盖内容', () async {
      final importedDir = Directory('${tmpDir.path}/audios/imported');
      await importedDir.create(recursive: true);
      final existingFile = File('${importedDir.path}/sha-episode.mp3');
      await existingFile.writeAsBytes([9, 9, 9]);
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(
          _FakeDownloadRunner(bytes: const <int>[5, 6, 7, 8]),
        ),
        computeSha256: (_) async => 'sha-episode',
        readDurationSeconds: (_) async => 61,
      );

      final result = await service.downloadEpisodeToSandbox(
        url: 'https://example.com/episode.mp3',
        displayName: 'Episode 1',
        enclosureType: 'audio/mpeg',
      );

      expect(result.relativePath, 'audios/imported/sha-episode.mp3');
      expect(await existingFile.readAsBytes(), [9, 9, 9]);
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });

    test('BBC 旧 HTTP enclosure 下载前自动升级为 HTTPS secure URL', () async {
      final runner = _FakeDownloadRunner(bytes: const <int>[5, 6, 7, 8]);
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(runner),
        computeSha256: (_) async => 'sha-episode',
        readDurationSeconds: (_) async => 61,
      );

      await service.downloadEpisodeToSandbox(
        url:
            'http://open.live.bbc.co.uk/mediaselector/6/redir/version/2.0/mediaset/audio-nondrm-download-rss-low/proto/http/vpid/p0n4bjcm.mp3',
        displayName: 'BBC episode title',
        enclosureType: 'audio/mpeg',
      );

      expect(
        runner.lastUri.toString(),
        startsWith('https://open.live.bbc.co.uk/'),
      );
      expect(runner.lastUri.toString(), contains('/proto/https/'));
      expect(runner.lastUri.toString(), endsWith('/vpid/p0n4bjcm.mp3'));
    });

    test('Anchor 播客重定向 URL 直接下载其内嵌的媒体 URL', () async {
      final runner = _FakeDownloadRunner(bytes: const <int>[5, 6, 7, 8]);
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        backgroundDownloader: _backgroundDownloader(runner),
        computeSha256: (_) async => 'sha-episode',
        readDurationSeconds: (_) async => 61,
      );

      await service.downloadEpisodeToSandbox(
        url:
            'https://anchor.fm/s/show/podcast/play/123/'
            'https%3A%2F%2Fcdn.example.com%2Fepisode.mp3',
        displayName: 'Anchor episode title',
        enclosureType: 'audio/mpeg',
      );

      expect(runner.lastUri, Uri.parse('https://cdn.example.com/episode.mp3'));
      expect(runner.lastDisplayName, 'Anchor episode title');
    });
  });
}

Future<List<FileSystemEntity>> _tmpAudioImportFiles(Directory dataDir) async {
  final dir = Directory('${dataDir.path}/tmp/audio_import');
  if (!await dir.exists()) return const [];
  return dir.list().toList();
}
