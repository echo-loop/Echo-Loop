import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/widgets/common/practice_playback_footer.dart';
import 'package:echo_loop/widgets/practice/practice_play_count_label.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('移动端学习页底部 label 只保留压缩后的安全区间距', (tester) async {
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
                  centerIcon: Icons.play_arrow_rounded,
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

    // 学习页共用 footer 不再叠加 label 内部 16px + footer 外部 16px；
    // 有 Home indicator 时保留约 16px 压缩安全区，避免 label 贴底重叠。
    expect(screenBottom - labelBottom, closeTo(16, 0.1));
  });
}
