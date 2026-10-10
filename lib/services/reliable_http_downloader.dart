/// 通用可靠 HTTP 下载器。
///
/// 只封装 GET 下载的可靠落盘能力：`.part` 临时文件、可选 Range 续传、
/// 原子 rename、大小校验、结构化失败分类与网络层自动重试。调用方负责
/// 拼好最终 URI、headers 与业务错误映射。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import 'app_logger.dart';

const _logTag = 'ReliableHttpDownloader';

/// 可靠下载完成结果。
class ReliableDownloadResult {
  /// 构造下载结果。
  const ReliableDownloadResult({
    required this.savePath,
    required this.bytesWritten,
    required this.resumed,
  });

  /// 最终文件路径。
  final String savePath;

  /// 最终落盘字节数。
  final int bytesWritten;

  /// 本次是否使用了 HTTP Range 追加续传。
  final bool resumed;
}

/// 结构化下载失败原因，供调用方做展示/重试策略判断，不依赖具体异常类型。
enum ReliableDownloadFailure {
  /// 调用方主动取消。
  cancelled,

  /// 连接/发送/接收超时。
  timeout,

  /// 网络连接失败（DNS、TLS、连接被拒绝等）或响应体读取中断。
  network,

  /// HTTP 状态码非 2xx（见 [ReliableDownloadException.statusCode]）。
  httpStatus,

  /// 重定向异常（缺少 Location、跳转次数过多）。
  redirect,

  /// 本地文件系统错误（如磁盘空间不足）。
  storage,

  /// 完整性校验失败：expectedSize、Content-Range 或续传状态不一致。
  integrity,

  /// 同一 savePath 已有下载在进行中。
  conflict,

  /// 无法归类的其它错误。
  unknown,
}

/// 可靠下载失败。
class ReliableDownloadException implements Exception {
  /// 构造可靠下载失败。
  const ReliableDownloadException(
    this.message, {
    this.kind = ReliableDownloadFailure.unknown,
    this.cause,
    this.statusCode,
    this.retryable = false,
    this.retryAfter,
  });

  /// 可读错误消息。
  final String message;

  /// 结构化失败原因。
  final ReliableDownloadFailure kind;

  /// 原始异常（DioException / FileSystemException 等），供日志排查。
  final Object? cause;

  /// HTTP 状态码（仅 [kind] 为 [ReliableDownloadFailure.httpStatus] 时有值）。
  final int? statusCode;

  /// 是否可由下载器内部自动重试。
  final bool retryable;

  /// 服务端建议的重试等待时长（来自 `Retry-After` 头，仅内部重试调度使用）。
  final Duration? retryAfter;

  @override
  String toString() {
    final parts = <String>['kind: $kind', message];
    if (statusCode != null) parts.add('statusCode: $statusCode');
    if (cause != null) parts.add('cause: $cause');
    return 'ReliableDownloadException(${parts.join(', ')})';
  }
}

/// GET 下载器抽象。
abstract interface class ReliableHttpDownloader {
  /// 下载 [uri] 到 [savePath]。
  Future<ReliableDownloadResult> download({
    required Uri uri,
    required String savePath,
    Map<String, String> headers = const <String, String>{},
    int? expectedSize,
    String? identityKey,
    bool allowResume = true,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  });
}

/// 单次 download() 调用内跨网络重试共享的可变状态。
class _RetryState {
  /// 一旦续传请求被服务端忽略（返回 200），本次调用后续重试不再发送 Range，
  /// 避免反复用错误的假设去猜服务端行为。
  bool rangeUnsupported = false;
}

/// 触发自动重试的 HTTP 状态码：显式限流/超时与常见 5xx。
const _retryableStatusCodes = {408, 429, 500, 502, 503, 504};

/// 基于 Dio stream 的默认可靠下载器。
class DioReliableHttpDownloader implements ReliableHttpDownloader {
  /// 构造默认实现。
  ///
  /// [maxRetries] 为网络层自动重试次数上限（不含首次尝试）。[backoffDelay] 供测试
  /// 注入，避免真实等待；默认使用 [Future.delayed]。
  DioReliableHttpDownloader({
    Dio? dio,
    int maxRetries = 3,
    Future<void> Function(Duration duration)? backoffDelay,
    Random? random,
  }) : _dio = dio ?? Dio(),
       _maxRetries = maxRetries,
       _backoffDelay = backoffDelay ?? Future<void>.delayed,
       _random = random ?? Random();

  final Dio _dio;
  final int _maxRetries;
  final Future<void> Function(Duration duration) _backoffDelay;
  final Random _random;

  /// 进程内并发锁：同一实例内同一 savePath 只允许一个活动下载任务。
  ///
  /// 仅表示「有任务正在写这个路径」，与磁盘上是否残留 `.part` 无关；
  /// 在最外层 finally 释放，避免锁泄漏。
  final _activeSavePaths = <String>{};

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
    final normalizedPath = _normalizedSavePath(savePath);
    if (!_activeSavePaths.add(normalizedPath)) {
      throw ReliableDownloadException(
        'A download is already in progress for $savePath.',
        kind: ReliableDownloadFailure.conflict,
      );
    }
    final startedAt = DateTime.now();
    try {
      final result = await _downloadWithRetry(
        uri: uri,
        savePath: savePath,
        headers: headers,
        expectedSize: expectedSize,
        identityKey: identityKey,
        allowResume: allowResume,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
      AppLogger.log(
        _logTag,
        '下载完成 uri=${_sanitizedUri(uri)} bytes=${result.bytesWritten} '
        'resumed=${result.resumed} elapsedMs=${DateTime.now().difference(startedAt).inMilliseconds}',
      );
      return result;
    } finally {
      _activeSavePaths.remove(normalizedPath);
    }
  }

  String _normalizedSavePath(String savePath) =>
      p.normalize(File(savePath).absolute.path);

  Future<ReliableDownloadResult> _downloadWithRetry({
    required Uri uri,
    required String savePath,
    required Map<String, String> headers,
    required int? expectedSize,
    required String? identityKey,
    required bool allowResume,
    required CancelToken? cancelToken,
    required void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final targetFile = File(savePath);
    final partFile = File('$savePath.part');
    final metaFile = File('$savePath.part.meta.json');
    await targetFile.parent.create(recursive: true);

    final state = _RetryState();
    var attempt = 0;
    while (true) {
      try {
        return await _downloadOnce(
          uri: uri,
          headers: headers,
          expectedSize: expectedSize,
          identityKey: identityKey,
          allowResume: allowResume,
          cancelToken: cancelToken,
          onProgress: onProgress,
          targetFile: targetFile,
          partFile: partFile,
          metaFile: metaFile,
          state: state,
        );
      } on ReliableDownloadException catch (error) {
        final canRetry = error.retryable && attempt < _maxRetries;
        if (!canRetry) {
          await _cleanupOnFailure(
            partFile: partFile,
            metaFile: metaFile,
            allowResume: allowResume,
          );
          final outcome = error.kind == ReliableDownloadFailure.cancelled
              ? '下载已取消'
              : '下载失败';
          AppLogger.log(
            _logTag,
            '$outcome uri=${_sanitizedUri(uri)} attempt=$attempt kind=${error.kind} '
            'statusCode=${error.statusCode} retryable=${error.retryable}',
          );
          rethrow;
        }
        attempt++;
        AppLogger.log(
          _logTag,
          '下载重试 uri=${_sanitizedUri(uri)} attempt=$attempt/$_maxRetries '
          'kind=${error.kind} statusCode=${error.statusCode}',
        );
        try {
          await _waitBeforeRetry(
            _backoffFor(attempt, retryAfter: error.retryAfter),
            cancelToken,
          );
        } on ReliableDownloadException {
          await _cleanupOnFailure(
            partFile: partFile,
            metaFile: metaFile,
            allowResume: allowResume,
          );
          rethrow;
        }
      }
    }
  }

  /// 失败终止时的临时文件清理策略。
  ///
  /// `allowResume=false` 的调用方明确不需要跨调用续传，失败即清理，避免残留
  /// 半成品文件误导下一次全新下载。`allowResume=true` 时保留 `.part`/meta，
  /// 供下一次 [download] 调用按 Range 续传（既有行为，见
  /// `test/services/reliable_http_downloader_test.dart` 大小不匹配场景）。
  Future<void> _cleanupOnFailure({
    required File partFile,
    required File metaFile,
    required bool allowResume,
  }) async {
    if (allowResume) return;
    await _deleteIfExists(partFile);
    await _deleteIfExists(metaFile);
  }

  Future<void> _waitBeforeRetry(
    Duration duration,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      await _backoffDelay(duration);
      return;
    }
    await Future.any<void>([_backoffDelay(duration), cancelToken.whenCancel]);
    if (cancelToken.isCancelled) {
      throw const ReliableDownloadException(
        'Download cancelled during retry backoff.',
        kind: ReliableDownloadFailure.cancelled,
      );
    }
  }

  static const _baseBackoffMs = 500;
  static const _maxBackoffMs = 8000;
  static const _jitterMs = 250;

  Duration _backoffFor(int attempt, {Duration? retryAfter}) {
    if (retryAfter != null) return retryAfter;
    final exponentialMs = _baseBackoffMs * (1 << (attempt - 1).clamp(0, 4));
    final cappedMs = min(exponentialMs, _maxBackoffMs);
    final jitterMs = _random.nextInt(_jitterMs + 1);
    return Duration(milliseconds: cappedMs + jitterMs);
  }

  Future<ReliableDownloadResult> _downloadOnce({
    required Uri uri,
    required Map<String, String> headers,
    required int? expectedSize,
    required String? identityKey,
    required bool allowResume,
    required CancelToken? cancelToken,
    required void Function(int receivedBytes, int? totalBytes)? onProgress,
    required File targetFile,
    required File partFile,
    required File metaFile,
    required _RetryState state,
  }) async {
    final resumableBytes = state.rangeUnsupported
        ? 0
        : await _resumableBytes(
            partFile: partFile,
            metaFile: metaFile,
            identityKey: identityKey,
            allowResume: allowResume,
          );
    var shouldResume = resumableBytes > 0;

    for (var attempt = 0; attempt < 2; attempt++) {
      final requestHeaders = <String, String>{...headers};
      if (shouldResume) {
        requestHeaders['Range'] = 'bytes=$resumableBytes-';
      }

      final response = await _getFollowingRedirects(
        uri: uri,
        headers: requestHeaders,
        cancelToken: cancelToken,
      );
      final statusCode = response.statusCode ?? 0;
      final body = response.data;
      if (body == null) {
        throw const ReliableDownloadException(
          'Download response body is empty.',
          kind: ReliableDownloadFailure.network,
        );
      }

      if (statusCode == 416) {
        final existingLength = await _lengthIfExists(partFile);
        if (expectedSize != null && existingLength == expectedSize) {
          await _replaceWithPart(partFile: partFile, targetFile: targetFile);
          await _deleteIfExists(metaFile);
          onProgress?.call(existingLength, expectedSize);
          return ReliableDownloadResult(
            savePath: targetFile.path,
            bytesWritten: existingLength,
            resumed: true,
          );
        }
        await _deleteIfExists(partFile);
        await _deleteIfExists(metaFile);
        shouldResume = false;
        continue;
      }

      if (statusCode < 200 || statusCode >= 300) {
        final dioError = DioException.badResponse(
          statusCode: statusCode,
          requestOptions: response.requestOptions,
          response: response,
        );
        throw _classifyDioException(
          dioError,
          contextMessage: 'Download request failed with status $statusCode.',
          retryAfter: _retryAfterFrom(response, statusCode),
        );
      }

      final append = shouldResume && statusCode == 206;
      if (shouldResume && statusCode == 206) {
        await _validateContentRange(
          response.headers.value('content-range'),
          expectedStart: resumableBytes,
          partFile: partFile,
          metaFile: metaFile,
        );
      }
      if (shouldResume && statusCode == 200) {
        await _deleteIfExists(partFile);
        await _deleteIfExists(metaFile);
        state.rangeUnsupported = true;
      }

      try {
        await _writeResumeMetadata(
          metaFile: metaFile,
          identityKey: identityKey,
          allowResume: allowResume,
        );
      } on ReliableDownloadException {
        await _cancelResponseBody(body);
        rethrow;
      }

      final initialBytes = append ? resumableBytes : 0;
      final totalBytes = _totalBytesFor(
        response: response,
        initialBytes: initialBytes,
        expectedSize: expectedSize,
      );
      final bytesWritten = await _writeBody(
        body: body,
        partFile: partFile,
        append: append,
        initialBytes: initialBytes,
        totalBytes: totalBytes,
        onProgress: onProgress,
      );
      if (expectedSize != null && bytesWritten != expectedSize) {
        throw ReliableDownloadException(
          'Downloaded size mismatch: expected $expectedSize bytes, got $bytesWritten bytes.',
          kind: ReliableDownloadFailure.integrity,
        );
      }
      await _replaceWithPart(partFile: partFile, targetFile: targetFile);
      await _deleteIfExists(metaFile);
      return ReliableDownloadResult(
        savePath: targetFile.path,
        bytesWritten: bytesWritten,
        resumed: append,
      );
    }

    throw const ReliableDownloadException(
      'Download range is not satisfiable.',
      kind: ReliableDownloadFailure.httpStatus,
      statusCode: 416,
    );
  }

  /// 把底层 [DioException] 归类为结构化 [ReliableDownloadException]。
  ReliableDownloadException _classifyDioException(
    DioException error, {
    String? contextMessage,
    Duration? retryAfter,
  }) {
    if (CancelToken.isCancel(error)) {
      return ReliableDownloadException(
        contextMessage ?? 'Download cancelled.',
        kind: ReliableDownloadFailure.cancelled,
        cause: error,
      );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ReliableDownloadException(
          contextMessage ?? 'Download timed out.',
          kind: ReliableDownloadFailure.timeout,
          cause: error,
          retryable: true,
        );
      case DioExceptionType.connectionError:
        return ReliableDownloadException(
          contextMessage ?? 'Download connection failed.',
          kind: ReliableDownloadFailure.network,
          cause: error,
          retryable: true,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        return ReliableDownloadException(
          contextMessage ?? 'Download request failed with status $statusCode.',
          kind: ReliableDownloadFailure.httpStatus,
          statusCode: statusCode,
          cause: error,
          retryable:
              statusCode != null && _retryableStatusCodes.contains(statusCode),
          retryAfter: retryAfter,
        );
      default:
        return ReliableDownloadException(
          contextMessage ?? 'Download failed.',
          kind: ReliableDownloadFailure.network,
          cause: error,
        );
    }
  }

  Duration? _retryAfterFrom(Response<Object?> response, int statusCode) {
    if (statusCode != 429 && statusCode != 503) return null;
    final value = response.headers.value('retry-after');
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }

  /// 手动跟随 3xx，确保跨域跳转后仍保留调用方注入的下载头。
  ///
  /// 百度网盘 dlink 会先跳到 `*.baidupcs.com`，目标 URL 校验
  /// `User-Agent`。Dio 自动 redirect 在跨域时不会稳定保留这些头，导致
  /// 目标地址返回 31362 sign error，因此这里显式逐跳 GET。
  ///
  /// 跨 origin 跳转时移除 `Authorization`/`Cookie`/`Proxy-Authorization`，避免
  /// 自家后端签发的凭据泄漏给第三方跳转目标；其余头（含 `User-Agent`/`Range`）
  /// 原样保留。
  Future<Response<ResponseBody>> _getFollowingRedirects({
    required Uri uri,
    required Map<String, String> headers,
    required CancelToken? cancelToken,
  }) async {
    var currentUri = uri;
    var currentHeaders = headers;
    for (var redirectCount = 0; redirectCount <= 10; redirectCount++) {
      Response<ResponseBody> response;
      try {
        response = await _dio.get<ResponseBody>(
          currentUri.toString(),
          options: Options(
            headers: currentHeaders,
            responseType: ResponseType.stream,
            followRedirects: false,
            validateStatus: (_) => true,
          ),
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        throw _classifyDioException(error);
      }
      final statusCode = response.statusCode ?? 0;
      if (!_isRedirect(statusCode)) return response;

      final location = response.headers.value('location');
      unawaited(response.data?.stream.drain<void>());
      if (location == null || location.isEmpty) {
        throw const ReliableDownloadException(
          'Download redirect is missing Location.',
          kind: ReliableDownloadFailure.redirect,
        );
      }
      final nextUri = currentUri.resolve(location);
      if (_isCrossOrigin(currentUri, nextUri)) {
        currentHeaders = Map<String, String>.from(currentHeaders)
          ..removeWhere(
            (key, _) =>
                _sensitiveCrossOriginHeaders.contains(key.toLowerCase()),
          );
      }
      currentUri = nextUri;
    }

    throw const ReliableDownloadException(
      'Download redirected too many times.',
      kind: ReliableDownloadFailure.redirect,
    );
  }

  bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  bool _isCrossOrigin(Uri a, Uri b) {
    return a.scheme != b.scheme || a.host != b.host || a.port != b.port;
  }

  Future<int> _resumableBytes({
    required File partFile,
    required File metaFile,
    required String? identityKey,
    required bool allowResume,
  }) async {
    if (!allowResume || !await partFile.exists()) return 0;
    final length = await partFile.length();
    if (length <= 0) return 0;
    if (identityKey == null || identityKey.isEmpty) return length;
    final meta = await _readMeta(metaFile);
    if (meta?['identityKey'] == identityKey) return length;
    await _deleteIfExists(partFile);
    await _deleteIfExists(metaFile);
    return 0;
  }

  Future<Map<String, Object?>?> _readMeta(File metaFile) async {
    if (!await metaFile.exists()) return null;
    try {
      final decoded = jsonDecode(await metaFile.readAsString());
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {}
    return null;
  }

  /// 在读取响应体前只保存一次续传身份，避免逐块写入小型元数据文件。
  ///
  /// 续传字节偏移始终取自 `.part` 文件长度；身份缺失或不允许续传时无需 sidecar。
  Future<void> _writeResumeMetadata({
    required File metaFile,
    required String? identityKey,
    required bool allowResume,
  }) async {
    if (!allowResume || identityKey == null || identityKey.isEmpty) return;
    try {
      await metaFile.writeAsString(jsonEncode({'identityKey': identityKey}));
    } on FileSystemException catch (error) {
      throw ReliableDownloadException(
        'Failed to save download resume metadata.',
        kind: ReliableDownloadFailure.storage,
        cause: error,
      );
    }
  }

  /// 元数据落盘失败时取消尚未消费的响应流，释放底层连接。
  Future<void> _cancelResponseBody(ResponseBody body) async {
    try {
      await body.stream.listen((_) {}).cancel();
    } on Object catch (error) {
      AppLogger.log(_logTag, '取消未消费响应流失败 errorType=${error.runtimeType}');
    }
  }

  /// 校验续传响应的 Content-Range 起点，起点缺失/不一致说明本地 `.part` 与
  /// 服务端状态已不可信，清理后交由上层判断是否重新开始。
  Future<void> _validateContentRange(
    String? value, {
    required int expectedStart,
    required File partFile,
    required File metaFile,
  }) async {
    if (value == null || value.isEmpty) {
      await _deleteIfExists(partFile);
      await _deleteIfExists(metaFile);
      throw const ReliableDownloadException(
        'Partial download response is missing Content-Range.',
        kind: ReliableDownloadFailure.integrity,
      );
    }
    final match = RegExp(r'^bytes\s+(\d+)-\d+/(\d+|\*)$').firstMatch(value);
    final start = match == null ? null : int.tryParse(match.group(1) ?? '');
    if (start != expectedStart) {
      await _deleteIfExists(partFile);
      await _deleteIfExists(metaFile);
      throw ReliableDownloadException(
        'Partial download response starts at ${start ?? 'unknown'}, expected $expectedStart.',
        kind: ReliableDownloadFailure.integrity,
      );
    }
  }

  int? _totalBytesFor({
    required Response<ResponseBody> response,
    required int initialBytes,
    required int? expectedSize,
  }) {
    if (expectedSize != null && expectedSize > 0) return expectedSize;
    final contentRange = response.headers.value('content-range');
    if (contentRange != null) {
      final match = RegExp(r'^bytes\s+\d+-\d+/(\d+)$').firstMatch(contentRange);
      final total = match == null ? null : int.tryParse(match.group(1) ?? '');
      if (total != null && total > 0) return total;
    }
    final contentLength = response.headers.value('content-length');
    final length = contentLength == null ? null : int.tryParse(contentLength);
    if (length == null || length <= 0) return null;
    return initialBytes + length;
  }

  Future<int> _writeBody({
    required ResponseBody body,
    required File partFile,
    required bool append,
    required int initialBytes,
    required int? totalBytes,
    required void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    var received = initialBytes;
    IOSink? sink;
    try {
      sink = partFile.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      await for (final chunk in body.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, totalBytes);
      }
      await sink.flush();
      await sink.close();
      return received;
    } catch (error) {
      try {
        await sink?.close();
      } catch (_) {}
      if (error is DioException) {
        throw _classifyDioException(
          error,
          contextMessage: 'Failed to save download stream.',
        );
      }
      if (error is FileSystemException) {
        throw ReliableDownloadException(
          'Failed to save download stream.',
          kind: ReliableDownloadFailure.storage,
          cause: error,
        );
      }
      throw ReliableDownloadException(
        'Failed to save download stream.',
        kind: ReliableDownloadFailure.unknown,
        cause: error,
      );
    }
  }

  /// 用 `.part` 原子替换目标文件。
  ///
  /// 直接 rename 即可：Dart `File.rename()` 在目标已存在普通文件时会先移除
  /// 目标再完成改名（同文件系统下由 POSIX `rename(2)` 保证原子性），因此不需要
  /// 额外的“备份旧文件 → rename → 失败回滚”步骤——那样反而会在两次 rename 之间
  /// 引入一个可被进程崩溃打断的窗口。前提是 `.part` 与目标始终同目录（当前
  /// `<savePath>.part` 命名约定已保证同文件系统）。
  Future<void> _replaceWithPart({
    required File partFile,
    required File targetFile,
  }) async {
    await partFile.rename(targetFile.path);
  }

  Future<int> _lengthIfExists(File file) async {
    if (!await file.exists()) return 0;
    return file.length();
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}

/// query 可能带签名/token（如百度 access_token），日志中一律去除。
String _sanitizedUri(Uri uri) =>
    uri.hasQuery ? uri.replace(query: '').toString() : uri.toString();

const _sensitiveCrossOriginHeaders = {
  'authorization',
  'cookie',
  'proxy-authorization',
};
