import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/account_usage/data/account_usage_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.responses);

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

void main() {
  test('GET /api/v1/me/usage 解析用量响应', () async {
    final adapter = _ScriptedAdapter([
      ResponseBody.fromString(
        jsonEncode({
          'plan': 'free',
          'period': '2026-11',
          'resetAt': '2026-12-01T00:00:00.000Z',
          'features': {
            'transcription': {'limit': 1, 'used': 125, 'remaining': 0},
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;

    final usage = await AccountUsageApi(dio).getUsage();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/api/v1/me/usage');
    expect(usage.plan, 'free');
    expect(usage.features.values.single.isExhausted, isTrue);
  });
}
