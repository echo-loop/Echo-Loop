import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/recording_button.dart';
import 'package:echo_loop/widgets/common/repeat_practice_panel.dart';

/// 验证 panel 不再承担权限引导职责（已交给入口前置弹窗）。
///
/// 关键回归：
/// - `permissionDenied` 状态下不再显示「前往设置」按钮（按钮槽位仍展示录音按钮）
/// - 兜底场景：若上层仍把 `errorMessage` 传进来，文案以通用错误形式显示
void main() {
  Future<Widget> wrap(Widget child) async {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    );
  }

  testWidgets('permissionDenied 状态不再显示「前往设置」按钮', (tester) async {
    await tester.pumpWidget(
      await wrap(
        Builder(
          builder: (context) => RepeatPracticePanel(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            isInPause: true,
            recordingMode: RecordingButtonMode.idle,
            currentAttempt: const SpeechPracticeAttempt(
              promptId: 'attempt-1',
              status: SpeechPracticeAttemptStatus.permissionDenied,
            ),
            onRecordTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 「前往设置」入口已迁移至入口前置弹窗；panel 内不再出现。
    expect(find.text('Go to Settings'), findsNothing);
    // 录音按钮仍然存在（点击会重新进入权限流程）。
    expect(find.byType(RecordingButton), findsOneWidget);
  });

  testWidgets('errorMessage 兜底走通用错误状态文字', (tester) async {
    const message = 'Microphone permission was denied';
    await tester.pumpWidget(
      await wrap(
        Builder(
          builder: (context) => RepeatPracticePanel(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            isInPause: true,
            recordingMode: RecordingButtonMode.idle,
            currentAttempt: const SpeechPracticeAttempt(
              promptId: 'attempt-1',
              status: SpeechPracticeAttemptStatus.permissionDenied,
              errorMessage: message,
            ),
            onRecordTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.text('Go to Settings'), findsNothing);
  });

  testWidgets('仅显式启用时在录音 badge 生命周期内显示 AI 评估按钮', (tester) async {
    const attempt = SpeechPracticeAttempt(
      promptId: 'retell:a1:0',
      filePath: '/tmp/retell.m4a',
      status: SpeechPracticeAttemptStatus.passed,
      score: .8,
    );
    await tester.pumpWidget(
      await wrap(
        Builder(
          builder: (context) => RepeatPracticePanel(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            isInPause: true,
            currentAttempt: attempt,
            onRecordTap: () {},
            showAiReviewButton: true,
            onAiReviewTap: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('retell_ai_review_button')), findsOneWidget);
    expect(find.text('AI review'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });

  testWidgets('AI 评估加载时仍保留可识别的胶囊标签', (tester) async {
    const attempt = SpeechPracticeAttempt(
      promptId: 'retell:a1:0',
      filePath: '/tmp/retell.m4a',
      status: SpeechPracticeAttemptStatus.passed,
      score: .8,
    );
    await tester.pumpWidget(
      await wrap(
        Builder(
          builder: (context) => RepeatPracticePanel(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            isInPause: true,
            currentAttempt: attempt,
            onRecordTap: () {},
            showAiReviewButton: true,
            isAiReviewLoading: true,
            onAiReviewTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('AI review'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('只要有录音就显示 badge，评分失败时降级为录音', (tester) async {
    const attempt = SpeechPracticeAttempt(
      promptId: 'attempt-1',
      filePath: '/tmp/attempt.m4a',
      status: SpeechPracticeAttemptStatus.noEnglishDetected,
    );
    await tester.pumpWidget(
      await wrap(
        Builder(
          builder: (context) => RepeatPracticePanel(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            isInPause: true,
            currentAttempt: attempt,
            onRecordTap: () {},
            showRatingBadge: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recording'), findsOneWidget);
  });

  testWidgets('关闭评分时有录音的成功结果也降级为录音 badge', (tester) async {
    const attempt = SpeechPracticeAttempt(
      promptId: 'attempt-1',
      filePath: '/tmp/attempt.m4a',
      status: SpeechPracticeAttemptStatus.passed,
      score: .9,
    );
    await tester.pumpWidget(
      await wrap(
        Builder(
          builder: (context) => RepeatPracticePanel(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            isInPause: true,
            currentAttempt: attempt,
            onRecordTap: () {},
            showRatingBadge: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recording'), findsOneWidget);
  });
}
