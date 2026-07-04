/// 录音权限前置弹窗测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';
import 'package:echo_loop/services/speech_permission_service.dart';
import 'package:echo_loop/widgets/speech_permission_dialog.dart';

/// 可控麦克风/语音识别权限的 fake 服务。
class _FakeService implements SpeechPermissionService {
  SpeechPracticePermissionState current;
  SpeechPracticePermissionState afterRequest;
  int requestCount = 0;
  int statusReadCount = 0;
  int openSettingsCount = 0;
  bool overrideSupported;

  _FakeService({
    required this.current,
    SpeechPracticePermissionState? afterRequest,
    this.overrideSupported = true,
  }) : afterRequest = afterRequest ?? current;

  @override
  bool get isSupported => overrideSupported;

  @override
  Future<SpeechPracticePermissionState> getStatus() async {
    statusReadCount += 1;
    return current;
  }

  @override
  Future<SpeechPracticePermissionState> request({required bool onlyMic}) async {
    requestCount += 1;
    current = afterRequest;
    return current;
  }

  @override
  Future<void> openAppSettings() async {
    openSettingsCount += 1;
  }
}

const _granted = SpeechPracticePermissionStatus.granted;
const _denied = SpeechPracticePermissionStatus.denied;
const _notDetermined = SpeechPracticePermissionStatus.notDetermined;
const _restricted = SpeechPracticePermissionStatus.restricted;

const AsrModelInfo _stubModel = AsrModelInfo(
  id: 'whisper-tiny-en-int8',
  displayName: 'Whisper Tiny.en',
  type: AsrModelType.whisper,
);

OfflineAsrSettingsState _settings({
  bool enabled = true,
  AsrBackend backend = AsrBackend.platform,
}) {
  return OfflineAsrSettingsState(
    enabled: enabled,
    backend: backend,
    downloadStatus: AsrModelDownloadStatus.downloaded,
    downloadProgress: 1.0,
    engineReady: true,
    recommendedModel: _stubModel,
  );
}

/// fake notifier — 只返回固定的初始状态。
class _FakeOfflineAsrSettingsNotifier extends OfflineAsrSettingsNotifier {
  _FakeOfflineAsrSettingsNotifier(this._initial);
  final OfflineAsrSettingsState _initial;

  @override
  OfflineAsrSettingsState build() => _initial;
}

/// 包一层 MaterialApp + ProviderScope，把 fake settings + service 注入。
Widget _wrap({
  required OfflineAsrSettingsState asr,
  required _FakeService service,
  LearningSettings learning = const LearningSettings(),
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      initialLearningSettingsProvider.overrideWithValue(learning),
      recommendedAsrModelProvider.overrideWith((ref) => _stubModel),
      offlineAsrSettingsProvider.overrideWith(
        () => _FakeOfflineAsrSettingsNotifier(asr),
      ),
      speechPermissionServiceProvider.overrideWith((ref) => service),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

/// 在 widget tree 内异步触发 ensureSpeechReadyForRecording 并捕获结果。
class _Probe extends ConsumerStatefulWidget {
  const _Probe({required this.onResult, this.subStage});
  final void Function(bool) onResult;
  final SubStageType? subStage;

  @override
  ConsumerState<_Probe> createState() => _ProbeState();
}

class _ProbeState extends ConsumerState<_Probe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = widget.subStage == null
          ? await ensureSpeechReadyForRecording(context, ref)
          : await ensureSpeechReadyForSubStage(context, ref, widget.subStage!);
      widget.onResult(ok);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  group('requiresMicForSubStage', () {
    test('录音类 subStage 返回 true', () {
      expect(requiresMicForSubStage(SubStageType.listenAndRepeat), isTrue);
      expect(requiresMicForSubStage(SubStageType.retell), isTrue);
      expect(
        requiresMicForSubStage(SubStageType.reviewDifficultPractice),
        isTrue,
      );
      expect(
        requiresMicForSubStage(SubStageType.reviewRetellParagraph),
        isTrue,
      );
      expect(requiresMicForSubStage(SubStageType.reviewRetellSummary), isTrue);
    });

    test('盲听 / 精听 返回 false', () {
      expect(requiresMicForSubStage(SubStageType.blindListen), isFalse);
      expect(requiresMicForSubStage(SubStageType.intensiveListen), isFalse);
    });
  });

  group('ensureSpeechReadyForRecording — 权限检查', () {
    testWidgets('全部 granted 时不弹窗、立即返回 true', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _granted,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('旧 ASR enabled=false 兼容态仍按基础能力开启处理', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(enabled: false),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('评分全部关闭时仅检查 mic — speech 缺失也放行', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          learning: const LearningSettings(
            listenAndRepeatRatingEnabled: false,
            retellRatingEnabled: false,
          ),
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('关闭跟读评分时进入跟读不检查 Whisper 模型', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(
            backend: AsrBackend.offline,
          ).copyWith(downloadStatus: AsrModelDownloadStatus.downloading),
          service: fake,
          learning: const LearningSettings(
            listenAndRepeatRatingEnabled: false,
            retellRatingEnabled: true,
          ),
          child: _Probe(
            subStage: SubStageType.listenAndRepeat,
            onResult: (r) => result = r,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('关闭复述评分时进入复述不检查 Whisper 模型', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(
            backend: AsrBackend.offline,
          ).copyWith(downloadStatus: AsrModelDownloadStatus.downloading),
          service: fake,
          learning: const LearningSettings(
            listenAndRepeatRatingEnabled: true,
            retellRatingEnabled: false,
          ),
          child: _Probe(
            subStage: SubStageType.retell,
            onResult: (r) => result = r,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Echo Loop（offline backend）时仅检查 mic', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(backend: AsrBackend.offline),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('platform backend + ASR 启用 → mic + speech 都需要 granted', (
      tester,
    ) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('notDetermined → 「授权」按钮触发 request', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _notDetermined,
          speech: _notDetermined,
        ),
        afterRequest: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _granted,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grant'), findsOneWidget);
      await tester.tap(find.text('Grant'));
      await tester.pumpAndSettle();

      expect(fake.requestCount, 1);
      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('notDetermined → 授权后仍缺 → 切换到「前往设置」对话框', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _notDetermined,
          speech: _notDetermined,
        ),
        afterRequest: const SpeechPracticePermissionState(
          microphone: _granted,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grant'));
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('restricted 状态展示「设备已限制」且只有关闭按钮', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _restricted,
          speech: _granted,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Device Restricted'), findsOneWidget);
      expect(find.text('Grant'), findsNothing);
      expect(find.text('Open Settings'), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('点「前往设置」调用 service.openAppSettings', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _denied,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(fake.openSettingsCount, 1);
      // 弹窗仍开着等待用户从设置回来
      expect(find.byType(AlertDialog), findsOneWidget);

      // 收尾：取消，避免测试结束时 dialog 仍挂在那
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('AppLifecycle.resumed 后权限变 granted → 弹窗自动 dismiss', (
      tester,
    ) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(
          microphone: _denied,
          speech: _denied,
        ),
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open Settings'), findsOneWidget);

      fake.current = const SpeechPracticePermissionState(
        microphone: _granted,
        speech: _granted,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('platform 不支持 → 不弹窗、toast 提示并返回 false', (tester) async {
      final fake = _FakeService(
        current: const SpeechPracticePermissionState(),
        overrideSupported: false,
      );

      bool? result;
      await tester.pumpWidget(
        _wrap(
          asr: _settings(),
          service: fake,
          child: _Probe(onResult: (r) => result = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
