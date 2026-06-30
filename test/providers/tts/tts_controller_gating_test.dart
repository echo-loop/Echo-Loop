import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/providers/tts/kokoro_model_provider.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart'
    show AsrModelDownloadStatus;
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

/// 受控 Kokoro notifier：注入初值，ensureDownloaded 仅计数（不做真实下载）。
class _CountingKokoroNotifier extends KokoroModelNotifier {
  _CountingKokoroNotifier(this._initial);
  final KokoroModelsState _initial;
  int ensureCount = 0;

  @override
  KokoroModelsState build() => _initial;

  @override
  Future<void> ensureDownloaded(KokoroModelVariant variant) async =>
      ensureCount++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('effectiveTtsEngine 生效门控', () {
    test('选平台 → 始终平台', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.platform,
          kokoroReady: false,
          piperReady: false,
        ),
        TtsEngineKind.platform,
      );
      expect(
        effectiveTtsEngine(
          TtsEngineKind.platform,
          kokoroReady: true,
          piperReady: true,
        ),
        TtsEngineKind.platform,
      );
    });

    test('选 Echo Loop 但未就绪 → 仍使用 Echo Loop，不回退平台', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.echoLoop,
          kokoroReady: false,
          piperReady: true,
        ),
        TtsEngineKind.echoLoop,
      );
    });

    test('选 Echo Loop 且已就绪 → Echo Loop', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.echoLoop,
          kokoroReady: true,
          piperReady: false,
        ),
        TtsEngineKind.echoLoop,
      );
    });

    test('选 Piper 但未就绪 → 仍使用 Piper，不回退平台', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.piper,
          kokoroReady: true,
          piperReady: false,
        ),
        TtsEngineKind.piper,
      );
    });

    test('选 Piper 且已就绪 → Piper', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.piper,
          kokoroReady: false,
          piperReady: true,
        ),
        TtsEngineKind.piper,
      );
    });
  });

  group('控制器后台自愈', () {
    ProviderContainer makeContainer(
      TtsSettings settings,
      _CountingKokoroNotifier notifier,
    ) {
      return ProviderContainer(
        overrides: [
          initialTtsSettingsProvider.overrideWithValue(settings),
          kokoroModelProvider.overrideWith(() => notifier),
        ],
      );
    }

    test('选 Echo Loop 但未就绪 → 控制器后台触发 ensureDownloaded', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _CountingKokoroNotifier(KokoroModelsState.initial());
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
        notifier,
      );
      addTearDown(c.dispose);

      // 读取即构建控制器 → build 内 _reconfigure 触发自愈。
      c.read(ttsControllerProvider);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.ensureCount, greaterThanOrEqualTo(1));
    });

    test('选平台 TTS → 不触发下载', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _CountingKokoroNotifier(KokoroModelsState.initial());
      final c = makeContainer(const TtsSettings(), notifier);
      addTearDown(c.dispose);

      c.read(ttsControllerProvider);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.ensureCount, 0);
    });

    test('Echo Loop 已就绪 → 不重复触发下载', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _CountingKokoroNotifier(
        const KokoroModelsState({
          KokoroModelVariant.fp32: KokoroModelState(
            downloadStatus: AsrModelDownloadStatus.downloaded,
            localSizeBytes: 1024,
          ),
        }),
      );
      final c = makeContainer(
        const TtsSettings(engine: TtsEngineKind.echoLoop),
        notifier,
      );
      addTearDown(c.dispose);

      c.read(ttsControllerProvider);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.ensureCount, 0);
    });
  });
}
