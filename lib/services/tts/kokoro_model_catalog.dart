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

  /// 官方发布地址；为空时回退到 Echo Loop CDN。
  final String? downloadUrl;

  /// 下载到磁盘时使用的归档文件名；为空时由 manager 按 [archivePath] 后缀生成。
  final String? archiveFileName;

  /// CDN 压缩归档的预计下载大小（字节），仅用于下载前展示近似流量。
  final int estimatedDownloadBytes;

  const KokoroModelSpec({
    required this.variant,
    required this.id,
    required this.archivePath,
    required this.sha256,
    required this.modelFileName,
    required this.estimatedDownloadBytes,
    this.downloadUrl,
    this.archiveFileName,
  });
}

/// Kokoro 模型 CDN 基地址。
const kokoroCdnBaseUrl = 'https://cdn.echo-loop.top';

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
    id: 'kokoro-multi-lang-v1_1',
    archivePath: 'tts/kokoro-multi-lang-v1_1.tar.bz2',
    sha256: 'a3f4c73d043860e3fd2e5b06f36795eb81de0fc8e8de6df703245edddd87dbad',
    modelFileName: 'model.onnx',
    estimatedDownloadBytes: 364816464,
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2',
  ),
  KokoroModelVariant.int8: KokoroModelSpec(
    variant: KokoroModelVariant.int8,
    id: 'kokoro-int8-multi-lang-v1_1',
    archivePath: 'tts/kokoro-int8-multi-lang-v1_1.tar.bz2',
    sha256: 'a1e94694776049035c4f2c6529f003aaece993c76aae9a78995831c3c4dcafc6',
    modelFileName: 'model.int8.onnx',
    estimatedDownloadBytes: 147031220,
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_1.tar.bz2',
  ),
};

/// 按变体读取 Kokoro 模型规格。
KokoroModelSpec kokoroSpecOf(KokoroModelVariant variant) =>
    kokoroModelSpecs[variant]!;
