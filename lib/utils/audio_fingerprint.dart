// 音频文件 SHA256 指纹计算工具
//
// 用于 AI 转录去重：相同内容的音频只需转录一次。
// 使用 Isolate 异步计算，避免阻塞 UI 线程。
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:universal_io/io.dart';

import '../features/audio_import/audio_import_cancel.dart';

typedef _FingerprintRequest = (String path, SendPort responsePort);

/// 计算音频文件的 SHA256 哈希值
///
/// 在 Isolate 中执行流式计算，避免将整个文件加载到内存。
/// [absolutePath] 音频文件的绝对路径。
/// 返回十六进制小写 SHA256 字符串。
/// 文件不存在时抛出 [FileSystemException]。
Future<String> computeAudioSha256(
  String absolutePath, {
  CancelToken? cancelToken,
}) async {
  if (cancelToken == null) {
    return Isolate.run(() => _computeSha256(absolutePath));
  }
  cancelToken.throwIfCanceled();

  final responsePort = ReceivePort();
  final isolate = await Isolate.spawn<_FingerprintRequest>(
    _computeSha256WithResponse,
    (absolutePath, responsePort.sendPort),
    // isolate 未经 try 捕获的异常或异常退出时也要回传，否则 responsePort.first 永远不完成
    onError: responsePort.sendPort,
    onExit: responsePort.sendPort,
  );
  try {
    final result = responsePort.first.then((message) {
      if (message case (true, final String hash)) return hash;
      if (message case (false, final String error)) {
        throw FileSystemException(error, absolutePath);
      }
      throw StateError('Audio fingerprint isolate ended without a result');
    });
    final canceled = cancelToken.whenCancel.then<String>(
      (error) => throw error,
    );
    return await Future.any([result, canceled]);
  } finally {
    isolate.kill(priority: Isolate.immediate);
    responsePort.close();
  }
}

void _computeSha256WithResponse(_FingerprintRequest request) {
  final (path, responsePort) = request;
  try {
    responsePort.send((true, _computeSha256(path)));
  } catch (error) {
    responsePort.send((false, error.toString()));
  }
}

/// Isolate 内部执行的同步 SHA256 计算
String _computeSha256(String absolutePath) {
  final file = File(absolutePath);
  if (!file.existsSync()) {
    throw FileSystemException('File not found', absolutePath);
  }
  final sink = AccumulatorSink<Digest>();
  final output = sha256.startChunkedConversion(sink);
  // 流式读取，每次 64KB
  final stream = file.openSync();
  try {
    // 用 Uint8List 且以视图传入：List<int> 的 sublist 每块都会复制，纯 Dart SHA-256 下约慢一倍。
    // hash 在 add 中同步消费数据，因此复用同一缓冲区是安全的。
    final buffer = Uint8List(65536);
    int bytesRead;
    while ((bytesRead = stream.readIntoSync(buffer)) > 0) {
      output.add(Uint8List.sublistView(buffer, 0, bytesRead));
    }
  } finally {
    stream.closeSync();
  }
  output.close();
  return sink.events.first.toString();
}

/// crypto 包的辅助类：收集 chunked conversion 的结果
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
