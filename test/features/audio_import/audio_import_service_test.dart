import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_registration_service.dart';
import 'package:echo_loop/features/audio_import/audio_import_service.dart';
import 'package:echo_loop/features/audio_import/audio_transcode_service.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _FakeTranscodeService extends AudioTranscodeService {
  _FakeTranscodeService({required this.shouldTranscode});

  final bool shouldTranscode;

  @override
  Future<AudioTranscodeResult> transcodeToM4a({
    required Directory dataDir,
    required String relativePath,
  }) async {
    if (!shouldTranscode) {
      return AudioTranscodeResult(
        relativePath: relativePath,
        transcoded: false,
      );
    }
    final source = File('${dataDir.path}/$relativePath');
    final targetRelativePath = relativePath.replaceAll(
      RegExp(r'\.[^.]+$'),
      '.m4a',
    );
    final target = File('${dataDir.path}/$targetRelativePath');
    await target.create(recursive: true);
    await target.writeAsBytes(await source.readAsBytes());
    await source.delete();
    return AudioTranscodeResult(
      relativePath: targetRelativePath,
      transcoded: true,
    );
  }
}

class _FakeAudioLibrary extends AudioLibrary {
  _FakeAudioLibrary([this.initialState = const AudioLibraryState()]);

  final AudioLibraryState initialState;

  @override
  AudioLibraryState build() => initialState;

  @override
  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(audioItems: [...state.audioItems, item]);
  }
}

class _FakeCollectionList extends CollectionList {
  @override
  CollectionState build() => const CollectionState();

  @override
  Future<void> addAudioToCollection(String collectionId, String audioId) async {
    final next = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(next[collectionId] ?? const <String>[]);
    if (!ids.contains(audioId)) ids.add(audioId);
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
      expect(resolved.contentLength, 1234);
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
          }),
        ),
      );
      when(
        () => dio.download(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        final savePath = invocation.positionalArguments[1] as String;
        final callback =
            invocation.namedArguments[#onReceiveProgress] as ProgressCallback?;
        callback?.call(4, 4);
        await File(savePath).writeAsBytes([1, 2, 3, 4]);
        return Response<void>(requestOptions: RequestOptions(path: ''));
      });
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('成功下载、创建 AudioItem 并写入库状态', () async {
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        computeSha256: (path) async {
          expect(path, endsWith('.m4a'));
          return 'sha';
        },
        registrationService: AudioRegistrationService(
          readDurationSeconds: (path) async {
            expect(path, endsWith('.m4a'));
            return 42;
          },
        ),
        transcodeService: _FakeTranscodeService(shouldTranscode: true),
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
      expect(item.audioPath, startsWith('audios/imported/lesson'));
      expect(item.audioPath, endsWith('.m4a'));
      expect(item.totalDuration, 42);
      expect(item.audioSha256, 'sha');
      expect(item.importSourceType, AudioImportSourceType.directUrl);
      expect(item.importSourceUrl, 'https://example.com/lesson.mp3');
      expect(container.read(audioLibraryProvider).audioItems, [item]);
      expect(await File('${tmpDir.path}/${item.audioPath}').exists(), isTrue);
      expect(
        await File('${tmpDir.path}/audios/imported/lesson.mp3').exists(),
        isFalse,
      );
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });

    test('转码失败时回退保存原始下载音频', () async {
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        computeSha256: (path) async {
          expect(path, endsWith('.mp3'));
          return 'sha-original';
        },
        registrationService: AudioRegistrationService(
          readDurationSeconds: (path) async {
            expect(path, endsWith('.mp3'));
            return 24;
          },
        ),
        transcodeService: _FakeTranscodeService(shouldTranscode: false),
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

      expect(item.audioPath, endsWith('.mp3'));
      expect(item.totalDuration, 24);
      expect(item.audioSha256, 'sha-original');
      expect(await File('${tmpDir.path}/${item.audioPath}').exists(), isTrue);
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });

    test('合集入口遇到同名音频时关联已有音频', () async {
      final existing = AudioItem(
        id: 'a1',
        name: 'lesson',
        audioPath: 'audios/lesson.mp3',
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
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
      );

      final item = await service.importFromUrl(
        url: 'https://example.com/lesson.mp3',
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        collectionId: 'c1',
      );

      expect(item, existing);
      expect(container.read(collectionListProvider).getAudioIds('c1'), ['a1']);
      verifyNever(
        () => dio.download(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });
  });

  group('AudioImportService.downloadEpisodeToSandbox', () {
    late Directory tmpDir;
    late _MockDio dio;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('episode_download_test_');
      dio = _MockDio();
      when(
        () => dio.download(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        final savePath = invocation.positionalArguments[1] as String;
        await File(savePath).writeAsBytes([5, 6, 7, 8]);
        return Response<void>(requestOptions: RequestOptions(path: ''));
      });
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('Podcast 单集下载成功后优先返回转码后的 m4a', () async {
      final service = AudioImportService(
        dio: dio,
        resolveDataDir: () async => tmpDir,
        computeSha256: (path) async {
          expect(path, endsWith('.m4a'));
          return 'sha-episode';
        },
        readDurationSeconds: (path) async {
          expect(path, endsWith('.m4a'));
          return 61;
        },
        transcodeService: _FakeTranscodeService(shouldTranscode: true),
      );

      final result = await service.downloadEpisodeToSandbox(
        url: 'https://example.com/episode.mp3',
        enclosureType: 'audio/mpeg',
      );

      expect(result.relativePath, endsWith('.m4a'));
      expect(result.durationSeconds, 61);
      expect(result.audioSha256, 'sha-episode');
      expect(await _tmpAudioImportFiles(tmpDir), isEmpty);
    });
  });
}

Future<List<FileSystemEntity>> _tmpAudioImportFiles(Directory dataDir) async {
  final dir = Directory('${dataDir.path}/tmp/audio_import');
  if (!await dir.exists()) return const [];
  return dir.list().toList();
}
