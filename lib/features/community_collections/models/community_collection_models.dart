import '../../../models/word_timestamp.dart';

/// v2 社区合集目录。
class PublicCollectionCatalogEntry {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String? coverUrlChina;
  final String? authorNickname;
  final int fileCount;
  final DateTime publishedAt;
  final DateTime updatedAt;

  const PublicCollectionCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.coverUrl,
    this.coverUrlChina,
    this.authorNickname,
    required this.fileCount,
    required this.publishedAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? publishedAt;

  factory PublicCollectionCatalogEntry.fromJson(Map<String, Object?> json) {
    return PublicCollectionCatalogEntry(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      description: _nullableString(json, 'description'),
      coverUrl: _nullableString(json, 'coverUrl'),
      coverUrlChina: _nullableString(json, 'coverUrlChina'),
      authorNickname: _nullableString(json, 'authorNickname'),
      fileCount: _requiredInt(json, 'fileCount'),
      publishedAt: _requiredDateTime(json, 'publishedAt'),
      updatedAt:
          _nullableDateTime(json, 'updatedAt') ??
          _requiredDateTime(json, 'publishedAt'),
    );
  }

  /// 序列化为发现页离线缓存，不作为后端请求契约使用。
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'coverUrl': coverUrl,
    'coverUrlChina': coverUrlChina,
    'authorNickname': authorNickname,
    'fileCount': fileCount,
    'publishedAt': publishedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// 社区合集文件类型。
enum CommunityMediaType {
  audio,
  video;

  static CommunityMediaType fromJson(Object? value) {
    return switch (value) {
      'audio' => CommunityMediaType.audio,
      'video' => CommunityMediaType.video,
      _ => throw const FormatException('Invalid community mediaType'),
    };
  }
}

/// 社区合集文件难度。
enum CommunityDifficulty {
  a1,
  a2,
  b1,
  b2,
  c1,
  c2;

  /// CEFR 难度标签。
  String get code => switch (this) {
    CommunityDifficulty.a1 => 'A1',
    CommunityDifficulty.a2 => 'A2',
    CommunityDifficulty.b1 => 'B1',
    CommunityDifficulty.b2 => 'B2',
    CommunityDifficulty.c1 => 'C1',
    CommunityDifficulty.c2 => 'C2',
  };

  /// 从已持久化的 CEFR 标签读取枚举；未知值不在列表中展示。
  static CommunityDifficulty? fromCode(String? value) => switch (value) {
    'A1' => CommunityDifficulty.a1,
    'A2' => CommunityDifficulty.a2,
    'B1' => CommunityDifficulty.b1,
    'B2' => CommunityDifficulty.b2,
    'C1' => CommunityDifficulty.c1,
    'C2' => CommunityDifficulty.c2,
    _ => null,
  };

  static CommunityDifficulty? fromJson(Object? value) {
    if (value == null) return null;
    if (value case final String code) {
      return fromCode(code) ??
          (throw const FormatException('Invalid community difficulty'));
    }
    throw const FormatException('Invalid community difficulty');
  }
}

/// v2 社区合集文件元数据。
class CommunityCollectionFile {
  final String id;
  final String title;
  final String? description;
  final CommunityMediaType mediaType;
  final int? durationSec;
  final int? fileSizeBytes;
  final CommunityDifficulty? difficulty;
  final DateTime? publishedAt;
  final int sortOrder;
  final String mediaUrl;
  final String? mediaUrlChina;

  const CommunityCollectionFile({
    required this.id,
    required this.title,
    required this.description,
    required this.mediaType,
    required this.durationSec,
    required this.fileSizeBytes,
    required this.difficulty,
    required this.publishedAt,
    required this.sortOrder,
    required this.mediaUrl,
    this.mediaUrlChina,
  });

  factory CommunityCollectionFile.fromJson(Map<String, Object?> json) {
    return CommunityCollectionFile(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      description: _nullableString(json, 'description'),
      mediaType: CommunityMediaType.fromJson(json['mediaType']),
      durationSec: _nullableInt(json, 'durationSec'),
      fileSizeBytes: _nullableInt(json, 'fileSizeBytes'),
      difficulty: CommunityDifficulty.fromJson(json['difficulty']),
      publishedAt: _nullableDateTime(json, 'publishedAt'),
      sortOrder: _requiredInt(json, 'sortOrder'),
      mediaUrl: _requiredString(json, 'mediaUrl'),
      mediaUrlChina: _nullableString(json, 'mediaUrlChina'),
    );
  }

  /// 序列化为社区合集 catalog 的本地缓存格式。
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'mediaType': mediaType.name,
    'durationSec': durationSec,
    'fileSizeBytes': fileSizeBytes,
    'difficulty': difficulty?.code,
    'publishedAt': publishedAt?.toIso8601String(),
    'sortOrder': sortOrder,
    'mediaUrl': mediaUrl,
    'mediaUrlChina': mediaUrlChina,
  };
}

/// 分页结果。
class PublicCollectionPage {
  final List<PublicCollectionCatalogEntry> items;
  final String? nextCursor;

  const PublicCollectionPage({required this.items, required this.nextCursor});
}

/// 合集文件分页结果。
class CommunityCollectionDetailPage {
  final PublicCollectionCatalogEntry collection;
  final List<CommunityCollectionFile> items;
  final String? nextCursor;

  const CommunityCollectionDetailPage({
    required this.collection,
    required this.items,
    required this.nextCursor,
  });
}

/// 单个社区文件的元数据和字幕详情。
class CommunityCollectionFileDetail {
  final CommunityCollectionFile file;
  final CommunitySubtitle subtitle;

  const CommunityCollectionFileDetail({
    required this.file,
    required this.subtitle,
  });
}

/// 单个文件字幕响应。
class CommunitySubtitle {
  final List<CommunitySubtitleSentence> sentences;
  final List<WordTimestamp> words;

  const CommunitySubtitle({required this.sentences, required this.words});

  factory CommunitySubtitle.fromJson(Map<String, Object?> json) {
    final sentenceValues = _requiredList(json, 'sentences');
    final wordValues = _requiredList(json, 'words');
    return CommunitySubtitle(
      sentences: sentenceValues
          .map(_asObjectMap)
          .map(CommunitySubtitleSentence.fromJson)
          .toList(growable: false),
      words: wordValues
          .map(_asObjectMap)
          .map(
            (json) => WordTimestamp.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList(growable: false),
    );
  }
}

/// 字幕句子；时间单位为秒，转换在模型边界完成。
class CommunitySubtitleSentence {
  final String text;
  final Duration startTime;
  final Duration endTime;

  const CommunitySubtitleSentence({
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  factory CommunitySubtitleSentence.fromJson(Map<String, Object?> json) {
    final text = _requiredString(json, 'text');
    final startTime = _secondsToDuration(json['startTime']);
    final endTime = _secondsToDuration(json['endTime']);
    if (text.trim().isEmpty || endTime < startTime) {
      throw const FormatException('Invalid community subtitle sentence');
    }
    return CommunitySubtitleSentence(
      text: text,
      startTime: startTime,
      endTime: endTime,
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing or invalid $key');
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Invalid $key');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('Missing or invalid $key');
}

int? _nullableInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toInt();
  throw FormatException('Invalid $key');
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  return DateTime.parse(_requiredString(json, key));
}

DateTime? _nullableDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Invalid $key');
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List<Object?>) return value;
  throw FormatException('Missing or invalid $key');
}

Map<String, Object?> _asObjectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  throw const FormatException('Expected JSON object');
}

Duration _secondsToDuration(Object? value) {
  if (value is! num || !value.isFinite || value < 0) {
    throw const FormatException('Invalid subtitle timestamp');
  }
  return Duration(milliseconds: (value * 1000).round());
}
