/// Echo Loop TTS（Kokoro）端到端集成测试。
///
/// 从官方 GitHub Release 下载真实 Kokoro int8 多语言模型（首次较慢，缓存到 app support 跨次复用；
/// 下载失败则跳过），跑真实 sherpa-onnx native 合成，验证：
/// 1. 合成产出非空有效 wav；
/// 2. 美音 / 英音音色产出**不同**音频——印证 Kokoro 在 macOS 能正确区分口音
///    （对照平台 TTS 在 macOS 的 synthesizeToFile 口音失效，CLAUDE.md §7.15）。
///
/// 运行方式：flutter test integration_test/kokoro_tts_test.dart -d macos
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart';
import 'package:echo_loop/services/tts/kokoro_model_catalog.dart';
import 'package:echo_loop/services/tts/kokoro_tts_engine.dart';
import 'package:echo_loop/services/tts/tts_cache_store.dart';
import 'package:echo_loop/services/tts/tts_coordinator.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';

/// 包装真实引擎，统计 synthesize 调用次数（验证缓存命中不重复合成）。
class _CountingEngine implements TtsEngine {
  _CountingEngine(this._inner);
  final TtsEngine _inner;
  int synthCount = 0;

  @override
  Future<void> initialize() => _inner.initialize();
  @override
  Future<void> applyConfig(TtsSpeechConfig config) =>
      _inner.applyConfig(config);
  @override
  Future<TtsSynthesisResult?> synthesize(
    String text, {
    required String outputDir,
    required String baseName,
    TtsSpeechConfig? config,
  }) {
    synthCount++;
    return _inner.synthesize(
      text,
      outputDir: outputDir,
      baseName: baseName,
      config: config,
    );
  }

  @override
  Future<bool> speakLive(String text) => _inner.speakLive(text);
  @override
  Future<void> stop() => _inner.stop();
  @override
  Future<void> dispose() => _inner.dispose();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late KokoroModelManager manager;
  late bool modelReady;
  late Directory outDir;

  setUpAll(() async {
    final modelRoot = Platform.environment['KOKORO_MODEL_ROOT'];
    manager = KokoroModelManager(
      spec: kokoroSpecOf(KokoroModelVariant.int8),
      modelsRootResolver: modelRoot == null ? null : () async => modelRoot,
    );
    outDir = await getTemporaryDirectory();

    modelReady = await manager.isModelDownloaded();
    if (!modelReady) {
      try {
        await manager.downloadModel(
          onProgress: (pr) => debugPrint(
            '[Kokoro Test] download ${(pr.progress * 100).toStringAsFixed(0)}%',
          ),
        );
        modelReady = await manager.isModelDownloaded();
      } catch (e) {
        debugPrint('[Kokoro Test] 模型下载失败，跳过: $e');
        modelReady = false;
      }
    }
  });

  group('KokoroTtsEngine 端到端', () {
    testWidgets('合成产出非空 wav，且美/英音音色音频不同', (tester) async {
      if (!modelReady) {
        markTestSkipped('Kokoro 模型不可用');
        return;
      }

      final engine = KokoroTtsEngine(resolvePaths: manager.kokoroConfigPaths);
      addTearDown(engine.dispose);

      const text = 'The quick brown fox jumps over the lazy dog.';

      // 美音（af_sol）。
      await engine.applyConfig(
        const TtsSpeechConfig(languageTag: 'en-US', voiceName: 'af_sol'),
      );
      final us = await engine.synthesize(
        text,
        outputDir: outDir.path,
        baseName: 'kokoro_us',
      );
      expect(us, isNotNull, reason: '美音合成应成功');
      expect(us!.format, 'wav');
      final usFile = File(us.filePath);
      expect(usFile.existsSync(), isTrue);
      expect(await usFile.length(), greaterThan(1000));
      debugPrint(
        '[Kokoro Test] US bytes=${await usFile.length()} sr=${us.sampleRate}',
      );

      // 英音（bf_vale）。
      await engine.applyConfig(
        const TtsSpeechConfig(languageTag: 'en-GB', voiceName: 'bf_vale'),
      );
      final uk = await engine.synthesize(
        text,
        outputDir: outDir.path,
        baseName: 'kokoro_uk',
      );
      expect(uk, isNotNull, reason: '英音合成应成功');
      final ukFile = File(uk!.filePath);
      expect(ukFile.existsSync(), isTrue);
      expect(await ukFile.length(), greaterThan(1000));
      debugPrint('[Kokoro Test] UK bytes=${await ukFile.length()}');

      // 美音 / 英音音频应不同（音色 sid 不同 → 输出不同）。
      final usBytes = await usFile.readAsBytes();
      final ukBytes = await ukFile.readAsBytes();
      expect(
        usBytes.length == ukBytes.length && _bytesEqual(usBytes, ukBytes),
        isFalse,
        reason: 'Kokoro 美音与英音应产出不同音频（口音生效）',
      );
    });

    testWidgets('speakLive 返回 false（始终产文件）', (tester) async {
      if (!modelReady) {
        markTestSkipped('Kokoro 模型不可用');
        return;
      }
      final engine = KokoroTtsEngine(resolvePaths: manager.kokoroConfigPaths);
      addTearDown(engine.dispose);
      expect(await engine.speakLive('hello'), isFalse);
    });

    testWidgets('中文与中英混合文本可合成', (tester) async {
      if (!modelReady) {
        markTestSkipped('Kokoro 模型不可用');
        return;
      }
      final engine = KokoroTtsEngine(resolvePaths: manager.kokoroConfigPaths);
      addTearDown(engine.dispose);
      await engine.applyConfig(
        const TtsSpeechConfig(languageTag: 'zh-CN', voiceName: 'zf_001'),
      );
      final result = await engine.synthesize(
        '你好，我正在学习 machine learning。今天很开心！',
        outputDir: outDir.path,
        baseName: 'kokoro_zh_mixed',
      );
      expect(result, isNotNull, reason: '中英混合合成应成功');
      expect(await File(result!.filePath).length(), greaterThan(1000));
      debugPrint(
        '[Kokoro Test] ZH mixed bytes=${await File(result.filePath).length()}',
      );
    });
  });

  group('统一管线端到端（文本 → 协调器 → 引擎 → 缓存 → 播放）', () {
    testWidgets('speak 构造文本：合成入缓存并播放，二次命中缓存不重复合成', (tester) async {
      if (!modelReady) {
        markTestSkipped('Kokoro 模型不可用');
        return;
      }

      // 内存 DB 提供 TtsCacheDao；缓存文件落真实 app cache 目录。
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cacheStore = TtsCacheStore(
        resolveDao: () => db.ttsCacheDao,
        resolveCacheDir: getApplicationCacheDirectory,
      );

      _CountingEngine? counting;
      final coordinator = TtsCoordinator(
        factory: (kind, config) {
          // 本测试只用 kokoro。
          final inner = KokoroTtsEngine(
            resolvePaths: manager.kokoroConfigPaths,
          );
          counting = _CountingEngine(inner);
          return counting!;
        },
        cacheStore: cacheStore,
        player: LocalAudioClipPlayer(),
      );
      addTearDown(coordinator.dispose);

      const config = TtsSpeechConfig(languageTag: 'en-US', voiceName: 'af_sol');
      await coordinator.configure(TtsEngineKind.kokoro, config);

      const text = 'Learning English with Echo Loop is really fun.';

      // 首次：未命中 → 合成 → 入库 → 播放完成。
      final played1 = await coordinator.speak(text);
      expect(played1, isTrue, reason: '首次发音应合成并播放完成');
      expect(counting!.synthCount, 1);

      // 缓存确实落库且文件存在。
      final cacheKey = cacheStore.deriveKey(
        text: text,
        engine: TtsEngineKind.kokoro,
        voiceId: config.voiceId,
        speed: config.speed,
      );
      final cachedFile = await cacheStore.lookup(cacheKey);
      expect(cachedFile, isNotNull, reason: '合成结果应入缓存');
      expect(await cachedFile!.length(), greaterThan(1000));

      // 二次：命中缓存 → 不再调用 synthesize，仍正常播放。
      final played2 = await coordinator.speak(text);
      expect(played2, isTrue, reason: '二次发音应命中缓存并播放');
      expect(counting!.synthCount, 1, reason: '命中缓存不应重复合成');
    });
  });
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 标记测试跳过（集成测试中无法用 skip 参数）。
void markTestSkipped(String reason) {
  debugPrint('SKIPPED: $reason');
}
