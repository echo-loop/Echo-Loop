/// SelectableSentenceText（可点词 + 词组选区手柄）交互测试
///
/// 组件与 DictionaryPanelHost 组合验证：点词查词、点空白不触发、
/// 选区手柄出现与拖拽扩选、面板关闭清选区、onBeforeLookup 时机。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:echo_loop/widgets/practice/selectable_sentence_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

class _MockDictionaryService extends Mock implements DictionaryService {}

/// 回显查询词的 fake 本地源（记录收到的查询）
class _EchoLocalSource implements DictionarySource {
  final List<String> queries = [];
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
  }) async {
    queries.add(request.word);
    return LocalDictResult(
      DictEntry(word: request.word, phonetic: 'x', translation: '释义'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryService oldInstance;
  late SharedPreferences prefs;
  late _EchoLocalSource source;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final mock = _MockDictionaryService();
    when(() => mock.isAvailable).thenReturn(true);
    oldInstance = DictionaryService.replaceInstance(mock);
    source = _EchoLocalSource();
  });

  tearDown(() => DictionaryService.replaceInstance(oldInstance));

  final hostKey = GlobalKey<DictionaryPanelHostState>();

  Widget wrap({
    String text = 'alpha beta gamma',
    List<SpeechTranscriptSegment>? segments,
    VoidCallback? onBeforeLookup,
    Widget Function(Widget sentence)? layout,
  }) => ProviderScope(
    overrides: [
      analyticsOverride(),
      dictionaryOverride(),
      sharedPreferencesProvider.overrideWithValue(prefs),
      dictionarySourcesProvider.overrideWithValue([source]),
      dictionarySourcesByIdProvider.overrideWithValue({'local': source}),
      resolvedDefaultSourceIdProvider.overrideWithValue('local'),
      dictionaryLookupContextProvider.overrideWithValue(
        const DictionaryLookupContext(
          accessToken: 'tok',
          targetLanguage: 'zh-CN',
        ),
      ),
    ],
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
            builder: (context) {
              final sentence = SelectableSentenceText(
                text: text,
                highlightedSegments: segments,
                origin: const DictionaryLookupOrigin(sentenceText: 'ctx'),
                onBeforeLookup: onBeforeLookup,
              );
              if (layout != null) return layout(sentence);
              return Align(alignment: Alignment.topLeft, child: sentence);
            },
          ),
        ),
      ),
    ),
  );

  /// 点击句中某个词的中心
  Future<void> tapWord(WidgetTester tester, String word) async {
    final rich = find.byType(RichText).first;
    final renderObject = tester.renderObject<RenderBox>(rich);
    // 用 RenderParagraph 的几何直接算词心：Ahem 字体等宽，按字符占比近似
    final text = 'alpha beta gamma';
    final wordStart = text.indexOf(word);
    final fraction = (wordStart + word.length / 2) / text.length;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    await tester.tapAt(topLeft + Offset(renderObject.size.width * fraction, 8));
  }

  testWidgets('点词：打开面板查询该词（剥标点交给归一化），onBeforeLookup 先触发', (tester) async {
    var beforeCalls = 0;
    await tester.pumpWidget(wrap(onBeforeLookup: () => beforeCalls++));
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    expect(beforeCalls, 1);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);
    expect(source.queries, ['beta']);
  });

  testWidgets('点词后出现左右选区手柄', (tester) async {
    await tester.pumpWidget(wrap());
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('word_handle_start')), findsOneWidget);
    expect(find.byKey(const Key('word_handle_end')), findsOneWidget);
  });

  testWidgets('拖动右手柄扩选到句尾：松手查询词组', (tester) async {
    await tester.pumpWidget(wrap());
    await tapWord(tester, 'alpha');
    await tester.pumpAndSettle();
    expect(source.queries, ['alpha']);

    // 向右远拖：吸附到最后一个词 gamma，选区 = alpha beta gamma
    await tester.drag(
      find.byKey(const Key('word_handle_end')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(source.queries.last, 'alpha beta gamma');
  });

  testWidgets('手柄交叉 clamp：右手柄拖过左侧不越界，仍为单词选区', (tester) async {
    await tester.pumpWidget(wrap());
    await tapWord(tester, 'gamma');
    await tester.pumpAndSettle();

    // 右手柄向左远拖：clamp 到不越过起始词，选区仍是 gamma
    await tester.drag(
      find.byKey(const Key('word_handle_end')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(source.queries.last, 'gamma');
  });

  testWidgets('面板开着时：点句子里另一个词切换查询（豁免放行），点句子外空白关面板', (tester) async {
    await tester.pumpWidget(wrap());
    await tapWord(tester, 'alpha');
    await tester.pumpAndSettle();
    expect(source.queries, ['alpha']);

    // 点句子里另一个词：屏障豁免放行，切换查询、面板不关
    await tapWord(tester, 'gamma');
    await tester.pumpAndSettle();
    expect(source.queries, ['alpha', 'gamma']);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);

    // 点句子外空白（正文中部）：屏障关面板并吸收点击
    await tester.tapAt(const Offset(400, 500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
    // 选区高亮/手柄一并清除
    expect(find.byKey(const Key('word_handle_start')), findsNothing);
    // 未发起新查询
    expect(source.queries, ['alpha', 'gamma']);
  });

  testWidgets('面板开着时点句子紧邻上下的下层控件：关面板并吸收，不误触发下层交互', (tester) async {
    // 复现真机反馈：句子上方一小条区域点击触发了「隐藏字幕」、解析按钮
    // 被误触发——旧实现豁免区是组件 bounds 上下外扩 36dp 的粗矩形。
    var aboveTaps = 0;
    var belowTaps = 0;
    await tester.pumpWidget(
      wrap(
        layout: (sentence) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: const Key('above_area'),
              behavior: HitTestBehavior.opaque,
              onTap: () => aboveTaps++,
              child: const SizedBox(width: 600, height: 30),
            ),
            sentence,
            GestureDetector(
              key: const Key('below_area'),
              behavior: HitTestBehavior.opaque,
              onTap: () => belowTaps++,
              child: const SizedBox(width: 600, height: 30),
            ),
          ],
        ),
      ),
    );
    // 面板关闭时下层控件正常可点（取右侧远离手柄横坐标的点，下同）
    final abovePoint = Offset(
      500,
      tester.getRect(find.byKey(const Key('above_area'))).center.dy,
    );
    await tester.tapAt(abovePoint);
    expect(aboveTaps, 1);

    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dict_sheet_sizer')), findsOneWidget);

    // 面板开着：点句子上方紧邻控件 → 屏障关面板并吸收，下层不触发
    await tester.tapAt(abovePoint);
    await tester.pumpAndSettle();
    expect(aboveTaps, 1);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);

    // 再开面板：点句子下方紧邻控件同理
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();
    final belowPoint = Offset(
      500,
      tester.getRect(find.byKey(const Key('below_area'))).center.dy,
    );
    await tester.tapAt(belowPoint);
    await tester.pumpAndSettle();
    expect(belowTaps, 0);
    expect(find.byKey(const Key('dict_sheet_sizer')), findsNothing);
  });

  testWidgets('面板关闭后选区与手柄清除', (tester) async {
    await tester.pumpWidget(wrap());
    await tapWord(tester, 'beta');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('word_handle_start')), findsOneWidget);

    hostKey.currentState!.close();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('word_handle_start')), findsNothing);
    expect(find.byKey(const Key('word_handle_end')), findsNothing);
  });

  testWidgets('评分片段染色仍生效（命中片段绿色）', (tester) async {
    await tester.pumpWidget(
      wrap(
        segments: const [
          SpeechTranscriptSegment(text: 'alpha ', isMatched: true),
          SpeechTranscriptSegment(text: 'beta gamma', isMatched: false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final spans = (rich.text as TextSpan).children!.cast<TextSpan>();
    // 首 token alpha 应为绿色
    expect(spans.first.text, 'alpha');
    expect(spans.first.style?.color, const Color(0xFF2E9B51));
    // beta 不染色
    final beta = spans.firstWhere((s) => s.text == 'beta');
    expect(beta.style?.color, isNull);
  });
}
