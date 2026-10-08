/// AI 句子翻译/解析 API 客户端
///
/// 封装与后端 `/api/v1/ai/` 的通信，用于获取句子的翻译和语法解析。
/// 基于 Dio，receiveTimeout 设为 60 秒以适应 LLM 响应延迟。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_io/io.dart';

import '../config/api_config.dart';
import '../features/auth/providers/auth_providers.dart';
import '../providers/package_info_provider.dart';
import 'ai_http_client_adapter.dart';
import 'app_logger.dart';
import 'backend_dio.dart';
import 'dictionary/dictionary_source.dart';
import 'ndjson_object_stream.dart';
import 'ndjson_stream.dart';
import 'supabase_token_coordinator.dart';
import 'runtime_endpoint_router.dart';
import '../models/sentence_ai_result.dart';
import '../models/sense_group_result.dart';
import '../models/retell_review_evaluation.dart';
import '../models/dictionary/dictionary_entry.dart';

part 'sentence_ai_api_client.g.dart';

/// AI 词典流式协议帧。
///
/// [isFinal] 只在后端完整成功末帧为 true；调用方只有收到 final 才能把最后
/// 一帧视为可缓存的完整结果。
class AiDictionaryStreamFrame {
  final AiDictionaryEntry entry;
  final bool isFinal;

  const AiDictionaryStreamFrame({required this.entry, required this.isFinal});
}

/// AI 句子解析流式协议帧。
///
/// [isFinal] 只在后端完整成功末帧为 true；调用方只有收到 final 才能把最后
/// 一帧视为可缓存的完整结果。
class SentenceAnalysisStreamFrame {
  final SentenceAnalysis analysis;
  final bool isFinal;

  const SentenceAnalysisStreamFrame({
    required this.analysis,
    required this.isFinal,
  });
}

/// 句子解析流内错误（`{"__error":...}` 或行损坏）。
class SentenceAnalysisStreamException implements Exception {
  const SentenceAnalysisStreamException();

  @override
  String toString() => 'SentenceAnalysisStreamException';
}

/// AI 句子翻译流式协议帧。
///
/// [isFinal] 只在后端完整成功末帧为 true；调用方只有收到 final 才能把最后
/// 一帧视为可缓存的完整译文。
class SentenceTranslationStreamFrame {
  final SentenceTranslation translation;
  final bool isFinal;

  const SentenceTranslationStreamFrame({
    required this.translation,
    required this.isFinal,
  });
}

/// 句子翻译流内错误（`{"__error":...}` 或行损坏）。
class SentenceTranslationStreamException implements Exception {
  const SentenceTranslationStreamException();

  @override
  String toString() => 'SentenceTranslationStreamException';
}

/// AI 意群拆分流式协议帧。
///
/// [isFinal] 只在后端完整成功末帧为 true；调用方只有收到 final 才能把最后一帧
/// 视为可缓存的完整结果（并做 concat 最终校验）。后端按 medium → fine 顺序流出。
class SenseGroupsStreamFrame {
  final SenseGroupResult result;
  final bool isFinal;

  const SenseGroupsStreamFrame({required this.result, required this.isFinal});
}

/// 意群拆分流内错误（`{"__error":...}` 或行损坏）。
class SenseGroupsStreamException implements Exception {
  const SenseGroupsStreamException();

  @override
  String toString() => 'SenseGroupsStreamException';
}

/// AI 句子翻译/解析 API 客户端
class SentenceAiApiClient {
  final Dio _dio;
  final void Function(String message) _streamLogPrint;

  /// [appVersion] 随请求以 `x-app-version` 上报（版本灰度预留），可为 null。
  /// 平台与渠道标识会随请求携带，后端据此按组合决定是否限额。
  SentenceAiApiClient({
    required String baseUrl,
    String? appVersion,
    SupabaseTokenCoordinator? tokenCoordinator,
    RuntimeEndpointRouter? endpointRouter,
    bool http2Enabled = aiHttp2EnabledByDefault,
    void Function(String message)? streamLogPrint,
  }) : _dio = createAuthenticatedBackendDio(
         tokenCoordinator: tokenCoordinator,
         baseUrl: baseUrl,
         endpointRouter: endpointRouter,
         appVersion: appVersion,
         connectTimeout: const Duration(seconds: 15),
         // h2 下只约束「到首个响应头」（后端 NDJSON 响应头立即 flush，30s 极充裕）；
         // 帧间停顿由 aiHttpStreamIdleTimeout 独立兜底。
         receiveTimeout: const Duration(seconds: 30),
         apiLogTag: 'AI-API',
       ),
       _streamLogPrint =
           streamLogPrint ?? ((message) => AppLogger.log('AI-API', message)) {
    configureAiHttpClientAdapter(
      _dio,
      baseUrl: baseUrl,
      http2Enabled: http2Enabled,
    );
  }

  /// 用于测试的构造函数，允许注入 Dio 实例
  SentenceAiApiClient.withDio(
    this._dio, {
    void Function(String message)? streamLogPrint,
  }) : _streamLogPrint =
           streamLogPrint ?? ((message) => AppLogger.log('AI-API', message));

  /// 请求公共 headers（仅测试用，验证平台/版本标识已随请求携带）。
  @visibleForTesting
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// 当前 Dio adapter（仅测试用，锁定 AI API transport 配置）。
  @visibleForTesting
  HttpClientAdapter get debugHttpClientAdapter => _dio.httpClientAdapter;

  /// 翻译句子（流式，单句 + 上下文）
  ///
  /// 调用后端 `POST /api/v1/stream/translate`（需登录态），`translation` 单字段随
  /// NDJSON 逐帧渐显。只译目标句 [text]，[previousText]/[nextText] 仅作上下文（缺失
  /// 即首/末句，可为 null）。协议与错误处理同 [analyzeStream]（同款 `ops` transport）。
  /// [targetLanguage] 为 BCP 47 代码（如 'zh-CN'），不传则由后端决定默认值。
  Stream<SentenceTranslationStreamFrame> translateStream(
    String text, {
    required String accessToken,
    String? previousText,
    String? nextText,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      '/api/v1/stream/translate',
      data: {
        'text': text,
        if (previousText != null) 'previousText': previousText,
        if (nextText != null) 'nextText': nextText,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      cancelToken: cancelToken,
    );

    final body = response.data;
    final status = response.statusCode ?? 0;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    if (status != 200) {
      final errorMap = await _decodeErrorBody(body);
      _logStreamHttpError(
        response.requestOptions,
        status: status,
        errorMap: errorMap,
      );
      // 402（额度）等：抛带状态码的 DioException，由 provider 的 _callWithQuotaMapping
      // 映射为额度超限；其余非 200 一并作为 badResponse 上抛。
      throw DioException(
        requestOptions: response.requestOptions,
        response: Response(
          requestOptions: response.requestOptions,
          statusCode: status,
          data: errorMap,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    // 单字段 translation 渐显：{"ops":[{"p":["translation"],"v":..}]} / {"done":true} /
    // {"__error":..}，委托通用层累积（协议见后端 stream/_shared.ts）。
    try {
      final frames = accumulateNdjsonObject<SentenceTranslation>(
        _decodeLoggedNdjson(body, response.requestOptions),
        fromJson: SentenceTranslation.fromJson,
      );
      await for (final f in frames) {
        yield SentenceTranslationStreamFrame(
          translation: f.value,
          isFinal: f.isFinal,
        );
      }
    } on NdjsonStreamException {
      throw const SentenceTranslationStreamException();
    }
  }

  /// 解析句子（流式）
  ///
  /// 调用后端 `POST /api/v1/stream/analyze`（需登录态），字段级增量流式（NDJSON）：
  /// grammar/vocabulary/listening 各要点随流逐条渐显。协议与错误处理见
  /// [_streamDictionaryFrames]（同款 NDJSON transport）。
  /// [targetLanguage] 为 BCP 47 代码（如 'zh-CN'），不传则由后端决定默认值。
  Stream<SentenceAnalysisStreamFrame> analyzeStream(
    String text, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      '/api/v1/stream/analyze',
      data: {
        'text': text,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      cancelToken: cancelToken,
    );

    final body = response.data;
    final status = response.statusCode ?? 0;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    if (status != 200) {
      final errorMap = await _decodeErrorBody(body);
      _logStreamHttpError(
        response.requestOptions,
        status: status,
        errorMap: errorMap,
      );
      // 402（额度）等：抛带状态码的 DioException，由 provider 的 _callWithQuotaMapping
      // 映射为额度超限；其余非 200 一并作为 badResponse 上抛。
      throw DioException(
        requestOptions: response.requestOptions,
        response: Response(
          requestOptions: response.requestOptions,
          statusCode: status,
          data: errorMap,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    // 字段级增量累积委托通用层 accumulateNdjsonObject：
    // {"ops":[{"p":["grammar",0,"point"],"v":..}]} 增量批 / {"done":true} / {"__error":..}
    try {
      final frames = accumulateNdjsonObject<SentenceAnalysis>(
        _decodeLoggedNdjson(body, response.requestOptions),
        fromJson: SentenceAnalysis.fromJson,
      );
      await for (final f in frames) {
        yield SentenceAnalysisStreamFrame(
          analysis: f.value,
          isFinal: f.isFinal,
        );
      }
    } on NdjsonStreamException {
      throw const SentenceAnalysisStreamException();
    }
  }

  /// AI 词典释义（单词，流式）
  ///
  /// 调用后端 `POST /api/v1/stream/lookup-word`（需登录态），字段级增量流式
  /// （NDJSON，见 [_streamDictionaryFrames]）。仅用于单词（规范化后无空白）；
  /// 词组用 [lookupPhraseStream]。
  Stream<AiDictionaryEntry> lookupWordStream(
    String word, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) => lookupWordStreamFrames(
    word,
    accessToken: accessToken,
    targetLanguage: targetLanguage,
    cancelToken: cancelToken,
  ).map((frame) => frame.entry);

  /// AI 词典释义（单词，带协议帧信息）。
  Stream<AiDictionaryStreamFrame> lookupWordStreamFrames(
    String word, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) => _streamDictionaryFrames(
    '/api/v1/stream/lookup-word',
    word,
    fromJson: DictionaryEntry.fromJson,
    accessToken: accessToken,
    targetLanguage: targetLanguage,
    cancelToken: cancelToken,
  );

  /// AI 词典释义（多词/短语，流式）
  ///
  /// 调用后端 `POST /api/v1/stream/lookup-phrase`（需登录态），字段级增量流式
  /// （NDJSON，见 [_streamDictionaryFrames]）。仅用于多词表达（规范化后含空白）；
  /// 单词用 [lookupWordStream]。
  Stream<AiDictionaryEntry> lookupPhraseStream(
    String phrase, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) => lookupPhraseStreamFrames(
    phrase,
    accessToken: accessToken,
    targetLanguage: targetLanguage,
    cancelToken: cancelToken,
  ).map((frame) => frame.entry);

  /// AI 词典释义（多词/短语，带协议帧信息）。
  Stream<AiDictionaryStreamFrame> lookupPhraseStreamFrames(
    String phrase, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) => _streamDictionaryFrames(
    '/api/v1/stream/lookup-phrase',
    phrase,
    fromJson: MultiWordDictionaryEntry.fromJson,
    accessToken: accessToken,
    targetLanguage: targetLanguage,
    cancelToken: cancelToken,
  );

  /// 流式查词通用实现：发起 `ResponseType.stream` 请求，逐帧解析 NDJSON。
  ///
  /// - 前置错误（非 200）：手动读小 JSON 错误体，映射为专用异常
  ///   （`phrase_too_long`/需登录）或带状态码的 [DioException]（如 402 由
  ///   controller 转额度态）。`validateStatus: (_) => true` 使 Dio 不在非 2xx
  ///   时提前抛出，让我们能读到错误体的 `code`。
  /// - 流内错误帧（`{"__error": ...}`）：抛 [DictionaryStreamException]。
  Stream<AiDictionaryStreamFrame> _streamDictionaryFrames(
    String path,
    String query, {
    required AiDictionaryEntry Function(Map<String, dynamic>) fromJson,
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      path,
      data: {
        'query': query,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      cancelToken: cancelToken,
    );

    final body = response.data;
    final status = response.statusCode ?? 0;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    if (status != 200) {
      final errorMap = await _decodeErrorBody(body);
      _logStreamHttpError(
        response.requestOptions,
        status: status,
        errorMap: errorMap,
      );
      if (status == 400 && errorMap?['code'] == 'phrase_too_long') {
        throw const DictionaryPhraseTooLongException();
      }
      if (status == 401) {
        throw const DictionaryAuthRequiredException();
      }
      // 402（额度）等：抛带状态码的 DioException，沿用 controller 现有分支处理
      throw DioException(
        requestOptions: response.requestOptions,
        response: Response(
          requestOptions: response.requestOptions,
          statusCode: status,
          data: errorMap,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    // 字段级增量累积委托给通用层 accumulateNdjsonObject：
    // {"ops":[...]} 增量批 / {"done":true} / {"__error":..}
    // （协议见后端 stream/_shared.ts）。类型由调用端点决定（单词/词组各传具体
    // fromJson），客户端不做结构嗅探。
    try {
      final frames = accumulateNdjsonObject<AiDictionaryEntry>(
        _decodeLoggedNdjson(body, response.requestOptions),
        fromJson: fromJson,
      );
      await for (final f in frames) {
        yield AiDictionaryStreamFrame(entry: f.value, isFinal: f.isFinal);
      }
    } on NdjsonStreamException {
      throw const DictionaryStreamException();
    }
  }

  /// 读取非 200 响应的错误体（小 JSON），解析为 Map；失败返回 null。
  Future<Map<String, dynamic>?> _decodeErrorBody(ResponseBody body) async {
    try {
      final text = await utf8.decodeStream(body.stream);
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// 流式非 2xx 响应需在消费错误 JSON 后补日志，公共拦截器不能提前读取响应流。
  void _logStreamHttpError(
    RequestOptions request, {
    required int status,
    required Map<String, dynamic>? errorMap,
  }) {
    _streamLogPrint(
      '流式请求失败 ${request.method} ${request.uri} '
      'status=$status code=${errorMap?['code'] ?? '(空)'} '
      'error=${errorMap?['error'] ?? '(空)'}',
    );
  }

  /// AI 意群拆分（流式）
  ///
  /// 调用后端 `POST /api/v1/stream/sense-groups`（需登录态），字段级增量流式（NDJSON，
  /// 协议与错误处理见 [analyzeStream]）：medium 意群先逐个渐显，fine 意群随后。
  /// **无 targetLanguage**——意群是原句子串的切分，与目标语言无关。
  Stream<SenseGroupsStreamFrame> senseGroupsStream(
    String text, {
    required String accessToken,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      '/api/v1/stream/sense-groups',
      data: {'text': text},
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      cancelToken: cancelToken,
    );

    final body = response.data;
    final status = response.statusCode ?? 0;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    if (status != 200) {
      final errorMap = await _decodeErrorBody(body);
      _logStreamHttpError(
        response.requestOptions,
        status: status,
        errorMap: errorMap,
      );
      // 402（额度）等：抛带状态码的 DioException，由 provider 的 _callWithQuotaMapping
      // 映射为额度超限；其余非 200 一并作为 badResponse 上抛。
      throw DioException(
        requestOptions: response.requestOptions,
        response: Response(
          requestOptions: response.requestOptions,
          statusCode: status,
          data: errorMap,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    // 字段级增量累积委托通用层：{"ops":[{"p":["medium",0],"v":".."}]} / {"done":true} / {"__error":..}
    try {
      final frames = accumulateNdjsonObject<SenseGroupResult>(
        _decodeLoggedNdjson(body, response.requestOptions),
        fromJson: SenseGroupResult.fromJson,
      );
      await for (final f in frames) {
        yield SenseGroupsStreamFrame(result: f.value, isFinal: f.isFinal);
      }
    } on NdjsonStreamException {
      throw const SenseGroupsStreamException();
    }
  }

  /// 复述效果 AI 评估（流式）。
  ///
  /// 调用后端 `POST /api/v1/stream/evaluate-review`（需登录态，按后端
  /// `retell_review` 口径计量）。错误处理同 [senseGroupsStream]：401/402 等
  /// 非 200 抛带状态码的 [DioException]，由 controller 映射成登录 / 额度态。
  Stream<RetellReviewStreamFrame> evaluateReviewStream({
    required File audioFile,
    required String originalText,
    required String targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      '/api/v1/stream/evaluate-review',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'retell-review.m4a',
        ),
        'originalText': originalText,
        'language': 'en',
        'targetLanguage': targetLanguage,
      }),
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      cancelToken: cancelToken,
    );

    final body = response.data;
    final status = response.statusCode ?? 0;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
    if (status != 200) {
      final errorMap = await _decodeErrorBody(body);
      _logStreamHttpError(
        response.requestOptions,
        status: status,
        errorMap: errorMap,
      );
      throw DioException(
        requestOptions: response.requestOptions,
        response: Response(
          requestOptions: response.requestOptions,
          statusCode: status,
          data: errorMap,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    try {
      // `meta` 首帧（转录文本）在转录完成、AI 尚未产出任何文本时就到达。把它改写成
      // 一个 `transcript` 叶子的 ops 帧，让通用累积层照常 yield 一帧：UI 因此能在
      // 等 AI 输出期间先显示转录，而不是一直停在骨架态。
      final frames = accumulateNdjsonObject<RetellReviewEvaluation>(
        _decodeLoggedNdjson(body, response.requestOptions).map((event) {
          final meta = event['meta'];
          if (meta is! Map) return event;
          final transcript = meta['transcript'];
          if (transcript is! String) return event;
          return <String, dynamic>{
            'ops': [
              {
                'p': ['transcript'],
                'v': transcript,
              },
            ],
          };
        }),
        fromJson: RetellReviewEvaluation.fromJson,
      );
      await for (final frame in frames) {
        yield RetellReviewStreamFrame(
          evaluation: frame.value,
          isFinal: frame.isFinal,
        );
      }
    } on NdjsonStreamException {
      throw const RetellReviewStreamException();
    }
  }

  /// 释放资源
  void dispose() => _dio.close();

  /// 流式响应体只能被消费一次；这里在 NDJSON 解码入口旁路打印原始帧，
  /// 既能看到每次服务端推送的响应内容，又不会破坏后续业务解析。
  Stream<Map<String, dynamic>> _decodeLoggedNdjson(
    ResponseBody body,
    RequestOptions request,
  ) {
    return decodeNdjson(
      body.stream,
      idleTimeout: aiHttpStreamIdleTimeout,
      onLine: (line) {
        _streamLogPrint(
          '  流式响应帧 ${request.method} ${request.uri}: '
          '${_truncateStreamLog(line)}',
        );
      },
    );
  }

  /// 单帧过长时截断，避免一条日志挤爆控制台和应用内环形缓冲。
  String _truncateStreamLog(String text) {
    const maxLength = 2000;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…（已截断，共 ${text.length} 字符）';
  }
}

/// AI API 客户端单例 Provider
@Riverpod(keepAlive: true)
SentenceAiApiClient sentenceAiApiClient(Ref ref) {
  final client = SentenceAiApiClient(
    baseUrl: apiBaseUrl,
    endpointRouter: runtimeEndpointRouter,
    appVersion: readAppVersion(ref),
    tokenCoordinator: ref.read(supabaseTokenCoordinatorProvider),
  );
  ref.onDispose(client.dispose);
  return client;
}
