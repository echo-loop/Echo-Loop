/// TtsSettings Provider 单元测试
///
/// 覆盖：默认值、SP 同步预读、setEngine（kokoro 持久化）、setAccent 持久化、
/// languageTag / toSpeechConfig 派生、copyWith / ==、Edge 音色与默认引擎迁移。
library;

import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/tts/edge_voices.dart';
import 'package:echo_loop/services/tts/piper_model_catalog.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer(SharedPreferences prefs) {
    return ProviderContainer(
      overrides: dedupeOverrides([
        initialTtsSettingsProvider.overrideWithValue(
          TtsSettings.fromPrefsSync(prefs),
        ),
      ]),
    );
  }

  group('TtsSettings.fromPrefsSync', () {
    test('SP 缺失 → 默认 Edge 在线 TTS + 美音', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = TtsSettings.fromPrefsSync(prefs);
      expect(s.engine, TtsEngineKind.edge);
      expect(s.accent, TtsAccent.us);
      expect(s.languageTag, 'en-US');
    });

    test('SP 已写 → 同步返回保存值', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.engine: 'kokoro',
        TtsSettingsKeys.accent: TtsAccent.uk.name,
      });
      final prefs = await SharedPreferences.getInstance();
      final s = TtsSettings.fromPrefsSync(prefs);
      expect(s.accent, TtsAccent.uk);
      expect(s.languageTag, 'en-GB');
    });

    test('非法值 → 回退默认', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.engine: 'bogus',
        TtsSettingsKeys.accent: 'bogus',
      });
      final prefs = await SharedPreferences.getInstance();
      final s = TtsSettings.fromPrefsSync(prefs);
      expect(s.engine, TtsEngineKind.edge);
      expect(s.accent, TtsAccent.us);
    });

    test('Android 历史系统语音偏好迁移为 Echo Loop AI Advanced', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.engine: TtsEngineKind.platform.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateAndroidPlatformTtsPreference(prefs);

      expect(prefs.getString(TtsSettingsKeys.engine), 'kokoro');
      expect(TtsSettings.fromPrefsSync(prefs).engine, TtsEngineKind.kokoro);
    });

    test('历史 echoLoop 值迁移为 kokoro', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.engine: TtsSettingsKeys.legacyEchoLoopEngineValue,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateLegacyEchoLoopTtsPreference(prefs);

      expect(prefs.getString(TtsSettingsKeys.engine), 'kokoro');
      expect(TtsSettings.fromPrefsSync(prefs).engine, TtsEngineKind.kokoro);
    });

    test('全平台旧值迁移不会处理 platform', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.engine: TtsEngineKind.platform.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateLegacyEchoLoopTtsPreference(prefs);

      expect(
        prefs.getString(TtsSettingsKeys.engine),
        TtsEngineKind.platform.name,
      );
    });

    test(
      'Android TTS migration keeps a non-platform preference unchanged',
      () async {
        SharedPreferences.setMockInitialValues({
          TtsSettingsKeys.engine: TtsEngineKind.piper.name,
        });
        final prefs = await SharedPreferences.getInstance();

        await migrateAndroidPlatformTtsPreference(prefs);

        expect(
          prefs.getString(TtsSettingsKeys.engine),
          TtsEngineKind.piper.name,
        );
      },
    );
  });

  group('toSpeechConfig', () {
    test('英音 → languageTag en-GB', () {
      const s = TtsSettings(accent: TtsAccent.uk);
      expect(s.toSpeechConfig().languageTag, 'en-GB');
    });
  });

  group('TtsSettingsNotifier', () {
    test('build 返回注入初值', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.accent: TtsAccent.uk.name,
      });
      final prefs = await SharedPreferences.getInstance();
      final c = makeContainer(prefs);
      addTearDown(c.dispose);
      expect(c.read(ttsSettingsProvider).accent, TtsAccent.uk);
    });

    test('setAccent 写 SP + 更新 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = makeContainer(prefs);
      addTearDown(c.dispose);

      await c.read(ttsSettingsProvider.notifier).setAccent(TtsAccent.uk);
      expect(c.read(ttsSettingsProvider).accent, TtsAccent.uk);

      final saved = await SharedPreferences.getInstance();
      expect(saved.getString(TtsSettingsKeys.accent), TtsAccent.uk.name);
    });

    test('setEngine(kokoro) 以 kokoro 持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = makeContainer(prefs);
      addTearDown(c.dispose);

      await c
          .read(ttsSettingsProvider.notifier)
          .setEngine(TtsEngineKind.platform);
      await c
          .read(ttsSettingsProvider.notifier)
          .setEngine(TtsEngineKind.kokoro);
      expect(c.read(ttsSettingsProvider).engine, TtsEngineKind.kokoro);
      final saved = await SharedPreferences.getInstance();
      expect(saved.getString(TtsSettingsKeys.engine), 'kokoro');
    });

    test('setKokoroVoice 写对应口音字段 + SP；口音不匹配忽略', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = makeContainer(prefs);
      addTearDown(c.dispose);
      final notifier = c.read(ttsSettingsProvider.notifier);

      await notifier.setKokoroVoice(TtsAccent.us, 'am_adam');
      expect(c.read(ttsSettingsProvider).kokoroVoiceUs, 'am_adam');
      await notifier.setKokoroVoice(TtsAccent.uk, 'bm_lewis');
      expect(c.read(ttsSettingsProvider).kokoroVoiceUk, 'bm_lewis');

      // 美音口音传英音音色 → 忽略。
      await notifier.setKokoroVoice(TtsAccent.us, 'bm_lewis');
      expect(c.read(ttsSettingsProvider).kokoroVoiceUs, 'am_adam');

      final saved = await SharedPreferences.getInstance();
      expect(saved.getString(TtsSettingsKeys.kokoroVoiceUs), 'am_adam');
      expect(saved.getString(TtsSettingsKeys.kokoroVoiceUk), 'bm_lewis');
    });
  });

  group('Kokoro 音色 / toSpeechConfig', () {
    test('默认音色：美音 af_sarah，英音 bf_emma', () {
      const s = TtsSettings();
      expect(s.kokoroVoiceUs, 'af_sarah');
      expect(s.kokoroVoiceUk, 'bf_emma');
      expect(s.activeKokoroVoice, 'af_sarah');
      expect(
        const TtsSettings(accent: TtsAccent.uk).activeKokoroVoice,
        'bf_emma',
      );
    });

    test('kokoro 引擎 → config 带 voiceName（当前口音音色）', () {
      const s = TtsSettings(
        engine: TtsEngineKind.kokoro,
        accent: TtsAccent.uk,
        kokoroVoiceUk: 'bm_george',
      );
      expect(s.toSpeechConfig().voiceName, 'bm_george');
    });

    test('平台引擎 → config 不带 voiceName', () {
      const s = TtsSettings(engine: TtsEngineKind.platform);
      expect(s.toSpeechConfig().voiceName, isNull);
    });

    test('fromPrefsSync 非法/不匹配音色 → 回退该口音默认', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.kokoroVoiceUs: 'bm_lewis', // 英音 id 放美音槽 → 回退
        TtsSettingsKeys.kokoroVoiceUk: 'bogus',
      });
      final prefs = await SharedPreferences.getInstance();
      final s = TtsSettings.fromPrefsSync(prefs);
      expect(s.kokoroVoiceUs, 'af_sarah');
      expect(s.kokoroVoiceUk, 'bf_emma');
    });
  });

  group('Kokoro 模型变体', () {
    test('默认 fp32', () {
      expect(const TtsSettings().kokoroVariant, KokoroModelVariant.fp32);
    });

    test('kokoro → config.modelTag 为变体名；平台 → null', () {
      const fp = TtsSettings(engine: TtsEngineKind.kokoro);
      expect(fp.toSpeechConfig().modelTag, 'fp32');
      const i8 = TtsSettings(
        engine: TtsEngineKind.kokoro,
        kokoroVariant: KokoroModelVariant.int8,
      );
      expect(i8.toSpeechConfig().modelTag, 'int8');
      const plat = TtsSettings(engine: TtsEngineKind.platform);
      expect(plat.toSpeechConfig().modelTag, isNull);
    });

    test('setKokoroVariant 写 SP + 更新 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = makeContainer(prefs);
      addTearDown(c.dispose);

      await c
          .read(ttsSettingsProvider.notifier)
          .setKokoroVariant(KokoroModelVariant.int8);
      expect(
        c.read(ttsSettingsProvider).kokoroVariant,
        KokoroModelVariant.int8,
      );
      final saved = await SharedPreferences.getInstance();
      expect(
        saved.getString(TtsSettingsKeys.kokoroVariant),
        KokoroModelVariant.int8.name,
      );
    });

    test('fromPrefsSync 非法变体 → 回退 fp32', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.kokoroVariant: 'bogus',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        TtsSettings.fromPrefsSync(prefs).kokoroVariant,
        KokoroModelVariant.fp32,
      );
    });
  });

  group('Piper 音色 / toSpeechConfig', () {
    test('默认音色：美音/英音各为对应默认', () {
      const s = TtsSettings();
      expect(s.piperVoiceUs, piperDefaultVoiceUs);
      expect(s.piperVoiceUk, piperDefaultVoiceUk);
      expect(s.activePiperVoice, piperDefaultVoiceUs);
      expect(
        const TtsSettings(accent: TtsAccent.uk).activePiperVoice,
        piperDefaultVoiceUk,
      );
    });

    test('piper 引擎 → config 带 voiceName（当前口音音色）、无 modelTag', () {
      const s = TtsSettings(engine: TtsEngineKind.piper, accent: TtsAccent.us);
      expect(s.toSpeechConfig().voiceName, piperDefaultVoiceUs);
      expect(s.toSpeechConfig().modelTag, isNull);
    });

    test('setPiperVoice 写对应口音字段 + SP；口音不匹配忽略', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = makeContainer(prefs);
      addTearDown(c.dispose);
      final notifier = c.read(ttsSettingsProvider.notifier);

      final usAlt = piperVoicesByAccent(TtsAccent.us).last.id;
      final ukAlt = piperVoicesByAccent(TtsAccent.uk).last.id;

      await notifier.setPiperVoice(TtsAccent.us, usAlt);
      expect(c.read(ttsSettingsProvider).piperVoiceUs, usAlt);
      await notifier.setPiperVoice(TtsAccent.uk, ukAlt);
      expect(c.read(ttsSettingsProvider).piperVoiceUk, ukAlt);

      // 美音口音传英音音色 → 忽略。
      await notifier.setPiperVoice(TtsAccent.us, ukAlt);
      expect(c.read(ttsSettingsProvider).piperVoiceUs, usAlt);

      final saved = await SharedPreferences.getInstance();
      expect(saved.getString(TtsSettingsKeys.piperVoiceUs), usAlt);
    });

    test('fromPrefsSync 非法/不匹配音色 → 回退该口音默认', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.piperVoiceUs: piperDefaultVoiceUk, // 英音 id 放美音槽
        TtsSettingsKeys.piperVoiceUk: 'bogus',
      });
      final prefs = await SharedPreferences.getInstance();
      final s = TtsSettings.fromPrefsSync(prefs);
      expect(s.piperVoiceUs, piperDefaultVoiceUs);
      expect(s.piperVoiceUk, piperDefaultVoiceUk);
    });
  });

  group('Edge 音色 / toSpeechConfig', () {
    test('edge 引擎 → config 带当前口音音色、无 modelTag', () {
      const us = TtsSettings(engine: TtsEngineKind.edge);
      expect(us.toSpeechConfig().voiceName, edgeDefaultVoiceUs);
      expect(us.toSpeechConfig().modelTag, isNull);
      const uk = TtsSettings(engine: TtsEngineKind.edge, accent: TtsAccent.uk);
      expect(uk.toSpeechConfig().voiceName, edgeDefaultVoiceUk);
      expect(uk.toSpeechConfig().languageTag, 'en-GB');
    });

    test('setEdgeVoice 写对应口音字段 + SP；口音不匹配忽略', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = makeContainer(prefs);
      addTearDown(c.dispose);
      final notifier = c.read(ttsSettingsProvider.notifier);

      final usAlt = edgeVoicesForAccent(TtsAccent.us).last.id;
      final ukAlt = edgeVoicesForAccent(TtsAccent.uk).last.id;
      await notifier.setEdgeVoice(TtsAccent.us, usAlt);
      await notifier.setEdgeVoice(TtsAccent.uk, ukAlt);
      // 美音槽传英音音色 → 忽略。
      await notifier.setEdgeVoice(TtsAccent.us, ukAlt);

      expect(c.read(ttsSettingsProvider).edgeVoiceUs, usAlt);
      expect(c.read(ttsSettingsProvider).edgeVoiceUk, ukAlt);
      expect(prefs.getString(TtsSettingsKeys.edgeVoiceUs), usAlt);
      expect(prefs.getString(TtsSettingsKeys.edgeVoiceUk), ukAlt);
    });

    test('fromPrefsSync 非法/不匹配音色 → 回退该口音默认', () async {
      SharedPreferences.setMockInitialValues({
        TtsSettingsKeys.edgeVoiceUs: edgeDefaultVoiceUk,
        TtsSettingsKeys.edgeVoiceUk: 'bogus',
      });
      final prefs = await SharedPreferences.getInstance();
      final s = TtsSettings.fromPrefsSync(prefs);
      expect(s.edgeVoiceUs, edgeDefaultVoiceUs);
      expect(s.edgeVoiceUk, edgeDefaultVoiceUk);
    });
  });

  group('migrateDefaultTtsEngineToEdge', () {
    Future<String?> migrate(String? stored) async {
      SharedPreferences.setMockInitialValues({
        if (stored != null) TtsSettingsKeys.engine: stored,
      });
      final prefs = await SharedPreferences.getInstance();
      await migrateDefaultTtsEngineToEdge(prefs);
      return prefs.getString(TtsSettingsKeys.engine);
    }

    test('未设置偏好 → edge', () async {
      expect(await migrate(null), 'edge');
    });

    test('老用户选的本地引擎（无论模型是否已装）→ 统一切到 edge', () async {
      expect(await migrate('kokoro'), 'edge');
      expect(await migrate('piper'), 'edge');
    });

    test('iOS/macOS 显式选的平台 TTS → edge', () async {
      expect(await migrate('platform'), 'edge');
    });

    test('已是 edge → 保持不变（幂等）', () async {
      expect(await migrate('edge'), 'edge');
    });
  });

  group('copyWith / ==', () {
    test('copyWith 改口音', () {
      const s = TtsSettings();
      expect(s.copyWith(accent: TtsAccent.uk).accent, TtsAccent.uk);
    });

    test('相同字段相等', () {
      expect(
        const TtsSettings(accent: TtsAccent.uk),
        const TtsSettings(accent: TtsAccent.uk),
      );
    });
  });
}
