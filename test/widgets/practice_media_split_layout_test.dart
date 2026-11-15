import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/providers/practice_media_split_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/widgets/common/practice_media_split_geometry.dart';
import 'package:echo_loop/widgets/common/practice_media_split_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mediaKey = ValueKey('media');
const _contentKey = ValueKey('content');
const _divider = PracticeMediaSplitGeometry.dividerExtent;

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  Future<void> pumpLayout(
    WidgetTester tester, {
    required Size size,
    bool hasMedia = true,
    bool isMediaResizable = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          home: PracticeMediaSplitLayout(
            media: hasMedia
                ? const ColoredBox(key: _mediaKey, color: Colors.black)
                : null,
            isMediaResizable: isMediaResizable,
            videoAspectRatio: 16 / 9,
            content: const _CounterContent(key: _contentKey),
          ),
        ),
      ),
    );
  }

  testWidgets('窄窗口视频在上，宽窗口视频在左', (tester) async {
    await pumpLayout(tester, size: const Size(390, 760));
    expect(
      find.byKey(const ValueKey('practice-media-split-stacked')),
      findsOne,
    );
    expect(tester.getSize(find.byKey(_mediaKey)).width, 390);

    await pumpLayout(tester, size: const Size(1200, 800));
    expect(
      find.byKey(const ValueKey('practice-media-split-side-by-side')),
      findsOne,
    );
    // 左侧画面按视频比例贴合并垂直居中，空白处不再铺黑底。
    final mediaRect = tester.getRect(find.byKey(_mediaKey));
    expect(mediaRect.left, 0);
    expect(mediaRect.width / mediaRect.height, closeTo(16 / 9, 0.01));
    expect(mediaRect.center.dy, 400);
  });

  testWidgets('跨越布局断点时保留学习内容状态', (tester) async {
    await pumpLayout(tester, size: const Size(390, 760));
    await tester.tap(find.byKey(_contentKey));
    await tester.pump();
    expect(find.text('1'), findsOne);

    await pumpLayout(tester, size: const Size(1200, 800));
    expect(find.text('1'), findsOne);
  });

  testWidgets('上下布局拖动分隔条调整视频高度并记住比例', (tester) async {
    await pumpLayout(tester, size: const Size(390, 760));
    final before = tester.getSize(find.byKey(_mediaKey)).height;

    await tester.drag(
      find.byKey(const ValueKey('practice-media-split-divider')),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();

    final after = tester.getSize(find.byKey(_mediaKey)).height;
    expect(after, lessThan(before));
    expect(
      preferences.getDouble(PracticeMediaSplitNotifier.stackedStorageKey),
      closeTo(after / (760 - _divider), 0.001),
    );
  });

  testWidgets('左右布局拖动分隔条调整视频宽度，双击恢复默认', (tester) async {
    await pumpLayout(tester, size: const Size(1200, 800));
    final defaultWidth = tester.getSize(find.byKey(_mediaKey)).width;

    await tester.drag(
      find.byKey(const ValueKey('practice-media-split-divider')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_mediaKey)).width, lessThan(defaultWidth));
    expect(
      preferences.getDouble(PracticeMediaSplitNotifier.sideBySideStorageKey),
      isNotNull,
    );

    final divider = find.byKey(const ValueKey('practice-media-split-divider'));
    await tester.tap(divider);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(divider);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_mediaKey)).width, defaultWidth);
    expect(
      preferences.containsKey(PracticeMediaSplitNotifier.sideBySideStorageKey),
      isFalse,
    );
  });

  // 回归：拖到上限后再次拖动比例不变，不应重复写入偏好（日志曾出现连续相同的保存）。
  testWidgets('拖到上限后再次拖动不重复保存相同比例', (tester) async {
    await pumpLayout(tester, size: const Size(1200, 800));
    final divider = find.byKey(const ValueKey('practice-media-split-divider'));
    int saveCount() => AppLogger.instance.entries
        .where(
          (entry) =>
              entry.tag == 'PracticeMediaLayout' &&
              entry.message.startsWith('保存视频尺寸'),
        )
        .length;
    final before = saveCount();

    await tester.drag(divider, const Offset(600, 0));
    await tester.pumpAndSettle();
    final maxWidth = tester.getSize(find.byKey(_mediaKey)).width;
    await tester.drag(divider, const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(_mediaKey)).width, maxWidth);
    expect(saveCount() - before, 1);
  });

  testWidgets('视频隐藏时不显示分隔条，内容占满剩余空间', (tester) async {
    await pumpLayout(
      tester,
      size: const Size(1200, 800),
      isMediaResizable: false,
    );
    expect(
      find.byKey(const ValueKey('practice-media-split-divider')),
      findsNothing,
    );
    expect(tester.getSize(find.byKey(_contentKey)).width, 1200);
  });

  testWidgets('纯音频任务只显示学习内容', (tester) async {
    await pumpLayout(tester, size: const Size(390, 760), hasMedia: false);
    expect(find.byKey(_mediaKey), findsNothing);
    expect(tester.getSize(find.byKey(_contentKey)), const Size(390, 760));
  });
}

/// 点击计数，用于验证跨布局移动后 State 未被重建。
class _CounterContent extends StatefulWidget {
  const _CounterContent({super.key});

  @override
  State<_CounterContent> createState() => _CounterContentState();
}

class _CounterContentState extends State<_CounterContent> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _count++),
      child: Center(child: Text('$_count')),
    );
  }
}
