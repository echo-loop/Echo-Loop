/// Piper VITS 原生合成器抽象 + isolate worker 实现。
///
/// 镜像 `kokoro_synthesizer.dart`，但因 Piper **每音色一个独立模型**，worker 持有
/// 「当前音色 + 其 OfflineTts」，收到不同音色的请求时先 `free` 旧实例再用请求里的
/// 路径新建（换音色 = 换 onnx = 重建引擎）。`OfflineTts`（FFI 指针）只能在创建它的
/// isolate 内使用，故 `generate` + `writeWave` 都在 worker 内执行（同 §7.16）。
/// 固定 `provider='cpu'`（可靠、规避 NNAPI 崩溃，§7.4）。
library;

import 'dart:isolate';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../app_logger.dart';
import 'piper_model_manager.dart' show PiperModelPaths;

/// Piper 原生合成器接口。
abstract interface class PiperNativeSynthesizer {
  /// 启动 worker isolate（不预加载任何模型；模型在首次 [synthesize] 按音色懒加载）。
  Future<void> init({int numThreads});

  /// 用 [paths] 指定音色的模型把 [text] 合成为 wav 写入 [outputPath]。
  ///
  /// [voiceId] 用于 worker 判断是否需重建 `OfflineTts`（与上次不同则重载）。
  /// 成功返回采样率；失败返回 null（不抛，交上层降级）。
  Future<int?> synthesize({
    required PiperModelPaths paths,
    required String voiceId,
    required String text,
    required double speed,
    required String outputPath,
  });

  /// 释放模型与 isolate。
  Future<void> dispose();
}

/// 常驻 worker isolate 实现。
class IsolatePiperSynthesizer implements PiperNativeSynthesizer {
  _PiperWorker? _worker;

  @override
  Future<void> init({int numThreads = 2}) async {
    if (_worker != null) return;
    AppLogger.log('PiperTts', '┌ init worker threads=$numThreads');
    final sw = Stopwatch()..start();
    _worker = await _PiperWorker.spawn(numThreads);
    sw.stop();
    AppLogger.log(
      'PiperTts',
      '└ init done elapsed=${sw.elapsedMilliseconds}ms',
    );
  }

  @override
  Future<int?> synthesize({
    required PiperModelPaths paths,
    required String voiceId,
    required String text,
    required double speed,
    required String outputPath,
  }) async {
    final worker = _worker;
    if (worker == null) {
      throw StateError('Piper synthesizer not initialized.');
    }
    return worker.synthesize(
      paths: paths,
      voiceId: voiceId,
      text: text,
      speed: speed,
      outputPath: outputPath,
    );
  }

  @override
  Future<void> dispose() async {
    await _worker?.dispose();
    _worker = null;
  }
}

// ---------------------------------------------------------------------------
// Worker isolate
// ---------------------------------------------------------------------------

class _PiperWorker {
  final Isolate _isolate;
  final SendPort _commandPort;

  _PiperWorker._(this._isolate, this._commandPort);

  static Future<_PiperWorker> spawn(int numThreads) async {
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(
      _entryPoint,
      _InitPayload(sendPort: initPort.sendPort, numThreads: numThreads),
    );
    final response = await initPort.first;
    initPort.close();
    if (response is SendPort) {
      return _PiperWorker._(isolate, response);
    }
    isolate.kill(priority: Isolate.immediate);
    throw StateError('Piper worker init failed: $response');
  }

  Future<int?> synthesize({
    required PiperModelPaths paths,
    required String voiceId,
    required String text,
    required double speed,
    required String outputPath,
  }) async {
    final replyPort = ReceivePort();
    _commandPort.send(
      _SynthRequest(
        modelPath: paths.model,
        tokensPath: paths.tokens,
        dataDir: paths.dataDir,
        voiceId: voiceId,
        text: text,
        speed: speed,
        outputPath: outputPath,
        replyPort: replyPort.sendPort,
      ),
    );
    final response = await replyPort.first;
    replyPort.close();
    if (response is _SynthResponse) {
      AppLogger.log(
        'PiperTts',
        '⏱ load=${response.loadMs}ms generate=${response.generateMs}ms '
            'writeWave=${response.writeMs}ms voice=$voiceId',
      );
      return response.sampleRate;
    }
    AppLogger.log('PiperTts', '✗ synthesize failed: $response');
    return null;
  }

  Future<void> dispose() async {
    final replyPort = ReceivePort();
    _commandPort.send(_DisposeRequest(replyPort.sendPort));
    await replyPort.first;
    replyPort.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

class _InitPayload {
  final SendPort sendPort;
  final int numThreads;
  const _InitPayload({required this.sendPort, required this.numThreads});
}

class _SynthRequest {
  final String modelPath;
  final String tokensPath;
  final String dataDir;
  final String voiceId;
  final String text;
  final double speed;
  final String outputPath;
  final SendPort replyPort;
  const _SynthRequest({
    required this.modelPath,
    required this.tokensPath,
    required this.dataDir,
    required this.voiceId,
    required this.text,
    required this.speed,
    required this.outputPath,
    required this.replyPort,
  });
}

class _SynthResponse {
  final int sampleRate;

  /// 本次是否重建了模型的加载耗时（命中同音色为 0），毫秒。
  final int loadMs;

  /// 纯推理（`OfflineTts.generate`）耗时，毫秒。
  final int generateMs;

  /// 写盘（`writeWave`）耗时，毫秒。
  final int writeMs;
  const _SynthResponse(
    this.sampleRate,
    this.loadMs,
    this.generateMs,
    this.writeMs,
  );
}

class _DisposeRequest {
  final SendPort replyPort;
  const _DisposeRequest(this.replyPort);
}

/// Worker isolate 入口：循环处理合成请求，按音色懒加载/重建 OfflineTts。
void _entryPoint(_InitPayload init) {
  sherpa.OfflineTts? tts;
  String? currentVoiceId;
  try {
    sherpa.initBindings();
    final commandPort = ReceivePort();
    init.sendPort.send(commandPort.sendPort);

    commandPort.listen((message) {
      if (message is _SynthRequest) {
        try {
          var loadMs = 0;
          // 换音色（含首次）：释放旧实例，用新音色的 vits 模型重建。
          if (currentVoiceId != message.voiceId || tts == null) {
            final swLoad = Stopwatch()..start();
            tts?.free();
            tts = sherpa.OfflineTts(
              sherpa.OfflineTtsConfig(
                model: sherpa.OfflineTtsModelConfig(
                  vits: sherpa.OfflineTtsVitsModelConfig(
                    model: message.modelPath,
                    tokens: message.tokensPath,
                    dataDir: message.dataDir,
                  ),
                  numThreads: init.numThreads,
                  provider: 'cpu',
                  debug: false,
                ),
              ),
            );
            currentVoiceId = message.voiceId;
            swLoad.stop();
            loadMs = swLoad.elapsedMilliseconds;
          }
          final swGen = Stopwatch()..start();
          // Piper 单说话人，固定 sid=0。
          final audio = tts!.generate(
            text: message.text,
            sid: 0,
            speed: message.speed,
          );
          swGen.stop();
          final swWrite = Stopwatch()..start();
          final ok = sherpa.writeWave(
            filename: message.outputPath,
            samples: audio.samples,
            sampleRate: audio.sampleRate,
          );
          swWrite.stop();
          if (ok) {
            message.replyPort.send(
              _SynthResponse(
                audio.sampleRate,
                loadMs,
                swGen.elapsedMilliseconds,
                swWrite.elapsedMilliseconds,
              ),
            );
          } else {
            message.replyPort.send('writeWave failed');
          }
        } catch (e) {
          message.replyPort.send('generate failed: $e');
        }
      } else if (message is _DisposeRequest) {
        tts?.free();
        tts = null;
        message.replyPort.send(null);
        commandPort.close();
      }
    });
  } catch (e) {
    tts?.free();
    init.sendPort.send('Init failed: $e');
  }
}
