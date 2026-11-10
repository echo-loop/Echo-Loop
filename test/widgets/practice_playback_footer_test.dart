import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart';
import 'package:echo_loop/widgets/common/practice_playback_footer.dart';
import 'package:echo_loop/widgets/practice/practice_play_count_label.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('手动模式 status label 与自动模式使用相同文字样式', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            final theme = Theme.of(context);
            return Column(
              children: [
                PracticePlayCountLabel(
                  isManualMode: false,
                  playCountText: formatPracticePlayCount(
                    l10n,
                    currentCount: 1,
                    totalCount: 2,
                  ),
                  statusSuffixText: '1.0x',
                  l10n: l10n,
                  theme: theme,
                ),
                PracticePlayCountLabel(
                  isManualMode: true,
                  playCountText: formatPracticePlayCount(
                    l10n,
                    currentCount: 1,
                    totalCount: 2,
                  ),
                  statusSuffixText: '1.0x',
                  l10n: l10n,
                  theme: theme,
                ),
              ],
            );
          },
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.pump();

    final autoLabel = tester.widget<Text>(find.text('自动 · 第 1/2 遍 · 1.0x'));
    final manualLabel = tester.widget<Text>(find.text('手动 · 第 1/2 遍 · 1.0x'));

    expect(manualLabel.style, autoLabel.style);
  });

  testWidgets('手动模式单次循环也显示遍数', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => PracticePlayCountLabel(
            isManualMode: true,
            playCountText: formatPracticePlayCount(
              AppLocalizations.of(context)!,
              currentCount: 1,
              totalCount: 1,
            ),
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
          ),
        ),
        locale: const Locale('zh'),
      ),
    );

    expect(find.text('手动 · 第 1/1 遍'), findsOneWidget);
  });

  testWidgets('播放控制按钮提供 Material 悬浮按压和聚焦反馈', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        const Center(
          child: PlaybackControls(
            canGoPrev: true,
            isLast: false,
            centerIcon: PlaybackToggleIcon.play,
            onPrevious: _noop,
            onNext: _noop,
            onCenter: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    IconButton buttonFor(Finder icon) => tester.widget<IconButton>(
      find.ancestor(of: icon, matching: find.byType(IconButton)),
    );

    final previousButton = buttonFor(find.byIcon(Icons.skip_previous_rounded));
    final centerButton = buttonFor(
      find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)),
    );
    final nextButton = buttonFor(find.byIcon(Icons.skip_next_rounded));

    for (final button in [previousButton, centerButton, nextButton]) {
      expect(
        button.style?.overlayColor?.resolve({WidgetState.hovered}),
        isNotNull,
      );
      expect(
        button.style?.overlayColor?.resolve({WidgetState.pressed}),
        isNotNull,
      );
      expect(
        button.style?.overlayColor?.resolve({WidgetState.focused}),
        isNotNull,
      );
    }

    expect(centerButton, isA<IconButton>());
    expect(
      centerButton.style?.fixedSize?.resolve({}),
      const Size.square(PlaybackControls.controlButtonSize),
    );
  });

  testWidgets('禁用的上一句按钮不响应点击', (tester) async {
    var previousCalls = 0;
    await tester.pumpWidget(
      createTestApp(
        Center(
          child: PlaybackControls(
            canGoPrev: false,
            isLast: false,
            centerIcon: PlaybackToggleIcon.play,
            onPrevious: () => previousCalls += 1,
            onNext: _noop,
            onCenter: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    final previousButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.skip_previous_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(previousButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await tester.pump();
    expect(previousCalls, 0);
  });

  testWidgets('无遍数文本时底栏与有遍数标签时等高，底部留白保持一致', (tester) async {
    Future<double> footerHeight(bool showCount) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  const Spacer(),
                  PracticePlaybackFooter(
                    canGoPrev: true,
                    isLast: false,
                    centerIcon: PlaybackToggleIcon.play,
                    onPrevious: () {},
                    onNext: () {},
                    onCenter: () {},
                    isManualMode: false,
                    playCountText: showCount
                        ? formatPracticePlayCount(
                            l10n,
                            currentCount: 1,
                            totalCount: 1,
                          )
                        : null,
                    l10n: l10n,
                    theme: Theme.of(context),
                  ),
                ],
              );
            },
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(PracticePlaybackFooter)).height;
    }

    final withLabel = await footerHeight(true);
    final withoutLabel = await footerHeight(false);

    expect(withoutLabel, closeTo(withLabel, 0.5));
  });

  testWidgets('移动端学习页底部控制区完整避让系统安全区', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Column(
              children: [
                const Spacer(),
                PracticePlaybackFooter(
                  canGoPrev: true,
                  isLast: false,
                  centerIcon: PlaybackToggleIcon.play,
                  onPrevious: () {},
                  onNext: () {},
                  onCenter: () {},
                  isManualMode: false,
                  playCountText: formatPracticePlayCount(
                    l10n,
                    currentCount: 1,
                    totalCount: 1,
                  ),
                  statusSuffixText: '1.0x',
                  l10n: l10n,
                  theme: Theme.of(context),
                ),
              ],
            );
          },
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.pump();

    final labelBottom = tester
        .getRect(find.byKey(kPracticePlaybackFooterLabelKey))
        .bottom;
    final screenBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // footer 的播放按钮和 label 统一避让底部系统区域，不再只给 label 留半个 inset。
    expect(screenBottom - labelBottom, closeTo(34, 0.1));
  });

  testWidgets('普通状态下播放按钮与上一句 / 下一句中心距为 104（与随心听一致）', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestApp(
        Center(
          child: PlaybackControls(
            canGoPrev: true,
            isLast: false,
            centerIcon: PlaybackToggleIcon.play,
            onPrevious: _noop,
            onNext: _noop,
            onCenter: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    final previousCenter = tester
        .getCenter(find.byType(PlaybackNavButton).first)
        .dx;
    final playCenter = tester
        .getCenter(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)))
        .dx;
    expect(playCenter - previousCenter, 104);
  });
}

void _noop() {}
