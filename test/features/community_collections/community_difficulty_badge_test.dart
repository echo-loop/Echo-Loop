import 'package:echo_loop/features/community_collections/models/community_collection_models.dart';
import 'package:echo_loop/features/community_collections/widgets/community_difficulty_badge.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const difficulties = CommunityDifficulty.values;

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} 主题下不同难度使用区分明显的颜色', (tester) async {
      final backgrounds = <Color>{};

      for (final difficulty in difficulties) {
        await tester.pumpWidget(
          _badgeApp(difficulty: difficulty, brightness: brightness),
        );

        final badge = tester.widget<Container>(
          find.byKey(const Key('community_difficulty_badge')),
        );
        final background = switch (badge.decoration) {
          BoxDecoration(:final color?) => color,
          _ => throw StateError('难度徽标没有设置背景颜色'),
        };
        final foreground = tester
            .widget<Text>(find.text(difficulty.code))
            .style
            ?.color;

        expect(
          backgrounds.add(background),
          isTrue,
          reason: '${difficulty.code} 应使用独立底色',
        );
        expect(foreground, isNotNull);
        expect(
          _contrastRatio(foreground ?? Colors.transparent, background),
          greaterThanOrEqualTo(4.5),
          reason: '${difficulty.code} 文字与底色应保持可读对比度',
        );
      }
    });
  }
}

Widget _badgeApp({
  required CommunityDifficulty difficulty,
  required Brightness brightness,
}) {
  final theme = brightness == Brightness.dark
      ? ThemeData.dark()
      : ThemeData.light();
  return MaterialApp(
    theme: theme,
    locale: const Locale('en'),
    supportedLocales: const [Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: CommunityDifficultyBadge(difficulty: difficulty)),
  );
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
