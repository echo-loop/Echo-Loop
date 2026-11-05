import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/widgets/dictionary/local_dict_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('已收录：渲染音标与释义', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LocalDictResultView(
          word: 'run',
          state: LookupLoaded(
            LocalDictResult(
              DictEntry(
                word: 'run',
                phonetic: 'rʌn',
                translation: 'v. 跑',
                collins: 3,
                examTags: ['CET4'],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('/rʌn/'), findsOneWidget);
    expect(find.text('跑'), findsOneWidget);
    expect(find.text('v.'), findsOneWidget);
    expect(find.text('CET4'), findsOneWidget);
    // 表面词形（run）与命中词一致：不显示原形回退提示
    expect(find.textContaining('base form'), findsNothing);
  });

  testWidgets('原形回退：表面词形与命中词不同时显示弱化提示', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LocalDictResultView(
          word: 'running',
          state: LookupLoaded(
            LocalDictResult(
              DictEntry(word: 'run', phonetic: 'rʌn', translation: 'v. 跑'),
            ),
          ),
        ),
      ),
    );
    // 释义仍是原形 run 的内容
    expect(find.text('/rʌn/'), findsOneWidget);
    // 弱化提示告知展示的是原形 run 的查词结果
    expect(find.textContaining('run'), findsWidgets);
    expect(find.textContaining('base form'), findsOneWidget);
  });

  testWidgets('未收录：显示提示', (tester) async {
    await tester.pumpWidget(
      _wrap(const LocalDictResultView(word: 'xyz', state: LookupNotFound())),
    );
    expect(find.text('Word not found in dictionary'), findsOneWidget);
  });

  testWidgets('查询失败：显示错误提示并可重试', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        LocalDictResultView(
          word: 'run',
          state: const LookupError('network'),
          onRetry: () => retried = true,
        ),
      ),
    );
    expect(
      find.text('Lookup failed. Check your network and try again'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('查询失败且未提供重试回调：不显示重试按钮', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LocalDictResultView(
          word: 'run',
          state: LookupError('network'),
        ),
      ),
    );
    expect(find.text('Retry'), findsNothing);
  });
}
