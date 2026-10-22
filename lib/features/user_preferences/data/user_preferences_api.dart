import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../services/app_logger.dart';
import '../../../services/backend_dio.dart';
import '../domain/user_preferences_document.dart';

class UserPreferencesApiResult {
  const UserPreferencesApiResult({
    required this.document,
    required this.revision,
    this.notModified = false,
  });

  final UserPreferencesDocument? document;
  final int revision;
  final bool notModified;
}

class UserPreferencesConflict implements Exception {
  const UserPreferencesConflict(this.current);

  final UserPreferencesApiResult current;
}

abstract interface class UserPreferencesRemoteDataSource {
  Future<UserPreferencesApiResult> getCurrent({int? knownRevision});

  Future<UserPreferencesApiResult> replace({
    required UserPreferencesDocument document,
    required int expectedRevision,
  });
}

class UserPreferencesApi implements UserPreferencesRemoteDataSource {
  const UserPreferencesApi(this._dio);

  final Dio _dio;

  @override
  Future<UserPreferencesApiResult> getCurrent({int? knownRevision}) async {
    if (knownRevision != null &&
        (knownRevision < 0 || knownRevision > 2147483647)) {
      throw ArgumentError.value(knownRevision, 'knownRevision');
    }

    AppLogger.log(
      'UserPreferencesSync',
      'GET request ifPreferenceRevision=$knownRevision',
    );
    final response = await _dio.get<Object?>(
      '/api/v1/me/preferences',
      options: authRetryOnceOptions(
        headers: knownRevision == null
            ? null
            : {'If-Preference-Revision': knownRevision.toString()},
        validateStatus: (status) =>
            status == 304 || (status != null && status >= 200 && status < 300),
      ),
    );
    if (response.statusCode == 304) {
      if (knownRevision == null) {
        throw const FormatException(
          'Preference endpoint returned 304 without a known revision',
        );
      }
      AppLogger.log(
        'UserPreferencesSync',
        'GET response status=304 revision=$knownRevision notModified=true '
            'headers=${_diagnosticHeadersForLog(response.headers)}',
      );
      return UserPreferencesApiResult(
        document: null,
        revision: knownRevision,
        notModified: true,
      );
    }

    final result = _parseResponse(response);
    AppLogger.log(
      'UserPreferencesSync',
      'GET response status=${response.statusCode} '
          'revision=${result.revision} '
          'headers=${_diagnosticHeadersForLog(response.headers)}',
    );
    return result;
  }

  @override
  Future<UserPreferencesApiResult> replace({
    required UserPreferencesDocument document,
    required int expectedRevision,
  }) async {
    AppLogger.log(
      'UserPreferencesSync',
      'PUT request expectedRevision=$expectedRevision',
    );
    try {
      final response = await _dio.put<Object?>(
        '/api/v1/me/preferences',
        data: document.toJson(),
        options: authRetryOnceOptions(
          // 用服务端返回的数据库 revision 做条件写入。
          headers: {'If-Preference-Revision': expectedRevision.toString()},
        ),
      );
      final result = _parseResponse(response);
      AppLogger.log(
        'UserPreferencesSync',
        'PUT response status=${response.statusCode} '
            'revision=${result.revision} '
            'headers=${_diagnosticHeadersForLog(response.headers)}',
      );
      return result;
    } on DioException catch (error) {
      final response = error.response;
      if (response?.statusCode == 412 && response != null) {
        final current = _parseResponse(response);
        AppLogger.log(
          'UserPreferencesSync',
          'PUT conflict currentRevision=${current.revision}',
        );
        throw UserPreferencesConflict(current);
      }

      final status = response?.statusCode?.toString() ?? 'no_response';
      final responseHeaders = response == null
          ? '<missing>'
          : _diagnosticHeadersForLog(response.headers);
      AppLogger.log(
        'UserPreferencesSync',
        'PUT failed status=$status '
            'expectedRevision=$expectedRevision '
            'responseHeaders=$responseHeaders',
      );
      rethrow;
    }
  }

  String _headerForLog(String? value) {
    if (value == null) return '<missing>';
    final bounded = value.length <= 128 ? value : '${value.substring(0, 128)}…';
    return jsonEncode(bounded);
  }

  String _diagnosticHeadersForLog(Headers headers) {
    const names = [
      'content-encoding',
      'content-length',
      'vary',
      'cache-control',
      'server',
      'via',
      'x-vercel-id',
      'x-cache',
      'cf-cache-status',
      'cf-ray',
      'eo-cache-status',
      'eo-log-uuid',
    ];
    return names
        .map((name) => '$name=${_headerForLog(headers.value(name))}')
        .join(' ');
  }

  UserPreferencesApiResult _parseResponse(Response<Object?> response) {
    final body = _objectMap(response.data);
    if (body == null) {
      throw const FormatException('Preference response must be a JSON object');
    }

    final rawRevision = body['revision'];
    if (rawRevision is! int || rawRevision < 0 || rawRevision > 2147483647) {
      throw const FormatException(
        'Preference response has an invalid revision',
      );
    }

    final rawPreferences = body['preferences'];
    final document = rawPreferences == null
        ? null
        : UserPreferencesDocument.fromJson(rawPreferences);
    return UserPreferencesApiResult(document: document, revision: rawRevision);
  }

  Map<String, Object?>? _objectMap(Object? value) {
    if (value is! Map) return null;
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) result[key] = entry.value;
    }
    return result;
  }
}
