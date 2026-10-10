/// 配置驱动的网页型词典源
///
/// 网页词典（Cambridge / Oxford / Longman / Britannica / Merriam-Webster / Collins /
/// Vocabulary.com / Wiktionary / OZDIC / PlayPhrase / YouGlish / Forvo /
/// WordReference / Etymonline / 有道 / 欧路词典）本质相同——不抓取/解析 HTML，
/// 只按词构造 URL，交给内置 WebView 显示。差异仅在 URL 模板与品牌展示，故抽象为一份 [WebDictConfig]
/// 配置 + 一个通用 [WebDictionarySource]：新增一个网页词典只需往 [kWebDictConfigs]
/// 加一行配置。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/dictionary/dictionary_lookup_result.dart';
import 'dictionary_source.dart';

/// 单个网页词典的配置（id / 展示 / URL 构造 / 可选页面注入）
@immutable
class WebDictConfig {
  /// 稳定唯一 id（持久化键/缓存前缀/切换标识，一经发布不可改）
  final String id;

  /// 切换器与设置页显示名（品牌名，不本地化）
  final String displayName;

  /// 列表图标
  final IconData icon;

  /// 品牌强调色（图标着色，便于区分各源）
  final Color color;

  /// 由「已 URL 编码的查询词」构造完整词条网页地址
  final String Function(String encodedWord) buildUrl;

  /// 可选：收敛页面 chrome（隐藏页眉/广告/cookie 横幅）的 CSS；
  /// 为 null 时视图使用通用默认注入。
  final String? tidyCss;

  /// 可选：自动接受 cookie 同意的 JS；为 null 时视图使用通用默认注入。
  final String? acceptCookieJs;

  const WebDictConfig({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.buildUrl,
    this.tidyCss,
    this.acceptCookieJs,
  });
}

/// 通用网页词典源：包装一份 [WebDictConfig]，[lookup] 只构造 URL。
class WebDictionarySource implements DictionarySource {
  /// 该源配置
  final WebDictConfig config;

  const WebDictionarySource(this.config);

  @override
  String get id => config.id;

  @override
  IconData get icon => config.icon;

  @override
  bool get canBeDisabled => true;

  @override
  bool get requiresNetwork => true;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    // request.word 已由 controller 完成基础清洗（见 DictionaryLookupRequest.word 契约）
    final slug = Uri.encodeComponent(request.word);
    return WebDictResult(
      sourceId: config.id,
      url: Uri.parse(config.buildUrl(slug)),
      word: request.word,
    );
  }
}

/// 全部网页词典配置（顺序即切换器排列顺序）。
///
/// Macmillan 未纳入：其官网已于 2023-06-30 永久关停，仅存手机 App。
const List<WebDictConfig> kWebDictConfigs = [
  WebDictConfig(
    id: 'cambridge',
    displayName: 'Cambridge',
    icon: Icons.school_rounded,
    color: Color(0xFF00BDB6), // 站点导航栏青绿
    buildUrl: _cambridgeUrl,
  ),
  WebDictConfig(
    id: 'oxford',
    displayName: 'Oxford',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF002147), // Oxford Blue（黑顶栏官方色）
    buildUrl: _oxfordUrl,
  ),
  WebDictConfig(
    id: 'longman',
    displayName: 'Longman',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF3B4CB8), // 站点靛蓝（提亮区分其余蓝）
    buildUrl: _longmanUrl,
  ),
  WebDictConfig(
    id: 'merriamWebster',
    displayName: 'Merriam-Webster',
    icon: Icons.import_contacts_rounded,
    color: Color(0xFFD7191F), // M-W 品牌红
    buildUrl: _merriamWebsterUrl,
  ),
  WebDictConfig(
    id: 'collins',
    displayName: 'Collins',
    icon: Icons.local_library_rounded,
    color: Color(0xFF0073E6), // 站点主色蓝
    buildUrl: _collinsUrl,
  ),
  WebDictConfig(
    id: 'britannica',
    displayName: 'Britannica',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF2D5B9A), // Britannica 蓝
    buildUrl: _britannicaUrl,
  ),
  WebDictConfig(
    id: 'vocabulary',
    displayName: 'Vocabulary.com',
    icon: Icons.book_rounded,
    color: Color(0xFF2D4D80), // 站点导航栏钢藏蓝
    buildUrl: _vocabularyUrl,
  ),
  WebDictConfig(
    id: 'wiktionary',
    displayName: 'Wiktionary',
    icon: Icons.public_rounded,
    color: Color(0xFF54595D), // Wikimedia 灰
    buildUrl: _wiktionaryUrl,
  ),
  WebDictConfig(
    id: 'ozdic',
    displayName: 'OZDIC',
    icon: Icons.hub_rounded,
    color: Color(0xFF00897B), // 搭配词典主打词间关系，用青绿色区分
    buildUrl: _ozdicUrl,
  ),
  WebDictConfig(
    id: 'playPhrase',
    displayName: 'PlayPhrase',
    icon: Icons.movie_filter_rounded,
    color: Color(0xFF6D4C41), // 影院语料场景，用暖棕与传统词典区分
    buildUrl: _playPhraseUrl,
  ),
  WebDictConfig(
    id: 'youglish',
    displayName: 'YouGlish',
    icon: Icons.ondemand_video_rounded,
    color: Color(0xFFFF0000), // YouTube 系视频语料红
    buildUrl: _youglishUrl,
  ),
  WebDictConfig(
    id: 'forvo',
    displayName: 'Forvo',
    icon: Icons.record_voice_over_rounded,
    color: Color(0xFF2E7D32), // 发音社区语料，用稳定绿色表示语音来源
    buildUrl: _forvoUrl,
  ),
  WebDictConfig(
    id: 'wordReference',
    displayName: 'WordReference',
    icon: Icons.forum_rounded,
    color: Color(0xFF0D47A1), // 站点常见深蓝识别色
    buildUrl: _wordReferenceUrl,
  ),
  WebDictConfig(
    id: 'etymonline',
    displayName: 'Etymonline',
    icon: Icons.history_edu_rounded,
    color: Color(0xFF795548), // 词源资料场景，用低饱和棕色区分
    buildUrl: _etymonlineUrl,
  ),
  WebDictConfig(
    id: 'youdao',
    displayName: '有道',
    icon: Icons.translate_rounded,
    color: Color(0xFFEA4B35), // 有道暖红（与 M-W 冷红拉开）
    buildUrl: _youdaoUrl,
  ),
  WebDictConfig(
    id: 'eudic',
    displayName: '欧路词典',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF2D6FA3), // 欧路词典蓝
    buildUrl: _eudicUrl,
  ),
];

// URL 模板（顶层函数，便于 const 配置引用）。`w` 为已 URL 编码的查询词。
String _cambridgeUrl(String w) =>
    'https://dictionary.cambridge.org/dictionary/english-chinese-simplified/$w';
String _oxfordUrl(String w) =>
    'https://www.oxfordlearnersdictionaries.com/definition/english/$w';
String _longmanUrl(String w) => 'https://www.ldoceonline.com/dictionary/$w';
String _britannicaUrl(String w) => 'https://www.britannica.com/dictionary/$w';
String _merriamWebsterUrl(String w) =>
    'https://www.merriam-webster.com/dictionary/$w';
String _collinsUrl(String w) =>
    'https://www.collinsdictionary.com/dictionary/english/$w';
String _vocabularyUrl(String w) => 'https://www.vocabulary.com/dictionary/$w';
String _wiktionaryUrl(String w) => 'https://en.m.wiktionary.org/wiki/$w';
String _ozdicUrl(String w) => 'https://ozdic.com/word/$w';
String _playPhraseUrl(String w) => 'https://www.playphrase.me/#/search?q=$w';
String _youglishUrl(String w) => 'https://youglish.com/pronounce/$w/english';
String _forvoUrl(String w) => 'https://forvo.com/word/$w/#en';
String _wordReferenceUrl(String w) =>
    'https://www.wordreference.com/definition/$w';
String _etymonlineUrl(String w) => 'https://www.etymonline.com/search?q=$w';
String _youdaoUrl(String w) => 'https://m.youdao.com/dict?le=eng&q=$w';
String _eudicUrl(String w) => 'https://dict.eudic.net/dicts/en/$w';
