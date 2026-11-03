/// 应用层下载错误，带 HTTP 状态及取消语义供现有功能映射。
class BackgroundFileDownloadException implements Exception {
  const BackgroundFileDownloadException(
    this.message, {
    this.statusCode,
    this.isCanceled = false,
    this.isStorageFailure = false,
    this.receivedBytes,
    this.expectedBytes,
    this.errorDomain,
    this.errorCode,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final bool isCanceled;
  final bool isStorageFailure;
  final int? receivedBytes;
  final int? expectedBytes;
  final String? errorDomain;
  final int? errorCode;
  final Object? cause;

  @override
  String toString() => 'BackgroundFileDownloadException($message)';
}
