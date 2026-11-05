import 'package:dio/dio.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary/local_dictionary_source.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDictionaryService extends Mock implements DictionaryService {}

void main() {
  late MockDictionaryService service;
  late LocalDictionarySource source;

  setUp(() {
    service = MockDictionaryService();
    source = LocalDictionarySource(service);
  });

  const req = DictionaryLookupRequest(word: 'run');

  test('元数据：在线查询，不可禁用', () {
    expect(source.id, 'local');
    expect(source.canBeDisabled, isFalse);
    expect(source.requiresNetwork, isTrue);
  });

  test('命中 → LocalDictResult', () async {
    when(() => service.lookup('run'))
        .thenAnswer((_) async => const DictEntry(word: 'run', phonetic: 'rʌn'));

    final result = await source.lookup(req);

    expect(result, isA<LocalDictResult>());
    expect((result! as LocalDictResult).entry.word, 'run');
  });

  test('未收录 → null', () async {
    when(() => service.lookup('run')).thenAnswer((_) async => null);

    expect(await source.lookup(req), isNull);
  });

  test('查询失败异常原样抛出，不伪装成未收录', () async {
    when(() => service.lookup('run'))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '/x')));

    await expectLater(source.lookup(req), throwsA(isA<DioException>()));
  });
}
