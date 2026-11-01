import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/community_collections/widgets/community_difficulty_badge.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/screens/audio_detail_screen.dart';

void main() {
  final baseItem = AudioItem(
    id: 'audio-1',
    name: 'A Puma at Large',
    addedDate: DateTime(2026, 1, 1),
    totalDuration: 129,
    sentenceCount: 10,
    wordCount: 198,
  );

  Future<void> pumpDetail(WidgetTester tester, AudioItem item) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AudioDetailScreen(audioItem: item),
      ),
    );
  }

  testWidgets('显示音频名称与元信息', (tester) async {
    await pumpDetail(tester, baseItem);
    await tester.pumpAndSettle();

    expect(find.text('A Puma at Large'), findsOneWidget);
    expect(find.textContaining('10 sentences'), findsOneWidget);
  });

  testWidgets('完整展示长描述，不做截断', (tester) async {
    final longDescription = List.filled(
      20,
      'Zoologists confirmed the puma from tracks and fur.',
    ).join(' ');
    await pumpDetail(tester, baseItem.copyWith(description: longDescription));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(
      find.byKey(const Key('audio_detail_description')),
    );
    expect(text.data, longDescription);
    expect(text.maxLines, isNull);
  });

  testWidgets('描述为空白时显示暂无简介占位', (tester) async {
    await pumpDetail(tester, baseItem.copyWith(description: '   '));
    await tester.pumpAndSettle();

    expect(find.text('No description yet'), findsOneWidget);
  });

  testWidgets('有难度时显示难度行与徽章', (tester) async {
    await pumpDetail(tester, baseItem.copyWith(difficulty: 'B1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audio_detail_difficulty')), findsOneWidget);
    expect(find.byType(CommunityDifficultyBadge), findsOneWidget);
  });

  testWidgets('没有难度时不显示难度行', (tester) async {
    await pumpDetail(tester, baseItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audio_detail_difficulty')), findsNothing);
  });
}
