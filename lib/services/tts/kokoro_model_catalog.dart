/// Kokoro TTS 模型发布规格目录。
///
/// 模型标识、归档路径、校验值和推理所需文件名集中在此处；下载与安装流程
/// 由 [KokoroModelManager] 负责。
library;

import 'tts_engine.dart' show KokoroModelVariant;

/// Kokoro 模型归档规格。
class KokoroModelSpec {
  final KokoroModelVariant variant;
  final String id;
  final String archivePath;
  final String sha256;
  final String modelFileName;

  /// CDN 压缩归档的预计下载大小（字节），仅用于下载前展示近似流量。
  final int estimatedDownloadBytes;

  const KokoroModelSpec({
    required this.variant,
    required this.id,
    required this.archivePath,
    required this.sha256,
    required this.modelFileName,
    required this.estimatedDownloadBytes,
  });
}

/// 默认 Kokoro 模型变体。
const kokoroDefaultVariant = KokoroModelVariant.fp32;

/// Kokoro 推理所需的固定文件名。
const kokoroVoicesFileName = 'voices.bin';
const kokoroTokensFileName = 'tokens.txt';
const kokoroDataDirectoryName = 'espeak-ng-data';

/// Kokoro 模型规格表。
const kokoroModelSpecs = <KokoroModelVariant, KokoroModelSpec>{
  KokoroModelVariant.fp32: KokoroModelSpec(
    variant: KokoroModelVariant.fp32,
    id: 'kokoro-en-v0_19',
    archivePath: 'tts/kokoro-en-v0_19.tar.gz',
    sha256: 'd97c85ba5777bc226eca3a40312bb29dd8fd0e77546d4100abb7243b9b6ad137',
    modelFileName: 'model.onnx',
    estimatedDownloadBytes: 313785757,
  ),
  KokoroModelVariant.int8: KokoroModelSpec(
    variant: KokoroModelVariant.int8,
    id: 'kokoro-en-v0_19-int8',
    archivePath: 'tts/kokoro-en-v0_19-int8-v2.tar.gz',
    sha256: '70fd7ff687d08245f9409557f58072f43eb8a5bf8a90e98dd3bb7f60e05b4b07',
    modelFileName: 'model.int8.onnx',
    estimatedDownloadBytes: 102614756,
  ),
};

/// 按变体读取 Kokoro 模型规格。
KokoroModelSpec kokoroSpecOf(KokoroModelVariant variant) =>
    kokoroModelSpecs[variant]!;
