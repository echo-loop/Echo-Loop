import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/user_preferences/data/user_preferences_api.dart';
import 'package:echo_loop/features/user_preferences/domain/user_preferences_document.dart';
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

ResponseBody _jsonResponse({
  required int status,
  required Map<String, Object?> body,
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test(
    'GET reads revision; PUT sends it and parses the current revision on 412',
    () async {
      final current = UserPreferencesDocument({
        'appearance': {'themeMode': 'dark'},
      });
      final latest = UserPreferencesDocument({
        'appearance': {'themeMode': 'light'},
      });
      final adapter = _ScriptedAdapter([
        _jsonResponse(
          status: 200,
          body: {
            'preferences': current.toJson(),
            'revision': 1,
            'updatedAt': '2026-01-01',
          },
        ),
        _jsonResponse(
          status: 412,
          body: {
            'preferences': latest.toJson(),
            'revision': 2,
            'updatedAt': '2026-01-02',
          },
        ),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final api = UserPreferencesApi(dio);

      final fetched = await api.getCurrent();
      expect(fetched.revision, 1);
      expect(fetched.document?.toJson(), current.toJson());

      await expectLater(
        api.replace(document: current, expectedRevision: fetched.revision),
        throwsA(
          isA<UserPreferencesConflict>().having(
            (conflict) => conflict.current.revision,
            'current revision',
            2,
          ),
        ),
      );
      expect(adapter.requests.last.headers['If-Preference-Revision'], '1');
      expect(adapter.requests.last.data, current.toJson());
    },
  );

  test('GET sends a known revision and accepts an empty 304', () async {
    final adapter = _ScriptedAdapter([ResponseBody.fromString('', 304)]);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    final result = await UserPreferencesApi(dio).getCurrent(knownRevision: 7);

    expect(result.notModified, isTrue);
    expect(result.revision, 7);
    expect(result.document, isNull);
    expect(adapter.requests.single.headers['If-Preference-Revision'], '7');
  });

  test('GET rejects a response without a valid integer revision', () async {
    for (final body in <Map<String, Object?>>[
      {'preferences': null},
      {'preferences': null, 'revision': -1},
      {'preferences': null, 'revision': 1.5},
    ]) {
      final adapter = _ScriptedAdapter([
        _jsonResponse(status: 200, body: body),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      await expectLater(
        UserPreferencesApi(dio).getCurrent(),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
