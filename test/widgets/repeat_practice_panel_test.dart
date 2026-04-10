import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:fluency/widgets/common/recording_button.dart';
import 'package:fluency/widgets/common/repeat_practice_panel.dart';

void main() {
  testWidgets('英文权限提示在窄屏下可完整换行显示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
          body: Center(
            child: SizedBox(
              width: 320,
              child: Builder(
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
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Microphone or speech recognition permission is required.'),
      findsOneWidget,
    );
    expect(find.text('Go to Settings'), findsOneWidget);
  });
}
