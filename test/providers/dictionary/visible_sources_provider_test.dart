import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/dictionary_settings_provider.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSource implements DictionarySource {
  @override
  final String id;
  @override
  final bool canBeDisabled;
  _FakeSource(this.id, {required this.canBeDisabled});
  @override
  IconData get icon => Icons.abc;
  @override
  bool get requiresNetwork => false;
  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeSources = <DictionarySource>[
    _FakeSource('local', canBeDisabled: false),
    _FakeSource('ai', canBeDisabled: false),
    _FakeSource('cambridge', canBeDisabled: true),
  ];

  late SharedPreferences prefs;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        dictionarySourcesProvider.overrideWithValue(fakeSources),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  ProviderContainer makeRegistryContainer() {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('默认全部可见', () {
    final c = makeContainer();
    final visible = c.read(visibleDictionarySourcesProvider);
    expect(visible.map((s) => s.id), ['local', 'ai', 'cambridge']);
  });

  test('欧路词典默认可见并可禁用', () async {
    final c = makeRegistryContainer();
    expect(
      c
          .read(visibleDictionarySourcesProvider)
          .any((source) => source.id == 'eudic'),
      isTrue,
    );

    await c
        .read(dictionarySettingsNotifierProvider.notifier)
        .setDisabled('eudic', true);

    expect(
      c
          .read(visibleDictionarySourcesProvider)
          .any((source) => source.id == 'eudic'),
      isFalse,
    );
    expect(c.read(dictionarySettingsNotifierProvider).defaultSourceId, 'local');
  });

  test('禁用 cambridge → 可见列表排除它', () async {
    final c = makeContainer();
    await c
        .read(dictionarySettingsNotifierProvider.notifier)
        .setDisabled('cambridge', true);
    final visible = c.read(visibleDictionarySourcesProvider);
    expect(visible.map((s) => s.id), ['local', 'ai']);
  });

  test('resolvedDefaultSourceId：默认源可见时原样返回', () async {
    final c = makeContainer();
    await c.read(dictionarySettingsNotifierProvider.notifier).setDefault('ai');
    expect(c.read(resolvedDefaultSourceIdProvider), 'ai');
  });

  test('resolvedDefaultSourceId：持久化默认源不可见时回退首个可见源（读侧兜底）', () async {
    // 直接构造「默认=cambridge 且 cambridge 已禁用」的历史持久化状态，
    // 绕过写侧回退规则，单独验证读侧 provider 的兜底。
    SharedPreferences.setMockInitialValues({
      'dictionary_settings':
          '{"defaultSourceId":"cambridge","disabledIds":["cambridge"]}',
    });
    prefs = await SharedPreferences.getInstance();
    final c = makeContainer();

    expect(
      c.read(dictionarySettingsNotifierProvider).defaultSourceId,
      'cambridge',
    );
    expect(c.read(resolvedDefaultSourceIdProvider), 'local'); // 回退
  });
}
