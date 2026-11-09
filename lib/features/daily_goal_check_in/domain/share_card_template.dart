import 'package:flutter/material.dart' show Color;

/// 服务端返回的分享模板；图片仅为背景，用户资料及统计由客户端合成。
class ShareCardTemplate {
  const ShareCardTemplate({
    required this.id,
    required this.imageUrl,
    required this.topColor,
    required this.bottomColor,
    required this.content,
  });

  factory ShareCardTemplate.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('分享模板必须是对象');
    }
    final id = value['id'];
    final imageUrl = value['imageUrl'];
    final colors = value['textColors'];
    if (id is! String ||
        id.isEmpty ||
        imageUrl is! String ||
        colors is! Map<String, Object?>) {
      throw const FormatException('分享模板字段无效');
    }
    final uri = Uri.tryParse(imageUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('分享背景地址无效');
    }
    return ShareCardTemplate(
      id: id,
      imageUrl: imageUrl,
      topColor: _color(colors['top']),
      bottomColor: _color(colors['bottom']),
      content: ShareCardContent.fromJson(value['content']),
    );
  }

  final String id;
  final String imageUrl;
  final Color topColor;
  final Color bottomColor;
  final ShareCardContent content;

  Map<String, Object?> toJson() => {
    'id': id,
    'imageUrl': imageUrl,
    'textColors': {
      'top':
          '#${(topColor.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}',
      'bottom':
          '#${(bottomColor.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}',
    },
    'content': switch (content) {
      ShareCardWord(:final english, :final translations, :final phonetic) => {
        'type': 'word',
        'word': english,
        'meaning': translations,
        'phonetic': phonetic,
      },
      ShareCardSentence(:final english, :final translations) => {
        'type': 'sentence',
        'en': english,
        'translation': translations,
      },
    },
  };

  static Color _color(Object? value) {
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      throw const FormatException('分享模板配色无效');
    }
    return Color(0xff000000 | int.parse(value.substring(1), radix: 16));
  }
}

sealed class ShareCardContent {
  const ShareCardContent(this.english, this.translations);

  factory ShareCardContent.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('分享文案必须是对象');
    }
    final type = value['type'];
    final english = value[type == 'word' ? 'word' : 'en'];
    final translations = value[type == 'word' ? 'meaning' : 'translation'];
    if ((type != 'word' && type != 'sentence') ||
        english is! String ||
        english.trim().isEmpty ||
        translations is! Map<String, Object?> ||
        english.length > (type == 'word' ? 60 : 100)) {
      throw const FormatException('分享文案字段无效');
    }
    final localized = <String, String>{};
    for (final entry in translations.entries) {
      final text = entry.value;
      if (text is! String || text.length > 60) {
        throw const FormatException('分享译文无效');
      }
      if (text.trim().isNotEmpty) localized[entry.key] = text;
    }
    if (type == 'sentence') return ShareCardSentence(english, localized);
    final phonetic = value['phonetic'];
    if (phonetic is! String || phonetic.length > 100) {
      throw const FormatException('分享单词音标无效');
    }
    return ShareCardWord(english, localized, phonetic);
  }

  final String english;
  final Map<String, String> translations;

  String translationFor(String language) =>
      translations[language] ??
      translations[language.split('-').first] ??
      translations['zh-CN'] ??
      translations.values.firstOrNull ??
      '';
}

class ShareCardWord extends ShareCardContent {
  const ShareCardWord(super.english, super.translations, this.phonetic);
  final String phonetic;
}

class ShareCardSentence extends ShareCardContent {
  const ShareCardSentence(super.english, super.translations);
}
