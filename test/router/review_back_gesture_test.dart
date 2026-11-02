import 'dart:async';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/bookmark_sentence.dart';
import 'package:echo_loop/models/flashcard_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/learning_session/bookmark_review_provider.dart';
import 'package:echo_loop/providers/learning_session/favorite_vocabulary_review_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/router/main_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';
import '../helpers/mock_providers.dart';

class _GatedBookmarkReview extends BookmarkReview {
  final disposeGate = Completer<void>();
  int disposeCalls = 0;

  @override
  BookmarkReviewState build() => BookmarkReviewState(
    currentCard: BookmarkSentence(
      sentence: Sentence(
        index: 0,
        text: 'A sentence for the review gesture test.',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 2),
        isBookmarked: true,
      ),
      audioItemId: 'audio-1',
      audioName: 'Test audio',
      originalSentenceIndex: 0,
      memorySubjectId: 'sentence-subject-1',
    ),
    initialTotal: 1,
    remainingCount: 1,
  );

  @override
  Future<void> startCurrentCard() async {}

  @override
  Future<void> disposeSession() async {
    disposeCalls++;
    await disposeGate.future;
  }
}

class _GatedFavoriteVocabularyReview extends FavoriteVocabularyReview {
  final disposeGate = Completer<void>();
  int disposeCalls = 0;

  @override
  FavoriteVocabularyReviewState build() => FavoriteVocabularyReviewState(
    currentCard: FlashcardWordItem(
      savedWord: SavedWord(
        id: 1,
        word: 'gesture',
        memorySubjectId: 'word-subject-1',
        practiceCount: 0,
        totalStudyMs: 0,
        viewedBack: false,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        syncStatus: 0,
      ),
    ),
    initialTotal: 1,
    remainingCount: 1,
  );

  @override
  Future<void> startCurrentCard() async {}

  @override
  Future<void> disposeSession() async {
    disposeCalls++;
    await disposeGate.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('收藏句复习 iOS 右滑退出不等待异步收尾', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final review = _GatedBookmarkReview();
    addTearDown(() {
      if (!review.disposeGate.isCompleted) review.disposeGate.complete();
    });

    await pumpFullApp(
      tester,
      overrides: dedupeOverrides([
        ...fullAppRouteTestStartupOverrides(),
        bookmarkReviewProvider.overrideWith(() => review),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final router = GoRouter.of(tester.element(find.byType(MainShell)));
    router.go(AppRoutes.favorites);
    await tester.pumpAndSettle();
    unawaited(router.push<void>(AppRoutes.bookmarkReview));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPageTransition), findsOneWidget);
    await tester.flingFrom(const Offset(1, 400), const Offset(520, 400), 1000);
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.favorites);
    expect(review.disposeGate.isCompleted, isFalse);

    review.disposeGate.complete();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('收藏词汇复习 iOS 右滑退出不等待异步收尾', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final review = _GatedFavoriteVocabularyReview();
    addTearDown(() {
      if (!review.disposeGate.isCompleted) review.disposeGate.complete();
    });

    await pumpFullApp(
      tester,
      overrides: dedupeOverrides([
        ...fullAppRouteTestStartupOverrides(),
        favoriteVocabularyReviewProvider.overrideWith(() => review),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final router = GoRouter.of(tester.element(find.byType(MainShell)));
    router.go(AppRoutes.favorites);
    await tester.pumpAndSettle();
    unawaited(router.push<void>(AppRoutes.favoriteVocabularyReview));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPageTransition), findsOneWidget);
    await tester.flingFrom(const Offset(1, 400), const Offset(520, 400), 1000);
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.favorites);
    expect(review.disposeGate.isCompleted, isFalse);

    review.disposeGate.complete();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('收藏句复习路由 pop 不等待异步收尾', (tester) async {
    final review = _GatedBookmarkReview();
    addTearDown(() {
      if (!review.disposeGate.isCompleted) review.disposeGate.complete();
    });

    await pumpFullApp(
      tester,
      overrides: dedupeOverrides([
        ...fullAppRouteTestStartupOverrides(),
        bookmarkReviewProvider.overrideWith(() => review),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final router = GoRouter.of(tester.element(find.byType(MainShell)));
    router.go(AppRoutes.favorites);
    await tester.pumpAndSettle();
    unawaited(router.push<void>(AppRoutes.bookmarkReview));
    await tester.pumpAndSettle();

    router.pop();
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.favorites);
    expect(review.disposeCalls, 1);
    expect(review.disposeGate.isCompleted, isFalse);
  });

  testWidgets('收藏词汇复习路由 pop 不等待异步收尾', (tester) async {
    final review = _GatedFavoriteVocabularyReview();
    addTearDown(() {
      if (!review.disposeGate.isCompleted) review.disposeGate.complete();
    });

    await pumpFullApp(
      tester,
      overrides: dedupeOverrides([
        ...fullAppRouteTestStartupOverrides(),
        favoriteVocabularyReviewProvider.overrideWith(() => review),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final router = GoRouter.of(tester.element(find.byType(MainShell)));
    router.go(AppRoutes.favorites);
    await tester.pumpAndSettle();
    unawaited(router.push<void>(AppRoutes.favoriteVocabularyReview));
    await tester.pumpAndSettle();

    router.pop();
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.favorites);
    expect(review.disposeCalls, 1);
    expect(review.disposeGate.isCompleted, isFalse);
  });
}
