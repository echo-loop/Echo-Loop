// 转录 API 客户端
//
// 封装与后端的所有 HTTP API 通信，用于 AI 转录流程。
// 基于 Dio，支持 CancelToken、上传进度回调和错误处理。
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_io/io.dart';
import '../config/api_config.dart';
import '../utils/srt_generator.dart';

part 'transcription_api_client.g.dart';

// ─── 响应模型 ───────────────────────────────────────────────

/// 获取上传 URL 响应
class UploadUrlResponse {
  /// 音频是否已存在（SHA256 匹配）
  final bool audioExists;

  /// R2 预签名上传 URL（仅 audioExists=false 时非 null）
  final String? uploadUrl;

  /// R2 对象路径
  final String? objectName;

  /// R2 公开访问 URL
  final String? publicUrl;

  const UploadUrlResponse({
    required this.audioExists,
    this.uploadUrl,
    this.objectName,
    this.publicUrl,
  });

  factory UploadUrlResponse.fromJson(Map<String, dynamic> json) {
    return UploadUrlResponse(
      audioExists: json['audioExists'] as bool,
      uploadUrl: json['uploadUrl'] as String?,
      objectName: json['objectName'] as String?,
      publicUrl: json['publicUrl'] as String?,
    );
  }
}

/// 提交转录响应
class SubmitTranscriptionResponse {
  /// 是否命中缓存
  final bool cached;

  /// 任务 ID（仅 cached=false 时非 null）
  final String? jobId;

  /// 转录结果（仅 cached=true 时非 null）
  final TranscriptResult? transcript;

  const SubmitTranscriptionResponse({
    required this.cached,
    this.jobId,
    this.transcript,
  });

  factory SubmitTranscriptionResponse.fromJson(Map<String, dynamic> json) {
    return SubmitTranscriptionResponse(
      cached: json['cached'] as bool,
      jobId: json['jobId'] as String?,
      transcript: json['transcript'] != null
          ? TranscriptResult.fromJson(
              json['transcript'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// 任务状态查询响应
class JobStatusResponse {
  /// 状态: queued / running / succeeded / failed
  final String status;

  /// 错误信息（仅 failed 时非 null）
  final String? errorMessage;

  const JobStatusResponse({required this.status, this.errorMessage});

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) {
    return JobStatusResponse(
      status: json['status'] as String,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  bool get isCompleted => status == 'succeeded';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'queued' || status == 'running';
}

/// 转录结果
class TranscriptResult {
  /// 句子列表
  final List<TranscriptSentence> sentences;

  /// 全文文本
  final String fullText;

  const TranscriptResult({required this.sentences, required this.fullText});

  factory TranscriptResult.fromJson(Map<String, dynamic> json) {
    final sentencesList = (json['sentences'] as List)
        .map((s) => TranscriptSentence.fromJson(s as Map<String, dynamic>))
        .toList();
    return TranscriptResult(
      sentences: sentencesList,
      fullText: json['fullText'] as String? ?? '',
    );
  }
}

// ─── API 客户端 ───────────────────────────────────────────────

/// 转录 API 客户端
///
/// 封装与后端 `/api/v1/user-audio/` 的所有通信。
class TranscriptionApiClient {
  final Dio _dio;

  TranscriptionApiClient({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ) {
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => print('[DIO] $obj'),
      ),
    );
  }

  /// 用于测试的构造函数，允许注入 Dio 实例
  TranscriptionApiClient.withDio(this._dio);

  /// 获取 R2 上传预签名 URL
  ///
  /// 自动检查音频缓存：[audioExists]=true 时跳过上传。
  Future<UploadUrlResponse> getUploadUrl({
    required String sha256,
    required String mimeType,
    required int fileSize,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/user-audio/upload-url',
      data: {'sha256': sha256, 'mimeType': mimeType, 'fileSize': fileSize},
    );
    return UploadUrlResponse.fromJson(response.data!);
  }

  /// 通过预签名 URL 直接上传到 R2
  ///
  /// [uploadUrl] 预签名 PUT URL。
  /// [filePath] 本地文件绝对路径。
  /// [contentType] MIME 类型。
  /// [cancelToken] 可选取消令牌。
  /// [onProgress] 可选上传进度回调 (已发送字节, 总字节)。
  Future<void> uploadToR2({
    required String uploadUrl,
    required String filePath,
    required String contentType,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    final fileLength = await file.length();
    // 直接 PUT 原始字节流到 R2 presigned URL
    await Dio().put<void>(
      uploadUrl,
      data: file.openRead(),
      options: Options(
        headers: {'Content-Type': contentType, 'Content-Length': fileLength},
      ),
      cancelToken: cancelToken,
      onSendProgress: onProgress,
    );
  }

  /// 提交转录任务
  ///
  /// 自动检查字幕缓存：[cached]=true 时直接返回 transcript。
  Future<SubmitTranscriptionResponse> submitTranscription({
    required String sha256,
    String? objectName,
    String? publicUrl,
    String? mimeType,
    int? fileSize,
    required String language,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/user-audio/submit-transcription',
      data: {
        'sha256': sha256,
        if (objectName != null) 'objectName': objectName,
        if (publicUrl != null) 'publicUrl': publicUrl,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileSize != null) 'fileSize': fileSize,
        'language': language,
      },
    );
    return SubmitTranscriptionResponse.fromJson(response.data!);
  }

  /// 查询转录任务状态
  Future<JobStatusResponse> getJobStatus(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/user-audio/job-status/$jobId',
    );
    return JobStatusResponse.fromJson(response.data!);
  }

  /// 获取转录结果
  Future<TranscriptResult> getTranscript(String sha256, String language) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/user-audio/transcript',
      queryParameters: {'sha256': sha256, 'language': language},
    );
    return TranscriptResult.fromJson(response.data!);
  }

  /// 删除后端转录记录
  ///
  /// 通过 [sha256] + [language] 删除 `user_audio_transcripts` 表中的记录。
  /// 如果记录不存在也不报错（幂等操作）。
  Future<void> deleteTranscript(String sha256, String language) async {
    await _dio.delete<Map<String, dynamic>>(
      '/api/v1/user-audio/transcript',
      queryParameters: {'sha256': sha256, 'language': language},
    );
  }

  /// 释放资源
  void dispose() => _dio.close();
}

// ─── Provider ───────────────────────────────────────────────

/// 转录 API 客户端单例 Provider
@Riverpod(keepAlive: true)
TranscriptionApiClient transcriptionApiClient(TranscriptionApiClientRef ref) {
  final client = TranscriptionApiClient(baseUrl: apiBaseUrl);
  ref.onDispose(client.dispose);
  return client;
}
