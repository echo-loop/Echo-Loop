/// 词典弹窗高度可拖拽测试：AI / 网页源默认 2/3 屏高，上拉指示条放大、下拉缩小。
///
/// 网页源用 linux 平台覆盖让 WebView 走「在浏览器打开」降级分支，避免在 widget
/// test 里渲染真实平台视图；只验证弹窗外层 SizedBox 高度随拖拽变化。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary/web_dictionary_source.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

class _MockDictionaryService extends Mock implements DictionaryService {}

/// 返回固定 AI 结果的 fake 源
class _FixedAiSource implements DictionarySource {
  @override
  String get id => 'ai';
  @override
  IconData get icon => Icons.auto_awesome;
  @override
  bool get canBeDisabled => false;
  @override
  bool get requiresNetwork => true;
  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async => AiDictResult(
    DictionaryEntry(
      headword: 'run',
      pronunciation: const Pronunciation(uk: '', us: ''),
      meanings: const [
        WordMeaning(
          partOfSpeech: 'v.',
          translation: ['奔跑'],
          definition: 'to move fast on foot',
          usageNote: '',
          examples: [],
          synonyms: [],
          antonyms: [],
        ),
      ],
      commonExpressions: const [],
      wordFamily: const [],
      forms: const [],
      etymology: '',
      learnerTips: const [],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryService oldInstance;
  late WebDictionarySource web;
  late _FixedAiSource ai;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final mock = _MockDictionaryService();
    when(() => mock.isAvailable).thenReturn(true);
    oldInstance = DictionaryService.replaceInstance(mock);
    web = WebDictionarySource(
      WebDictConfig(
        id: 'cambridge',
        displayName: 'Cambridge',
        icon: Icons.menu_book,
        color: const Color(0xFF000000),
        buildUrl: (w) => 'https://example.com/$w',
      ),
    );
    ai = _FixedAiSource();
  });

  tearDown(() => DictionaryService.replaceInstance(oldInstance));

  // linux 下 WebDictionaryView 走「在浏览器打开」降级，不渲染平台视图。
  // 必须在测试体内复位（invariant 校验早于 tearDown）。
  Future<void> withLinux(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  List<Override> buildOverrides(String defaultId) => [
    analyticsOverride(),
    dictionaryOverride(),
    sharedPreferencesProvider.overrideWithValue(prefs),
    dictionarySourcesProvider.overrideWithValue([web, ai]),
    dictionarySourcesByIdProvider.overrideWithValue({
      'cambridge': web,
      'ai': ai,
    }),
    resolvedDefaultSourceIdProvider.overrideWithValue(defaultId),
    dictionaryLookupContextProvider.overrideWithValue(
      const DictionaryLookupContext(
        accessToken: 'tok',
        targetLanguage: 'zh-CN',
      ),
    ),
  ];

  Widget app(String defaultId, Widget home) => ProviderScope(
    overrides: buildOverrides(defaultId),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: home,
    ),
  );

  Widget wrap({String defaultId = 'cambridge'}) => app(
    defaultId,
    Scaffold(
      body: DictionaryPanel(
        query: const DictionaryPanelQuery(word: 'run'),
        onClose: () {},
      ),
    ),
  );

  /// 经宿主面板打开（下拉超阈值关闭断言面板从树中移除，而非路由 pop）
  Future<void> pumpPanelHost(
    WidgetTester tester, {
    String defaultId = 'ai',
  }) async {
    await tester.pumpWidget(
      app(
        defaultId,
        Scaffold(
          body: DictionaryPanelHost(
            child: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => DictionaryPanelHost.of(
                    context,
                  ).show(const DictionaryPanelQuery(word: 'run')),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('网页源默认 1/2 屏高，上拉指示条放大、下拉缩小', (tester) async {
    await withLinux(() async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final sizer = find.byKey(const Key('dict_sheet_sizer'));
      final handle = find.byKey(const Key('dict_drag_handle'));
      expect(sizer, findsOneWidget);
      expect(handle, findsOneWidget);

      final screenH =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final initial = tester.getSize(sizer).height;
      // 默认约 1/2 屏高（受 SafeArea 影响略小，给足容差）
      expect(initial, closeTo(screenH / 2, 40));

      // 上拉放大
      await tester.drag(handle, const Offset(0, -200));
      await tester.pumpAndSettle();
      final enlarged = tester.getSize(sizer).height;
      expect(enlarged, greaterThan(initial + 150));

      // 下拉缩小
      await tester.drag(handle, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(tester.getSize(sizer).height, lessThan(enlarged));
    });
  });

  testWidgets('上拉不超过 95% 屏高上限', (tester) async {
    await withLinux(() async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final handle = find.byKey(const Key('dict_drag_handle'));
      final sizer = find.byKey(const Key('dict_sheet_sizer'));
      final screenH =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      // 远超上限的拖拽量
      await tester.drag(handle, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(sizer).height,
        lessThanOrEqualTo(screenH * 0.95 + 1),
      );
    });
  });

  testWidgets('AI 源默认 1/2 屏高，上拉指示条放大', (tester) async {
    await tester.pumpWidget(wrap(defaultId: 'ai'));
    await tester.pumpAndSettle();

    // 渲染的是 AI 结果（释义「奔跑」），确认走 AI 源
    expect(find.text('奔跑'), findsOneWidget);

    final sizer = find.byKey(const Key('dict_sheet_sizer'));
    final handle = find.byKey(const Key('dict_drag_handle'));
    expect(sizer, findsOneWidget);
    expect(handle, findsOneWidget);

    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final initial = tester.getSize(sizer).height;
    expect(initial, closeTo(screenH / 2, 40));

    await tester.drag(handle, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getSize(sizer).height, greaterThan(initial + 150));
  });

  testWidgets('在标题行（非指示条）区域上拉也能放大弹窗', (tester) async {
    await tester.pumpWidget(wrap(defaultId: 'ai'));
    await tester.pumpAndSettle();

    final sizer = find.byKey(const Key('dict_sheet_sizer'));
    final initial = tester.getSize(sizer).height;

    // 在标题行（header 内的非指示条区域）发起竖向拖拽
    await tester.drag(find.text('run'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getSize(sizer).height, greaterThan(initial + 150));
  });

  testWidgets('下拉到底再继续下拉关闭弹窗', (tester) async {
    await pumpPanelHost(tester);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);

    // 远超下限的下拉：缩到下限后继续下拉（overdrag）超阈值，松手关闭
    await tester.drag(
      find.byKey(const Key('dict_drag_handle')),
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
  });

  testWidgets('下拉到下限但未超 overdrag 阈值：仅缩小，不关闭', (tester) async {
    await pumpPanelHost(tester);
    final sizer = find.byKey(const Key('dict_sheet_sizer'));
    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final initial = tester.getSize(sizer).height;

    // 缩到下限附近（overdrag < 80）：弹窗仍在，高度夹在 40% 下限
    await tester.drag(
      find.byKey(const Key('dict_drag_handle')),
      Offset(0, initial - screenH * 0.4 + 40),
    );
    await tester.pumpAndSettle();
    expect(sizer, findsOneWidget);
    expect(tester.getSize(sizer).height, closeTo(screenH * 0.4, 20));
  });
}
