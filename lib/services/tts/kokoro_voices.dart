/// Kokoro v1.1 多语言发音人目录。
///
/// sid 顺序严格对应官方 `voices.bin` 与 ONNX metadata；前三个为英文发音人，
/// 后续 100 个为中文发音人。英文口音仍沿用 `a*=美音 / b*=英音` 约定。
library;

import 'tts_engine.dart';

class KokoroVoice {
  final String id;
  final int sid;
  final String displayName;
  final TtsLanguage language;

  const KokoroVoice({
    required this.id,
    required this.sid,
    required this.displayName,
    this.language = TtsLanguage.english,
  });

  /// 英文口音；中文语音不使用该字段，默认归入美音组以兼容既有设置结构。
  TtsAccent get accent => id.startsWith('b') ? TtsAccent.uk : TtsAccent.us;

  /// 是否女声：`*f_`=女声，`*m_`=男声。
  bool get isFemale => id.length > 1 && id[1] == 'f';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KokoroVoice &&
          id == other.id &&
          sid == other.sid &&
          displayName == other.displayName &&
          language == other.language;

  @override
  int get hashCode => Object.hash(id, sid, displayName, language);
}

/// 多语言 Kokoro v1.1 的全部 103 个发音人（sid 0..102）。
final List<KokoroVoice> kokoroVoices = List.unmodifiable([
  const KokoroVoice(
    id: 'af_maple',
    sid: 0,
    displayName: 'Maple',
    language: TtsLanguage.english,
  ),
  const KokoroVoice(
    id: 'af_sol',
    sid: 1,
    displayName: 'Sol',
    language: TtsLanguage.english,
  ),
  const KokoroVoice(
    id: 'bf_vale',
    sid: 2,
    displayName: 'Vale',
    language: TtsLanguage.english,
  ),
  ..._buildChineseVoices(),
]);

const List<String> _chineseVoiceNames = [
  'zf_001',
  'zf_002',
  'zf_003',
  'zf_004',
  'zf_005',
  'zf_006',
  'zf_007',
  'zf_008',
  'zf_017',
  'zf_018',
  'zf_019',
  'zf_021',
  'zf_022',
  'zf_023',
  'zf_024',
  'zf_026',
  'zf_027',
  'zf_028',
  'zf_032',
  'zf_036',
  'zf_038',
  'zf_039',
  'zf_040',
  'zf_042',
  'zf_043',
  'zf_044',
  'zf_046',
  'zf_047',
  'zf_048',
  'zf_049',
  'zf_051',
  'zf_059',
  'zf_060',
  'zf_067',
  'zf_070',
  'zf_071',
  'zf_072',
  'zf_073',
  'zf_074',
  'zf_075',
  'zf_076',
  'zf_077',
  'zf_078',
  'zf_079',
  'zf_083',
  'zf_084',
  'zf_085',
  'zf_086',
  'zf_087',
  'zf_088',
  'zf_090',
  'zf_092',
  'zf_093',
  'zf_094',
  'zf_099',
  'zm_009',
  'zm_010',
  'zm_011',
  'zm_012',
  'zm_013',
  'zm_014',
  'zm_015',
  'zm_016',
  'zm_020',
  'zm_025',
  'zm_029',
  'zm_030',
  'zm_031',
  'zm_033',
  'zm_034',
  'zm_035',
  'zm_037',
  'zm_041',
  'zm_045',
  'zm_050',
  'zm_052',
  'zm_053',
  'zm_054',
  'zm_055',
  'zm_056',
  'zm_057',
  'zm_058',
  'zm_061',
  'zm_062',
  'zm_063',
  'zm_064',
  'zm_065',
  'zm_066',
  'zm_068',
  'zm_069',
  'zm_080',
  'zm_081',
  'zm_082',
  'zm_089',
  'zm_091',
  'zm_095',
  'zm_096',
  'zm_097',
  'zm_098',
  'zm_100',
];

List<KokoroVoice> _buildChineseVoices() {
  return [
    for (var index = 0; index < _chineseVoiceNames.length; index++)
      KokoroVoice(
        id: _chineseVoiceNames[index],
        sid: index + 3,
        displayName: _voiceDisplayName(_chineseVoiceNames[index], index + 1),
        language: TtsLanguage.chinese,
      ),
  ];
}

String _voiceDisplayName(String id, int ordinal) {
  return id.startsWith('zf_')
      ? 'Chinese Female ${ordinal.toString().padLeft(3, '0')}'
      : 'Chinese Male ${ordinal.toString().padLeft(3, '0')}';
}

/// 英文美音默认音色（v1.1 官方英文目录）。
const String kokoroDefaultVoiceUs = 'af_sol';

/// 英文英音默认音色（v1.1 官方英文目录）。
const String kokoroDefaultVoiceUk = 'bf_vale';

/// 中文默认音色。
const String kokoroDefaultVoiceZh = 'zf_001';

/// 返回指定语言的发音人。
List<KokoroVoice> voicesForLanguage(TtsLanguage language) =>
    kokoroVoices.where((v) => v.language == language).toList(growable: false);

/// 返回指定英文口音下的全部发音人。
List<KokoroVoice> voicesForAccent(TtsAccent accent) => kokoroVoices
    .where((v) => v.language == TtsLanguage.english && v.accent == accent)
    .toList(growable: false);

/// 按 id 查找发音人；未知 id 返回 null。
KokoroVoice? voiceById(String id) {
  for (final v in kokoroVoices) {
    if (v.id == id) return v;
  }
  return null;
}

/// 指定英文口音的默认发音人。
KokoroVoice defaultVoice(TtsAccent accent) {
  final id = accent == TtsAccent.uk
      ? kokoroDefaultVoiceUk
      : kokoroDefaultVoiceUs;
  return voiceById(id)!;
}

/// 中文默认发音人。
KokoroVoice get defaultChineseVoice => voiceById(kokoroDefaultVoiceZh)!;

/// 按文本自动选择 default voice：含 CJK 时使用中文字典默认音色。
KokoroVoice voiceForText(String text) {
  return RegExp(r'[\u3400-\u9fff]').hasMatch(text)
      ? defaultChineseVoice
      : defaultVoice(TtsAccent.us);
}

/// 把 voiceId 解析为合成用的 sid；未知 id 回退到该口音或中文默认音色。
int sidForVoiceId(String? voiceId, {required TtsAccent fallbackAccent}) {
  if (voiceId != null) {
    final v = voiceById(voiceId);
    if (v != null) return v.sid;
  }
  return defaultVoice(fallbackAccent).sid;
}
