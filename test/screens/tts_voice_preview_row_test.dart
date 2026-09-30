import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/tts/kokoro_model_provider.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/screens/tts_settings_screen.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart'
    show AsrModelDownloadStatus, KokoroModelVariant;
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 受控 Kokoro 模型 notifier：返回注入初值，下载方法空操作。
class _ReadyKokoroNotifier extends KokoroModelNotifier {
  @override
  KokoroModelsState build() => const KokoroModelsState({
    KokoroModelVariant.fp32: KokoroModelState(
      downloadStatus: AsrModelDownloadStatus.downloaded,
      localSizeBytes: 1024,
    ),
  });
  @override
  Future<void> ensureDownloaded(KokoroModelVariant v) async {}
}

/// 假 TTS 控制器：state 固定为给定 speakingKey；试听/预热方法空操作
/// （避免触碰未初始化的 coordinator）。仅用于验证音色行据 speakingKey 显播放图标。
class _FakeTtsController extends TtsController {
  _FakeTtsController(this._key);
  final String? _key;

  @override
  TtsControllerState build() => TtsControllerState(speakingKey: _key);
  @override
  Future<void> previewVoice(voice) async {}
  @override
  Future<void> prewarmVoicePreviews() async {}
  @override
  Future<void> previewAccent(accent) async {}
  @override
  Future<void> prewarmAccentPreviews() async {}
  @override
  void cancelVoicePreviewPrewarm() {}
  @override
  Future<void> stop() async {}
}

Widget _wrap(
  String? speakingKey, {
  TtsEngineKind engine = TtsEngineKind.kokoro,
}) {
  return ProviderScope(
    overrides: [
      initialTtsSettingsProvider.overrideWithValue(TtsSettings(engine: engine)),
      kokoroModelProvider.overrideWith(_ReadyKokoroNotifier.new),
      ttsControllerProvider.overrideWith(() => _FakeTtsController(speakingKey)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: TtsSettingsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('正在试听的音色行显播放图标（volume_up），其余不显', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrap(ttsVoicePreviewKey('af_maple')));
    await tester.pumpAndSettle();

    // 打开音色弹层。
    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();

    // 仅 Maple（正在试听）行显喇叭图标。
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('无试听进行时音色弹层不显任何播放图标', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrap(null));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up), findsNothing);
  });

  testWidgets('平台引擎：正在试听的口音行显播放图标（volume_up）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _wrap(ttsAccentPreviewKey(TtsAccent.us), engine: TtsEngineKind.platform),
    );
    await tester.pumpAndSettle();

    // 仅美音（正在试听）行显喇叭图标。
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('平台引擎：无试听进行时口音行不显播放图标', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrap(null, engine: TtsEngineKind.platform));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up), findsNothing);
  });
}
