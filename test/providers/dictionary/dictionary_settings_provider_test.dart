import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/dictionary_settings_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 轻量 fake 源（只携带元数据，不真正查词）
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('默认值', () {
    final c = makeContainer();
    final s = c.read(dictionarySettingsNotifierProvider);
    expect(s.defaultSourceId, 'local');
    expect(s.disabledIds, isEmpty);
    expect(s.autoSpeakOnLookup, isTrue);
    expect(s.adFilteringEnabled, isFalse);
  });

  test('setDefault 更新并持久化', () async {
    final c = makeContainer();
    await c.read(dictionarySettingsNotifierProvider.notifier).setDefault('ai');
    expect(c.read(dictionarySettingsNotifierProvider).defaultSourceId, 'ai');

    expect(prefs.getString('dictionary_settings'), contains('ai'));
  });

  test('setAutoSpeakOnLookup 更新并持久化', () async {
    final c = makeContainer();
    await c
        .read(dictionarySettingsNotifierProvider.notifier)
        .setAutoSpeakOnLookup(false);

    expect(
      c.read(dictionarySettingsNotifierProvider).autoSpeakOnLookup,
      isFalse,
    );
    expect(prefs.getString('dictionary_settings'), contains('false'));
  });

  test('网页词典广告过滤默认关闭，开启后持久化', () async {
    final c1 = makeContainer();
    expect(
      c1.read(dictionarySettingsNotifierProvider).adFilteringEnabled,
      isFalse,
    );
    await c1
        .read(dictionarySettingsNotifierProvider.notifier)
        .setAdFilteringEnabled(true);
    expect(
      c1.read(dictionarySettingsNotifierProvider).adFilteringEnabled,
      isTrue,
    );
    expect(prefs.getString('dictionary_settings'), contains('adFilteringEnabled'));

    final c2 = makeContainer();
    expect(
      c2.read(dictionarySettingsNotifierProvider).adFilteringEnabled,
      isTrue,
    );
  });

  test('冷启动同步读取持久化的默认源（不再先返缺省 local）', () async {
    // 模拟上次已把默认源存为 ai
    SharedPreferences.setMockInitialValues({
      'dictionary_settings': '{"defaultSourceId":"ai","disabledIds":[]}',
    });
    prefs = await SharedPreferences.getInstance();
    final c = makeContainer();
    // 首次 build 同步即为 ai，不需要任何异步等待
    expect(c.read(dictionarySettingsNotifierProvider).defaultSourceId, 'ai');
    expect(
      c.read(dictionarySettingsNotifierProvider).autoSpeakOnLookup,
      isTrue,
    );
  });

  test('禁用可禁用源 cambridge → 进入禁用集合', () async {
    final c = makeContainer();
    await c
        .read(dictionarySettingsNotifierProvider.notifier)
        .setDisabled('cambridge', true);
    expect(c.read(dictionarySettingsNotifierProvider).disabledIds, {
      'cambridge',
    });
  });

  test('不可禁用源 local/ai 的禁用请求被忽略', () async {
    final c = makeContainer();
    final notifier = c.read(dictionarySettingsNotifierProvider.notifier);
    await notifier.setDisabled('local', true);
    await notifier.setDisabled('ai', true);
    expect(c.read(dictionarySettingsNotifierProvider).disabledIds, isEmpty);
  });

  test('禁用当前默认源 → 默认回退到第一个仍启用源（local）', () async {
    final c = makeContainer();
    final notifier = c.read(dictionarySettingsNotifierProvider.notifier);
    await notifier.setDefault('cambridge');
    await notifier.setDisabled('cambridge', true);

    final s = c.read(dictionarySettingsNotifierProvider);
    expect(s.disabledIds, {'cambridge'});
    expect(s.defaultSourceId, 'local');
  });

  test('重新启用源 → 移出禁用集合', () async {
    final c = makeContainer();
    final notifier = c.read(dictionarySettingsNotifierProvider.notifier);
    await notifier.setDisabled('cambridge', true);
    await notifier.setDisabled('cambridge', false);
    expect(c.read(dictionarySettingsNotifierProvider).disabledIds, isEmpty);
  });

  test('持久化后重建可恢复', () async {
    final c1 = makeContainer();
    await c1
        .read(dictionarySettingsNotifierProvider.notifier)
        .setDisabled('cambridge', true);
    await c1.read(dictionarySettingsNotifierProvider.notifier).setDefault('ai');

    // 新容器共享同一 prefs 实例，build 同步读取，无需等待
    final c2 = makeContainer();
    final s = c2.read(dictionarySettingsNotifierProvider);
    expect(s.defaultSourceId, 'ai');
    expect(s.disabledIds, {'cambridge'});
    expect(s.autoSpeakOnLookup, isTrue);
  });

  test('持久化后重建可恢复自动发音开关', () async {
    final c1 = makeContainer();
    await c1
        .read(dictionarySettingsNotifierProvider.notifier)
        .setAutoSpeakOnLookup(false);

    final c2 = makeContainer();
    expect(
      c2.read(dictionarySettingsNotifierProvider).autoSpeakOnLookup,
      isFalse,
    );
  });
}
