import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/widgets/practice/practice_normal_mode_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('中文难句操作按钮显示取消收藏与重新收藏', (tester) async {
    Future<void> pumpView({required bool isDifficult}) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: PracticeNormalModeView(
                l10n: AppLocalizations.of(context)!,
                theme: ThemeData.light(),
                isTextRevealed: true,
                sentenceText: 'A sentence.',
                isDifficult: isDifficult,
                onPeekToggle: () {},
                onUnclear: () {},
                onToggleMark: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpView(isDifficult: true);
    expect(find.widgetWithText(FilledButton, '取消收藏'), findsOneWidget);

    await pumpView(isDifficult: false);
    expect(find.widgetWithText(OutlinedButton, '重新收藏'), findsOneWidget);
  });

  testWidgets('切换收藏动画中「听不太懂」按钮不复用取消标记按钮的样式', (tester) async {
    // 回归：切换收藏时 Row 子项按位置复用 FilledButton element，动画中
    // TextStyle 从默认样式插值到 copyWith 样式会因 inherit 不一致抛异常。
    final isDifficult = ValueNotifier<bool>(false);
    addTearDown(isDifficult.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: isDifficult,
              builder: (context, difficult, _) => PracticeNormalModeView(
                l10n: AppLocalizations.of(context)!,
                theme: ThemeData.light(),
                isTextRevealed: true,
                sentenceText: 'A sentence.',
                isDifficult: difficult,
                alwaysShowToggleButton: false,
                onPeekToggle: () {},
                onUnclear: () {},
                onToggleMark: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    isDifficult.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, '取消收藏'), findsOneWidget);

    isDifficult.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 未收藏且非始终显示时，取消标记按钮隐藏，只剩「听不太懂」。
    expect(find.widgetWithText(OutlinedButton, '重新收藏'), findsNothing);
    expect(find.text('听不太懂'), findsOneWidget);
  });

  testWidgets('难句收藏入口显示中英文收藏与取消收藏文案', (tester) async {
    Future<void> pumpView({
      required Locale locale,
      required bool isDifficult,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: PracticeNormalModeView(
                l10n: AppLocalizations.of(context)!,
                theme: ThemeData.light(),
                isTextRevealed: true,
                sentenceText: 'A sentence.',
                isDifficult: isDifficult,
                onPeekToggle: () {},
                onUnclear: () {},
                onToggleMark: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpView(locale: const Locale('zh'), isDifficult: false);
    expect(find.text('收藏'), findsOneWidget);

    await pumpView(locale: const Locale('zh'), isDifficult: true);
    expect(find.text('取消收藏'), findsWidgets);

    await pumpView(locale: const Locale('en'), isDifficult: false);
    expect(find.text('Save'), findsOneWidget);

    await pumpView(locale: const Locale('en'), isDifficult: true);
    expect(find.text('Unsave'), findsOneWidget);
  });

  testWidgets('隐藏画面时耳朵、灰线与偷看入口在可利用区域整体居中', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: PracticeNormalModeView(
              l10n: AppLocalizations.of(context)!,
              theme: ThemeData.light(),
              isTextRevealed: false,
              onPeekToggle: () {},
              onUnclear: () {},
              onToggleMark: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(PracticeNormalModeView.hiddenPlaceholderKey),
      findsOneWidget,
    );
    expect(find.byKey(PracticeNormalModeView.peekLabelKey), findsOneWidget);
    expect(
      find.byKey(PracticeNormalModeView.hiddenPlaceholderLinesKey),
      findsOneWidget,
    );

    final mainRegion = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleMainRegionKey),
    );
    final contentGroup = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleContentGroupKey),
    );
    final labelRegion = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleLabelRegionKey),
    );
    final label = tester.getRect(
      find.byKey(PracticeNormalModeView.peekLabelKey),
    );
    expect(contentGroup.center.dy, closeTo(mainRegion.center.dy, 0.5));
    expect(label.center.dy, closeTo(labelRegion.center.dy, 0.5));
    expect(labelRegion.top, closeTo(mainRegion.bottom, 0.5));
  });

  testWidgets('视频画面可见时可隐藏灰线但保留居中的耳朵与偷看入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: PracticeNormalModeView(
              l10n: AppLocalizations.of(context)!,
              theme: ThemeData.light(),
              isTextRevealed: false,
              showHiddenTextPlaceholderLines: false,
              onPeekToggle: () {},
              onUnclear: () {},
              onToggleMark: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final peekLabel = tester.getRect(
      find.byKey(PracticeNormalModeView.peekLabelKey),
    );

    expect(
      find.byKey(PracticeNormalModeView.hiddenPlaceholderKey),
      findsOneWidget,
    );
    expect(
      find.byKey(PracticeNormalModeView.hiddenPlaceholderLinesKey),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(PracticeNormalModeView.hiddenPlaceholderKey),
        matching: find.byIcon(Icons.hearing),
      ),
      findsOneWidget,
    );
    final ear = tester.getRect(find.byIcon(Icons.hearing));
    final mainRegion = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleMainRegionKey),
    );
    final contentGroup = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleContentGroupKey),
    );
    final labelRegion = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleLabelRegionKey),
    );

    // 提示在耳朵下方，通过内容间距排版，不能与图标重叠。
    expect(peekLabel.top, greaterThan(ear.bottom));
    expect(contentGroup.center.dy, closeTo(mainRegion.center.dy, 0.5));
    expect(peekLabel.center.dy, closeTo(labelRegion.center.dy, 0.5));
  });

  testWidgets('视频精听显示字幕后将隐藏入口排在正文下方', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: PracticeNormalModeView(
              l10n: AppLocalizations.of(context)!,
              theme: ThemeData.light(),
              isTextRevealed: true,
              sentenceText: 'How about you? I like boxing.',
              showHiddenTextPlaceholderLines: false,
              onPeekToggle: () {},
              onUnclear: () {},
              onToggleMark: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sentence = tester.getRect(find.text('How about you? I like boxing.'));
    final hideLabel = tester.getRect(
      find.byKey(PracticeNormalModeView.peekLabelKey),
    );
    final mainRegion = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleMainRegionKey),
    );
    final labelRegion = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleLabelRegionKey),
    );

    expect(sentence.center.dy, closeTo(mainRegion.center.dy, 0.5));
    expect(hideLabel.center.dy, closeTo(labelRegion.center.dy, 0.5));
    expect(hideLabel.top, greaterThan(sentence.bottom));
  });

  testWidgets('长字幕在较小可利用区域内不溢出并可滚动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: PracticeNormalModeView(
              l10n: AppLocalizations.of(context)!,
              theme: ThemeData.light(),
              isTextRevealed: true,
              sentenceText: List.filled(
                12,
                'This is a deliberately long subtitle for layout testing.',
              ).join(' '),
              onPeekToggle: () {},
              onUnclear: () {},
              onToggleMark: () {},
              alwaysShowToggleButton: false,
              isDifficult: false,
              showBookmarkRow: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(PracticeNormalModeView.subtitleRegionKey),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('标签下方直到操作按钮前的空白区域也可以切换字幕', (tester) async {
    var toggleCount = 0;
    await tester.binding.setSurfaceSize(const Size(800, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: PracticeNormalModeView(
              l10n: AppLocalizations.of(context)!,
              theme: ThemeData.light(),
              isTextRevealed: false,
              onPeekToggle: () => toggleCount++,
              onUnclear: () {},
              onToggleMark: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trailingTapRegion = tester.getRect(
      find.byKey(PracticeNormalModeView.subtitleTrailingTapRegionKey),
    );

    await tester.tapAt(trailingTapRegion.center);
    await tester.pump();

    expect(toggleCount, 1);
  });
}
