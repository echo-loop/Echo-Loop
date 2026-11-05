/// DictionaryPanelHost（非 modal 词典面板宿主）行为测试
///
/// 验证：show 打开面板 / 面板开着时 show 新词原地切换内容（不重开）/
/// close 与 closeIfOpen / 关闭按钮 / activeOwnerOf 选区清理依赖面。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

/// 按词返回固定本地释义的 fake 源
class _WordedLocalSource implements DictionarySource {
  @override
  String get id => 'local';
  @override
  IconData get icon => Icons.abc;
  @override
  bool get canBeDisabled => false;
  @override
  bool get requiresNetwork => false;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async => LocalDictResult(
    DictEntry(
      word: request.word,
      phonetic: 'x',
      translation: '释义-${request.word}',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _WordedLocalSource local;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    local = _WordedLocalSource();
  });


  final hostKey = GlobalKey<DictionaryPanelHostState>();

  /// 记录 activeOwnerOf 的探针（建立依赖，随 owner 变化重建）
  final ownerLog = <Object?>[];

  /// 正文点击计数（断言屏障吸收点击、不触发下层交互）
  var bodyTaps = 0;

  Widget wrap({bool handleBackButton = false}) => ProviderScope(
    overrides: dedupeOverrides([
      analyticsOverride(),
      dictionaryServiceOverride(),
      sharedPreferencesProvider.overrideWithValue(prefs),
      dictionarySourcesProvider.overrideWithValue([local]),
      dictionarySourcesByIdProvider.overrideWithValue({'local': local}),
      resolvedDefaultSourceIdProvider.overrideWithValue('local'),
      dictionaryLookupContextProvider.overrideWithValue(
        const DictionaryLookupContext(
          accessToken: 'tok',
          targetLanguage: 'zh-CN',
        ),
      ),
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
      theme: AppTheme.light(),
      home: Scaffold(
        body: DictionaryPanelHost(
          key: hostKey,
          handleBackButton: handleBackButton,
          child: Builder(
            builder: (context) {
              ownerLog.add(DictionaryPanelHost.activeOwnerOf(context));
              return Align(
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => bodyTaps++,
                  child: const Text('正文'),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  testWidgets('show 打开面板并渲染查词结果', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);

    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'run'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(find.text('释义-run'), findsOneWidget);
    // 正文仍在树中可见（非 modal，无遮罩变暗）
    expect(find.text('正文'), findsOneWidget);
  });

  testWidgets('点面板外：关面板并吸收点击（不触发正文交互）；关闭后正文恢复可点', (tester) async {
    bodyTaps = 0;
    await tester.pumpWidget(wrap());
    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'run'));
    await tester.pumpAndSettle();

    // 面板开着：点正文 → 屏障关面板并吸收，正文 onTap 不触发
    await tester.tap(find.text('正文'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
    expect(bodyTaps, 0);

    // 面板已关：正文恢复正常交互
    await tester.tap(find.text('正文'));
    await tester.pump();
    expect(bodyTaps, 1);
  });

  testWidgets('面板开着时 show 新词：原地切换内容，面板不重开', (tester) async {
    await tester.pumpWidget(wrap());
    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'run'));
    await tester.pumpAndSettle();
    expect(find.text('释义-run'), findsOneWidget);

    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'walk'));
    // 面板始终在树中（不经历移除-重插）
    await tester.pump();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('释义-walk'), findsOneWidget);
    expect(find.text('释义-run'), findsNothing);
  });

  testWidgets('close 播放滑出动画后移除面板；closeIfOpen 语义', (tester) async {
    await tester.pumpWidget(wrap());
    expect(hostKey.currentState!.closeIfOpen(), isFalse); // 未开时 false

    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'run'));
    await tester.pumpAndSettle();

    expect(hostKey.currentState!.isOpen, isTrue);
    expect(hostKey.currentState!.closeIfOpen(), isTrue);
    // 滑出中再次 closeIfOpen 不重复消费
    expect(hostKey.currentState!.closeIfOpen(), isFalse);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
  });

  testWidgets('closeIfOwnedBy 只关闭同一 owner 发起的面板', (tester) async {
    final owner = Object();
    final otherOwner = Object();
    await tester.pumpWidget(wrap());
    hostKey.currentState!.show(
      const DictionaryPanelQuery(word: 'run'),
      owner: owner,
    );
    await tester.pumpAndSettle();

    expect(hostKey.currentState!.isOwnedBy(owner), isTrue);
    expect(hostKey.currentState!.isOwnedBy(otherOwner), isFalse);
    expect(hostKey.currentState!.closeIfOwnedBy(otherOwner), isFalse);
    expect(hostKey.currentState!.isOpen, isTrue);
    expect(hostKey.currentState!.closeIfOwnedBy(owner), isTrue);
    await tester.pumpAndSettle();
    expect(hostKey.currentState!.isOwnedBy(owner), isFalse);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
  });

  testWidgets('openStateListener 在打开和关闭时通知', (tester) async {
    final states = <bool>[];
    await tester.pumpWidget(wrap());
    void listener() => states.add(hostKey.currentState!.isOpen);
    hostKey.currentState!.addOpenStateListener(listener);
    addTearDown(() => hostKey.currentState?.removeOpenStateListener(listener));

    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'run'));
    await tester.pumpAndSettle();
    hostKey.currentState!.close();
    await tester.pumpAndSettle();

    expect(states, containsAllInOrder([true, false]));
  });

  testWidgets('点击关闭按钮关闭面板', (tester) async {
    await tester.pumpWidget(wrap());
    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'run'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dict_panel_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
  });

  testWidgets('长词组标题使用固定字号并允许自动换行', (tester) async {
    await tester.pumpWidget(wrap());
    const phrase = 'a very long multi word expression for testing';
    hostKey.currentState!.show(const DictionaryPanelQuery(word: phrase));
    await tester.pumpAndSettle();

    final titleText = tester.widget<Text>(find.text(phrase).first);
    expect(titleText.maxLines, isNull);
    expect(titleText.softWrap, isTrue);
    expect(titleText.overflow, TextOverflow.visible);
    expect(titleText.style?.fontSize, 17);

    final fittedBox = find.ancestor(
      of: find.text(phrase).first,
      matching: find.byType(FittedBox),
    );
    expect(fittedBox, findsNothing);
  });

  testWidgets('activeOwnerOf：show 传入 owner 后子树可见，关闭后为 null', (tester) async {
    final owner = Object();
    await tester.pumpWidget(wrap());
    expect(ownerLog.last, isNull);

    hostKey.currentState!.show(
      const DictionaryPanelQuery(word: 'run'),
      owner: owner,
    );
    await tester.pumpAndSettle();
    expect(ownerLog.last, same(owner));

    hostKey.currentState!.close();
    await tester.pumpAndSettle();
    expect(ownerLog.last, isNull);
  });

  testWidgets('isPanelOpenOf：面板开着时翻页器不接受滑动，关闭后恢复', (tester) async {
    // 屏障是按区域放行的（豁免正文文本以支持连续点词），而触屏的水平拖拽不被
    // 文本消费，会穿到下层 PageView → 切句成功但面板还开着。翻页器据这个依赖面
    // 直接停用滑动，不影响文本区域的 tap / 长按 / 手柄拖拽。
    final pageController = PageController();
    addTearDown(pageController.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          analyticsOverride(),
          dictionaryServiceOverride(),
          sharedPreferencesProvider.overrideWithValue(prefs),
          dictionarySourcesProvider.overrideWithValue([local]),
          dictionarySourcesByIdProvider.overrideWithValue({'local': local}),
          resolvedDefaultSourceIdProvider.overrideWithValue('local'),
          dictionaryLookupContextProvider.overrideWithValue(
            const DictionaryLookupContext(
              accessToken: 'tok',
              targetLanguage: 'zh-CN',
            ),
          ),
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
          theme: AppTheme.light(),
          home: Scaffold(
            body: DictionaryPanelHost(
              key: hostKey,
              child: Builder(
                builder: (context) => PageView.builder(
                  controller: pageController,
                  physics: DictionaryPanelHost.isPanelOpenOf(context)
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemCount: 3,
                  itemBuilder: (_, index) => Center(child: Text('第 $index 句')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('第 0 句'), findsOneWidget);

    // 面板关闭：横滑正常切页
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(pageController.page?.round(), 1);

    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'run'));
    await tester.pumpAndSettle();

    // 面板开着：横滑不切页
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(pageController.page?.round(), 1);

    hostKey.currentState!.close();
    await tester.pumpAndSettle();

    // 关闭后恢复可滑
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(pageController.page?.round(), 2);
  });

  testWidgets('handleBackButton：面板开着时返回键先关面板，再返回才退页', (tester) async {
    await tester.pumpWidget(wrap(handleBackButton: true));
    hostKey.currentState!.show(const DictionaryPanelQuery(word: 'run'));
    await tester.pumpAndSettle();

    // 模拟返回：PopScope(canPop:false) 拦截 pop 并回调关面板
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    // 面板被关闭，页面仍在
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
    expect(find.text('正文'), findsOneWidget);
  });
}
