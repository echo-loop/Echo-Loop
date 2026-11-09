import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_api.dart';
import 'package:echo_loop/features/baidu_netdisk/models/cloud_drive_models.dart';
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _FakeBackgroundDownloadRunner implements BackgroundDownloadRunner {
  Uri? uri;
  final uris = <Uri>[];
  final displayNames = <String?>[];
  String? savePath;
  Map<String, String>? headers;
  BackgroundDownloadResult result = const BackgroundDownloadResult(
    status: BackgroundDownloadStatus.complete,
  );

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) async {
    this.uri = uri;
    uris.add(uri);
    displayNames.add(displayName);
    this.savePath = savePath;
    this.headers = headers;
    if (result.status == BackgroundDownloadStatus.complete) {
      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsBytes(const <int>[1, 2]);
    }
    return result;
  }
}

void main() {
  late _MockDio metadataDio;
  late _FakeBackgroundDownloadRunner downloader;
  late Directory tempDirectory;
  late DefaultBaiduNetdiskApi api;

  setUp(() async {
    metadataDio = _MockDio();
    downloader = _FakeBackgroundDownloadRunner();
    tempDirectory = await Directory.systemTemp.createTemp('baidu-api-test-');
    api = DefaultBaiduNetdiskApi(
      metadataDio: metadataDio,
      backgroundDownloader: BackgroundFileDownloadService(runner: downloader),
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Response<Object?> jsonResponse(Object? data) => Response<Object?>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 200,
    data: data,
  );

  group('DefaultBaiduNetdiskApi', () {
    test('fetchAccountProfile 调用 uinfo 并解析账号资料', () async {
      final profileDio = _MockDio();
      api = DefaultBaiduNetdiskApi(
        metadataDio: metadataDio,
        profileDio: profileDio,
        backgroundDownloader: BackgroundFileDownloadService(runner: downloader),
      );
      when(
        () => profileDio.get<Object?>(
          '/rest/2.0/xpan/nas',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'errno': 0,
          'uk': 4165472688,
          'baidu_name': 'account-name',
          'netdisk_name': '网盘昵称',
          'avatar_url': 'https://example.invalid/avatar',
        }),
      );

      final profile = await api.fetchAccountProfile(
        accessToken: 'access-token',
      );

      expect(profile.uk, 4165472688);
      expect(profile.baiduName, 'account-name');
      expect(profile.netdiskName, '网盘昵称');
      final query =
          verify(
                () => profileDio.get<Object?>(
                  '/rest/2.0/xpan/nas',
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(query['method'], 'uinfo');
      expect(query['access_token'], 'access-token');
    });

    test('downloadFiles 一次提交批量文件并为每个 dlink 添加 access token', () async {
      final results = await api.downloadFiles(
        accessToken: 'access-token',
        requests: [
          BaiduNetdiskDownloadRequest(
            id: 'audio-1',
            fsId: 1,
            displayName: 'first.mp3',
            dlink: 'https://d.pcs.baidu.com/file/1?source=test',
            savePath: '${tempDirectory.path}/1.mp3',
          ),
          BaiduNetdiskDownloadRequest(
            id: 'audio-2',
            fsId: 2,
            displayName: 'second.mp3',
            dlink: 'https://d.pcs.baidu.com/file/2',
            savePath: '${tempDirectory.path}/2.mp3',
          ),
        ],
      );

      expect(results.map((result) => result.request.id), [
        'audio-1',
        'audio-2',
      ]);
      expect(results.every((result) => result.succeeded), isTrue);
      expect(downloader.uris, hasLength(2));
      expect(downloader.displayNames, ['first.mp3', 'second.mp3']);
      expect(downloader.uris[0].queryParameters, {
        'source': 'test',
        'access_token': 'access-token',
      });
      expect(
        downloader.uris[1].queryParameters['access_token'],
        'access-token',
      );
    });

    test('listDirectory 调用百度列表接口并解析目录/文件', () async {
      when(
        () => metadataDio.get<Object?>(
          '/rest/2.0/xpan/file',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'errno': 0,
          'list': [
            {
              'fs_id': 1,
              'server_filename': 'Folder',
              'path': '/Folder',
              'isdir': 1,
              'size': 0,
              'server_mtime': 1784361000,
            },
            {
              'fs_id': '2',
              'server_filename': 'lesson.mp3',
              'path': '/Folder/lesson.mp3',
              'isdir': 0,
              'size': '123',
            },
          ],
        }),
      );

      final page = await api.listDirectory(
        accessToken: 'access-token',
        dir: '/Folder',
        start: 5,
        limit: 2,
      );

      expect(page.entries, hasLength(2));
      expect(page.entries.first.isDirectory, isTrue);
      expect(page.entries[1].name, 'lesson.mp3');
      expect(page.entries[1].extension, 'mp3');
      expect(page.nextStart, 7);

      final query =
          verify(
                () => metadataDio.get<Object?>(
                  '/rest/2.0/xpan/file',
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(query['method'], 'list');
      expect(query['access_token'], 'access-token');
      expect(query['dir'], '/Folder');
      expect(query['start'], 5);
      expect(query['limit'], 2);
    });

    test('fetchDownloadLinks 调用 filemetas 并解析 dlink', () async {
      when(
        () => metadataDio.get<Object?>(
          '/rest/2.0/xpan/multimedia',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'errno': 0,
          'list': [
            {
              'fs_id': 42,
              'server_filename': 'lesson.m4a',
              'size': 456,
              'dlink': 'https://d.pcs.baidu.com/file/lesson',
            },
          ],
        }),
      );

      final links = await api.fetchDownloadLinks(
        accessToken: 'access-token',
        fsIds: const [42],
      );

      final link = links[42]!;
      expect(link.fsId, 42);
      expect(link.dlink, 'https://d.pcs.baidu.com/file/lesson');
      expect(link.size, 456);

      final query =
          verify(
                () => metadataDio.get<Object?>(
                  '/rest/2.0/xpan/multimedia',
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(query['fsids'], '[42]');
      expect(query['dlink'], 1);
    });

    test('fetchDownloadLinks 缺失或无 dlink 的文件不进入结果', () async {
      when(
        () => metadataDio.get<Object?>(
          '/rest/2.0/xpan/multimedia',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'errno': 0,
          'list': [
            {'fs_id': 1, 'dlink': 'https://d.pcs.baidu.com/file/1'},
            {'fs_id': 2, 'dlink': ''},
          ],
        }),
      );

      final links = await api.fetchDownloadLinks(
        accessToken: 'access-token',
        fsIds: const [1, 2, 3],
      );

      expect(links.keys, [1]);
    });

    test('fetchDownloadLinks 超过单次上限时分块请求', () async {
      when(
        () => metadataDio.get<Object?>(
          '/rest/2.0/xpan/multimedia',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => jsonResponse({'errno': 0, 'list': []}));

      await api.fetchDownloadLinks(
        accessToken: 'access-token',
        fsIds: [for (var index = 1; index <= 101; index++) index],
      );

      final captured = verify(
        () => metadataDio.get<Object?>(
          '/rest/2.0/xpan/multimedia',
          queryParameters: captureAny(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).captured.cast<Map<String, Object?>>();
      expect(captured, hasLength(2));
      expect(captured[0]['fsids'], startsWith('[1,2,3,'));
      expect(captured[0]['fsids'], endsWith(',100]'));
      expect(captured[1]['fsids'], '[101]');
    });

    test('百度 errno -6 映射为 unauthorized', () async {
      when(
        () => metadataDio.get<Object?>(
          '/rest/2.0/xpan/file',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async =>
            jsonResponse({'errno': -6, 'errmsg': 'invalid access token'}),
      );

      expect(
        api.listDirectory(accessToken: 'bad'),
        throwsA(
          isA<BaiduNetdiskFileException>().having(
            (error) => error.kind,
            'kind',
            BaiduNetdiskFileErrorKind.unauthorized,
          ),
        ),
      );
    });

    test('downloadToFile 给 dlink 补 access_token 并带百度 UA，不依赖元数据大小', () async {
      final savePath = '${tempDirectory.path}/lesson.mp3';
      await api.downloadToFile(
        accessToken: 'access-token',
        dlink: 'https://d.pcs.baidu.com/file/lesson?x=1',
        savePath: savePath,
        displayName: 'Lesson 1.mp3',
      );

      expect(downloader.uri?.queryParameters['x'], '1');
      expect(downloader.uri?.queryParameters['access_token'], 'access-token');
      expect(downloader.savePath, savePath);
      expect(downloader.displayNames.last, 'Lesson 1.mp3');
      expect(downloader.headers?['User-Agent'], 'pan.baidu.com');
      expect(await File(savePath).readAsBytes(), const <int>[1, 2]);
    });

    test('downloadToFile 网络异常保留底层错误原因', () async {
      downloader.result = const BackgroundDownloadResult(
        status: BackgroundDownloadStatus.failed,
        message: 'HandshakeException: Connection terminated during handshake',
      );

      await expectLater(
        api.downloadToFile(
          accessToken: 'access-token',
          dlink: 'https://d.pcs.baidu.com/file/lesson',
          savePath: '${tempDirectory.path}/lesson.mp3',
          displayName: 'Lesson 1.mp3',
        ),
        throwsA(
          isA<BaiduNetdiskFileException>()
              .having(
                (error) => error.kind,
                'kind',
                BaiduNetdiskFileErrorKind.network,
              )
              .having(
                (error) => error.message,
                'message',
                contains('Connection terminated during handshake'),
              ),
        ),
      );
    });

    test('downloadToFile HTTP 401 映射为 unauthorized', () async {
      downloader.result = const BackgroundDownloadResult(
        status: BackgroundDownloadStatus.failed,
        statusCode: 401,
        message: 'unauthorized',
      );

      await expectLater(
        api.downloadToFile(
          accessToken: 'access-token',
          dlink: 'https://d.pcs.baidu.com/file/lesson',
          savePath: '${tempDirectory.path}/lesson.mp3',
          displayName: 'Lesson 1.mp3',
        ),
        throwsA(
          isA<BaiduNetdiskFileException>().having(
            (error) => error.kind,
            'kind',
            BaiduNetdiskFileErrorKind.unauthorized,
          ),
        ),
      );
    });

    test('downloadToFile canceled 映射为 canceled', () async {
      downloader.result = const BackgroundDownloadResult(
        status: BackgroundDownloadStatus.canceled,
        message: 'cancelled',
      );

      await expectLater(
        api.downloadToFile(
          accessToken: 'access-token',
          dlink: 'https://d.pcs.baidu.com/file/lesson',
          savePath: '${tempDirectory.path}/lesson.mp3',
          displayName: 'Lesson 1.mp3',
        ),
        throwsA(
          isA<BaiduNetdiskFileException>().having(
            (error) => error.kind,
            'kind',
            BaiduNetdiskFileErrorKind.canceled,
          ),
        ),
      );
    });
  });
}
