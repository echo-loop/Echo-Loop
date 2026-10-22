import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/data/user_onboarding_api.dart';
import 'package:echo_loop/services/backend_dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.statusCode);

  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString('', statusCode);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'PUT sends the raw answer object to the authenticated onboarding route',
    () async {
      final adapter = _ScriptedAdapter(204);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      await UserOnboardingApi(
        dio,
      ).saveAnswers({'goal': 'work', 'dailyMinutes': '20'});

      expect(adapter.request?.method, 'PUT');
      expect(adapter.request?.path, '/api/v1/me/onboarding');
      expect(adapter.request?.data, {'goal': 'work', 'dailyMinutes': '20'});
      expect(adapter.request?.extra['authRetryPolicy'], AuthRetryPolicy.once);
    },
  );

  test(
    'rejects a successful response other than the endpoint 204 contract',
    () async {
      final adapter = _ScriptedAdapter(200);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      await expectLater(
        UserOnboardingApi(dio).saveAnswers({'goal': 'work'}),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
