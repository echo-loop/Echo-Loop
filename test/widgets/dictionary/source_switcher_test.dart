import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/dictionary_settings_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/widgets/dictionary/source_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/misc.dart';
import '../../helpers/mock_providers.dart';

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

  Widget wrap(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: dedupeOverrides([
          dictionarySourcesProvider.overrideWithValue(fakeSources),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overrides,
        ]),
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: child),
        ),
      );

  testWidgets('显示当前源标签；展开列出非 AI 可见源（AI 不在菜单内）', (tester) async {
    String? picked;
    await tester.pumpWidget(
      wrap(
        SourceSwitcher(selectedId: 'local', onSelected: (id) => picked = id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Dictionary'), findsOneWidget);

    await tester.tap(find.text('Local Dictionary'));
    await tester.pumpAndSettle();

    // AI 已提到下拉菜单外，不再出现在切换器里
    expect(find.text('AI Dictionary'), findsNothing);
    expect(find.text('Cambridge'), findsOneWidget);

    await tester.tap(find.text('Cambridge'));
    await tester.pumpAndSettle();
    expect(picked, 'cambridge');
  });

  testWidgets('选中 AI 时点 chip 直接切到显示的源（不展开菜单）', (tester) async {
    String? picked;
    await tester.pumpWidget(
      wrap(SourceSwitcher(selectedId: 'ai', onSelected: (id) => picked = id)),
    );
    await tester.pumpAndSettle();

    // 选中 AI 时 chip 退回默认源（local）
    expect(find.text('Local Dictionary'), findsOneWidget);

    await tester.tap(find.text('Local Dictionary'));
    await tester.pumpAndSettle();

    // 单击直接回调该源，不展开菜单（菜单里才会出现的 Cambridge 不应出现）
    expect(picked, 'local');
    expect(find.text('Cambridge'), findsNothing);
  });

  testWidgets('禁用的源不出现在菜单中', (tester) async {
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        dictionarySourcesProvider.overrideWithValue(fakeSources),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]),
    );
    addTearDown(container.dispose);
    await container
        .read(dictionarySettingsProvider.notifier)
        .setDisabled('cambridge', true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SourceSwitcher(selectedId: 'local', onSelected: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Dictionary'));
    await tester.pumpAndSettle();

    expect(find.text('Cambridge'), findsNothing);
  });

  testWidgets('AI 快捷按钮：渲染 AI 文案，点击回调 ai', (tester) async {
    String? picked;
    await tester.pumpWidget(
      wrap(
        AiSourceButton(selectedId: 'local', onSelected: (id) => picked = id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(picked, 'ai');
  });

  testWidgets('源列表不含 AI 时，AI 快捷按钮不渲染', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          dictionarySourcesProvider.overrideWithValue(<DictionarySource>[
            _FakeSource('local', canBeDisabled: false),
            _FakeSource('cambridge', canBeDisabled: true),
          ]),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ]),
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: AiSourceButton(selectedId: 'local', onSelected: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI'), findsNothing);
  });
}
