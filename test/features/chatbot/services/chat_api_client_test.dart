/// ChatApiClient + FakeChatApiClient 测试（mock Dio）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/services/chat_api_client.dart';
import 'package:echo_loop/features/chatbot/services/fake_chat_api_client.dart';
import 'package:echo_loop/features/chatbot/services/ndjson_text_stream.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const endpoint = '/api/v1/stream/chat/sentence';
  final now = DateTime(2026, 7, 18);

  late MockDio mockDio;
  late ChatApiClient client;

  setUp(() {
    mockDio = MockDio();
    client = ChatApiClient.withDio(mockDio, streamLogPrint: (_) {});
  });

  Response<ResponseBody> ndjsonResponse(String ndjson, {int status = 200}) {
    final bytes = Uint8List.fromList(utf8.encode(ndjson));
    return Response(
      data: ResponseBody(Stream<Uint8List>.fromIterable([bytes]), status),
      statusCode: status,
      requestOptions: RequestOptions(path: endpoint, method: 'POST'),
    );
  }

  List<ChatMessage> history() => [
    ChatMessage.user(id: 'u1', content: '这句话什么意思？', createdAt: now),
  ];

  Stream<ChatTextFrame> stream({
    Map<String, Object?> context = const {'sentence': 'The fox'},
    String? targetLanguage = 'zh-CN',
  }) => client.streamChat(
    endpoint: endpoint,
    history: history(),
    context: context,
    followUpInstruction: 'Answer based on the quote.',
    targetLanguage: targetLanguage,
    accessToken: 'access-token',
  );

  test('200 正常流：帧序列正确（累计全文 + done）', () async {
    when(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => ndjsonResponse(
        '${jsonEncode({'delta': '它'})}\n'
        '${jsonEncode({'delta': '表示'})}\n'
        '${jsonEncode({'done': true})}\n',
      ),
    );

    final frames = await stream().toList();
    expect(frames.map((f) => f.text).toList(), ['它', '它表示', '它表示']);
    expect(frames.last.isFinal, isTrue);
  });

  test('请求体组装：messages/context/targetLanguage + Bearer header', () async {
    when(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: {
          'messages': [
            {'role': 'user', 'content': '这句话什么意思？'},
          ],
          'context': {'sentence': 'The fox'},
          'targetLanguage': 'zh-CN',
        },
        options: any(
          named: 'options',
          that: isA<Options>().having(
            (o) => o.headers?['Authorization'],
            'Authorization',
            'Bearer access-token',
          ),
        ),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => ndjsonResponse('${jsonEncode({'done': true})}\n'),
    );

    await stream().toList();

    verify(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: {
          'messages': [
            {'role': 'user', 'content': '这句话什么意思？'},
          ],
          'context': {'sentence': 'The fox'},
          'targetLanguage': 'zh-CN',
        },
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test('空 context / 无 targetLanguage 时请求体省略该字段', () async {
    when(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: {
          'messages': [
            {'role': 'user', 'content': '这句话什么意思？'},
          ],
        },
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => ndjsonResponse('${jsonEncode({'done': true})}\n'),
    );

    await stream(context: const {}, targetLanguage: null).toList();

    verify(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: {
          'messages': [
            {'role': 'user', 'content': '这句话什么意思？'},
          ],
        },
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test('401 → ChatAuthRequiredException', () {
    when(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async =>
          ndjsonResponse(jsonEncode({'code': 'auth_required'}), status: 401),
    );

    expect(stream().toList(), throwsA(isA<ChatAuthRequiredException>()));
  });

  test('402 quota → 带状态码 402 的 DioException', () {
    when(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async =>
          ndjsonResponse(jsonEncode({'code': 'quota_exceeded'}), status: 402),
    );

    expect(
      stream().toList(),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          402,
        ),
      ),
    );
  });

  test('5xx → DioException(badResponse)', () {
    when(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => ndjsonResponse('{}', status: 500));

    expect(
      stream().toList(),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });

  test('流内 __error → ChatStreamException', () {
    when(
      () => mockDio.post<ResponseBody>(
        endpoint,
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => ndjsonResponse(
        '${jsonEncode({'delta': '它'})}\n'
        '${jsonEncode({'__error': 'boom'})}\n',
      ),
    );

    expect(stream().toList(), throwsA(isA<ChatStreamException>()));
  });

  group('FakeChatApiClient', () {
    test('逐帧吐 delta + 末帧 done', () async {
      const fake = FakeChatApiClient(frameDelay: Duration.zero);
      final frames = await fake
          .streamChat(
            endpoint: endpoint,
            history: history(),
            context: const {},
            followUpInstruction: 'Answer based on the quote.',
            accessToken: 't',
          )
          .toList();
      expect(frames.length, greaterThan(1));
      expect(frames.last.isFinal, isTrue);
      expect(frames.last.text, contains('这句话什么意思？'));
      // 累计递增
      for (var i = 1; i < frames.length; i++) {
        expect(
          frames[i].text.length,
          greaterThanOrEqualTo(frames[i - 1].text.length),
        );
      }
    });

    test('cancelToken 取消后停止吐帧、无 final', () async {
      const fake = FakeChatApiClient(frameDelay: Duration(milliseconds: 5));
      final cancel = CancelToken();
      final frames = <ChatTextFrame>[];
      final sub = fake
          .streamChat(
            endpoint: endpoint,
            history: history(),
            context: const {},
            followUpInstruction: 'Answer based on the quote.',
            accessToken: 't',
            cancelToken: cancel,
          )
          .listen(frames.add);
      await Future<void>.delayed(const Duration(milliseconds: 12));
      cancel.cancel('stopped');
      await sub.asFuture<void>();
      expect(frames.every((f) => !f.isFinal), isTrue);
    });
  });
}
