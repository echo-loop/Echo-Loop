/// ASR 模型发布规格目录。
///
/// 模型 CDN 路径、归档摘要、预计流量和解压后关键文件只在本文件维护；
/// 下载与安装行为由 ASR 专属归档安装器负责。
library;

/// 所有 Whisper 模型共享的 VAD 资源 ID。
const vadModelId = 'silero-vad';

class AsrModelResourceSpec {
  const AsrModelResourceSpec({
    required this.id,
    required this.archivePath,
    required this.sha256,
    required this.estimatedDownloadBytes,
    required this.requiredFiles,
    this.dependencies = const [],
  });

  final String id;
  final String archivePath;
  final String sha256;
  final int estimatedDownloadBytes;
  final List<String> requiredFiles;
  final List<String> dependencies;
}

const asrModelResourceCatalog = <String, AsrModelResourceSpec>{
  vadModelId: AsrModelResourceSpec(
    id: vadModelId,
    archivePath: 'asr/silero-vad-v1.zip',
    sha256: 'e7ae67c1610b5ef8d1f00d2e0e42e833ced8d3bc22f8e59a809d36616028f5e2',
    estimatedDownloadBytes: 508294,
    requiredFiles: ['silero_vad.onnx'],
  ),
  'whisper-tiny-en-int8': AsrModelResourceSpec(
    id: 'whisper-tiny-en-int8',
    archivePath: 'asr/whisper-tiny-en-int8-v1.zip',
    sha256: '251f653212befd7fa0318cca2ff0ce4f71804581aad387ba88bc7c85f9eb5dc3',
    estimatedDownloadBytes: 62337248,
    requiredFiles: [
      'tiny.en-encoder.int8.onnx',
      'tiny.en-decoder.int8.onnx',
      'tiny.en-tokens.txt',
    ],
    dependencies: [vadModelId],
  ),
  'whisper-base-en-int8': AsrModelResourceSpec(
    id: 'whisper-base-en-int8',
    archivePath: 'asr/whisper-base-en-int8-v1.zip',
    sha256: 'ff8af5965f6d017ad317e9a7c023c3f457259cef3de33e543c2fa87338a32fbb',
    estimatedDownloadBytes: 95051629,
    requiredFiles: [
      'base.en-encoder.int8.onnx',
      'base.en-decoder.int8.onnx',
      'base.en-tokens.txt',
    ],
    dependencies: [vadModelId],
  ),
  'whisper-small-en-int8': AsrModelResourceSpec(
    id: 'whisper-small-en-int8',
    archivePath: 'asr/whisper-small-en-int8-v1.zip',
    sha256: '33f80b3bbc4871daaeb57376c0629bf868443ab95b0a71e9970da09c163eeed9',
    estimatedDownloadBytes: 228206095,
    requiredFiles: [
      'small.en-encoder.int8.onnx',
      'small.en-decoder.int8.onnx',
      'small.en-tokens.txt',
    ],
    dependencies: [vadModelId],
  ),
};
