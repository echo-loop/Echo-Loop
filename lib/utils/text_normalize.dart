/// 文本归一化工具
///
/// 提供缓存键生成所需的文本归一化和哈希功能。
/// 用于 AI 翻译/解析的三级缓存（内存 → SQLite → API）查找。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 归一化文本，用于缓存键匹配
///
/// 处理步骤：去首尾空白 → 转小写 → 合并连续空白。
/// 确保同一句话的不同格式变体映射到同一缓存键。
String normalizeForCache(String text) {
  return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// 生成文本的 SHA-256 哈希值
///
/// 先归一化文本，再计算哈希。返回 64 字符十六进制字符串。
String hashText(String text) {
  final normalized = normalizeForCache(text);
  return sha256.convert(utf8.encode(normalized)).toString();
}

/// 各种弯/花撇号（U+2019 ’ / U+2018 ‘ / U+02BC ʼ / U+FF07 ＇ / 反引号 ` / U+00B4 ´）
/// 统一为直撇号 `'`：排版文本（如 "I'd"）多用弯撇号，而词典库（ECDICT / 网页源）
/// 用直撇号存储，不归一会查不中且粗体标题渲染异常。
final RegExp _smartApostrophes = RegExp('[’‘ʼ＇`´]');

/// 剥离查词输入首尾的非字母数字字符（保留词内连字符/点，如 COVID-19）。
///
/// 右侧不剥离直撇号 `'`，保留所有格/缩写形式（dogs' / it's / library's）。
final RegExp _edgeNonAlnum = RegExp(r"^[^A-Za-z0-9]+|[^A-Za-z0-9']+$");

/// 归一化查词输入，供本地 / AI / 网页等所有词典源共用，保证大小写处理一致。
///
/// 处理步骤：去首尾空白 → 弯撇号归一为直撇号 → 剥离首尾标点（右侧直撇号除外）
/// → 一律转小写 → 折叠内部连续空白为单个空格（多词词组换行/多空格归一）。
/// 全大写缩写（NASA / FBI 等）不做特殊保留，统一小写化。
String normalizeWord(String word) {
  return word
      .trim()
      .replaceAll(_smartApostrophes, "'")
      .replaceAll(_edgeNonAlnum, '')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}
