/// CDN 单词音频的文件名合同（与单词发音库生成端 `identity.py` 逐字节一致）。
///
/// 生成端规则：`normalize_v1` → UTF-8 → SHA-256 十六进制 + `.m4a`，路径为
/// `words/en-US/<hash>.m4a`。任何一处规则漂移都会让 CDN 文件无法命中，因此
/// 改动本文件必须同步跑 `word_audio_identity_test.dart` 的黄金样例。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

final RegExp _upperLetter = RegExp(r'\p{Lu}|\p{Lt}', unicode: true);
final RegExp _lowerLetter = RegExp(r'\p{Ll}', unicode: true);
final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _latinLetter = RegExp(r'\p{Script=Latin}', unicode: true);
final RegExp _combiningMark = RegExp(r'\p{M}', unicode: true);

/// 词内允许的结构：字母段以撇号/连字符连接，或为带点缩写（`U.S.`、`mr.`）。
final RegExp _wordStructure = RegExp(r"^a+(?:['’-]a+)*$");
final RegExp _abbreviationStructure = RegExp(r'^(?:a+\.)+a*$');

/// 返回 [text] 对应的 CDN 文件名（`<sha256>.m4a`）；输入不在合同内时返回 null，
/// 调用方应直接回退 TTS。
///
/// Dart 标准库没有 NFC 规范化。含组合记号（NFD 输入）的文本直接视为不合规，
/// 避免与生成端（先 NFC 再哈希）算出不同的文件名。
String? wordAudioFileName(String text) {
  if (_combiningMark.hasMatch(text)) return null;
  final normalized = normalizeWordForAudio(text);
  if (!_isSupportedWordStructure(normalized)) return null;
  final digest = sha256.convert(utf8.encode(normalized)).toString();
  return '$digest.m4a';
}

/// 与生成端 `normalize_v1` 一致：去首尾空白；仅首字母大写且其余字母小写时整体转小写；
/// 全大写与混合大小写保持原样。
String normalizeWordForAudio(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;
  final isAllUpper =
      _upperLetter.hasMatch(trimmed) && !_lowerLetter.hasMatch(trimmed);
  final startsUpper = _upperLetter.hasMatch(trimmed[0]);
  final restIsLowerOrNonLetter = trimmed.substring(1).runes.every((rune) {
    final char = String.fromCharCode(rune);
    return !_letter.hasMatch(char) || _lowerLetter.hasMatch(char);
  });
  if (!isAllUpper && startsUpper && restIsLowerOrNonLetter) {
    return trimmed.toLowerCase();
  }
  return trimmed;
}

bool _isSupportedWordStructure(String word) {
  if (word.isEmpty) return false;
  final mask = StringBuffer();
  for (final rune in word.runes) {
    final char = String.fromCharCode(rune);
    if (_letter.hasMatch(char) && _latinLetter.hasMatch(char)) {
      mask.write('a');
    } else if ("'’-.".contains(char)) {
      mask.write(char);
    } else {
      return false;
    }
  }
  final structure = mask.toString();
  return _wordStructure.hasMatch(structure) ||
      _abbreviationStructure.hasMatch(structure);
}
