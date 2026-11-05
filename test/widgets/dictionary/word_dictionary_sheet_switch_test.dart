/// 弹窗多源切换集成测试：默认本地 → 切到 AI → 切回本地（复用缓存）。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel.dart';
import 'package:echo_loop/widgets/dictionary/dictionary_panel_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

/// 返回固定结果的 fake 源，记录调用次数
class _FixedSource implements DictionarySource {
  @override
  final String id;
  final DictionaryLookupResult result;
  int calls = 0;
  _FixedSource(this.id, this.result);
  @override
  IconData get icon => Icons.abc;
  @override
  bool get canBeDisabled => id == 'cambridge';
  @override
  bool get requiresNetwork => id != 'local';
  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    return result;
  }
}

DictionaryEntry _aiEntry({String headword = 'run'}) => DictionaryEntry(
  headword: headword,
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
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FixedSource local;
  late _FixedSource ai;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    local = _FixedSource(
      'local',
      const LocalDictResult(
        DictEntry(word: 'run', phonetic: 'rʌn', translation: 'v. 跑'),
      ),
    );
    ai = _FixedSource('ai', AiDictResult(_aiEntry()));
  });


  Widget wrap({_FixedSource? aiSource, String word = 'run'}) {
    final aiSrc = aiSource ?? ai;
    return ProviderScope(
      overrides: dedupeOverrides([
        analyticsOverride(),
        dictionaryServiceOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        dictionarySourcesProvider.overrideWithValue([local, aiSrc]),
        dictionarySourcesByIdProvider.overrideWithValue({
          'local': local,
          'ai': aiSrc,
        }),
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
          body: DictionaryPanel(
            query: DictionaryPanelQuery(word: word),
            onClose: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('默认本地 → 切 AI → 切回本地复用缓存', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 默认本地：显示释义「跑」，切换器为 Basic Dictionary
    expect(find.text('跑'), findsOneWidget);
    expect(find.text('Basic Dictionary'), findsOneWidget);

    // 切到 AI（独立的 AI 快捷按钮）
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('奔跑'), findsOneWidget);
    expect(ai.calls, 1);

    // 切回本地：点切换器 chip 打开菜单，选 Basic Dictionary，复用缓存不重复查询
    await tester.tap(find.text('Basic Dictionary')); // 切换器 chip
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic Dictionary').last); // 菜单项
    await tester.pumpAndSettle();
    expect(find.text('跑'), findsOneWidget);
    expect(local.calls, 1); // 仍只查过一次
  });

  testWidgets('标题跨源恒为保留大小写的清洗 query，不用词形还原/headword 原形', (tester) async {
    // 查询词 "Geese"：本地源经词形还原命中原形（fake 返回 headword=run），
    // AI 源返回权威 headword "goose"——两者标题都应保持用户所选 query Geese。
    final aiGoose = _FixedSource(
      'ai',
      AiDictResult(_aiEntry(headword: 'goose')),
    );
    await tester.pumpWidget(wrap(aiSource: aiGoose, word: 'Geese'));
    await tester.pumpAndSettle();

    // 本地源：标题为保留大小写 query Geese（不显示本地词干 run），并有原形回退提示
    expect(find.text('Geese'), findsOneWidget);
    expect(find.text('run'), findsNothing);
    expect(find.textContaining('base form'), findsOneWidget);

    // 切到 AI：标题仍为 Geese，不替换成 AI headword goose
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('Geese'), findsOneWidget);
    expect(find.text('goose'), findsNothing);
  });
}
