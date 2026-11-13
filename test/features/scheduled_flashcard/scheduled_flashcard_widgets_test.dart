import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_rating.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_model_adapter.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_schedule.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_results.dart';
import 'package:echo_loop/features/scheduled_flashcard/widgets/memory_rating_bar.dart';
import 'package:echo_loop/features/scheduled_flashcard/widgets/flashcard_rating_action_bar.dart';
import 'package:echo_loop/features/scheduled_flashcard/widgets/scheduled_flashcard_scaffold.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);
  MemoryRatingPreview preview(MemoryRating rating) => MemoryRatingPreview(
    scheduleId: 's',
    revision: 0,
    rating: rating,
    reviewedAt: now,
    dueAt: now,
    interval: const Duration(days: 1),
    phase: MemorySchedulePhase.learning,
    transition: MemoryModelTransition(
      state: MemoryModelState(version: 1, values: const <String, Object?>{}),
      phase: MemorySchedulePhase.learning,
      dueAt: now,
      lastReviewedAt: now,
    ),
  );

  final previews = MemoryRatingPreviewSet(
    scheduleId: 's',
    revision: 0,
    reviewedAt: now,
    again: preview(MemoryRating.again),
    hard: preview(MemoryRating.hard),
    good: preview(MemoryRating.good),
    easy: preview(MemoryRating.easy),
  );

  testWidgets('rating bar uses two columns on narrow screens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          child: MemoryRatingBar(previews: previews, onRating: (_) {}),
        ),
      ),
    );
    expect(find.textContaining('Again'), findsOneWidget);
    expect(
      tester.getSize(find.byType(OutlinedButton).first).width,
      greaterThan(100),
    );
  });

  testWidgets('scaffold exposes progress and safe footer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduledFlashcardScaffold(
          title: 'Review',
          position: 2,
          total: 4,
          content: const Text('prompt'),
          footer: const Text('footer'),
        ),
      ),
    );
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('prompt'), findsOneWidget);
    expect(find.byType(SafeArea), findsAtLeastNWidgets(1));
  });

  testWidgets('rating actions use two lines and support a four-action layout', (
    tester,
  ) async {
    MemoryRating? selected;
    final actions = [
      const FlashcardRatingAction(
        rating: MemoryRating.again,
        emoji: '😕',
        label: 'Forgot',
      ),
      const FlashcardRatingAction(
        rating: MemoryRating.hard,
        emoji: '😓',
        label: 'Hard',
      ),
      const FlashcardRatingAction(
        rating: MemoryRating.good,
        emoji: '🙂',
        label: 'Remembered',
      ),
      const FlashcardRatingAction(
        rating: MemoryRating.easy,
        emoji: '😎',
        label: 'Easy',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          child: FlashcardRatingActionBar(
            actions: actions,
            onSelected: (action) => selected = action.rating,
          ),
        ),
      ),
    );

    expect(find.text('😕'), findsOneWidget);
    expect(find.text('Forgot'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('flashcard-rating-good')));
    expect(selected, MemoryRating.good);
  });

  testWidgets('rating actions do not inherit the system bottom inset', (
    tester,
  ) async {
    const actions = [
      FlashcardRatingAction(
        rating: MemoryRating.again,
        emoji: '😕',
        label: 'Forgot',
      ),
      FlashcardRatingAction(
        rating: MemoryRating.good,
        emoji: '🙂',
        label: 'Remembered',
      ),
      FlashcardRatingAction(
        rating: MemoryRating.easy,
        emoji: '😎',
        label: 'Easy',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 34),
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: FlashcardRatingActionBar(
                actions: actions,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final ratingBar = tester.getRect(
      find.byKey(const Key('flashcard-rating-action-bar')),
    );
    final button = tester.getRect(
      find.byKey(const Key('flashcard-rating-easy')),
    );
    expect(ratingBar.bottom - button.bottom, closeTo(0, 0.1));
  });

  testWidgets('rating actions with details fit a compact three-action footer', (
    tester,
  ) async {
    const actions = [
      FlashcardRatingAction(
        rating: MemoryRating.again,
        emoji: '😕',
        label: 'Forgot',
        detail: '8/14 17:30',
      ),
      FlashcardRatingAction(
        rating: MemoryRating.good,
        emoji: '🙂',
        label: 'Remembered',
        detail: '8/20 17:30',
      ),
      FlashcardRatingAction(
        rating: MemoryRating.easy,
        emoji: '😎',
        label: 'Easy',
        detail: '9/01 17:30',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 69,
              child: FlashcardRatingActionBar(
                actions: actions,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('8/14 17:30'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(3));
  });

  testWidgets('bookmark review rating labels follow the active locale', (
    tester,
  ) async {
    Future<void> pumpFor(Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return FlashcardRatingActionBar(
                actions: [
                  FlashcardRatingAction(
                    rating: MemoryRating.again,
                    emoji: '😕',
                    label: l10n.bookmarkReviewRatingAgain,
                  ),
                  FlashcardRatingAction(
                    rating: MemoryRating.good,
                    emoji: '🙂',
                    label: l10n.bookmarkReviewRatingGood,
                  ),
                  FlashcardRatingAction(
                    rating: MemoryRating.easy,
                    emoji: '😎',
                    label: l10n.bookmarkReviewRatingEasy,
                  ),
                ],
                onSelected: (_) {},
              );
            },
          ),
        ),
      );
    }

    await pumpFor(const Locale('zh'));
    expect(find.text('听不懂'), findsOneWidget);
    expect(find.text('听懂了'), findsOneWidget);
    expect(find.text('轻松听懂'), findsOneWidget);

    await pumpFor(const Locale('en'));
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
  });
}
