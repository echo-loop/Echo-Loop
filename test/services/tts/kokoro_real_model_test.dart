import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/tts/kokoro_model_catalog.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart';
import 'package:echo_loop/services/tts/kokoro_tts_engine.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

void main() {
  final modelRoot = Platform.environment['KOKORO_MODEL_ROOT'];

  test(
    '真实 Kokoro int8 多语言模型可合成中英混合音频',
    () async {
      final manager = KokoroModelManager(
        spec: kokoroSpecOf(KokoroModelVariant.int8),
        modelsRootResolver: () async => modelRoot!,
      );
      addTearDown(manager.dispose);
      expect(await manager.isModelDownloaded(), isTrue);

      final engine = KokoroTtsEngine(resolvePaths: manager.kokoroConfigPaths);
      addTearDown(engine.dispose);
      await engine.applyConfig(
        const TtsSpeechConfig(
          languageTag: 'zh-CN',
          voiceName: 'zf_001',
          speed: 1.2,
        ),
      );
      final outDir = await Directory.systemTemp.createTemp(
        'kokoro-real-model-test',
      );
      addTearDown(() async {
        if (await outDir.exists()) await outDir.delete(recursive: true);
      });
      final result = await engine.synthesize(
        '你好，我正在学习 machine learning。今天很开心！',
        outputDir: outDir.path,
        baseName: 'real_zh_mixed',
      );
      expect(result, isNotNull);
      expect(result!.sampleRate, greaterThan(0));
      expect(await File(result.filePath).length(), greaterThan(1000));
    },
    skip: modelRoot == null
        ? 'Set KOKORO_MODEL_ROOT to run real-model test.'
        : null,
  );
}
