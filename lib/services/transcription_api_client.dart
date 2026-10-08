// 转录 API 客户端
//
// 封装与后端的所有 HTTP API 通信，用于 AI 转录流程。
// 基于 Dio，支持 CancelToken、上传进度回调和错误处理。
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_io/io.dart';
import '../features/auth/providers/auth_providers.dart';
import '../config/api_config.dart';
import '../models/word_timestamp.dart';
import '../providers/package_info_provider.dart';
import 'api_log_interceptor.dart';
import 'backend_dio.dart';
import 'supabase_token_coordinator.dart';
import 'runtime_endpoint_router.dart';
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

  /// 词级时间戳列表（AI 转录时非空）
  final List<WordTimestamp>? words;

  /// 全文文本
  final String fullText;

  const TranscriptResult({
    required this.sentences,
    this.words,
    required this.fullText,
  });

  factory TranscriptResult.fromJson(Map<String, dynamic> json) {
    final sentencesList = (json['sentences'] as List)
        .map((s) => TranscriptSentence.fromJson(s as Map<String, dynamic>))
        .toList();
    final wordsList = json['words'] != null
        ? (json['words'] as List)
              .map((w) => WordTimestamp.fromJson(w as Map<String, dynamic>))
              .toList()
        : null;
    return TranscriptResult(
      sentences: sentencesList,
      words: wordsList,
      fullText: json['fullText'] as String? ?? '',
    );
  }
}

// ─── API 客户端 ───────────────────────────────────────────────

/// 转录 API 客户端
///
/// 封装与后端 `/api/v2/user-audio/` 的所有通信。
class TranscriptionApiClient {
  final Dio _dio;

  /// [appVersion] 随请求以 `x-app-version` 上报（版本灰度预留），可为 null。
  /// 平台与渠道标识会随请求携带，后端据此按组合决定是否限额。
  TranscriptionApiClient({
    required String baseUrl,
    String? appVersion,
    SupabaseTokenCoordinator? tokenCoordinator,
    RuntimeEndpointRouter? endpointRouter,
  }) : _dio = createAuthenticatedBackendDio(
         tokenCoordinator: tokenCoordinator,
         baseUrl: baseUrl,
         endpointRouter: endpointRouter,
         appVersion: appVersion,
         connectTimeout: const Duration(seconds: 15),
         receiveTimeout: const Duration(seconds: 30),
         apiLogTag: 'DIO',
       );

  /// 用于测试的构造函数，允许注入 Dio 实例
  TranscriptionApiClient.withDio(this._dio);

  /// 请求公共 headers（仅测试用，验证平台/版本标识已随请求携带）。
  @visibleForTesting
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// 获取 R2 上传预签名 URL
  ///
  /// 自动检查音频缓存：[audioExists]=true 时跳过上传。
  Future<UploadUrlResponse> getUploadUrl({
    required String sha256,
    required String mimeType,
    required int fileSize,
    required String accessToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/user-audio/upload-url',
      data: {'sha256': sha256, 'mimeType': mimeType, 'fileSize': fileSize},
      options: _authOptions(accessToken),
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
    // 直接 PUT 原始字节流到 R2 presigned URL（挂日志拦截器，便于排查上传失败）
    final uploadDio = Dio()
      ..interceptors.add(ApiLogInterceptor(tag: 'R2-UPLOAD'));
    await uploadDio.put<void>(
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
    String? fileName,
    String? objectName,
    String? publicUrl,
    String? mimeType,
    int? fileSize,
    required String language,
    required String accessToken,
    bool mergeSentences = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/user-audio/submit-transcription',
      data: {
        'sha256': sha256,
        if (fileName != null) 'fileName': fileName,
        if (objectName != null) 'objectName': objectName,
        if (publicUrl != null) 'publicUrl': publicUrl,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileSize != null) 'fileSize': fileSize,
        'language': language,
        // 关闭「自动合并短句」时传 false，后端返回未合并基线
        'mergeSentences': mergeSentences,
      },
      options: _authOptions(accessToken),
    );
    return SubmitTranscriptionResponse.fromJson(response.data!);
  }

  /// 查询转录任务状态
  Future<JobStatusResponse> getJobStatus(
    String jobId, {
    required String accessToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v2/user-audio/job-status/$jobId',
      options: _authOptions(accessToken),
    );
    return JobStatusResponse.fromJson(response.data!);
  }

  /// 获取转录结果
  Future<TranscriptResult> getTranscript(
    String sha256,
    String language, {
    required String accessToken,
    bool mergeSentences = true,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v2/user-audio/transcript',
      queryParameters: {
        'sha256': sha256,
        'language': language,
        // 关闭「自动合并短句」时传 false，后端返回未合并基线
        'mergeSentences': mergeSentences,
      },
      options: _authOptions(accessToken),
    );
    return TranscriptResult.fromJson(response.data!);
  }

  Options _authOptions(String accessToken) {
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }

  /// 释放资源
  void dispose() => _dio.close();
}

// ─── Provider ───────────────────────────────────────────────

/// 转录 API 客户端单例 Provider
@Riverpod(keepAlive: true)
TranscriptionApiClient transcriptionApiClient(Ref ref) {
  final client = TranscriptionApiClient(
    baseUrl: apiBaseUrl,
    endpointRouter: runtimeEndpointRouter,
    appVersion: readAppVersion(ref),
    tokenCoordinator: ref.read(supabaseTokenCoordinatorProvider),
  );
  ref.onDispose(client.dispose);
  return client;
}
