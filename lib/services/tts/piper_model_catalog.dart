/// Piper VITS（Echo Loop TTS 平衡档）音色目录。
///
/// 与 Kokoro 根本不同：Piper 每个音色 = 一个**独立单说话人模型**（一个 `.onnx`），
/// 故音色既是「选择项」也是「下载单元」——每个音色单独下载、互不共享，合成时固定
/// `sid=0`（换音色需重建 `OfflineTts`，见 `piper_synthesizer.dart`）。
///
/// [PiperVoice.id] 同时作为：① 本地模型目录名；② 缓存键 voiceId（见
/// [TtsSpeechConfig.voiceId]）；③ 下载状态机的 key（见 `piper_model_provider.dart`）。
/// 模型来自 sherpa-onnx releases 的 medium 单说话人 piper 模型，重打包为 gzip
/// （去 macOS 元数据，见 CLAUDE.md §7.17）后托管到自家 CDN。
library;

import 'tts_engine.dart';

/// Piper 推理所需的固定文件名。
const piperTokensFileName = 'tokens.txt';
const piperDataDirectoryName = 'espeak-ng-data';

/// 单个 Piper 音色（= 一个独立模型）。
class PiperVoice {
  /// 音色标识（如 `en_US-amy-medium`）：本地目录名 + 缓存 voiceId + 下载 key。
  final String id;

  /// 展示名（如 `Amy`）。
  final String displayName;

  /// 口音（美/英），决定语言标签与分组。
  final TtsAccent accent;

  /// 是否女声（仅用于 UI 性别标签）。
  final bool isFemale;

  /// 归档相对路径（拼到 `$cdnBase/model/$archivePath`），如
  /// `tts/vits-piper-en_US-amy-medium.tar.gz`。
  final String archivePath;

  /// 归档整包 SHA-256。换归档须同步改此值（先传 CDN 再改常量，见 §7.17）。
  final String sha256;

  /// CDN 压缩归档的预计下载大小（字节），仅用于下载前展示近似流量。
  final int estimatedDownloadBytes;

  const PiperVoice({
    required this.id,
    required this.displayName,
    required this.accent,
    required this.isFemale,
    required this.archivePath,
    required this.sha256,
    required this.estimatedDownloadBytes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PiperVoice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          accent == other.accent &&
          isFemale == other.isFemale &&
          archivePath == other.archivePath &&
          sha256 == other.sha256 &&
          estimatedDownloadBytes == other.estimatedDownloadBytes;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    accent,
    isFemale,
    archivePath,
    sha256,
    estimatedDownloadBytes,
  );
}

/// 全部 9 个 Piper 音色（6 美音 + 3 英音）。
///
/// TODO(piper): `sha256` 待用户提供 CDN 实际产物清单后回填；`displayName` /
/// `archivePath` 同步按清单核对。SHA 为空串时本地 UI/单测可跑（mock 下载），
/// 但真机下载会 SHA 校验失败——回填后方可端到端验证（见 PLAN「前置条件」）。
const List<PiperVoice> piperVoices = [
  // 美音（en_US）
  PiperVoice(
    id: 'en_US-amy-medium',
    displayName: 'Amy',
    accent: TtsAccent.us,
    isFemale: true,
    archivePath: 'tts/vits-piper-en_US-amy-medium.tar.gz',
    estimatedDownloadBytes: 67347129,
    sha256: 'ce4fc13a01c2b670f744c5d944469ac2c01b144f8f98ff7985d67d7402695c29',
  ),
  PiperVoice(
    id: 'en_US-lessac-medium',
    displayName: 'Lessac',
    accent: TtsAccent.us,
    isFemale: true,
    archivePath: 'tts/vits-piper-en_US-lessac-medium.tar.gz',
    estimatedDownloadBytes: 67358584,
    sha256: 'd0fd375de4be84199813d3c69b94ebf5b14ae5c291bda61315d0307eed039065',
  ),
  PiperVoice(
    id: 'en_US-ryan-medium',
    displayName: 'Ryan',
    accent: TtsAccent.us,
    isFemale: false,
    archivePath: 'tts/vits-piper-en_US-ryan-medium.tar.gz',
    estimatedDownloadBytes: 67370820,
    sha256: '49e5065dd3f17c27be2d29310887dbd17b924ebfb0fc24a6f82b7e96a34a44d4',
  ),
  PiperVoice(
    id: 'en_US-joe-medium',
    displayName: 'Joe',
    accent: TtsAccent.us,
    isFemale: false,
    archivePath: 'tts/vits-piper-en_US-joe-medium.tar.gz',
    estimatedDownloadBytes: 67329430,
    sha256: 'c13190297212663f4371e365e239f7208ceeaae0e2d8ce5994456b42bb1e6799',
  ),
  PiperVoice(
    id: 'en_US-kristin-medium',
    displayName: 'Kristin',
    accent: TtsAccent.us,
    isFemale: true,
    archivePath: 'tts/vits-piper-en_US-kristin-medium.tar.gz',
    estimatedDownloadBytes: 67424191,
    sha256: '58988662c21850d05b5687043dc710a6c41bbf15814aff34e4be32c32cb377a8',
  ),
  PiperVoice(
    id: 'en_US-hfc_female-medium',
    displayName: 'Hannah',
    accent: TtsAccent.us,
    isFemale: true,
    archivePath: 'tts/vits-piper-en_US-hfc_female-medium.tar.gz',
    estimatedDownloadBytes: 67359748,
    sha256: 'b849044f82219e2b0d990d81e75b80cecedda53608b182299beffbeadfac33f0',
  ),
  // 英音（en_GB）
  PiperVoice(
    id: 'en_GB-alan-medium',
    displayName: 'Alan',
    accent: TtsAccent.uk,
    isFemale: false,
    archivePath: 'tts/vits-piper-en_GB-alan-medium.tar.gz',
    estimatedDownloadBytes: 67339791,
    sha256: '29c62a69788b0533ef3ce1488eea1e1a90d6f7a0a7ece2a3ae7aadc78bd043e7',
  ),
  PiperVoice(
    id: 'en_GB-cori-medium',
    displayName: 'Cori',
    accent: TtsAccent.uk,
    isFemale: true,
    archivePath: 'tts/vits-piper-en_GB-cori-medium.tar.gz',
    estimatedDownloadBytes: 67431659,
    sha256: 'd49b0cc0353ceabc8cb15a4781b7c4f5cb858ecad52fbfb5591b2577b21b77e8',
  ),
  PiperVoice(
    id: 'en_GB-alba-medium',
    displayName: 'Alba',
    accent: TtsAccent.uk,
    isFemale: true,
    archivePath: 'tts/vits-piper-en_GB-alba-medium.tar.gz',
    estimatedDownloadBytes: 67356380,
    sha256: '3f2685f7c34ec9e025a05297e294a7dad0e373acefd4a796d872e7cee1e8a696',
  ),
];

/// 美音默认音色。
const String piperDefaultVoiceUs = 'en_US-amy-medium';

/// 英音默认音色。
const String piperDefaultVoiceUk = 'en_GB-alan-medium';

/// 按 id 查找音色；未知 id 返回 null。
PiperVoice? piperVoiceById(String id) {
  for (final v in piperVoices) {
    if (v.id == id) return v;
  }
  return null;
}

/// 返回指定口音下的全部音色。
List<PiperVoice> piperVoicesByAccent(TtsAccent accent) =>
    piperVoices.where((v) => v.accent == accent).toList(growable: false);

/// 指定口音的默认音色。
PiperVoice piperDefaultVoice(TtsAccent accent) {
  final id = accent == TtsAccent.uk ? piperDefaultVoiceUk : piperDefaultVoiceUs;
  return piperVoiceById(id) ?? piperVoices.first;
}
