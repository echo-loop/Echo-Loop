/// 本地 AI 缓存的只读解码（PDF 导出共用，不触发任何网络请求）
library;

import 'dart:convert';

import '../../../models/sentence_ai_result.dart';

/// 解码句子翻译缓存 JSON；未命中 / 损坏 / 译文为空均返回 null
String? decodeCachedTranslation(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final text = SentenceTranslation.fromJson(decoded).translation.trim();
      return text.isEmpty ? null : text;
    }
  } catch (_) {
    // 损坏数据视作未命中
  }
  return null;
}
