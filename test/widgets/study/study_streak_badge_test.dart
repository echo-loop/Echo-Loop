import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/widgets/study/study_streak_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('badge 使用 13 dp 字号，传入回调时可点击', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Center(
            child: StudyStreakBadge(streak: 5, onTap: () => tapCount++),
          ),
        ),
      ),
    );

    final badge = find.byType(StudyStreakBadge);
    expect(tester.getSize(badge).height, 33);
    expect(tester.widget<Text>(find.text('5d streak')).style!.fontSize, 13);
    await tester.tap(badge);
    expect(tapCount, 1);
  });

  testWidgets('未传回调时 badge 不可点击', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Center(child: const StudyStreakBadge(streak: 5))),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(StudyStreakBadge),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });
}
