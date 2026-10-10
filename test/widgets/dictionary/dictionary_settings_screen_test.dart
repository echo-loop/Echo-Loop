import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/dictionary_settings_provider.dart';
import 'package:echo_loop/screens/dictionary_settings_screen.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final fakeSources = <DictionarySource>[
    _FakeSource('local', canBeDisabled: false),
    _FakeSource('ai', canBeDisabled: false),
    _FakeSource('cambridge', canBeDisabled: true),
  ];

  (ProviderContainer, Widget) build() {
    final container = ProviderContainer(
      overrides: [
        dictionarySourcesProvider.overrideWithValue(fakeSources),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    return (
      container,
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en'), Locale('zh')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DictionarySettingsScreen(),
        ),
      ),
    );
  }

  testWidgets('本地/AI 锁定，Cambridge 可开关', (tester) async {
    final (_, widget) = build();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // local + ai 显示「Always on」锁定
    expect(find.text('Always on'), findsNWidgets(2));
    // 自动发音、网页广告过滤、Cambridge 三个 Switch
    expect(find.byType(Switch), findsNWidgets(3));
  });

  testWidgets('网页词典广告过滤默认关闭并可开启', (tester) async {
    final (container, widget) = build();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Block ads in web dictionaries'), findsOneWidget);
    final toggle = find.byType(Switch).at(1);
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      container.read(dictionarySettingsNotifierProvider).adFilteringEnabled,
      isTrue,
    );
  });

  testWidgets('顶部自动发音开关默认开启并可切换', (tester) async {
    final (container, widget) = build();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Auto-play Pronunciation'), findsOneWidget);
    final toggle = find.byType(Switch).first;
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      container.read(dictionarySettingsNotifierProvider).autoSpeakOnLookup,
      isFalse,
    );
  });

  testWidgets('切换默认词典', (tester) async {
    final (container, widget) = build();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(
      container.read(dictionarySettingsNotifierProvider).defaultSourceId,
      'local',
    );
    // 默认区在前，首个 'AI Dictionary' 即默认区项
    await tester.tap(find.text('AI Dictionary').first);
    await tester.pumpAndSettle();
    expect(
      container.read(dictionarySettingsNotifierProvider).defaultSourceId,
      'ai',
    );
  });

  testWidgets('禁用 Cambridge → 移出默认区选项', (tester) async {
    final (container, widget) = build();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // 初始：默认区 + 词典源区各一个 Cambridge
    expect(find.text('Cambridge'), findsNWidgets(2));

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(container.read(dictionarySettingsNotifierProvider).disabledIds, {
      'cambridge',
    });
    // 默认区不再列出 Cambridge，仅词典源区保留
    expect(find.text('Cambridge'), findsOneWidget);
  });
}
