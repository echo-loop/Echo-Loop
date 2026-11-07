import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/profile/data/user_profile_api.dart';
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

Map<String, Object?> _profileBody({String? nickname, String? avatarUrl}) => {
  'userId': 'user-1',
  'nickname': nickname,
  'avatarUrl': avatarUrl,
  'updatedAt': '2026-11-07T08:00:00.000Z',
};

UserProfileApi _apiWith(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter;
  return UserProfileApi(dio);
}

void main() {
  test('GET 解析昵称与头像，允许两者为 null', () async {
    final adapter = _ScriptedAdapter([
      _jsonResponse(status: 200, body: _profileBody()),
    ]);

    final profile = await _apiWith(adapter).getProfile();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/api/v1/me/profile');
    expect(profile.userId, 'user-1');
    expect(profile.nickname, isNull);
    expect(profile.avatarUrl, isNull);
  });

  test('PATCH 昵称以 multipart 字段发送并解析响应', () async {
    final adapter = _ScriptedAdapter([
      _jsonResponse(status: 200, body: _profileBody(nickname: 'Ann')),
    ]);

    final profile = await _apiWith(adapter).updateNickname('Ann');

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    final form = request.data as FormData;
    expect(form.fields.single.key, 'nickname');
    expect(form.fields.single.value, 'Ann');
    expect(form.files, isEmpty);
    expect(profile.nickname, 'Ann');
  });

  test('PATCH 上传头像时以 avatar 文件字段发送', () async {
    final adapter = _ScriptedAdapter([
      _jsonResponse(
        status: 200,
        body: _profileBody(avatarUrl: 'https://cdn.test/a.jpg'),
      ),
    ]);

    final profile = await _apiWith(adapter)
        .uploadAvatar(Uint8List.fromList([1, 2, 3]));

    final form = adapter.requests.single.data as FormData;
    expect(form.files.single.key, 'avatar');
    expect(form.files.single.value.length, 3);
    expect(profile.avatarUrl, 'https://cdn.test/a.jpg');
  });

  test('移除头像发送 removeAvatar=true', () async {
    final adapter = _ScriptedAdapter([
      _jsonResponse(status: 200, body: _profileBody()),
    ]);

    await _apiWith(adapter).removeAvatar();

    final form = adapter.requests.single.data as FormData;
    expect(form.fields.single.key, 'removeAvatar');
    expect(form.fields.single.value, 'true');
  });

  test('PATCH 失败时抛出 DioException，不静默吞掉', () async {
    final adapter = _ScriptedAdapter([
      _jsonResponse(status: 400, body: {'error': 'nickname invalid'}),
    ]);

    await expectLater(
      _apiWith(adapter).updateNickname(''),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          400,
        ),
      ),
    );
  });
}
