/// PdfPreviewScreen 组件测试
///
/// 注入 loader / exportService 桩与 previewBuilder 替身
/// （真 `PdfPreview` 走 method channel，测试环境不可用），验证：
/// 加载成功后的动作可用性、菜单默认全选、切换选项触发重新生成、
/// 缓存命中不重复生成、加载失败错误态与重试。
library;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/models/pdf_export/study_pdf_data.dart';
import 'package:echo_loop/screens/pdf_preview_screen.dart';
import 'package:echo_loop/widgets/common/anchored_bubble.dart';
import 'package:echo_loop/services/pdf_export/study_pdf_export_service.dart';
import 'package:echo_loop/services/pdf_export/study_pdf_loader.dart';

import '../helpers/svg_icon_finder.dart';

import '../helpers/shared/test_fixtures.dart';
import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _MockLoader extends Mock implements StudyPdfLoader {}

class _MockExportService extends Mock implements StudyPdfExportService {}

/// 最小测试文档
const _testDocument = StudyPdfDocument(
  title: 'Test Audio',
  paragraphs: [
    [StudyPdfSentence(index: 0, text: 'Hello world.')],
  ],
);

void main() {
  late _MockLoader loader;
  late _MockExportService exportService;

  setUpAll(() {
    registerFallbackValue(_testDocument);
    registerFallbackValue(
      const StudyPdfLabels(
        metaDuration: '',
        metaSentences: '',
        metaWords: '',
        appendixTitle: '',
        grammar: '',
        vocabulary: '',
        listening: '',
      ),
    );
  });

  setUp(() {
    loader = _MockLoader();
    exportService = _MockExportService();
    when(
      () => loader.load(any(), targetLanguage: any(named: 'targetLanguage')),
    ).thenAnswer((_) async => _testDocument);
    when(
      () => exportService.buildBytes(any(), labels: any(named: 'labels')),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
  });

  // [reminderShown] 默认 true：跳过首次导出提醒弹窗，聚焦预览/选项断言。
  Widget buildScreen({bool reminderShown = true}) {
    return createTestApp(
      PdfPreviewScreen(
        audioItem: createTestAudioItem(),
        loader: loader,
        exportService: exportService,
        // 预览替身：把选项位掩码渲染成文本，便于断言刷新
        previewBuilder: (context, bytes, bitmask) => Text('preview-$bitmask'),
      ),
      overrides: learningSettingsOverrides(
        pdfExportReminderShown: reminderShown,
      ),
    );
  }

  testWidgets('加载成功后显示预览，下载/分享/菜单可用', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('preview-7'), findsOneWidget);
    expect(svgIcon('assets/icon/download.svg'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.ellipsis), findsOneWidget);

    // 下载/分享按钮已启用
    final downloadButton = tester.widget<IconButton>(
      find.ancestor(
        of: svgIcon('assets/icon/download.svg'),
        matching: find.byType(IconButton),
      ),
    );
    expect(downloadButton.onPressed, isNotNull);

    verify(
      () => loader.load(any(), targetLanguage: any(named: 'targetLanguage')),
    ).called(1);
    verify(
      () => exportService.buildBytes(any(), labels: any(named: 'labels')),
    ).called(1);
  });

  testWidgets('菜单三个选项默认全选', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    final items = tester
        .widgetList<BubbleMenuRow>(find.byType(BubbleMenuRow))
        .toList();
    expect(items, hasLength(3));
    // 全选态：三行行尾都有打勾
    expect(items.every((item) => item.trailing != null), isTrue);
    expect(find.text('Translations of saved sentences'), findsOneWidget);
    expect(find.text('meanings of saved words'), findsOneWidget);
    expect(find.text('Key Sentence Analysis'), findsOneWidget);
  });

  testWidgets('取消勾选译文触发重新生成，恢复勾选命中缓存', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(find.text('preview-7'), findsOneWidget);

    // 取消勾选「译文」→ bitmask 6，重新生成（气泡菜单点选后保持打开）
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translations of saved sentences'));
    await tester.pumpAndSettle();

    expect(find.text('preview-6'), findsOneWidget);
    verify(
      () => exportService.buildBytes(any(), labels: any(named: 'labels')),
    ).called(2);

    // 恢复勾选 → bitmask 7 命中缓存，不再调用 buildBytes
    await tester.tap(find.text('Translations of saved sentences'));
    await tester.pumpAndSettle();

    expect(find.text('preview-7'), findsOneWidget);
    verifyNever(
      () => exportService.buildBytes(any(), labels: any(named: 'labels')),
    );
  });

  testWidgets('文档只加载一次，切换选项不重新加载', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Key Sentence Analysis'));
    await tester.pumpAndSettle();

    // 选项确实生效（bitmask 7→3），但文档没有重新加载
    expect(find.text('preview-3'), findsOneWidget);
    verify(
      () => loader.load(any(), targetLanguage: any(named: 'targetLanguage')),
    ).called(1);
  });

  testWidgets('加载失败显示错误态，重试后恢复', (tester) async {
    var calls = 0;
    when(
      () => loader.load(any(), targetLanguage: any(named: 'targetLanguage')),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('boom');
      return _testDocument;
    });

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // 错误态：无预览，有重试按钮
    expect(find.text('preview-7'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('preview-7'), findsOneWidget);
  });

  testWidgets('首次导出弹补充复习材料提醒，点「知道了」后进入预览', (tester) async {
    await tester.pumpWidget(buildScreen(reminderShown: false));
    // 提醒弹窗打开期间预览区是 loading 转圈（持续动画），不能 pumpAndSettle，
    // 用固定时长 pump 让 postFrame 回调 + 弹窗过场完成。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 提醒弹窗展示，预览尚未生成
    expect(find.text('The PDF is your review notes'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('preview-7'), findsNothing);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // 关闭提醒后照常加载生成预览
    expect(find.text('The PDF is your review notes'), findsNothing);
    expect(find.text('preview-7'), findsOneWidget);
  });

  testWidgets('已提醒过则不再弹出，直接进入预览', (tester) async {
    await tester.pumpWidget(buildScreen(reminderShown: true));
    await tester.pumpAndSettle();

    expect(find.text('The PDF is your review notes'), findsNothing);
    expect(find.text('preview-7'), findsOneWidget);
  });
}
