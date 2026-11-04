/// 百度网盘文件 API 客户端。
///
/// 只访问百度开放平台域名，不复用自家后端 Dio。请求统一把 access_token 放在
/// query 中，并由 ApiLogInterceptor 脱敏，避免凭据进入开发者日志。
library;

import 'package:dio/dio.dart';

import '../../../services/api_log_interceptor.dart';
import '../../../services/background_file_download_service.dart';
import '../models/cloud_drive_models.dart';
import '../models/baidu_account_profile.dart';

/// 百度网盘文件 API 抽象。
abstract interface class BaiduNetdiskApi {
  /// 获取当前授权账户资料。
  Future<BaiduAccountProfile> fetchAccountProfile({
    required String accessToken,
  });

  /// 列出目录。
  Future<CloudDriveListPage> listDirectory({
    required String accessToken,
    String dir = '/',
    int start = 0,
    int limit = 100,
  });

  /// 批量获取文件下载 dlink。返回的 map 只包含百度给出有效链接的文件，缺失的 fs_id 不在其中。
  Future<Map<int, BaiduDownloadLink>> fetchDownloadLinks({
    required String accessToken,
    required List<int> fsIds,
  });

  /// 下载 dlink 到本地文件。
  Future<void> downloadToFile({
    required String accessToken,
    required String dlink,
    required String savePath,
    required String displayName,
    String? resourceKey,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  });

  /// 将多个已有 dlink 提交给共享后台队列；返回顺序与请求顺序一致。
  Future<List<BaiduNetdiskDownloadItemResult>> downloadFiles({
    required String accessToken,
    required List<BaiduNetdiskDownloadRequest> requests,
    CancelToken? cancelToken,
    void Function(String taskId, int receivedBytes, int? totalBytes)?
    onProgress,
  });
}

/// 百度网盘文件的资源身份。dlink 每次获取都不同，只能用文件 id。
String baiduResourceKey(int fsId) => 'baidu:$fsId';

/// 百度网盘批量下载中的单个文件请求。
class BaiduNetdiskDownloadRequest {
  const BaiduNetdiskDownloadRequest({
    required this.id,
    required this.fsId,
    required this.displayName,
    required this.dlink,
    required this.savePath,
  });

  final String id;
  final int fsId;
  final String displayName;
  final String dlink;
  final String savePath;
}

/// 百度网盘批量下载的单文件终态。
class BaiduNetdiskDownloadItemResult {
  const BaiduNetdiskDownloadItemResult({required this.request, this.failure});

  final BaiduNetdiskDownloadRequest request;
  final BaiduNetdiskFileException? failure;

  bool get succeeded => failure == null;
}

/// 默认百度网盘文件 API 实现。
class DefaultBaiduNetdiskApi implements BaiduNetdiskApi {
  /// 构造默认实现。
  DefaultBaiduNetdiskApi({
    Dio? metadataDio,
    Dio? profileDio,
    BackgroundFileDownloadService? backgroundDownloader,
  }) : _metadataDio = metadataDio ?? _createMetadataDio(),
       _profileDio = profileDio ?? _createProfileDio(),
       _backgroundDownloader =
           backgroundDownloader ?? BackgroundFileDownloadService();

  final Dio _metadataDio;
  final Dio _profileDio;
  final BackgroundFileDownloadService _backgroundDownloader;

  static Dio _createBaiduDio({
    required bool enableLogging,
    String logTag = 'BAIDU-NETDISK',
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://pan.baidu.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'User-Agent': _baiduUserAgent},
      ),
    );
    if (enableLogging) {
      dio.interceptors.add(ApiLogInterceptor(tag: logTag));
    }
    return dio;
  }

  static Dio _createMetadataDio() => _createBaiduDio(enableLogging: true);

  static Dio _createProfileDio() => _createBaiduDio(enableLogging: false);

  @override
  Future<BaiduAccountProfile> fetchAccountProfile({
    required String accessToken,
  }) async {
    final data = await _getJson(
      _profileDio,
      '/rest/2.0/xpan/nas',
      queryParameters: <String, Object?>{
        'method': 'uinfo',
        'access_token': accessToken,
      },
    );
    return BaiduAccountProfile.fromBaiduJson(data);
  }

  @override
  Future<CloudDriveListPage> listDirectory({
    required String accessToken,
    String dir = '/',
    int start = 0,
    int limit = 100,
  }) async {
    final normalizedLimit = limit.clamp(1, 1000);
    final data = await _getJson(
      _metadataDio,
      '/rest/2.0/xpan/file',
      queryParameters: <String, Object?>{
        'method': 'list',
        'access_token': accessToken,
        'dir': dir.isEmpty ? '/' : dir,
        'order': 'name',
        'start': start < 0 ? 0 : start,
        'limit': normalizedLimit,
        'web': 1,
        'folder': 0,
        'desc': 0,
      },
    );
    final list = data['list'];
    if (list is! List) {
      throw const BaiduNetdiskFileException(
        kind: BaiduNetdiskFileErrorKind.unknown,
        message: 'Baidu list response is missing file list.',
      );
    }
    final entries = list
        .whereType<Map>()
        .map(CloudDriveEntry.fromBaiduJson)
        .toList(growable: false);
    return CloudDriveListPage(
      entries: entries,
      nextStart: (start < 0 ? 0 : start) + entries.length,
      hasMore: entries.length >= normalizedLimit,
    );
  }

  @override
  Future<Map<int, BaiduDownloadLink>> fetchDownloadLinks({
    required String accessToken,
    required List<int> fsIds,
  }) async {
    final links = <int, BaiduDownloadLink>{};
    // filemetas 单次 fsids 数量有上限，超出时分块请求。
    for (var start = 0; start < fsIds.length; start += _downloadLinkBatchSize) {
      final chunk = fsIds.skip(start).take(_downloadLinkBatchSize);
      final data = await _getJson(
        _metadataDio,
        '/rest/2.0/xpan/multimedia',
        queryParameters: <String, Object?>{
          'method': 'filemetas',
          'access_token': accessToken,
          'fsids': '[${chunk.join(',')}]',
          'dlink': 1,
        },
      );
      final list = data['list'];
      if (list is! List) {
        throw const BaiduNetdiskFileException(
          kind: BaiduNetdiskFileErrorKind.unknown,
          message: 'Baidu filemetas response is missing file list.',
        );
      }
      for (final item in list.whereType<Map>()) {
        // 无法下载的文件会缺少或清空 dlink；单个文件异常不应让整批请求失败。
        final dlink = item['dlink'];
        if (dlink is! String || dlink.isEmpty) continue;
        final link = BaiduDownloadLink.fromBaiduJson(item);
        links[link.fsId] = link;
      }
    }
    return links;
  }

  @override
  Future<void> downloadToFile({
    required String accessToken,
    required String dlink,
    required String savePath,
    required String displayName,
    String? resourceKey,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final uri = Uri.parse(dlink);
    final downloadUri = uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'access_token': accessToken,
      },
    );
    try {
      await _backgroundDownloader.download(
        uri: downloadUri,
        savePath: savePath,
        displayName: displayName,
        resourceKey: resourceKey,
        headers: const {'User-Agent': _baiduUserAgent},
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'Baidu download failed.');
    } on BackgroundFileDownloadException catch (error) {
      throw _mapBackgroundDownloadException(error);
    }
  }

  @override
  Future<List<BaiduNetdiskDownloadItemResult>> downloadFiles({
    required String accessToken,
    required List<BaiduNetdiskDownloadRequest> requests,
    CancelToken? cancelToken,
    void Function(String taskId, int receivedBytes, int? totalBytes)?
    onProgress,
  }) async {
    final downloadRequests = requests
        .map(
          (request) => BackgroundFileDownloadRequest(
            id: request.id,
            uri: _downloadUri(request.dlink, accessToken),
            savePath: request.savePath,
            resourceKey: baiduResourceKey(request.fsId),
            displayName: request.displayName,
            headers: const {'User-Agent': _baiduUserAgent},
          ),
        )
        .toList(growable: false);
    final results = await _backgroundDownloader.downloadBatch(
      requests: downloadRequests,
      cancelToken: cancelToken,
      onProgress: (id, received, total) {
        onProgress?.call(id, received, total);
      },
    );
    return [
      for (var index = 0; index < requests.length; index++)
        BaiduNetdiskDownloadItemResult(
          request: requests[index],
          failure: switch (results[index].error) {
            final error? => _mapBackgroundDownloadException(error),
            null => null,
          },
        ),
    ];
  }

  Uri _downloadUri(String dlink, String accessToken) {
    final uri = Uri.parse(dlink);
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'access_token': accessToken,
      },
    );
  }

  Future<Map<dynamic, dynamic>> _getJson(
    Dio dio,
    String path, {
    required Map<String, Object?> queryParameters,
  }) async {
    try {
      final response = await dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        options: Options(validateStatus: (_) => true),
      );
      final data = response.data;
      if (data is! Map) {
        throw const BaiduNetdiskFileException(
          kind: BaiduNetdiskFileErrorKind.unknown,
          message: 'Baidu response is not a JSON object.',
        );
      }
      _throwIfBaiduError(data);
      return data;
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'Baidu request failed.');
    }
  }

  void _throwIfBaiduError(Map<dynamic, dynamic> data) {
    final errno = _errnoOf(data['errno']);
    if (errno == null || errno == 0) return;
    final message =
        data['errmsg'] as String? ??
        data['error_msg'] as String? ??
        data['error_description'] as String? ??
        'Baidu request failed.';
    throw BaiduNetdiskFileException(
      kind: _kindForErrno(errno),
      message: message,
      errno: errno,
    );
  }

  BaiduNetdiskFileException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    if (CancelToken.isCancel(error)) {
      return const BaiduNetdiskFileException(
        kind: BaiduNetdiskFileErrorKind.canceled,
        message: 'Baidu request canceled.',
      );
    }
    final statusCode = error.response?.statusCode;
    final kind = switch (statusCode) {
      401 || 403 => BaiduNetdiskFileErrorKind.unauthorized,
      404 => BaiduNetdiskFileErrorKind.notFound,
      429 => BaiduNetdiskFileErrorKind.rateLimited,
      _ => BaiduNetdiskFileErrorKind.network,
    };
    return BaiduNetdiskFileException(
      kind: kind,
      message: _displayMessageForDioException(
        error,
        fallbackMessage: fallbackMessage,
      ),
      cause: error,
    );
  }

  /// 将后台任务错误转换成网盘导入使用的稳定错误分类。
  BaiduNetdiskFileException _mapBackgroundDownloadException(
    BackgroundFileDownloadException error,
  ) {
    if (error.isCanceled) {
      return const BaiduNetdiskFileException(
        kind: BaiduNetdiskFileErrorKind.canceled,
        message: 'Baidu request canceled.',
      );
    }
    final kind = switch (error.statusCode) {
      401 || 403 => BaiduNetdiskFileErrorKind.unauthorized,
      404 => BaiduNetdiskFileErrorKind.notFound,
      429 => BaiduNetdiskFileErrorKind.rateLimited,
      _ => BaiduNetdiskFileErrorKind.network,
    };
    return BaiduNetdiskFileException(
      kind: kind,
      message: _displayMessageForBackgroundDownloadException(error),
      cause: error,
    );
  }

  /// 保留 Dio 底层异常原因，供批量导入结果页展示可排查的失败信息。
  String _displayMessageForDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final responseMessage = error.response?.statusMessage;
    final detail = _cleanDioMessage(
      responseMessage,
      error.message,
      error.error?.toString(),
    );
    if (detail == null || detail == fallbackMessage) return fallbackMessage;
    return '$fallbackMessage $detail';
  }

  String? _cleanDioMessage(String? first, String? second, String? third) {
    for (final message in [first, second, third]) {
      if (message == null) continue;
      final trimmed = message.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  String _displayMessageForBackgroundDownloadException(
    BackgroundFileDownloadException error,
  ) {
    final detail = error.message.trim();
    if (detail.isEmpty || detail == 'Background download failed.') {
      return 'Baidu download failed.';
    }
    return 'Baidu download failed. $detail';
  }

  int? _errnoOf(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  BaiduNetdiskFileErrorKind _kindForErrno(int errno) {
    return switch (errno) {
      -6 || 111 || 110 => BaiduNetdiskFileErrorKind.unauthorized,
      -9 || 31066 => BaiduNetdiskFileErrorKind.notFound,
      31045 || 31046 || 31061 => BaiduNetdiskFileErrorKind.rateLimited,
      2 || 31023 => BaiduNetdiskFileErrorKind.badRequest,
      _ => BaiduNetdiskFileErrorKind.unknown,
    };
  }
}

const _baiduUserAgent = 'pan.baidu.com';

/// 单次 filemetas 请求最多携带的 fs_id 数量。
/// 数值取自百度文件元信息接口的单次上限（未在本地实测），超过时需要调整。
const _downloadLinkBatchSize = 100;
