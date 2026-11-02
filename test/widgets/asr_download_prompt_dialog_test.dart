import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/asr_model_installation_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/asr_model_installation_gate.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/services/download/download_failure.dart';
import 'package:echo_loop/widgets/asr_download_prompt_dialog.dart';

import '../helpers/mock_providers.dart';

class _TestOfflineAsrSettingsNotifier extends OfflineAsrSettingsNotifier {
  _TestOfflineAsrSettingsNotifier(this._initialState);

  final OfflineAsrSettingsState _initialState;
  int enableCallCount = 0;
  int retryCallCount = 0;
  int cancelCallCount = 0;

  @override
  OfflineAsrSettingsState build() => _initialState;

  @override
  Future<void> enable() async {
    enableCallCount++;
    _startDownload();
  }

  @override
  Future<void> retryDownload([String? modelId]) async {
    retryCallCount++;
    _startDownload();
  }

  @override
  Future<void> cancelDownload([String? modelId]) async {
    cancelCallCount++;
    state = state.copyWith(
      downloadStatus: AsrModelDownloadStatus.notDownloaded,
      downloadProgress: 0,
      clearError: true,
    );
  }

  void _startDownload() {
    state = state.copyWith(
      enabled: true,
      downloadStatus: AsrModelDownloadStatus.downloading,
      downloadProgress: 0.4,
      clearError: true,
    );
  }

  void completeDownload({DownloadFailureKind? failure}) {
    state = state.copyWith(
      downloadStatus: failure == null
          ? AsrModelDownloadStatus.downloaded
          : AsrModelDownloadStatus.failed,
      downloadProgress: failure == null ? 1 : state.downloadProgress,
      downloadError: failure,
    );
  }
}

const _recommendedModel = AsrModelInfo(
  id: 'whisper-base-en-int8',
  displayName: 'Echo Loop AI (Balanced)',
  type: AsrModelType.whisper,
);

void main() {
  Widget createTestWidget(_TestOfflineAsrSettingsNotifier notifier) {
    return ProviderScope(
      overrides: dedupeOverrides([
        analyticsOverride(),
        initialLearningSettingsProvider.overrideWithValue(
          const LearningSettings(),
        ),
        offlineAsrSettingsProvider.overrideWith(() => notifier),
        asrModelInstallationGateProvider.overrideWithValue(
          AsrModelInstallationGate(({required shouldCommit}) async {}),
        ),
      ]),
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => FilledButton(
              onPressed: () async {
                final allowed = await ensureAsrReadyBeforeSpeechPractice(
                  context,
                  ref,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('allowed=$allowed')));
                }
              },
              child: const Text('start'),
            ),
          ),
        ),
      ),
    );
  }

  OfflineAsrSettingsState state({
    AsrModelDownloadStatus status = AsrModelDownloadStatus.notDownloaded,
    DownloadFailureKind? failure,
  }) {
    return OfflineAsrSettingsState(
      backend: AsrBackend.offline,
      recommendedModel: _recommendedModel,
      downloadStatus: status,
      downloadError: failure,
    );
  }

  test('仅评分开启的录音子阶段要求本地 ASR', () {
    expect(
      requiresAsrBeforeEnteringSubStage(SubStageType.blindListen),
      isFalse,
    );
    expect(
      requiresAsrBeforeEnteringSubStage(SubStageType.listenAndRepeat),
      isTrue,
    );
    expect(requiresAsrBeforeEnteringSubStage(SubStageType.retell), isTrue);
    expect(
      requiresAsrBeforeEnteringSubStage(
        SubStageType.retell,
        retellRatingEnabled: false,
      ),
      isFalse,
    );
  });

  testWidgets('未下载状态采用与 TTS 对应的说明、流量和设置提示', (tester) async {
    final notifier = _TestOfflineAsrSettingsNotifier(state());
    await tester.pumpWidget(createTestWidget(notifier));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Speech Recognition Model Required'), findsOneWidget);
    expect(
      find.textContaining('automatically evaluate your pronunciation'),
      findsOneWidget,
    );
    expect(find.text('Estimated download: ~90.6 MB'), findsOneWidget);
    expect(
      find.text(
        'You can also choose another speech recognition model in Settings.',
      ),
      findsOneWidget,
    );
    expect(find.text('Download model'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('下载完成仅关闭弹窗，不自动恢复本次录音', (tester) async {
    final notifier = _TestOfflineAsrSettingsNotifier(state());
    await tester.pumpWidget(createTestWidget(notifier));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download model'));
    await tester.pump();

    expect(find.text('Downloading Speech Recognition Model'), findsOneWidget);
    expect(find.text('40% complete'), findsOneWidget);

    notifier.completeDownload();
    await tester.pumpAndSettle();
    expect(find.text('allowed=false'), findsOneWidget);
    expect(notifier.enableCallCount, 1);
  });

  testWidgets('下载中可取消', (tester) async {
    final notifier = _TestOfflineAsrSettingsNotifier(
      state(status: AsrModelDownloadStatus.downloading),
    );
    await tester.pumpWidget(createTestWidget(notifier));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel Download'), findsOneWidget);
    await tester.tap(find.text('Cancel Download'));
    await tester.pumpAndSettle();
    expect(notifier.cancelCallCount, 1);
    expect(find.text('allowed=false'), findsOneWidget);
  });

  testWidgets('失败时展示对应失败文案并可重试', (tester) async {
    final failedNotifier = _TestOfflineAsrSettingsNotifier(
      state(
        status: AsrModelDownloadStatus.failed,
        failure: DownloadFailureKind.network,
      ),
    );
    await tester.pumpWidget(createTestWidget(failedNotifier));
    await tester.pump();
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(
      find.text('Speech Recognition Model Download Failed'),
      findsOneWidget,
    );
    expect(find.textContaining('The download did not finish.'), findsOneWidget);
    expect(
      find.text(
        'You can also choose another speech recognition model in Settings.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(failedNotifier.retryCallCount, 1);
  });
}
