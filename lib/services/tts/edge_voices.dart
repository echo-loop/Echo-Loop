/// 微软 Edge 在线 TTS 精选音色目录。
///
/// 从 Edge 端点返回的数百个音色中精选美音 / 英音各 4 个 Neural 音色（2026-11 实测
/// `getVoices()` 均存在且可合成）。[EdgeVoice.id] 即 Edge 的 ShortName，既用于合成
/// 请求，也作为缓存键的 voiceId（见 [TtsSpeechConfig.voiceId]）。
library;

import 'tts_engine.dart';

/// 单个 Edge 音色。
class EdgeVoice {
  /// Edge 音色 ShortName（如 `en-US-AvaNeural`），同时作为缓存 voiceId。
  final String id;

  /// 展示名（如 `Ava`）。
  final String displayName;

  /// 口音。
  final TtsAccent accent;

  /// 是否女声。
  final bool isFemale;

  const EdgeVoice({
    required this.id,
    required this.displayName,
    required this.accent,
    required this.isFemale,
  });

  /// 合成请求使用的语言标签（`en-US` / `en-GB`）。
  String get languageTag => accent == TtsAccent.uk ? 'en-GB' : 'en-US';
}

/// 全部精选 Edge 音色（按口音分组，组内女声在前）。
const List<EdgeVoice> edgeVoices = [
  // 美音
  EdgeVoice(
    id: 'en-US-AvaNeural',
    displayName: 'Ava',
    accent: TtsAccent.us,
    isFemale: true,
  ),
  EdgeVoice(
    id: 'en-US-EmmaNeural',
    displayName: 'Emma',
    accent: TtsAccent.us,
    isFemale: true,
  ),
  EdgeVoice(
    id: 'en-US-AndrewNeural',
    displayName: 'Andrew',
    accent: TtsAccent.us,
    isFemale: false,
  ),
  EdgeVoice(
    id: 'en-US-BrianNeural',
    displayName: 'Brian',
    accent: TtsAccent.us,
    isFemale: false,
  ),
  // 英音
  EdgeVoice(
    id: 'en-GB-SoniaNeural',
    displayName: 'Sonia',
    accent: TtsAccent.uk,
    isFemale: true,
  ),
  EdgeVoice(
    id: 'en-GB-LibbyNeural',
    displayName: 'Libby',
    accent: TtsAccent.uk,
    isFemale: true,
  ),
  EdgeVoice(
    id: 'en-GB-RyanNeural',
    displayName: 'Ryan',
    accent: TtsAccent.uk,
    isFemale: false,
  ),
  EdgeVoice(
    id: 'en-GB-ThomasNeural',
    displayName: 'Thomas',
    accent: TtsAccent.uk,
    isFemale: false,
  ),
];

/// 美音默认音色。
const String edgeDefaultVoiceUs = 'en-US-AvaNeural';

/// 英音默认音色。
const String edgeDefaultVoiceUk = 'en-GB-SoniaNeural';

/// 返回指定口音下的全部 Edge 音色。
List<EdgeVoice> edgeVoicesForAccent(TtsAccent accent) =>
    edgeVoices.where((v) => v.accent == accent).toList(growable: false);

/// 按 id 查找 Edge 音色；未知 id 返回 null。
EdgeVoice? edgeVoiceById(String id) {
  for (final v in edgeVoices) {
    if (v.id == id) return v;
  }
  return null;
}

/// 指定口音的默认 Edge 音色。
EdgeVoice edgeDefaultVoice(TtsAccent accent) => edgeVoiceById(
  accent == TtsAccent.uk ? edgeDefaultVoiceUk : edgeDefaultVoiceUs,
)!;
