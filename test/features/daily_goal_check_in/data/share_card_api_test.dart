import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/daily_goal_check_in/data/share_card_api.dart';
import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../share_card_fixtures.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);
  final List<ResponseBody> responses;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test('解析两种文案，并按语言回退，拒绝无效配色和图片地址', () {
    final word = ShareCardTemplate.fromJson(cardJson(word: true));
    expect(word.content, isA<ShareCardWord>());
    expect(word.content.translationFor('en'), '意外的美好');
    expect(
      ShareCardTemplate.fromJson(cardJson()).content,
      isA<ShareCardSentence>(),
    );
    expect(
      () => ShareCardTemplate.fromJson({
        ...cardJson(),
        'imageUrl': 'file:///tmp/a',
      }),
      throwsFormatException,
    );
    expect(
      () => ShareCardTemplate.fromJson({
        ...cardJson(),
        'textColors': {'top': 'invalid', 'bottom': '#000000'},
      }),
      throwsFormatException,
    );
  });

  test('今日、随机及分享计数符合后端契约；公网下载不携带鉴权头', () async {
    final backendAdapter = _Adapter([
      _json(200, {'date': '2026-11-07', 'timezone': 'UTC', 'card': cardJson()}),
      _json(200, {'card': cardJson(word: true)}),
      ResponseBody.fromString('', 204),
    ]);
    final imagesAdapter = _Adapter([
      ResponseBody.fromBytes([1, 2, 3], 200),
    ]);
    final backend = Dio(
      BaseOptions(
        baseUrl: 'https://api.test',
        headers: {'Authorization': 'Bearer private'},
      ),
    )..httpClientAdapter = backendAdapter;
    final images = Dio()..httpClientAdapter = imagesAdapter;
    final api = ShareCardApi(backend, images);
    final today = await api.getToday();
    await api.getRandom(today.id);
    await api.recordShare(today.id);
    expect(await api.downloadImage(today.imageUrl), [1, 2, 3]);
    expect(backendAdapter.requests[0].path, '/api/v1/share-cards/today');
    expect(backendAdapter.requests[0].queryParameters, isEmpty);
    expect(backendAdapter.requests[1].queryParameters, {'excludeId': today.id});
    expect(backendAdapter.requests[2].method, 'POST');
    expect(backendAdapter.requests[2].data, isNull);
    expect(
      imagesAdapter.requests.single.headers,
      isNot(contains('Authorization')),
    );
    backend.close();
    images.close();
  });

  test('空卡池及计数失败向调用方报告，POST 不重试', () async {
    final adapter = _Adapter([
      _json(404, {'code': 'no_available_cards', 'error': 'none'}),
      _json(500, {'code': 'internal_error', 'error': 'failed'}),
    ]);
    final backend = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final images = Dio();
    final api = ShareCardApi(backend, images);
    await expectLater(api.getToday(), throwsA(isA<DioException>()));
    await expectLater(api.recordShare('id'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(2));
    backend.close();
    images.close();
  });
}
