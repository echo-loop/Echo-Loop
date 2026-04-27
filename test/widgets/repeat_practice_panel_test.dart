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
  Future<Widget> _wrap(Widget child) async {
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
      await _wrap(
        Builder(
          builder: (context) => RepeatPracticePanel(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            isInPause: true,
            showCountdown: false,
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
      await _wrap(
        Builder(
          builder: (context) => RepeatPracticePanel(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            isInPause: true,
            showCountdown: false,
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
}
