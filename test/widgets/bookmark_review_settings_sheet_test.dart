import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/favorite_review_settings_provider.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/bookmark_review/bookmark_review_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget buildSheet(
    ProviderContainer container,
    FavoriteReviewSettingsTask task,
  ) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Scaffold(body: BookmarkReviewSettingsSheet(task: task)),
    ),
  );

  Widget buildModalHost(ProviderContainer container) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open-bookmark-review-settings'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  constraints: const BoxConstraints(maxHeight: 400),
                  builder: (_) => const BookmarkReviewSettingsSheet(
                    task: FavoriteReviewSettingsTask.favorites,
                  ),
                ),
                child: const Text('打开设置'),
              ),
            ),
          ),
        ),
      );

  testWidgets('从收藏句入口打开时，句子专属设置默认展开', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      buildSheet(container, FavoriteReviewSettingsTask.sentence),
    );
    await tester.pumpAndSettle();

    expect(find.text('自动显示 AI 讲解', skipOffstage: false), findsOneWidget);
    expect(find.text('正面显示词汇'), findsNothing);

    final vocabularySection = find.byKey(
      const Key('favorite-review-settings-vocabulary-section'),
    );
    await tester.ensureVisible(vocabularySection);
    await tester.tap(vocabularySection);
    await tester.pumpAndSettle();

    expect(find.text('正面显示词汇', skipOffstage: false), findsOneWidget);
  });

  testWidgets('词汇专属开关写入共用复习设置', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      buildSheet(container, FavoriteReviewSettingsTask.vocabulary),
    );
    await tester.pumpAndSettle();

    final showVocabularySwitch = find.descendant(
      of: find.byKey(const Key('favorite-review-show-vocabulary-on-front')),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(showVocabularySwitch);
    await tester.tap(showVocabularySwitch);
    await tester.pump();

    expect(
      container.read(favoriteReviewSettingsProvider).showVocabularyOnFront,
      isTrue,
    );
  });

  testWidgets('单词释义开关写入共用复习设置', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      buildSheet(container, FavoriteReviewSettingsTask.vocabulary),
    );
    await tester.pumpAndSettle();

    final showDefinitionSwitch = find.descendant(
      of: find.byKey(
        const Key('favorite-review-show-word-definition-on-front'),
      ),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(showDefinitionSwitch);
    await tester.tap(showDefinitionSwitch);
    await tester.pump();

    expect(
      container.read(favoriteReviewSettingsProvider).showWordDefinitionOnFront,
      isTrue,
    );
  });

  testWidgets('两个专属设置都展开时，固定关闭按钮仍可关闭弹窗', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(buildModalHost(container));
    await tester.tap(find.byKey(const Key('open-bookmark-review-settings')));
    await tester.pumpAndSettle();

    final sentenceSection = find.byKey(
      const Key('favorite-review-settings-sentence-section'),
    );
    await tester.ensureVisible(sentenceSection);
    await tester.tap(sentenceSection);
    await tester.pumpAndSettle();

    final vocabularySection = find.byKey(
      const Key('favorite-review-settings-vocabulary-section'),
    );
    await tester.ensureVisible(vocabularySection);
    await tester.tap(vocabularySection);
    await tester.pumpAndSettle();

    final closeButton = find.byKey(const Key('bookmark-review-settings-close'));
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(closeButton, findsNothing);
  });

  testWidgets('内容滚动后，固定关闭按钮仍可关闭弹窗', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(360, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildModalHost(container));
    await tester.tap(find.byKey(const Key('open-bookmark-review-settings')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();

    final closeButton = find.byKey(const Key('bookmark-review-settings-close'));
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(closeButton, findsNothing);
  });
}
