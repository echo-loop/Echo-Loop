/// 复述 AI 评估弹窗的展示与失败态测试。
///
/// 覆盖：评级未到达时不渲染评级词、五种要点状态与统计条、要点摘录、
/// 纠错与建议的先后顺序、空字段不占位、转录默认收起、失败态按错误码给文案并能重试。
library;

import 'dart:async';

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/retell_review_evaluation.dart';
import 'package:echo_loop/providers/retell_review_evaluation_provider.dart';
import 'package:echo_loop/services/audio_playback_service.dart';
import 'package:echo_loop/services/audio_preview_controller.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/retell/retell_review_corrections.dart';
import 'package:echo_loop/widgets/retell/retell_review_key_points.dart';
import 'package:echo_loop/widgets/retell/retell_review_rating_style.dart';
import 'package:echo_loop/widgets/retell/retell_review_report.dart';
import 'package:echo_loop/widgets/retell/retell_review_sheet.dart';
import 'package:echo_loop/widgets/retell/retell_review_transcript_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart' show PlaybackToggleIcon, playbackCenterIconKey;
import 'package:flutter_riverpod/misc.dart';
import '../../helpers/mock_providers.dart';

/// 不触碰平台的播放替身：[play] 返回可控 Future，便于分别断言播放中与播放结束两态。
class _FakePlaybackService extends AudioPlaybackService {
  final List<String> playedFiles = [];
  Completer<void>? _completer;
  int stopCalls = 0;

  @override
  Future<void> play(String filePath) {
    playedFiles.add(filePath);
    _completer = Completer<void>();
    return _completer!.future;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _finish();
  }

  @override
  Future<void> dispose() async => _finish();

  /// 模拟播放自然结束。
  void finishPlayback() => _finish();

  void _finish() {
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}

/// 直接把状态钉死，避免 widget 测试触碰真实网络与音频转码。
class _FixedReviewController extends RetellReviewEvaluationController {
  _FixedReviewController(this._fixedState);

  final RetellReviewEvaluationState _fixedState;

  @override
  RetellReviewEvaluationState build() => _fixedState;
}

void main() {
  late _FakePlaybackService playback;
  late AudioPreviewController preview;

  setUp(() {
    playback = _FakePlaybackService();
    preview = AudioPreviewController(service: playback);
  });

  tearDown(() => preview.dispose());

  Widget wrap(
    Widget child, {
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
  }) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );

  Widget report(
    RetellReviewEvaluation evaluation, {
    bool isStreaming = false,
  }) => Padding(
    padding: const EdgeInsets.all(16),
    child: RetellReviewReport(
      evaluation: evaluation,
      isStreaming: isStreaming,
      recordingPath: '/tmp/retell.m4a',
      preview: preview,
      onBeforePlayback: () async {},
    ),
  );

  testWidgets('评级未到达时显示评估中，不渲染任何评级词', (tester) async {
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(summary: 'You covered the main idea.'),
          isStreaming: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Evaluating…'), findsOneWidget);
    expect(find.text('Good'), findsNothing);
    expect(find.text('Excellent'), findsNothing);
    expect(find.text('Keep going'), findsNothing);
    // 流式未结束时提示后续还有内容。
    expect(find.text('Generating…'), findsOneWidget);
  });

  testWidgets('五种要点状态各有图标，统计条按状态计数', (tester) async {
    // 一条要点一张卡，六条要比默认测试视口高；放大视口让 ListView 全部建出来。
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            summary: 'Mostly accurate.',
            rating: RetellReviewRating.good,
            keyPoints: [
              RetellReviewKeyPoint(
                keyPoint: '练习提升流利度。',
                original: 'Practice improves fluency.',
                transcript: 'practice makes you speak better',
                status: RetellReviewKeyPointStatus.covered,
                feedback: '',
              ),
              RetellReviewKeyPoint(
                keyPoint: '反馈很重要。',
                original: 'Feedback matters.',
                transcript: 'feedback helps a lot',
                status: RetellReviewKeyPointStatus.covered,
                feedback: '',
              ),
              RetellReviewKeyPoint(
                keyPoint: '睡眠巩固记忆。',
                original: 'Sleep consolidates memory.',
                transcript: 'sleep is important',
                status: RetellReviewKeyPointStatus.partial,
                feedback: 'Only half of it was said.',
              ),
              // missed 没有对应摘录，「我说」行用占位文案顶住。
              RetellReviewKeyPoint(
                keyPoint: '分散练习胜过临时突击。',
                original: 'Spacing beats cramming.',
                transcript: '',
                status: RetellReviewKeyPointStatus.missed,
                feedback: 'Not mentioned at all.',
              ),
              RetellReviewKeyPoint(
                keyPoint: '因果关系。',
                original: 'Practice makes you fluent.',
                transcript: 'being fluent makes you practice',
                status: RetellReviewKeyPointStatus.distorted,
                feedback: 'The direction was reversed.',
              ),
              // added 原文里没有对应内容，original 合法为空。
              RetellReviewKeyPoint(
                keyPoint: '每天要练两小时。',
                original: '',
                transcript: 'you must practice two hours every day',
                status: RetellReviewKeyPointStatus.added,
                feedback: 'The original never mentions any amount of time.',
              ),
              // keyPoint 未到达的半成品条目不渲染。
              RetellReviewKeyPoint(
                keyPoint: '',
                original: '',
                transcript: '',
                status: null,
                feedback: '',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Key point coverage'), findsOneWidget);
    // 卡片一套 + 统计条一套：covered 有两张卡，其余各一张。
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.error_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNWidgets(2));
    // 统计条文案带计数。
    expect(find.text('2 Covered'), findsOneWidget);
    expect(find.text('1 Partial'), findsOneWidget);
    expect(find.text('1 Missed'), findsOneWidget);
    expect(find.text('1 Distorted'), findsOneWidget);
    expect(find.text('1 Added'), findsOneWidget);
    // 「提示」行的标签内联进正文，正文不再是独立的 Text。
    expect(find.textContaining('Only half of it was said.'), findsOneWidget);

    // 统计条与要点卡必须用同一套标记，用户才能把统计和卡片对上。
    final context = tester.element(find.byType(RetellReviewReport));
    final l10n = AppLocalizations.of(context)!;
    final tally = find.byType(RetellReviewStatusTally);
    for (final status in RetellReviewKeyPointStatus.values) {
      final visual = retellKeyPointVisual(context, l10n, status);
      final tallyRow = find
          .ancestor(
            of: find.descendant(
              of: tally,
              matching: find.textContaining(visual.label),
            ),
            matching: find.byType(Row),
          )
          .first;
      expect(
        find.descendant(of: tallyRow, matching: find.byIcon(visual.icon)),
        findsOneWidget,
        reason: '统计条 ${visual.label} 应与要点卡同图标',
      );
    }

    // 图标看不出含义，判定文案必须同时出现在卡上：五种状态各有一张卡带同名胶囊
    // （covered 两张），文字与图标同色。
    for (final status in RetellReviewKeyPointStatus.values) {
      final visual = retellKeyPointVisual(context, l10n, status);
      final chip = find.descendant(
        of: find.byType(RetellReviewKeyPointCard),
        matching: find.text(visual.label),
      );
      expect(
        chip,
        status == RetellReviewKeyPointStatus.covered
            ? findsNWidgets(2)
            : findsOneWidget,
        reason: '要点卡应带「${visual.label}」胶囊',
      );
      expect(tester.widget<Text>(chip.first).style?.color, visual.color);
    }
  });

  testWidgets('中文要点状态使用准确文案', (tester) async {
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            keyPoints: [
              RetellReviewKeyPoint(
                keyPoint: '练习提升流利度。',
                original: 'Practice improves fluency.',
                transcript: 'practice makes you fluent',
                status: RetellReviewKeyPointStatus.covered,
                feedback: '',
              ),
              RetellReviewKeyPoint(
                keyPoint: '反馈很重要。',
                original: 'Feedback matters.',
                transcript: 'feedback helps',
                status: RetellReviewKeyPointStatus.partial,
                feedback: '',
              ),
              RetellReviewKeyPoint(
                keyPoint: '因果关系。',
                original: 'Practice makes you fluent.',
                transcript: 'being fluent makes you practice',
                status: RetellReviewKeyPointStatus.distorted,
                feedback: '',
              ),
            ],
          ),
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.pump();

    expect(find.text('一致'), findsOneWidget);
    expect(find.text('片面'), findsOneWidget);
    expect(find.text('误解'), findsOneWidget);
    expect(find.text('覆盖'), findsNothing);
    expect(find.text('部分'), findsNothing);
    expect(find.text('偏差'), findsNothing);
  });

  testWidgets('要点卡分行给出要点/原文/我说/提示：摘录为空的行整行不出现', (tester) async {
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            rating: RetellReviewRating.good,
            keyPoints: [
              RetellReviewKeyPoint(
                keyPoint: '练习提升流利度。',
                original: 'Practice improves fluency.',
                transcript: 'practice makes you speak better',
                status: RetellReviewKeyPointStatus.covered,
                feedback: '',
              ),
              // missed 没说到：没有转录摘录，「我说」行整行不出现。
              RetellReviewKeyPoint(
                keyPoint: '分散练习胜过临时突击。',
                original: 'Spacing beats cramming.',
                transcript: '',
                status: RetellReviewKeyPointStatus.missed,
                feedback: 'Not mentioned at all.',
              ),
              // added 不来自原文：没有原文摘录可给，「原文」行整行不出现。
              RetellReviewKeyPoint(
                keyPoint: '每天要练两小时。',
                original: '',
                transcript: 'you must practice two hours every day',
                status: RetellReviewKeyPointStatus.added,
                feedback: 'The original never mentions any amount of time.',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    String? lineWith(String fragment) => tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.textSpan?.toPlainText() ?? widget.data ?? '')
        .firstWhere((text) => text.contains(fragment), orElse: () => '');

    // 首行胶囊是判定文案；统计条文案带计数（'1 Covered'），这里只命中卡片胶囊。
    expect(find.text('Covered'), findsOneWidget);
    // missed 那条没有转录摘录，只有另外两条有「我说」行。
    expect(find.text('You said'), findsNWidgets(2));
    expect(
      lineWith('practice makes you speak better'),
      contains('practice makes you speak better'),
    );
    expect(lineWith('练习提升流利度。'), contains('练习提升流利度。'));
    // added 没有原文摘录，只有另外两条有「原文」行。
    expect(find.text('Original'), findsNWidgets(2));
    expect(find.textContaining('Spacing beats cramming.'), findsOneWidget);
    // 有判定说明的两条各有一行「提示」。
    expect(find.text('Tip'), findsNWidgets(2));
    // 卡内不再出现「无」占位：缺哪一侧由判定胶囊说明，空行直接不占地方。
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .where(
            (widget) => (widget.textSpan?.toPlainText() ?? widget.data ?? '')
                .contains('None'),
          ),
      isEmpty,
    );
    // 卡内唯一的彩色是首行的判定（图标 + 同色胶囊）：附属行标签一律中性色，
    // 也不带图标，否则四种颜色平摊下来判定反而看不见。
    final context = tester.element(find.byType(RetellReviewReport));
    final neutral = Theme.of(context).colorScheme.onSurfaceVariant;
    Color? labelColor(String text) =>
        tester.widgetList<Text>(find.text(text)).first.style?.color;
    expect(labelColor('Original'), neutral);
    expect(labelColor('You said'), neutral);
    expect(labelColor('Tip'), neutral);
    // 卡内图标只有三张卡各自的状态图标。
    expect(
      find.descendant(
        of: find.byType(RetellReviewKeyPointCard),
        matching: find.byType(Icon),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('纠错区排在建议之前', (tester) async {
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            rating: RetellReviewRating.fair,
            suggestion: 'List three keywords before you start.',
            corrections: [
              RetellReviewCorrection(
                type: RetellReviewCorrectionType.grammar,
                transcript: "he don't know",
                correction: "he doesn't know",
                explanation: 'Third person singular takes doesn\'t.',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 逐条可操作的纠错在前，唯一一条整体建议在后。
    expect(
      tester.getTopLeft(find.text('Expression corrections')).dy,
      lessThan(tester.getTopLeft(find.text('Suggestion')).dy),
    );
  });

  testWidgets('建议与表达纠错为空时不渲染对应区块', (tester) async {
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            summary: 'Nice work.',
            rating: RetellReviewRating.perfect,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Perfect!'), findsOneWidget);
    expect(find.text('Suggestion'), findsNothing);
    expect(find.text('Expression corrections'), findsNothing);
    // 两个小节标题的图标也不该出现。
    expect(find.byIcon(Icons.tips_and_updates_rounded), findsNothing);
    expect(find.byIcon(Icons.spellcheck_rounded), findsNothing);
  });

  testWidgets('表达纠错渲染类别标签、原句与更正，建议渲染为 callout', (tester) async {
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            rating: RetellReviewRating.fair,
            suggestion: 'List three keywords before you start.',
            corrections: [
              RetellReviewCorrection(
                type: RetellReviewCorrectionType.grammar,
                transcript: "he don't know",
                correction: "he doesn't know",
                explanation: 'Third person singular takes doesn\'t.',
              ),
              // 原句未到达的半成品条目不渲染。
              RetellReviewCorrection(
                type: null,
                transcript: '',
                correction: '',
                explanation: '',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Suggestion'), findsOneWidget);
    expect(find.text('List three keywords before you start.'), findsOneWidget);
    expect(find.text('Expression corrections'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);
    // 两个小节标题各有一个语义色图标作为扫读锚点。
    expect(find.byIcon(Icons.spellcheck_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tips_and_updates_rounded), findsOneWidget);
    expect(find.text("he don't know"), findsOneWidget);
    expect(find.text("he doesn't know"), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_right_rounded), findsOneWidget);
  });

  testWidgets('只有语法和用词类别的原句划删除线', (tester) async {
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            rating: RetellReviewRating.fair,
            corrections: [
              RetellReviewCorrection(
                type: RetellReviewCorrectionType.wordChoice,
                transcript: 'open the light',
                correction: 'turn on the light',
                explanation: 'Use turn on with a light.',
              ),
              RetellReviewCorrection(
                type: RetellReviewCorrectionType.redundancy,
                transcript: 'in my own personal opinion',
                correction: 'in my opinion',
                explanation: 'Own and personal repeat the same idea.',
              ),
              // 类别未到达时不渲染标签，也不划线。
              RetellReviewCorrection(
                type: null,
                transcript: 'and then and then',
                correction: '',
                explanation: '',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    TextDecoration? decorationOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.decoration;

    expect(decorationOf('open the light'), TextDecoration.lineThrough);
    expect(decorationOf('in my own personal opinion'), TextDecoration.none);
    expect(decorationOf('and then and then'), TextDecoration.none);
    expect(find.text('Word choice'), findsOneWidget);
    expect(find.text('Wordy'), findsOneWidget);
  });

  testWidgets('播放按钮滑出屏幕再滑回来后，图标仍反映真实播放状态', (tester) async {
    // 回归：按钮曾把播放状态存在自己的 State 里，滑出视口被回收后重建时读到
    // 过期状态，播完仍停在停止图标。状态改由 controller 持有后不再随回收丢失。
    final manyKeyPoints = [
      for (var i = 0; i < 10; i++)
        RetellReviewKeyPoint(
          keyPoint: '要点 $i',
          original: 'Key point $i',
          transcript: 'what the learner said about $i',
          status: RetellReviewKeyPointStatus.covered,
          feedback: '',
        ),
    ];
    await tester.pumpWidget(
      wrap(
        report(
          RetellReviewEvaluation(
            summary: 'Long enough to scroll.',
            rating: RetellReviewRating.good,
            keyPoints: manyKeyPoints,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    // 按钮滑出视口（含 cacheExtent）后被回收。
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.stop_rounded), findsNothing);

    // 仍在播放时滑回来必须还是停止图标：证明读的是真实状态，而不是重建后的默认值。
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    // 播放在按钮不在屏期间自然结束。
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    playback.finishPlayback();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });

  testWidgets('关闭评估弹窗后停止录音试听', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showRetellReviewSheet(
                context,
                recordingPath: '/tmp/retell.m4a',
                preview: preview,
                onBeforePlayback: () async {},
                onRetry: () async {},
                onUpgrade: () async {},
                onSignIn: () async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: dedupeOverrides([
          retellReviewEvaluationProvider.overrideWith(
            () => _FixedReviewController(
              const RetellReviewEvaluationState(
                attemptKey: 'retell:a1:0',
                phase: RetellReviewEvaluationPhase.completed,
                evaluation: RetellReviewEvaluation(
                  summary: 'Nice work.',
                  rating: RetellReviewRating.good,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();
    expect(preview.isPlaying, isTrue);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(playback.stopCalls, 1);
    expect(preview.isPlaying, isFalse);
  });

  testWidgets('关闭弹窗后迟到的播放前置回调不会重新启动试听', (tester) async {
    final beforePlayback = Completer<void>();
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showRetellReviewSheet(
                context,
                recordingPath: '/tmp/retell.m4a',
                preview: preview,
                onBeforePlayback: () => beforePlayback.future,
                onRetry: () async {},
                onUpgrade: () async {},
                onSignIn: () async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: dedupeOverrides([
          retellReviewEvaluationProvider.overrideWith(
            () => _FixedReviewController(
              const RetellReviewEvaluationState(
                attemptKey: 'retell:a1:0',
                phase: RetellReviewEvaluationPhase.completed,
                evaluation: RetellReviewEvaluation(
                  summary: 'Nice work.',
                  rating: RetellReviewRating.good,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(playbackCenterIconKey(PlaybackToggleIcon.play)));
    await tester.pump();
    expect(preview.isPlaying, isFalse);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    beforePlayback.complete();
    await tester.pumpAndSettle();

    expect(playback.playedFiles, isEmpty);
  });

  testWidgets('转录排在结论与要点之间，默认露一行、点击可展开收起', (tester) async {
    // 长到必然超过一行，才有折叠可言。
    const transcript =
        'I practiced retelling the paragraph today, and I tried to keep the '
        'main ideas in the same order as the original text, although I '
        'forgot a few details near the end of the second part.';
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            transcript: transcript,
            summary: 'You covered the main idea.',
            rating: RetellReviewRating.good,
            keyPoints: [
              RetellReviewKeyPoint(
                keyPoint: '练习提升流利度。',
                original: 'Practice improves fluency.',
                transcript: 'practice makes you speak better',
                status: RetellReviewKeyPointStatus.covered,
                feedback: '',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 转录是后面每条判定的依据：排在总评之后、要点之前。
    expect(
      tester.getTopLeft(find.text('You covered the main idea.')).dy,
      lessThan(tester.getTopLeft(find.byKey(transcriptTextKey)).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(transcriptTextKey)).dy,
      lessThan(tester.getTopLeft(find.text('Key point coverage')).dy),
    );

    // 卡内不再有「本次转录」标签，正文就是全部内容。
    expect(tester.widget<Text>(find.byKey(transcriptTextKey)).data, transcript);
    expect(find.text('Transcription'), findsNothing);

    // 折叠态就能看到开头，只是截到一行。
    int? maxLinesOfTranscript() =>
        tester.widget<Text>(find.byKey(transcriptTextKey)).maxLines;
    expect(maxLinesOfTranscript(), 1);

    await tester.tap(find.byKey(transcriptTextKey));
    await tester.pumpAndSettle();
    expect(maxLinesOfTranscript(), isNull);

    // 再点收回一行。
    await tester.tap(find.byKey(transcriptTextKey));
    await tester.pumpAndSettle();
    expect(maxLinesOfTranscript(), 1);
  });

  testWidgets('转录不足一行时不给展开箭头，也不响应点击', (tester) async {
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            transcript: 'I practiced today.',
            rating: RetellReviewRating.good,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    // 转录卡整体不可点：卡片内没有任何 InkWell（播放按钮不在这张卡里）。
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.byKey(transcriptTextKey),
          matching: find.byType(Container),
        ),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('失败态按错误码给文案，点击重试触发回调', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showRetellReviewSheet(
                context,
                recordingPath: '/tmp/retell.m4a',
                preview: preview,
                onBeforePlayback: () async {},
                onRetry: () async => retried++,
                onUpgrade: () async {},
                onSignIn: () async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: dedupeOverrides([
          retellReviewEvaluationProvider.overrideWith(
            () => _FixedReviewController(
              const RetellReviewEvaluationState(
                attemptKey: 'retell:a1:0',
                phase: RetellReviewEvaluationPhase.failed,
                errorCode: 'audio_too_large',
              ),
            ),
          ),
        ]),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text('The prepared recording exceeds the 2 MB limit.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(retried, 1);
  });

  testWidgets('额度用尽给升级入口而不是重试', (tester) async {
    // 重试必然再撞同一堵墙，还白跑一次本地转码与 2MB 上传，所以这里不能给重试。
    var upgraded = 0;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showRetellReviewSheet(
                context,
                recordingPath: '/tmp/retell.m4a',
                preview: preview,
                onBeforePlayback: () async {},
                onRetry: () async {},
                onUpgrade: () async => upgraded++,
                onSignIn: () async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: dedupeOverrides([
          retellReviewEvaluationProvider.overrideWith(
            () => _FixedReviewController(
              const RetellReviewEvaluationState(
                attemptKey: 'retell:a1:0',
                phase: RetellReviewEvaluationPhase.failed,
                errorCode: 'quota_exceeded',
              ),
            ),
          ),
        ]),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text("This month's free AI retell review quota is used up"),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.text('Upgrade Now'));
    await tester.pumpAndSettle();

    expect(upgraded, 1);
  });

  testWidgets('未登录给登录入口而不是重试', (tester) async {
    var signedIn = 0;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showRetellReviewSheet(
                context,
                recordingPath: '/tmp/retell.m4a',
                preview: preview,
                onBeforePlayback: () async {},
                onRetry: () async {},
                onUpgrade: () async {},
                onSignIn: () async => signedIn++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: dedupeOverrides([
          retellReviewEvaluationProvider.overrideWith(
            () => _FixedReviewController(
              const RetellReviewEvaluationState(
                attemptKey: 'retell:a1:0',
                phase: RetellReviewEvaluationPhase.failed,
                errorCode: 'auth_required',
              ),
            ),
          ),
        ]),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to use AI retell review'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(signedIn, 1);
  });

  testWidgets('首帧到达前显示骨架而非报告', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showRetellReviewSheet(
                context,
                recordingPath: '/tmp/retell.m4a',
                preview: preview,
                onBeforePlayback: () async {},
                onRetry: () async {},
                onUpgrade: () async {},
                onSignIn: () async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: dedupeOverrides([
          retellReviewEvaluationProvider.overrideWith(
            () => _FixedReviewController(
              const RetellReviewEvaluationState(
                attemptKey: 'retell:a1:0',
                phase: RetellReviewEvaluationPhase.loading,
              ),
            ),
          ),
        ]),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.text('AI Retell Review'), findsOneWidget);
    expect(find.byType(RetellReviewReport), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('retell-review-sheet'))).height,
      tester.view.physicalSize.height / tester.view.devicePixelRatio * .8,
    );
  });

  testWidgets('转录条 / 要点卡 / 纠错卡共用同一套卡面，且不再是中灰底', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(
        report(
          const RetellReviewEvaluation(
            transcript:
                'in the traditional workplace people kept work separate',
            rating: RetellReviewRating.good,
            keyPoints: [
              RetellReviewKeyPoint(
                keyPoint: '练习提升流利度。',
                original: 'Practice improves fluency.',
                transcript: 'practice makes you speak better',
                status: RetellReviewKeyPointStatus.covered,
                feedback: '',
              ),
            ],
            corrections: [
              RetellReviewCorrection(
                type: RetellReviewCorrectionType.grammar,
                transcript: 'he go to work',
                correction: 'he goes to work',
                explanation: '第三人称单数。',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    /// 取一张卡最外层 Container 的底色（深度优先第一个即卡片本身）。
    Color? cardColor(Finder card) {
      final container = tester.widget<Container>(
        find.descendant(of: card, matching: find.byType(Container)).first,
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    final context = tester.element(find.byType(RetellReviewReport));
    final fill = retellCardFill(context);
    expect(cardColor(find.byType(RetellReviewTranscriptCard)), fill);
    expect(cardColor(find.byType(RetellReviewKeyPointCard)), fill);
    expect(cardColor(find.byType(RetellReviewCorrectionCard)), fill);
    // 防回退：满宽的中灰卡底正是这次要治的「一排大灰砖」。
    expect(fill, isNot(Theme.of(context).colorScheme.surfaceContainerHighest));
  });

  testWidgets('卡面贴近弹窗底：浅色近白，深色比 sheet 底更亮', (tester) async {
    Future<Color> fillFor(ThemeData theme) async {
      late Color fill;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              fill = retellCardFill(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return fill;
    }

    // 浅色：弹窗底是纯白，卡面只低一档，不能是中灰（后者亮度约 .78）。
    expect(
      (await fillFor(AppTheme.light())).computeLuminance(),
      greaterThan(.92),
    );

    // 深色：sheet 底是 #1E1E20，比所有 surfaceContainer* 都亮，卡面只能靠半透明白
    // 往上叠提亮，取任何 surface 角色色都会比底还暗、成一个洞。
    const sheetBlack = Color(0xFF1E1E20);
    final darkFill = await fillFor(AppTheme.dark());
    expect(
      Color.alphaBlend(darkFill, sheetBlack).computeLuminance(),
      greaterThan(sheetBlack.computeLuminance()),
    );
  });
}
