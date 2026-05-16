// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AudioItemsTable extends AudioItems
    with TableInfo<$AudioItemsTable, AudioItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptPathMeta = const VerificationMeta(
    'transcriptPath',
  );
  @override
  late final GeneratedColumn<String> transcriptPath = GeneratedColumn<String>(
    'transcript_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedDateMeta = const VerificationMeta(
    'addedDate',
  );
  @override
  late final GeneratedColumn<DateTime> addedDate = GeneratedColumn<DateTime>(
    'added_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalDurationMeta = const VerificationMeta(
    'totalDuration',
  );
  @override
  late final GeneratedColumn<int> totalDuration = GeneratedColumn<int>(
    'total_duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sentenceCountMeta = const VerificationMeta(
    'sentenceCount',
  );
  @override
  late final GeneratedColumn<int> sentenceCount = GeneratedColumn<int>(
    'sentence_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _transcriptSourceMeta = const VerificationMeta(
    'transcriptSource',
  );
  @override
  late final GeneratedColumn<int> transcriptSource = GeneratedColumn<int>(
    'transcript_source',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioSha256Meta = const VerificationMeta(
    'audioSha256',
  );
  @override
  late final GeneratedColumn<String> audioSha256 = GeneratedColumn<String>(
    'audio_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptLanguageMeta =
      const VerificationMeta('transcriptLanguage');
  @override
  late final GeneratedColumn<String> transcriptLanguage =
      GeneratedColumn<String>(
        'transcript_language',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordTimestampsJsonMeta =
      const VerificationMeta('wordTimestampsJson');
  @override
  late final GeneratedColumn<String> wordTimestampsJson =
      GeneratedColumn<String>(
        'word_timestamps_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteAudioIdMeta = const VerificationMeta(
    'remoteAudioId',
  );
  @override
  late final GeneratedColumn<String> remoteAudioId = GeneratedColumn<String>(
    'remote_audio_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalDateMeta = const VerificationMeta(
    'originalDate',
  );
  @override
  late final GeneratedColumn<DateTime> originalDate = GeneratedColumn<DateTime>(
    'original_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    audioPath,
    transcriptPath,
    addedDate,
    totalDuration,
    sentenceCount,
    wordCount,
    isPinned,
    transcriptSource,
    audioSha256,
    transcriptLanguage,
    updatedAt,
    deletedAt,
    wordTimestampsJson,
    syncStatus,
    remoteAudioId,
    originalDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('transcript_path')) {
      context.handle(
        _transcriptPathMeta,
        transcriptPath.isAcceptableOrUnknown(
          data['transcript_path']!,
          _transcriptPathMeta,
        ),
      );
    }
    if (data.containsKey('added_date')) {
      context.handle(
        _addedDateMeta,
        addedDate.isAcceptableOrUnknown(data['added_date']!, _addedDateMeta),
      );
    } else if (isInserting) {
      context.missing(_addedDateMeta);
    }
    if (data.containsKey('total_duration')) {
      context.handle(
        _totalDurationMeta,
        totalDuration.isAcceptableOrUnknown(
          data['total_duration']!,
          _totalDurationMeta,
        ),
      );
    }
    if (data.containsKey('sentence_count')) {
      context.handle(
        _sentenceCountMeta,
        sentenceCount.isAcceptableOrUnknown(
          data['sentence_count']!,
          _sentenceCountMeta,
        ),
      );
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('transcript_source')) {
      context.handle(
        _transcriptSourceMeta,
        transcriptSource.isAcceptableOrUnknown(
          data['transcript_source']!,
          _transcriptSourceMeta,
        ),
      );
    }
    if (data.containsKey('audio_sha256')) {
      context.handle(
        _audioSha256Meta,
        audioSha256.isAcceptableOrUnknown(
          data['audio_sha256']!,
          _audioSha256Meta,
        ),
      );
    }
    if (data.containsKey('transcript_language')) {
      context.handle(
        _transcriptLanguageMeta,
        transcriptLanguage.isAcceptableOrUnknown(
          data['transcript_language']!,
          _transcriptLanguageMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('word_timestamps_json')) {
      context.handle(
        _wordTimestampsJsonMeta,
        wordTimestampsJson.isAcceptableOrUnknown(
          data['word_timestamps_json']!,
          _wordTimestampsJsonMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('remote_audio_id')) {
      context.handle(
        _remoteAudioIdMeta,
        remoteAudioId.isAcceptableOrUnknown(
          data['remote_audio_id']!,
          _remoteAudioIdMeta,
        ),
      );
    }
    if (data.containsKey('original_date')) {
      context.handle(
        _originalDateMeta,
        originalDate.isAcceptableOrUnknown(
          data['original_date']!,
          _originalDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AudioItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      transcriptPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_path'],
      ),
      addedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_date'],
      )!,
      totalDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_duration'],
      )!,
      sentenceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_count'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      transcriptSource: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transcript_source'],
      ),
      audioSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_sha256'],
      ),
      transcriptLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_language'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      wordTimestampsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_timestamps_json'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      remoteAudioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_audio_id'],
      ),
      originalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}original_date'],
      ),
    );
  }

  @override
  $AudioItemsTable createAlias(String alias) {
    return $AudioItemsTable(attachedDatabase, alias);
  }
}

class AudioItem extends DataClass implements Insertable<AudioItem> {
  /// UUID 主键
  final String id;

  /// 音频名称
  final String name;

  /// 音频文件相对路径。
  ///
  /// NULL 表示音频尚未就绪（官方合集加入后、下载完成前）；非 NULL 表示文件已在本地。
  /// 是「音频是否可用」的单一真实来源。
  final String? audioPath;

  /// 字幕文件相对路径。
  ///
  /// NULL 表示无字幕或尚未下载；非 NULL 表示文件已在本地。
  final String? transcriptPath;

  /// 添加时间
  final DateTime addedDate;

  /// 时长（秒）
  final int totalDuration;

  /// 字幕句子数
  final int sentenceCount;

  /// 字幕单词数
  final int wordCount;

  /// 是否置顶
  final bool isPinned;

  /// 字幕来源：0=local, 1=ai, null=无字幕
  final int? transcriptSource;

  /// 音频文件 SHA256 指纹（缓存，避免重复计算）
  final String? audioSha256;

  /// AI 转录使用的语言（'en' / 'multi'）
  final String? transcriptLanguage;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 词级时间戳 JSON（AI 转录时由后端返回，与字幕一起管理）
  final String? wordTimestampsJson;

  /// 同步状态：0=synced, 1=pendingUpload, 2=pendingDelete
  final int syncStatus;

  /// 官方合集中该音频在后端的 UUID；仅官方合集音频有值。
  /// 用于同步比对（通过 remoteAudioId 反查本地行）。
  final String? remoteAudioId;

  /// 原始发布/播出日期。官方合集音频从后端 catalog 同步（如 VOA 某期的播出日期）；
  /// 用户自建音频保持 NULL。用于官方合集详情页「最早/最新发布」排序。
  final DateTime? originalDate;
  const AudioItem({
    required this.id,
    required this.name,
    this.audioPath,
    this.transcriptPath,
    required this.addedDate,
    required this.totalDuration,
    required this.sentenceCount,
    required this.wordCount,
    required this.isPinned,
    this.transcriptSource,
    this.audioSha256,
    this.transcriptLanguage,
    required this.updatedAt,
    this.deletedAt,
    this.wordTimestampsJson,
    required this.syncStatus,
    this.remoteAudioId,
    this.originalDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || transcriptPath != null) {
      map['transcript_path'] = Variable<String>(transcriptPath);
    }
    map['added_date'] = Variable<DateTime>(addedDate);
    map['total_duration'] = Variable<int>(totalDuration);
    map['sentence_count'] = Variable<int>(sentenceCount);
    map['word_count'] = Variable<int>(wordCount);
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || transcriptSource != null) {
      map['transcript_source'] = Variable<int>(transcriptSource);
    }
    if (!nullToAbsent || audioSha256 != null) {
      map['audio_sha256'] = Variable<String>(audioSha256);
    }
    if (!nullToAbsent || transcriptLanguage != null) {
      map['transcript_language'] = Variable<String>(transcriptLanguage);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || wordTimestampsJson != null) {
      map['word_timestamps_json'] = Variable<String>(wordTimestampsJson);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    if (!nullToAbsent || remoteAudioId != null) {
      map['remote_audio_id'] = Variable<String>(remoteAudioId);
    }
    if (!nullToAbsent || originalDate != null) {
      map['original_date'] = Variable<DateTime>(originalDate);
    }
    return map;
  }

  AudioItemsCompanion toCompanion(bool nullToAbsent) {
    return AudioItemsCompanion(
      id: Value(id),
      name: Value(name),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      transcriptPath: transcriptPath == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptPath),
      addedDate: Value(addedDate),
      totalDuration: Value(totalDuration),
      sentenceCount: Value(sentenceCount),
      wordCount: Value(wordCount),
      isPinned: Value(isPinned),
      transcriptSource: transcriptSource == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptSource),
      audioSha256: audioSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(audioSha256),
      transcriptLanguage: transcriptLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptLanguage),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      wordTimestampsJson: wordTimestampsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(wordTimestampsJson),
      syncStatus: Value(syncStatus),
      remoteAudioId: remoteAudioId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteAudioId),
      originalDate: originalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(originalDate),
    );
  }

  factory AudioItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioItem(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      transcriptPath: serializer.fromJson<String?>(json['transcriptPath']),
      addedDate: serializer.fromJson<DateTime>(json['addedDate']),
      totalDuration: serializer.fromJson<int>(json['totalDuration']),
      sentenceCount: serializer.fromJson<int>(json['sentenceCount']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      transcriptSource: serializer.fromJson<int?>(json['transcriptSource']),
      audioSha256: serializer.fromJson<String?>(json['audioSha256']),
      transcriptLanguage: serializer.fromJson<String?>(
        json['transcriptLanguage'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      wordTimestampsJson: serializer.fromJson<String?>(
        json['wordTimestampsJson'],
      ),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      remoteAudioId: serializer.fromJson<String?>(json['remoteAudioId']),
      originalDate: serializer.fromJson<DateTime?>(json['originalDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'audioPath': serializer.toJson<String?>(audioPath),
      'transcriptPath': serializer.toJson<String?>(transcriptPath),
      'addedDate': serializer.toJson<DateTime>(addedDate),
      'totalDuration': serializer.toJson<int>(totalDuration),
      'sentenceCount': serializer.toJson<int>(sentenceCount),
      'wordCount': serializer.toJson<int>(wordCount),
      'isPinned': serializer.toJson<bool>(isPinned),
      'transcriptSource': serializer.toJson<int?>(transcriptSource),
      'audioSha256': serializer.toJson<String?>(audioSha256),
      'transcriptLanguage': serializer.toJson<String?>(transcriptLanguage),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'wordTimestampsJson': serializer.toJson<String?>(wordTimestampsJson),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'remoteAudioId': serializer.toJson<String?>(remoteAudioId),
      'originalDate': serializer.toJson<DateTime?>(originalDate),
    };
  }

  AudioItem copyWith({
    String? id,
    String? name,
    Value<String?> audioPath = const Value.absent(),
    Value<String?> transcriptPath = const Value.absent(),
    DateTime? addedDate,
    int? totalDuration,
    int? sentenceCount,
    int? wordCount,
    bool? isPinned,
    Value<int?> transcriptSource = const Value.absent(),
    Value<String?> audioSha256 = const Value.absent(),
    Value<String?> transcriptLanguage = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> wordTimestampsJson = const Value.absent(),
    int? syncStatus,
    Value<String?> remoteAudioId = const Value.absent(),
    Value<DateTime?> originalDate = const Value.absent(),
  }) => AudioItem(
    id: id ?? this.id,
    name: name ?? this.name,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    transcriptPath: transcriptPath.present
        ? transcriptPath.value
        : this.transcriptPath,
    addedDate: addedDate ?? this.addedDate,
    totalDuration: totalDuration ?? this.totalDuration,
    sentenceCount: sentenceCount ?? this.sentenceCount,
    wordCount: wordCount ?? this.wordCount,
    isPinned: isPinned ?? this.isPinned,
    transcriptSource: transcriptSource.present
        ? transcriptSource.value
        : this.transcriptSource,
    audioSha256: audioSha256.present ? audioSha256.value : this.audioSha256,
    transcriptLanguage: transcriptLanguage.present
        ? transcriptLanguage.value
        : this.transcriptLanguage,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    wordTimestampsJson: wordTimestampsJson.present
        ? wordTimestampsJson.value
        : this.wordTimestampsJson,
    syncStatus: syncStatus ?? this.syncStatus,
    remoteAudioId: remoteAudioId.present
        ? remoteAudioId.value
        : this.remoteAudioId,
    originalDate: originalDate.present ? originalDate.value : this.originalDate,
  );
  AudioItem copyWithCompanion(AudioItemsCompanion data) {
    return AudioItem(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      transcriptPath: data.transcriptPath.present
          ? data.transcriptPath.value
          : this.transcriptPath,
      addedDate: data.addedDate.present ? data.addedDate.value : this.addedDate,
      totalDuration: data.totalDuration.present
          ? data.totalDuration.value
          : this.totalDuration,
      sentenceCount: data.sentenceCount.present
          ? data.sentenceCount.value
          : this.sentenceCount,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      transcriptSource: data.transcriptSource.present
          ? data.transcriptSource.value
          : this.transcriptSource,
      audioSha256: data.audioSha256.present
          ? data.audioSha256.value
          : this.audioSha256,
      transcriptLanguage: data.transcriptLanguage.present
          ? data.transcriptLanguage.value
          : this.transcriptLanguage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      wordTimestampsJson: data.wordTimestampsJson.present
          ? data.wordTimestampsJson.value
          : this.wordTimestampsJson,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      remoteAudioId: data.remoteAudioId.present
          ? data.remoteAudioId.value
          : this.remoteAudioId,
      originalDate: data.originalDate.present
          ? data.originalDate.value
          : this.originalDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioItem(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('audioPath: $audioPath, ')
          ..write('transcriptPath: $transcriptPath, ')
          ..write('addedDate: $addedDate, ')
          ..write('totalDuration: $totalDuration, ')
          ..write('sentenceCount: $sentenceCount, ')
          ..write('wordCount: $wordCount, ')
          ..write('isPinned: $isPinned, ')
          ..write('transcriptSource: $transcriptSource, ')
          ..write('audioSha256: $audioSha256, ')
          ..write('transcriptLanguage: $transcriptLanguage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('wordTimestampsJson: $wordTimestampsJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('remoteAudioId: $remoteAudioId, ')
          ..write('originalDate: $originalDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    audioPath,
    transcriptPath,
    addedDate,
    totalDuration,
    sentenceCount,
    wordCount,
    isPinned,
    transcriptSource,
    audioSha256,
    transcriptLanguage,
    updatedAt,
    deletedAt,
    wordTimestampsJson,
    syncStatus,
    remoteAudioId,
    originalDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioItem &&
          other.id == this.id &&
          other.name == this.name &&
          other.audioPath == this.audioPath &&
          other.transcriptPath == this.transcriptPath &&
          other.addedDate == this.addedDate &&
          other.totalDuration == this.totalDuration &&
          other.sentenceCount == this.sentenceCount &&
          other.wordCount == this.wordCount &&
          other.isPinned == this.isPinned &&
          other.transcriptSource == this.transcriptSource &&
          other.audioSha256 == this.audioSha256 &&
          other.transcriptLanguage == this.transcriptLanguage &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.wordTimestampsJson == this.wordTimestampsJson &&
          other.syncStatus == this.syncStatus &&
          other.remoteAudioId == this.remoteAudioId &&
          other.originalDate == this.originalDate);
}

class AudioItemsCompanion extends UpdateCompanion<AudioItem> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> audioPath;
  final Value<String?> transcriptPath;
  final Value<DateTime> addedDate;
  final Value<int> totalDuration;
  final Value<int> sentenceCount;
  final Value<int> wordCount;
  final Value<bool> isPinned;
  final Value<int?> transcriptSource;
  final Value<String?> audioSha256;
  final Value<String?> transcriptLanguage;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> wordTimestampsJson;
  final Value<int> syncStatus;
  final Value<String?> remoteAudioId;
  final Value<DateTime?> originalDate;
  final Value<int> rowid;
  const AudioItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.transcriptPath = const Value.absent(),
    this.addedDate = const Value.absent(),
    this.totalDuration = const Value.absent(),
    this.sentenceCount = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.transcriptSource = const Value.absent(),
    this.audioSha256 = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.wordTimestampsJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.remoteAudioId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioItemsCompanion.insert({
    required String id,
    required String name,
    this.audioPath = const Value.absent(),
    this.transcriptPath = const Value.absent(),
    required DateTime addedDate,
    this.totalDuration = const Value.absent(),
    this.sentenceCount = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.transcriptSource = const Value.absent(),
    this.audioSha256 = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.wordTimestampsJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.remoteAudioId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       addedDate = Value(addedDate),
       updatedAt = Value(updatedAt);
  static Insertable<AudioItem> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? audioPath,
    Expression<String>? transcriptPath,
    Expression<DateTime>? addedDate,
    Expression<int>? totalDuration,
    Expression<int>? sentenceCount,
    Expression<int>? wordCount,
    Expression<bool>? isPinned,
    Expression<int>? transcriptSource,
    Expression<String>? audioSha256,
    Expression<String>? transcriptLanguage,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? wordTimestampsJson,
    Expression<int>? syncStatus,
    Expression<String>? remoteAudioId,
    Expression<DateTime>? originalDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (audioPath != null) 'audio_path': audioPath,
      if (transcriptPath != null) 'transcript_path': transcriptPath,
      if (addedDate != null) 'added_date': addedDate,
      if (totalDuration != null) 'total_duration': totalDuration,
      if (sentenceCount != null) 'sentence_count': sentenceCount,
      if (wordCount != null) 'word_count': wordCount,
      if (isPinned != null) 'is_pinned': isPinned,
      if (transcriptSource != null) 'transcript_source': transcriptSource,
      if (audioSha256 != null) 'audio_sha256': audioSha256,
      if (transcriptLanguage != null) 'transcript_language': transcriptLanguage,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (wordTimestampsJson != null)
        'word_timestamps_json': wordTimestampsJson,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (remoteAudioId != null) 'remote_audio_id': remoteAudioId,
      if (originalDate != null) 'original_date': originalDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? audioPath,
    Value<String?>? transcriptPath,
    Value<DateTime>? addedDate,
    Value<int>? totalDuration,
    Value<int>? sentenceCount,
    Value<int>? wordCount,
    Value<bool>? isPinned,
    Value<int?>? transcriptSource,
    Value<String?>? audioSha256,
    Value<String?>? transcriptLanguage,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String?>? wordTimestampsJson,
    Value<int>? syncStatus,
    Value<String?>? remoteAudioId,
    Value<DateTime?>? originalDate,
    Value<int>? rowid,
  }) {
    return AudioItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      audioPath: audioPath ?? this.audioPath,
      transcriptPath: transcriptPath ?? this.transcriptPath,
      addedDate: addedDate ?? this.addedDate,
      totalDuration: totalDuration ?? this.totalDuration,
      sentenceCount: sentenceCount ?? this.sentenceCount,
      wordCount: wordCount ?? this.wordCount,
      isPinned: isPinned ?? this.isPinned,
      transcriptSource: transcriptSource ?? this.transcriptSource,
      audioSha256: audioSha256 ?? this.audioSha256,
      transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      wordTimestampsJson: wordTimestampsJson ?? this.wordTimestampsJson,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteAudioId: remoteAudioId ?? this.remoteAudioId,
      originalDate: originalDate ?? this.originalDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (transcriptPath.present) {
      map['transcript_path'] = Variable<String>(transcriptPath.value);
    }
    if (addedDate.present) {
      map['added_date'] = Variable<DateTime>(addedDate.value);
    }
    if (totalDuration.present) {
      map['total_duration'] = Variable<int>(totalDuration.value);
    }
    if (sentenceCount.present) {
      map['sentence_count'] = Variable<int>(sentenceCount.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (transcriptSource.present) {
      map['transcript_source'] = Variable<int>(transcriptSource.value);
    }
    if (audioSha256.present) {
      map['audio_sha256'] = Variable<String>(audioSha256.value);
    }
    if (transcriptLanguage.present) {
      map['transcript_language'] = Variable<String>(transcriptLanguage.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (wordTimestampsJson.present) {
      map['word_timestamps_json'] = Variable<String>(wordTimestampsJson.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (remoteAudioId.present) {
      map['remote_audio_id'] = Variable<String>(remoteAudioId.value);
    }
    if (originalDate.present) {
      map['original_date'] = Variable<DateTime>(originalDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('audioPath: $audioPath, ')
          ..write('transcriptPath: $transcriptPath, ')
          ..write('addedDate: $addedDate, ')
          ..write('totalDuration: $totalDuration, ')
          ..write('sentenceCount: $sentenceCount, ')
          ..write('wordCount: $wordCount, ')
          ..write('isPinned: $isPinned, ')
          ..write('transcriptSource: $transcriptSource, ')
          ..write('audioSha256: $audioSha256, ')
          ..write('transcriptLanguage: $transcriptLanguage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('wordTimestampsJson: $wordTimestampsJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('remoteAudioId: $remoteAudioId, ')
          ..write('originalDate: $originalDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionsTable extends Collections
    with TableInfo<$CollectionsTable, Collection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdDateMeta = const VerificationMeta(
    'createdDate',
  );
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
    'created_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deprecatedAtMeta = const VerificationMeta(
    'deprecatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deprecatedAt = GeneratedColumn<DateTime>(
    'deprecated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdDate,
    isPinned,
    updatedAt,
    deletedAt,
    syncStatus,
    source,
    remoteId,
    coverUrl,
    description,
    deprecatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Collection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
        _createdDateMeta,
        createdDate.isAcceptableOrUnknown(
          data['created_date']!,
          _createdDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('deprecated_at')) {
      context.handle(
        _deprecatedAtMeta,
        deprecatedAt.isAcceptableOrUnknown(
          data['deprecated_at']!,
          _deprecatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Collection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Collection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_date'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      deprecatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deprecated_at'],
      ),
    );
  }

  @override
  $CollectionsTable createAlias(String alias) {
    return $CollectionsTable(attachedDatabase, alias);
  }
}

class Collection extends DataClass implements Insertable<Collection> {
  /// UUID 主键
  final String id;

  /// 合集名称
  final String name;

  /// 创建时间
  final DateTime createdDate;

  /// 置顶
  final bool isPinned;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 同步状态
  final int syncStatus;

  /// 合集来源：`local`（用户自建）| `official`（从后端加入的官方合集）
  ///
  /// 老数据默认 `local`。不可变 —— 决定了 UI 是否显示官方 badge、
  /// 长按菜单是否允许重命名/删除音频、移除流程是否彻底清空等。
  final String source;

  /// 官方合集在后端的 UUID；仅 source='official' 时有值。
  /// 与 [source]=official 联合唯一（见 v29 迁移里的唯一索引）。
  final String? remoteId;

  /// 合集封面图 URL；用户自建合集目前为 null。
  final String? coverUrl;

  /// 合集描述；用户自建合集目前为 null。
  final String? description;

  /// 官方合集被后端标记下架的时间；非 null 时 UI 置灰、sync 不再请求。
  /// source='local' 永远为 null。
  final DateTime? deprecatedAt;
  const Collection({
    required this.id,
    required this.name,
    required this.createdDate,
    required this.isPinned,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
    required this.source,
    this.remoteId,
    this.coverUrl,
    this.description,
    this.deprecatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_date'] = Variable<DateTime>(createdDate);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || deprecatedAt != null) {
      map['deprecated_at'] = Variable<DateTime>(deprecatedAt);
    }
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      createdDate: Value(createdDate),
      isPinned: Value(isPinned),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
      source: Value(source),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      deprecatedAt: deprecatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deprecatedAt),
    );
  }

  factory Collection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Collection(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      source: serializer.fromJson<String>(json['source']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      description: serializer.fromJson<String?>(json['description']),
      deprecatedAt: serializer.fromJson<DateTime?>(json['deprecatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'isPinned': serializer.toJson<bool>(isPinned),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'source': serializer.toJson<String>(source),
      'remoteId': serializer.toJson<String?>(remoteId),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'description': serializer.toJson<String?>(description),
      'deprecatedAt': serializer.toJson<DateTime?>(deprecatedAt),
    };
  }

  Collection copyWith({
    String? id,
    String? name,
    DateTime? createdDate,
    bool? isPinned,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
    String? source,
    Value<String?> remoteId = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<DateTime?> deprecatedAt = const Value.absent(),
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    createdDate: createdDate ?? this.createdDate,
    isPinned: isPinned ?? this.isPinned,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    source: source ?? this.source,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    description: description.present ? description.value : this.description,
    deprecatedAt: deprecatedAt.present ? deprecatedAt.value : this.deprecatedAt,
  );
  Collection copyWithCompanion(CollectionsCompanion data) {
    return Collection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdDate: data.createdDate.present
          ? data.createdDate.value
          : this.createdDate,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      source: data.source.present ? data.source.value : this.source,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      description: data.description.present
          ? data.description.value
          : this.description,
      deprecatedAt: data.deprecatedAt.present
          ? data.deprecatedAt.value
          : this.deprecatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdDate: $createdDate, ')
          ..write('isPinned: $isPinned, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('source: $source, ')
          ..write('remoteId: $remoteId, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('description: $description, ')
          ..write('deprecatedAt: $deprecatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdDate,
    isPinned,
    updatedAt,
    deletedAt,
    syncStatus,
    source,
    remoteId,
    coverUrl,
    description,
    deprecatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdDate == this.createdDate &&
          other.isPinned == this.isPinned &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus &&
          other.source == this.source &&
          other.remoteId == this.remoteId &&
          other.coverUrl == this.coverUrl &&
          other.description == this.description &&
          other.deprecatedAt == this.deprecatedAt);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdDate;
  final Value<bool> isPinned;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  final Value<String> source;
  final Value<String?> remoteId;
  final Value<String?> coverUrl;
  final Value<String?> description;
  final Value<DateTime?> deprecatedAt;
  final Value<int> rowid;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.source = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.deprecatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdDate,
    this.isPinned = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.source = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.description = const Value.absent(),
    this.deprecatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdDate = Value(createdDate),
       updatedAt = Value(updatedAt);
  static Insertable<Collection> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdDate,
    Expression<bool>? isPinned,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? syncStatus,
    Expression<String>? source,
    Expression<String>? remoteId,
    Expression<String>? coverUrl,
    Expression<String>? description,
    Expression<DateTime>? deprecatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdDate != null) 'created_date': createdDate,
      if (isPinned != null) 'is_pinned': isPinned,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (source != null) 'source': source,
      if (remoteId != null) 'remote_id': remoteId,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (description != null) 'description': description,
      if (deprecatedAt != null) 'deprecated_at': deprecatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdDate,
    Value<bool>? isPinned,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
    Value<String>? source,
    Value<String?>? remoteId,
    Value<String?>? coverUrl,
    Value<String?>? description,
    Value<DateTime?>? deprecatedAt,
    Value<int>? rowid,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdDate: createdDate ?? this.createdDate,
      isPinned: isPinned ?? this.isPinned,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      source: source ?? this.source,
      remoteId: remoteId ?? this.remoteId,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      deprecatedAt: deprecatedAt ?? this.deprecatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (deprecatedAt.present) {
      map['deprecated_at'] = Variable<DateTime>(deprecatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdDate: $createdDate, ')
          ..write('isPinned: $isPinned, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('source: $source, ')
          ..write('remoteId: $remoteId, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('description: $description, ')
          ..write('deprecatedAt: $deprecatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionAudioItemsTable extends CollectionAudioItems
    with TableInfo<$CollectionAudioItemsTable, CollectionAudioItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionAudioItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES collections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _audioItemIdMeta = const VerificationMeta(
    'audioItemId',
  );
  @override
  late final GeneratedColumn<String> audioItemId = GeneratedColumn<String>(
    'audio_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES audio_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionId,
    audioItemId,
    sortOrder,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_audio_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionAudioItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('audio_item_id')) {
      context.handle(
        _audioItemIdMeta,
        audioItemId.isAcceptableOrUnknown(
          data['audio_item_id']!,
          _audioItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioItemIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, audioItemId};
  @override
  CollectionAudioItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionAudioItem(
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      audioItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_item_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $CollectionAudioItemsTable createAlias(String alias) {
    return $CollectionAudioItemsTable(attachedDatabase, alias);
  }
}

class CollectionAudioItem extends DataClass
    implements Insertable<CollectionAudioItem> {
  /// 合集 ID，外键关联 collections.id
  final String collectionId;

  /// 音频 ID，外键关联 audio_items.id
  final String audioItemId;

  /// 在合集内的排序序号
  final int sortOrder;

  /// 加入合集的时间
  final DateTime addedAt;
  const CollectionAudioItem({
    required this.collectionId,
    required this.audioItemId,
    required this.sortOrder,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<String>(collectionId);
    map['audio_item_id'] = Variable<String>(audioItemId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  CollectionAudioItemsCompanion toCompanion(bool nullToAbsent) {
    return CollectionAudioItemsCompanion(
      collectionId: Value(collectionId),
      audioItemId: Value(audioItemId),
      sortOrder: Value(sortOrder),
      addedAt: Value(addedAt),
    );
  }

  factory CollectionAudioItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionAudioItem(
      collectionId: serializer.fromJson<String>(json['collectionId']),
      audioItemId: serializer.fromJson<String>(json['audioItemId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<String>(collectionId),
      'audioItemId': serializer.toJson<String>(audioItemId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  CollectionAudioItem copyWith({
    String? collectionId,
    String? audioItemId,
    int? sortOrder,
    DateTime? addedAt,
  }) => CollectionAudioItem(
    collectionId: collectionId ?? this.collectionId,
    audioItemId: audioItemId ?? this.audioItemId,
    sortOrder: sortOrder ?? this.sortOrder,
    addedAt: addedAt ?? this.addedAt,
  );
  CollectionAudioItem copyWithCompanion(CollectionAudioItemsCompanion data) {
    return CollectionAudioItem(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      audioItemId: data.audioItemId.present
          ? data.audioItemId.value
          : this.audioItemId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionAudioItem(')
          ..write('collectionId: $collectionId, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(collectionId, audioItemId, sortOrder, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionAudioItem &&
          other.collectionId == this.collectionId &&
          other.audioItemId == this.audioItemId &&
          other.sortOrder == this.sortOrder &&
          other.addedAt == this.addedAt);
}

class CollectionAudioItemsCompanion
    extends UpdateCompanion<CollectionAudioItem> {
  final Value<String> collectionId;
  final Value<String> audioItemId;
  final Value<int> sortOrder;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const CollectionAudioItemsCompanion({
    this.collectionId = const Value.absent(),
    this.audioItemId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionAudioItemsCompanion.insert({
    required String collectionId,
    required String audioItemId,
    this.sortOrder = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       audioItemId = Value(audioItemId),
       addedAt = Value(addedAt);
  static Insertable<CollectionAudioItem> custom({
    Expression<String>? collectionId,
    Expression<String>? audioItemId,
    Expression<int>? sortOrder,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (audioItemId != null) 'audio_item_id': audioItemId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionAudioItemsCompanion copyWith({
    Value<String>? collectionId,
    Value<String>? audioItemId,
    Value<int>? sortOrder,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return CollectionAudioItemsCompanion(
      collectionId: collectionId ?? this.collectionId,
      audioItemId: audioItemId ?? this.audioItemId,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (audioItemId.present) {
      map['audio_item_id'] = Variable<String>(audioItemId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionAudioItemsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _audioItemIdMeta = const VerificationMeta(
    'audioItemId',
  );
  @override
  late final GeneratedColumn<String> audioItemId = GeneratedColumn<String>(
    'audio_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES audio_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sentenceIndexMeta = const VerificationMeta(
    'sentenceIndex',
  );
  @override
  late final GeneratedColumn<int> sentenceIndex = GeneratedColumn<int>(
    'sentence_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentenceTextMeta = const VerificationMeta(
    'sentenceText',
  );
  @override
  late final GeneratedColumn<String> sentenceText = GeneratedColumn<String>(
    'sentence_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<double> startTime = GeneratedColumn<double>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<double> endTime = GeneratedColumn<double>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    audioItemId,
    sentenceIndex,
    sentenceText,
    startTime,
    endTime,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('audio_item_id')) {
      context.handle(
        _audioItemIdMeta,
        audioItemId.isAcceptableOrUnknown(
          data['audio_item_id']!,
          _audioItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioItemIdMeta);
    }
    if (data.containsKey('sentence_index')) {
      context.handle(
        _sentenceIndexMeta,
        sentenceIndex.isAcceptableOrUnknown(
          data['sentence_index']!,
          _sentenceIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sentenceIndexMeta);
    }
    if (data.containsKey('sentence_text')) {
      context.handle(
        _sentenceTextMeta,
        sentenceText.isAcceptableOrUnknown(
          data['sentence_text']!,
          _sentenceTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sentenceTextMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {audioItemId, sentenceIndex},
  ];
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      audioItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_item_id'],
      )!,
      sentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_index'],
      )!,
      sentenceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_text'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_time'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  /// 自增主键
  final int id;

  /// 音频 ID，外键关联 audio_items.id
  final String audioItemId;

  /// 句子索引（快速查询 + 向后兼容）
  final int sentenceIndex;

  /// 句子文本（防止索引错位时可通过文本匹配）
  final String sentenceText;

  /// 句子起始时间（秒）
  final double startTime;

  /// 句子结束时间（秒）
  final double endTime;

  /// 创建时间
  final DateTime createdAt;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 同步状态
  final int syncStatus;
  const Bookmark({
    required this.id,
    required this.audioItemId,
    required this.sentenceIndex,
    required this.sentenceText,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['audio_item_id'] = Variable<String>(audioItemId);
    map['sentence_index'] = Variable<int>(sentenceIndex);
    map['sentence_text'] = Variable<String>(sentenceText);
    map['start_time'] = Variable<double>(startTime);
    map['end_time'] = Variable<double>(endTime);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      audioItemId: Value(audioItemId),
      sentenceIndex: Value(sentenceIndex),
      sentenceText: Value(sentenceText),
      startTime: Value(startTime),
      endTime: Value(endTime),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<int>(json['id']),
      audioItemId: serializer.fromJson<String>(json['audioItemId']),
      sentenceIndex: serializer.fromJson<int>(json['sentenceIndex']),
      sentenceText: serializer.fromJson<String>(json['sentenceText']),
      startTime: serializer.fromJson<double>(json['startTime']),
      endTime: serializer.fromJson<double>(json['endTime']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'audioItemId': serializer.toJson<String>(audioItemId),
      'sentenceIndex': serializer.toJson<int>(sentenceIndex),
      'sentenceText': serializer.toJson<String>(sentenceText),
      'startTime': serializer.toJson<double>(startTime),
      'endTime': serializer.toJson<double>(endTime),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  Bookmark copyWith({
    int? id,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    double? startTime,
    double? endTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => Bookmark(
    id: id ?? this.id,
    audioItemId: audioItemId ?? this.audioItemId,
    sentenceIndex: sentenceIndex ?? this.sentenceIndex,
    sentenceText: sentenceText ?? this.sentenceText,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      audioItemId: data.audioItemId.present
          ? data.audioItemId.value
          : this.audioItemId,
      sentenceIndex: data.sentenceIndex.present
          ? data.sentenceIndex.value
          : this.sentenceIndex,
      sentenceText: data.sentenceText.present
          ? data.sentenceText.value
          : this.sentenceText,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('sentenceText: $sentenceText, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    audioItemId,
    sentenceIndex,
    sentenceText,
    startTime,
    endTime,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.audioItemId == this.audioItemId &&
          other.sentenceIndex == this.sentenceIndex &&
          other.sentenceText == this.sentenceText &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<String> audioItemId;
  final Value<int> sentenceIndex;
  final Value<String> sentenceText;
  final Value<double> startTime;
  final Value<double> endTime;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.audioItemId = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.sentenceText = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String audioItemId,
    required int sentenceIndex,
    required String sentenceText,
    required double startTime,
    required double endTime,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : audioItemId = Value(audioItemId),
       sentenceIndex = Value(sentenceIndex),
       sentenceText = Value(sentenceText),
       startTime = Value(startTime),
       endTime = Value(endTime),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<String>? audioItemId,
    Expression<int>? sentenceIndex,
    Expression<String>? sentenceText,
    Expression<double>? startTime,
    Expression<double>? endTime,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (audioItemId != null) 'audio_item_id': audioItemId,
      if (sentenceIndex != null) 'sentence_index': sentenceIndex,
      if (sentenceText != null) 'sentence_text': sentenceText,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? audioItemId,
    Value<int>? sentenceIndex,
    Value<String>? sentenceText,
    Value<double>? startTime,
    Value<double>? endTime,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      audioItemId: audioItemId ?? this.audioItemId,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      sentenceText: sentenceText ?? this.sentenceText,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (audioItemId.present) {
      map['audio_item_id'] = Variable<String>(audioItemId.value);
    }
    if (sentenceIndex.present) {
      map['sentence_index'] = Variable<int>(sentenceIndex.value);
    }
    if (sentenceText.present) {
      map['sentence_text'] = Variable<String>(sentenceText.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<double>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<double>(endTime.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('sentenceText: $sentenceText, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $PlaybackStatesTable extends PlaybackStates
    with TableInfo<$PlaybackStatesTable, PlaybackState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _audioItemIdMeta = const VerificationMeta(
    'audioItemId',
  );
  @override
  late final GeneratedColumn<String> audioItemId = GeneratedColumn<String>(
    'audio_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES audio_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playlistModeMeta = const VerificationMeta(
    'playlistMode',
  );
  @override
  late final GeneratedColumn<int> playlistMode = GeneratedColumn<int>(
    'playlist_mode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    audioItemId,
    positionMs,
    playlistMode,
    savedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('audio_item_id')) {
      context.handle(
        _audioItemIdMeta,
        audioItemId.isAcceptableOrUnknown(
          data['audio_item_id']!,
          _audioItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioItemIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('playlist_mode')) {
      context.handle(
        _playlistModeMeta,
        playlistMode.isAcceptableOrUnknown(
          data['playlist_mode']!,
          _playlistModeMeta,
        ),
      );
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {audioItemId};
  @override
  PlaybackState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackState(
      audioItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_item_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      playlistMode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_mode'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $PlaybackStatesTable createAlias(String alias) {
    return $PlaybackStatesTable(attachedDatabase, alias);
  }
}

class PlaybackState extends DataClass implements Insertable<PlaybackState> {
  /// 音频 ID，主键 + 外键关联 audio_items.id
  final String audioItemId;

  /// 播放位置（毫秒）
  final int positionMs;

  /// 播放模式枚举：0=full, 1=bookmarks
  final int playlistMode;

  /// 保存时间
  final DateTime savedAt;
  const PlaybackState({
    required this.audioItemId,
    required this.positionMs,
    required this.playlistMode,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['audio_item_id'] = Variable<String>(audioItemId);
    map['position_ms'] = Variable<int>(positionMs);
    map['playlist_mode'] = Variable<int>(playlistMode);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  PlaybackStatesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackStatesCompanion(
      audioItemId: Value(audioItemId),
      positionMs: Value(positionMs),
      playlistMode: Value(playlistMode),
      savedAt: Value(savedAt),
    );
  }

  factory PlaybackState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackState(
      audioItemId: serializer.fromJson<String>(json['audioItemId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      playlistMode: serializer.fromJson<int>(json['playlistMode']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'audioItemId': serializer.toJson<String>(audioItemId),
      'positionMs': serializer.toJson<int>(positionMs),
      'playlistMode': serializer.toJson<int>(playlistMode),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  PlaybackState copyWith({
    String? audioItemId,
    int? positionMs,
    int? playlistMode,
    DateTime? savedAt,
  }) => PlaybackState(
    audioItemId: audioItemId ?? this.audioItemId,
    positionMs: positionMs ?? this.positionMs,
    playlistMode: playlistMode ?? this.playlistMode,
    savedAt: savedAt ?? this.savedAt,
  );
  PlaybackState copyWithCompanion(PlaybackStatesCompanion data) {
    return PlaybackState(
      audioItemId: data.audioItemId.present
          ? data.audioItemId.value
          : this.audioItemId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      playlistMode: data.playlistMode.present
          ? data.playlistMode.value
          : this.playlistMode,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackState(')
          ..write('audioItemId: $audioItemId, ')
          ..write('positionMs: $positionMs, ')
          ..write('playlistMode: $playlistMode, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(audioItemId, positionMs, playlistMode, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackState &&
          other.audioItemId == this.audioItemId &&
          other.positionMs == this.positionMs &&
          other.playlistMode == this.playlistMode &&
          other.savedAt == this.savedAt);
}

class PlaybackStatesCompanion extends UpdateCompanion<PlaybackState> {
  final Value<String> audioItemId;
  final Value<int> positionMs;
  final Value<int> playlistMode;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const PlaybackStatesCompanion({
    this.audioItemId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.playlistMode = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackStatesCompanion.insert({
    required String audioItemId,
    required int positionMs,
    this.playlistMode = const Value.absent(),
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : audioItemId = Value(audioItemId),
       positionMs = Value(positionMs),
       savedAt = Value(savedAt);
  static Insertable<PlaybackState> custom({
    Expression<String>? audioItemId,
    Expression<int>? positionMs,
    Expression<int>? playlistMode,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (audioItemId != null) 'audio_item_id': audioItemId,
      if (positionMs != null) 'position_ms': positionMs,
      if (playlistMode != null) 'playlist_mode': playlistMode,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackStatesCompanion copyWith({
    Value<String>? audioItemId,
    Value<int>? positionMs,
    Value<int>? playlistMode,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return PlaybackStatesCompanion(
      audioItemId: audioItemId ?? this.audioItemId,
      positionMs: positionMs ?? this.positionMs,
      playlistMode: playlistMode ?? this.playlistMode,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (audioItemId.present) {
      map['audio_item_id'] = Variable<String>(audioItemId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (playlistMode.present) {
      map['playlist_mode'] = Variable<int>(playlistMode.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStatesCompanion(')
          ..write('audioItemId: $audioItemId, ')
          ..write('positionMs: $positionMs, ')
          ..write('playlistMode: $playlistMode, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningProgressesTable extends LearningProgresses
    with TableInfo<$LearningProgressesTable, LearningProgressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _audioItemIdMeta = const VerificationMeta(
    'audioItemId',
  );
  @override
  late final GeneratedColumn<String> audioItemId = GeneratedColumn<String>(
    'audio_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES audio_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _currentStageMeta = const VerificationMeta(
    'currentStage',
  );
  @override
  late final GeneratedColumn<String> currentStage = GeneratedColumn<String>(
    'current_stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('firstLearn'),
  );
  static const VerificationMeta _currentSubStageMeta = const VerificationMeta(
    'currentSubStage',
  );
  @override
  late final GeneratedColumn<String> currentSubStage = GeneratedColumn<String>(
    'current_sub_stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('blindListen'),
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<int> difficulty = GeneratedColumn<int>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _firstLearnCompletedAtMeta =
      const VerificationMeta('firstLearnCompletedAt');
  @override
  late final GeneratedColumn<DateTime> firstLearnCompletedAt =
      GeneratedColumn<DateTime>(
        'first_learn_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastStageCompletedAtMeta =
      const VerificationMeta('lastStageCompletedAt');
  @override
  late final GeneratedColumn<DateTime> lastStageCompletedAt =
      GeneratedColumn<DateTime>(
        'last_stage_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _currentStageStartedAtMeta =
      const VerificationMeta('currentStageStartedAt');
  @override
  late final GeneratedColumn<DateTime> currentStageStartedAt =
      GeneratedColumn<DateTime>(
        'current_stage_started_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _totalStudyDurationMsMeta =
      const VerificationMeta('totalStudyDurationMs');
  @override
  late final GeneratedColumn<int> totalStudyDurationMs = GeneratedColumn<int>(
    'total_study_duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blindListenPassCountMeta =
      const VerificationMeta('blindListenPassCount');
  @override
  late final GeneratedColumn<int> blindListenPassCount = GeneratedColumn<int>(
    'blind_listen_pass_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _intensiveListenSentenceIndexMeta =
      const VerificationMeta('intensiveListenSentenceIndex');
  @override
  late final GeneratedColumn<int> intensiveListenSentenceIndex =
      GeneratedColumn<int>(
        'intensive_listen_sentence_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _intensiveListenDifficultCountMeta =
      const VerificationMeta('intensiveListenDifficultCount');
  @override
  late final GeneratedColumn<int> intensiveListenDifficultCount =
      GeneratedColumn<int>(
        'intensive_listen_difficult_count',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _intensiveListenPassCountMeta =
      const VerificationMeta('intensiveListenPassCount');
  @override
  late final GeneratedColumn<int> intensiveListenPassCount =
      GeneratedColumn<int>(
        'intensive_listen_pass_count',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _shadowingPassCountMeta =
      const VerificationMeta('shadowingPassCount');
  @override
  late final GeneratedColumn<int> shadowingPassCount = GeneratedColumn<int>(
    'shadowing_pass_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shadowingSentenceIndexMeta =
      const VerificationMeta('shadowingSentenceIndex');
  @override
  late final GeneratedColumn<int> shadowingSentenceIndex = GeneratedColumn<int>(
    'shadowing_sentence_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultPracticeSentenceIndexMeta =
      const VerificationMeta('difficultPracticeSentenceIndex');
  @override
  late final GeneratedColumn<int> difficultPracticeSentenceIndex =
      GeneratedColumn<int>(
        'difficult_practice_sentence_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _retellParagraphIndexMeta =
      const VerificationMeta('retellParagraphIndex');
  @override
  late final GeneratedColumn<int> retellParagraphIndex = GeneratedColumn<int>(
    'retell_paragraph_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retellPassCountMeta = const VerificationMeta(
    'retellPassCount',
  );
  @override
  late final GeneratedColumn<int> retellPassCount = GeneratedColumn<int>(
    'retell_pass_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blindListenParagraphIndexMeta =
      const VerificationMeta('blindListenParagraphIndex');
  @override
  late final GeneratedColumn<int> blindListenParagraphIndex =
      GeneratedColumn<int>(
        'blind_listen_paragraph_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freePlayBlindListenParagraphIndexMeta =
      const VerificationMeta('freePlayBlindListenParagraphIndex');
  @override
  late final GeneratedColumn<int> freePlayBlindListenParagraphIndex =
      GeneratedColumn<int>(
        'free_play_blind_listen_paragraph_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freePlayIntensiveListenSentenceIndexMeta =
      const VerificationMeta('freePlayIntensiveListenSentenceIndex');
  @override
  late final GeneratedColumn<int> freePlayIntensiveListenSentenceIndex =
      GeneratedColumn<int>(
        'free_play_intensive_listen_sentence_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freePlayShadowingSentenceIndexMeta =
      const VerificationMeta('freePlayShadowingSentenceIndex');
  @override
  late final GeneratedColumn<int> freePlayShadowingSentenceIndex =
      GeneratedColumn<int>(
        'free_play_shadowing_sentence_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freePlayDifficultPracticeSentenceIndexMeta =
      const VerificationMeta('freePlayDifficultPracticeSentenceIndex');
  @override
  late final GeneratedColumn<int> freePlayDifficultPracticeSentenceIndex =
      GeneratedColumn<int>(
        'free_play_difficult_practice_sentence_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freePlayRetellParagraphIndexMeta =
      const VerificationMeta('freePlayRetellParagraphIndex');
  @override
  late final GeneratedColumn<int> freePlayRetellParagraphIndex =
      GeneratedColumn<int>(
        'free_play_retell_paragraph_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _newLearningBreakpointSavedAtMeta =
      const VerificationMeta('newLearningBreakpointSavedAt');
  @override
  late final GeneratedColumn<DateTime> newLearningBreakpointSavedAt =
      GeneratedColumn<DateTime>(
        'new_learning_breakpoint_saved_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freePlayBreakpointSavedAtMeta =
      const VerificationMeta('freePlayBreakpointSavedAt');
  @override
  late final GeneratedColumn<DateTime> freePlayBreakpointSavedAt =
      GeneratedColumn<DateTime>(
        'free_play_breakpoint_saved_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skippedSubStagesMeta = const VerificationMeta(
    'skippedSubStages',
  );
  @override
  late final GeneratedColumn<String> skippedSubStages = GeneratedColumn<String>(
    'skipped_sub_stages',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    audioItemId,
    currentStage,
    currentSubStage,
    difficulty,
    firstLearnCompletedAt,
    lastStageCompletedAt,
    currentStageStartedAt,
    totalStudyDurationMs,
    blindListenPassCount,
    intensiveListenSentenceIndex,
    intensiveListenDifficultCount,
    intensiveListenPassCount,
    shadowingPassCount,
    shadowingSentenceIndex,
    difficultPracticeSentenceIndex,
    retellParagraphIndex,
    retellPassCount,
    blindListenParagraphIndex,
    freePlayBlindListenParagraphIndex,
    freePlayIntensiveListenSentenceIndex,
    freePlayShadowingSentenceIndex,
    freePlayDifficultPracticeSentenceIndex,
    freePlayRetellParagraphIndex,
    newLearningBreakpointSavedAt,
    freePlayBreakpointSavedAt,
    updatedAt,
    skippedSubStages,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningProgressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('audio_item_id')) {
      context.handle(
        _audioItemIdMeta,
        audioItemId.isAcceptableOrUnknown(
          data['audio_item_id']!,
          _audioItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioItemIdMeta);
    }
    if (data.containsKey('current_stage')) {
      context.handle(
        _currentStageMeta,
        currentStage.isAcceptableOrUnknown(
          data['current_stage']!,
          _currentStageMeta,
        ),
      );
    }
    if (data.containsKey('current_sub_stage')) {
      context.handle(
        _currentSubStageMeta,
        currentSubStage.isAcceptableOrUnknown(
          data['current_sub_stage']!,
          _currentSubStageMeta,
        ),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('first_learn_completed_at')) {
      context.handle(
        _firstLearnCompletedAtMeta,
        firstLearnCompletedAt.isAcceptableOrUnknown(
          data['first_learn_completed_at']!,
          _firstLearnCompletedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_stage_completed_at')) {
      context.handle(
        _lastStageCompletedAtMeta,
        lastStageCompletedAt.isAcceptableOrUnknown(
          data['last_stage_completed_at']!,
          _lastStageCompletedAtMeta,
        ),
      );
    }
    if (data.containsKey('current_stage_started_at')) {
      context.handle(
        _currentStageStartedAtMeta,
        currentStageStartedAt.isAcceptableOrUnknown(
          data['current_stage_started_at']!,
          _currentStageStartedAtMeta,
        ),
      );
    }
    if (data.containsKey('total_study_duration_ms')) {
      context.handle(
        _totalStudyDurationMsMeta,
        totalStudyDurationMs.isAcceptableOrUnknown(
          data['total_study_duration_ms']!,
          _totalStudyDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('blind_listen_pass_count')) {
      context.handle(
        _blindListenPassCountMeta,
        blindListenPassCount.isAcceptableOrUnknown(
          data['blind_listen_pass_count']!,
          _blindListenPassCountMeta,
        ),
      );
    }
    if (data.containsKey('intensive_listen_sentence_index')) {
      context.handle(
        _intensiveListenSentenceIndexMeta,
        intensiveListenSentenceIndex.isAcceptableOrUnknown(
          data['intensive_listen_sentence_index']!,
          _intensiveListenSentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('intensive_listen_difficult_count')) {
      context.handle(
        _intensiveListenDifficultCountMeta,
        intensiveListenDifficultCount.isAcceptableOrUnknown(
          data['intensive_listen_difficult_count']!,
          _intensiveListenDifficultCountMeta,
        ),
      );
    }
    if (data.containsKey('intensive_listen_pass_count')) {
      context.handle(
        _intensiveListenPassCountMeta,
        intensiveListenPassCount.isAcceptableOrUnknown(
          data['intensive_listen_pass_count']!,
          _intensiveListenPassCountMeta,
        ),
      );
    }
    if (data.containsKey('shadowing_pass_count')) {
      context.handle(
        _shadowingPassCountMeta,
        shadowingPassCount.isAcceptableOrUnknown(
          data['shadowing_pass_count']!,
          _shadowingPassCountMeta,
        ),
      );
    }
    if (data.containsKey('shadowing_sentence_index')) {
      context.handle(
        _shadowingSentenceIndexMeta,
        shadowingSentenceIndex.isAcceptableOrUnknown(
          data['shadowing_sentence_index']!,
          _shadowingSentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('difficult_practice_sentence_index')) {
      context.handle(
        _difficultPracticeSentenceIndexMeta,
        difficultPracticeSentenceIndex.isAcceptableOrUnknown(
          data['difficult_practice_sentence_index']!,
          _difficultPracticeSentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('retell_paragraph_index')) {
      context.handle(
        _retellParagraphIndexMeta,
        retellParagraphIndex.isAcceptableOrUnknown(
          data['retell_paragraph_index']!,
          _retellParagraphIndexMeta,
        ),
      );
    }
    if (data.containsKey('retell_pass_count')) {
      context.handle(
        _retellPassCountMeta,
        retellPassCount.isAcceptableOrUnknown(
          data['retell_pass_count']!,
          _retellPassCountMeta,
        ),
      );
    }
    if (data.containsKey('blind_listen_paragraph_index')) {
      context.handle(
        _blindListenParagraphIndexMeta,
        blindListenParagraphIndex.isAcceptableOrUnknown(
          data['blind_listen_paragraph_index']!,
          _blindListenParagraphIndexMeta,
        ),
      );
    }
    if (data.containsKey('free_play_blind_listen_paragraph_index')) {
      context.handle(
        _freePlayBlindListenParagraphIndexMeta,
        freePlayBlindListenParagraphIndex.isAcceptableOrUnknown(
          data['free_play_blind_listen_paragraph_index']!,
          _freePlayBlindListenParagraphIndexMeta,
        ),
      );
    }
    if (data.containsKey('free_play_intensive_listen_sentence_index')) {
      context.handle(
        _freePlayIntensiveListenSentenceIndexMeta,
        freePlayIntensiveListenSentenceIndex.isAcceptableOrUnknown(
          data['free_play_intensive_listen_sentence_index']!,
          _freePlayIntensiveListenSentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('free_play_shadowing_sentence_index')) {
      context.handle(
        _freePlayShadowingSentenceIndexMeta,
        freePlayShadowingSentenceIndex.isAcceptableOrUnknown(
          data['free_play_shadowing_sentence_index']!,
          _freePlayShadowingSentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('free_play_difficult_practice_sentence_index')) {
      context.handle(
        _freePlayDifficultPracticeSentenceIndexMeta,
        freePlayDifficultPracticeSentenceIndex.isAcceptableOrUnknown(
          data['free_play_difficult_practice_sentence_index']!,
          _freePlayDifficultPracticeSentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('free_play_retell_paragraph_index')) {
      context.handle(
        _freePlayRetellParagraphIndexMeta,
        freePlayRetellParagraphIndex.isAcceptableOrUnknown(
          data['free_play_retell_paragraph_index']!,
          _freePlayRetellParagraphIndexMeta,
        ),
      );
    }
    if (data.containsKey('new_learning_breakpoint_saved_at')) {
      context.handle(
        _newLearningBreakpointSavedAtMeta,
        newLearningBreakpointSavedAt.isAcceptableOrUnknown(
          data['new_learning_breakpoint_saved_at']!,
          _newLearningBreakpointSavedAtMeta,
        ),
      );
    }
    if (data.containsKey('free_play_breakpoint_saved_at')) {
      context.handle(
        _freePlayBreakpointSavedAtMeta,
        freePlayBreakpointSavedAt.isAcceptableOrUnknown(
          data['free_play_breakpoint_saved_at']!,
          _freePlayBreakpointSavedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('skipped_sub_stages')) {
      context.handle(
        _skippedSubStagesMeta,
        skippedSubStages.isAcceptableOrUnknown(
          data['skipped_sub_stages']!,
          _skippedSubStagesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {audioItemId};
  @override
  LearningProgressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningProgressesData(
      audioItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_item_id'],
      )!,
      currentStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_stage'],
      )!,
      currentSubStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_sub_stage'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difficulty'],
      )!,
      firstLearnCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_learn_completed_at'],
      ),
      lastStageCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_stage_completed_at'],
      ),
      currentStageStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}current_stage_started_at'],
      ),
      totalStudyDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_study_duration_ms'],
      )!,
      blindListenPassCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blind_listen_pass_count'],
      )!,
      intensiveListenSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intensive_listen_sentence_index'],
      ),
      intensiveListenDifficultCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intensive_listen_difficult_count'],
      ),
      intensiveListenPassCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intensive_listen_pass_count'],
      ),
      shadowingPassCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shadowing_pass_count'],
      ),
      shadowingSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shadowing_sentence_index'],
      ),
      difficultPracticeSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difficult_practice_sentence_index'],
      ),
      retellParagraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retell_paragraph_index'],
      ),
      retellPassCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retell_pass_count'],
      ),
      blindListenParagraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blind_listen_paragraph_index'],
      ),
      freePlayBlindListenParagraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_play_blind_listen_paragraph_index'],
      ),
      freePlayIntensiveListenSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_play_intensive_listen_sentence_index'],
      ),
      freePlayShadowingSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_play_shadowing_sentence_index'],
      ),
      freePlayDifficultPracticeSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_play_difficult_practice_sentence_index'],
      ),
      freePlayRetellParagraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_play_retell_paragraph_index'],
      ),
      newLearningBreakpointSavedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}new_learning_breakpoint_saved_at'],
      ),
      freePlayBreakpointSavedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}free_play_breakpoint_saved_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      skippedSubStages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skipped_sub_stages'],
      )!,
    );
  }

  @override
  $LearningProgressesTable createAlias(String alias) {
    return $LearningProgressesTable(attachedDatabase, alias);
  }
}

class LearningProgressesData extends DataClass
    implements Insertable<LearningProgressesData> {
  /// 音频 ID，主键 + 外键关联 audio_items（级联删除）
  final String audioItemId;

  /// 当前大阶段键（对应 LearningStage.key）
  final String currentStage;

  /// 当前子步骤键（对应 SubStageType.key）
  final String currentSubStage;

  /// 难度等级（0=easy, 1=medium, 2=hard）
  final int difficulty;

  /// 首次学习完成时间（复习间隔计算基准，首次学习完成前为 null）
  final DateTime? firstLearnCompletedAt;

  /// 上一阶段完成时间（复习调度核心字段，用于计算下次复习时间）
  final DateTime? lastStageCompletedAt;

  /// 当前阶段开始时间（进入该阶段的时间，用于断点续学和耗时计算）
  final DateTime? currentStageStartedAt;

  /// 累计学习时长（毫秒）
  final int totalStudyDurationMs;

  /// 盲听已完成遍数（用户可随时查看）
  final int blindListenPassCount;

  /// 精听断点续学句子索引（null 表示从头开始）
  final int? intensiveListenSentenceIndex;

  /// 精听标记的难句数量
  final int? intensiveListenDifficultCount;

  /// 精听总完成遍数（每次完成精听 +1，类似盲听的 blindListenPassCount）
  final int? intensiveListenPassCount;

  /// 跟读总完成遍数（每次完成跟读 +1）
  final int? shadowingPassCount;

  /// 跟读断点续学句子索引（null 表示从头开始）
  final int? shadowingSentenceIndex;

  /// 难句补练断点续学句子索引（null 表示从头开始）
  final int? difficultPracticeSentenceIndex;

  /// 复述断点续学段落索引（null 表示从头开始）
  final int? retellParagraphIndex;

  /// 复述总完成遍数（每次完成复述 +1）
  final int? retellPassCount;

  /// 盲听断点续学段落索引（null 表示从头开始）
  final int? blindListenParagraphIndex;

  /// 自由练习-盲听断点段落索引
  final int? freePlayBlindListenParagraphIndex;

  /// 自由练习-精听断点句子索引
  final int? freePlayIntensiveListenSentenceIndex;

  /// 自由练习-跟读断点句子索引
  final int? freePlayShadowingSentenceIndex;

  /// 自由练习-难句补练断点句子索引
  final int? freePlayDifficultPracticeSentenceIndex;

  /// 自由练习-复述断点段落索引
  final int? freePlayRetellParagraphIndex;

  /// 新学习断点保存时间（>3天则不恢复）
  final DateTime? newLearningBreakpointSavedAt;

  /// 自由练习断点保存时间（>3天则不恢复）
  final DateTime? freePlayBreakpointSavedAt;

  /// 最后更新时间
  final DateTime updatedAt;

  /// 用户（或自动跳过策略）在该音频上跳过的子步骤集合
  ///
  /// 存储格式：逗号分隔的 `'stage.key:subStage.key'`（空字符串 = 空集合）。
  ///
  /// 不变量：与 `stage_completions` 中该音频的 (stage, subStage) 集合**互斥**——
  /// 写 completion 时清除此集合中对应 key；写 skip 时若已 completed 则早返回。
  final String skippedSubStages;
  const LearningProgressesData({
    required this.audioItemId,
    required this.currentStage,
    required this.currentSubStage,
    required this.difficulty,
    this.firstLearnCompletedAt,
    this.lastStageCompletedAt,
    this.currentStageStartedAt,
    required this.totalStudyDurationMs,
    required this.blindListenPassCount,
    this.intensiveListenSentenceIndex,
    this.intensiveListenDifficultCount,
    this.intensiveListenPassCount,
    this.shadowingPassCount,
    this.shadowingSentenceIndex,
    this.difficultPracticeSentenceIndex,
    this.retellParagraphIndex,
    this.retellPassCount,
    this.blindListenParagraphIndex,
    this.freePlayBlindListenParagraphIndex,
    this.freePlayIntensiveListenSentenceIndex,
    this.freePlayShadowingSentenceIndex,
    this.freePlayDifficultPracticeSentenceIndex,
    this.freePlayRetellParagraphIndex,
    this.newLearningBreakpointSavedAt,
    this.freePlayBreakpointSavedAt,
    required this.updatedAt,
    required this.skippedSubStages,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['audio_item_id'] = Variable<String>(audioItemId);
    map['current_stage'] = Variable<String>(currentStage);
    map['current_sub_stage'] = Variable<String>(currentSubStage);
    map['difficulty'] = Variable<int>(difficulty);
    if (!nullToAbsent || firstLearnCompletedAt != null) {
      map['first_learn_completed_at'] = Variable<DateTime>(
        firstLearnCompletedAt,
      );
    }
    if (!nullToAbsent || lastStageCompletedAt != null) {
      map['last_stage_completed_at'] = Variable<DateTime>(lastStageCompletedAt);
    }
    if (!nullToAbsent || currentStageStartedAt != null) {
      map['current_stage_started_at'] = Variable<DateTime>(
        currentStageStartedAt,
      );
    }
    map['total_study_duration_ms'] = Variable<int>(totalStudyDurationMs);
    map['blind_listen_pass_count'] = Variable<int>(blindListenPassCount);
    if (!nullToAbsent || intensiveListenSentenceIndex != null) {
      map['intensive_listen_sentence_index'] = Variable<int>(
        intensiveListenSentenceIndex,
      );
    }
    if (!nullToAbsent || intensiveListenDifficultCount != null) {
      map['intensive_listen_difficult_count'] = Variable<int>(
        intensiveListenDifficultCount,
      );
    }
    if (!nullToAbsent || intensiveListenPassCount != null) {
      map['intensive_listen_pass_count'] = Variable<int>(
        intensiveListenPassCount,
      );
    }
    if (!nullToAbsent || shadowingPassCount != null) {
      map['shadowing_pass_count'] = Variable<int>(shadowingPassCount);
    }
    if (!nullToAbsent || shadowingSentenceIndex != null) {
      map['shadowing_sentence_index'] = Variable<int>(shadowingSentenceIndex);
    }
    if (!nullToAbsent || difficultPracticeSentenceIndex != null) {
      map['difficult_practice_sentence_index'] = Variable<int>(
        difficultPracticeSentenceIndex,
      );
    }
    if (!nullToAbsent || retellParagraphIndex != null) {
      map['retell_paragraph_index'] = Variable<int>(retellParagraphIndex);
    }
    if (!nullToAbsent || retellPassCount != null) {
      map['retell_pass_count'] = Variable<int>(retellPassCount);
    }
    if (!nullToAbsent || blindListenParagraphIndex != null) {
      map['blind_listen_paragraph_index'] = Variable<int>(
        blindListenParagraphIndex,
      );
    }
    if (!nullToAbsent || freePlayBlindListenParagraphIndex != null) {
      map['free_play_blind_listen_paragraph_index'] = Variable<int>(
        freePlayBlindListenParagraphIndex,
      );
    }
    if (!nullToAbsent || freePlayIntensiveListenSentenceIndex != null) {
      map['free_play_intensive_listen_sentence_index'] = Variable<int>(
        freePlayIntensiveListenSentenceIndex,
      );
    }
    if (!nullToAbsent || freePlayShadowingSentenceIndex != null) {
      map['free_play_shadowing_sentence_index'] = Variable<int>(
        freePlayShadowingSentenceIndex,
      );
    }
    if (!nullToAbsent || freePlayDifficultPracticeSentenceIndex != null) {
      map['free_play_difficult_practice_sentence_index'] = Variable<int>(
        freePlayDifficultPracticeSentenceIndex,
      );
    }
    if (!nullToAbsent || freePlayRetellParagraphIndex != null) {
      map['free_play_retell_paragraph_index'] = Variable<int>(
        freePlayRetellParagraphIndex,
      );
    }
    if (!nullToAbsent || newLearningBreakpointSavedAt != null) {
      map['new_learning_breakpoint_saved_at'] = Variable<DateTime>(
        newLearningBreakpointSavedAt,
      );
    }
    if (!nullToAbsent || freePlayBreakpointSavedAt != null) {
      map['free_play_breakpoint_saved_at'] = Variable<DateTime>(
        freePlayBreakpointSavedAt,
      );
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['skipped_sub_stages'] = Variable<String>(skippedSubStages);
    return map;
  }

  LearningProgressesCompanion toCompanion(bool nullToAbsent) {
    return LearningProgressesCompanion(
      audioItemId: Value(audioItemId),
      currentStage: Value(currentStage),
      currentSubStage: Value(currentSubStage),
      difficulty: Value(difficulty),
      firstLearnCompletedAt: firstLearnCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firstLearnCompletedAt),
      lastStageCompletedAt: lastStageCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStageCompletedAt),
      currentStageStartedAt: currentStageStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(currentStageStartedAt),
      totalStudyDurationMs: Value(totalStudyDurationMs),
      blindListenPassCount: Value(blindListenPassCount),
      intensiveListenSentenceIndex:
          intensiveListenSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(intensiveListenSentenceIndex),
      intensiveListenDifficultCount:
          intensiveListenDifficultCount == null && nullToAbsent
          ? const Value.absent()
          : Value(intensiveListenDifficultCount),
      intensiveListenPassCount: intensiveListenPassCount == null && nullToAbsent
          ? const Value.absent()
          : Value(intensiveListenPassCount),
      shadowingPassCount: shadowingPassCount == null && nullToAbsent
          ? const Value.absent()
          : Value(shadowingPassCount),
      shadowingSentenceIndex: shadowingSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(shadowingSentenceIndex),
      difficultPracticeSentenceIndex:
          difficultPracticeSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(difficultPracticeSentenceIndex),
      retellParagraphIndex: retellParagraphIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(retellParagraphIndex),
      retellPassCount: retellPassCount == null && nullToAbsent
          ? const Value.absent()
          : Value(retellPassCount),
      blindListenParagraphIndex:
          blindListenParagraphIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(blindListenParagraphIndex),
      freePlayBlindListenParagraphIndex:
          freePlayBlindListenParagraphIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(freePlayBlindListenParagraphIndex),
      freePlayIntensiveListenSentenceIndex:
          freePlayIntensiveListenSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(freePlayIntensiveListenSentenceIndex),
      freePlayShadowingSentenceIndex:
          freePlayShadowingSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(freePlayShadowingSentenceIndex),
      freePlayDifficultPracticeSentenceIndex:
          freePlayDifficultPracticeSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(freePlayDifficultPracticeSentenceIndex),
      freePlayRetellParagraphIndex:
          freePlayRetellParagraphIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(freePlayRetellParagraphIndex),
      newLearningBreakpointSavedAt:
          newLearningBreakpointSavedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(newLearningBreakpointSavedAt),
      freePlayBreakpointSavedAt:
          freePlayBreakpointSavedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(freePlayBreakpointSavedAt),
      updatedAt: Value(updatedAt),
      skippedSubStages: Value(skippedSubStages),
    );
  }

  factory LearningProgressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningProgressesData(
      audioItemId: serializer.fromJson<String>(json['audioItemId']),
      currentStage: serializer.fromJson<String>(json['currentStage']),
      currentSubStage: serializer.fromJson<String>(json['currentSubStage']),
      difficulty: serializer.fromJson<int>(json['difficulty']),
      firstLearnCompletedAt: serializer.fromJson<DateTime?>(
        json['firstLearnCompletedAt'],
      ),
      lastStageCompletedAt: serializer.fromJson<DateTime?>(
        json['lastStageCompletedAt'],
      ),
      currentStageStartedAt: serializer.fromJson<DateTime?>(
        json['currentStageStartedAt'],
      ),
      totalStudyDurationMs: serializer.fromJson<int>(
        json['totalStudyDurationMs'],
      ),
      blindListenPassCount: serializer.fromJson<int>(
        json['blindListenPassCount'],
      ),
      intensiveListenSentenceIndex: serializer.fromJson<int?>(
        json['intensiveListenSentenceIndex'],
      ),
      intensiveListenDifficultCount: serializer.fromJson<int?>(
        json['intensiveListenDifficultCount'],
      ),
      intensiveListenPassCount: serializer.fromJson<int?>(
        json['intensiveListenPassCount'],
      ),
      shadowingPassCount: serializer.fromJson<int?>(json['shadowingPassCount']),
      shadowingSentenceIndex: serializer.fromJson<int?>(
        json['shadowingSentenceIndex'],
      ),
      difficultPracticeSentenceIndex: serializer.fromJson<int?>(
        json['difficultPracticeSentenceIndex'],
      ),
      retellParagraphIndex: serializer.fromJson<int?>(
        json['retellParagraphIndex'],
      ),
      retellPassCount: serializer.fromJson<int?>(json['retellPassCount']),
      blindListenParagraphIndex: serializer.fromJson<int?>(
        json['blindListenParagraphIndex'],
      ),
      freePlayBlindListenParagraphIndex: serializer.fromJson<int?>(
        json['freePlayBlindListenParagraphIndex'],
      ),
      freePlayIntensiveListenSentenceIndex: serializer.fromJson<int?>(
        json['freePlayIntensiveListenSentenceIndex'],
      ),
      freePlayShadowingSentenceIndex: serializer.fromJson<int?>(
        json['freePlayShadowingSentenceIndex'],
      ),
      freePlayDifficultPracticeSentenceIndex: serializer.fromJson<int?>(
        json['freePlayDifficultPracticeSentenceIndex'],
      ),
      freePlayRetellParagraphIndex: serializer.fromJson<int?>(
        json['freePlayRetellParagraphIndex'],
      ),
      newLearningBreakpointSavedAt: serializer.fromJson<DateTime?>(
        json['newLearningBreakpointSavedAt'],
      ),
      freePlayBreakpointSavedAt: serializer.fromJson<DateTime?>(
        json['freePlayBreakpointSavedAt'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      skippedSubStages: serializer.fromJson<String>(json['skippedSubStages']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'audioItemId': serializer.toJson<String>(audioItemId),
      'currentStage': serializer.toJson<String>(currentStage),
      'currentSubStage': serializer.toJson<String>(currentSubStage),
      'difficulty': serializer.toJson<int>(difficulty),
      'firstLearnCompletedAt': serializer.toJson<DateTime?>(
        firstLearnCompletedAt,
      ),
      'lastStageCompletedAt': serializer.toJson<DateTime?>(
        lastStageCompletedAt,
      ),
      'currentStageStartedAt': serializer.toJson<DateTime?>(
        currentStageStartedAt,
      ),
      'totalStudyDurationMs': serializer.toJson<int>(totalStudyDurationMs),
      'blindListenPassCount': serializer.toJson<int>(blindListenPassCount),
      'intensiveListenSentenceIndex': serializer.toJson<int?>(
        intensiveListenSentenceIndex,
      ),
      'intensiveListenDifficultCount': serializer.toJson<int?>(
        intensiveListenDifficultCount,
      ),
      'intensiveListenPassCount': serializer.toJson<int?>(
        intensiveListenPassCount,
      ),
      'shadowingPassCount': serializer.toJson<int?>(shadowingPassCount),
      'shadowingSentenceIndex': serializer.toJson<int?>(shadowingSentenceIndex),
      'difficultPracticeSentenceIndex': serializer.toJson<int?>(
        difficultPracticeSentenceIndex,
      ),
      'retellParagraphIndex': serializer.toJson<int?>(retellParagraphIndex),
      'retellPassCount': serializer.toJson<int?>(retellPassCount),
      'blindListenParagraphIndex': serializer.toJson<int?>(
        blindListenParagraphIndex,
      ),
      'freePlayBlindListenParagraphIndex': serializer.toJson<int?>(
        freePlayBlindListenParagraphIndex,
      ),
      'freePlayIntensiveListenSentenceIndex': serializer.toJson<int?>(
        freePlayIntensiveListenSentenceIndex,
      ),
      'freePlayShadowingSentenceIndex': serializer.toJson<int?>(
        freePlayShadowingSentenceIndex,
      ),
      'freePlayDifficultPracticeSentenceIndex': serializer.toJson<int?>(
        freePlayDifficultPracticeSentenceIndex,
      ),
      'freePlayRetellParagraphIndex': serializer.toJson<int?>(
        freePlayRetellParagraphIndex,
      ),
      'newLearningBreakpointSavedAt': serializer.toJson<DateTime?>(
        newLearningBreakpointSavedAt,
      ),
      'freePlayBreakpointSavedAt': serializer.toJson<DateTime?>(
        freePlayBreakpointSavedAt,
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'skippedSubStages': serializer.toJson<String>(skippedSubStages),
    };
  }

  LearningProgressesData copyWith({
    String? audioItemId,
    String? currentStage,
    String? currentSubStage,
    int? difficulty,
    Value<DateTime?> firstLearnCompletedAt = const Value.absent(),
    Value<DateTime?> lastStageCompletedAt = const Value.absent(),
    Value<DateTime?> currentStageStartedAt = const Value.absent(),
    int? totalStudyDurationMs,
    int? blindListenPassCount,
    Value<int?> intensiveListenSentenceIndex = const Value.absent(),
    Value<int?> intensiveListenDifficultCount = const Value.absent(),
    Value<int?> intensiveListenPassCount = const Value.absent(),
    Value<int?> shadowingPassCount = const Value.absent(),
    Value<int?> shadowingSentenceIndex = const Value.absent(),
    Value<int?> difficultPracticeSentenceIndex = const Value.absent(),
    Value<int?> retellParagraphIndex = const Value.absent(),
    Value<int?> retellPassCount = const Value.absent(),
    Value<int?> blindListenParagraphIndex = const Value.absent(),
    Value<int?> freePlayBlindListenParagraphIndex = const Value.absent(),
    Value<int?> freePlayIntensiveListenSentenceIndex = const Value.absent(),
    Value<int?> freePlayShadowingSentenceIndex = const Value.absent(),
    Value<int?> freePlayDifficultPracticeSentenceIndex = const Value.absent(),
    Value<int?> freePlayRetellParagraphIndex = const Value.absent(),
    Value<DateTime?> newLearningBreakpointSavedAt = const Value.absent(),
    Value<DateTime?> freePlayBreakpointSavedAt = const Value.absent(),
    DateTime? updatedAt,
    String? skippedSubStages,
  }) => LearningProgressesData(
    audioItemId: audioItemId ?? this.audioItemId,
    currentStage: currentStage ?? this.currentStage,
    currentSubStage: currentSubStage ?? this.currentSubStage,
    difficulty: difficulty ?? this.difficulty,
    firstLearnCompletedAt: firstLearnCompletedAt.present
        ? firstLearnCompletedAt.value
        : this.firstLearnCompletedAt,
    lastStageCompletedAt: lastStageCompletedAt.present
        ? lastStageCompletedAt.value
        : this.lastStageCompletedAt,
    currentStageStartedAt: currentStageStartedAt.present
        ? currentStageStartedAt.value
        : this.currentStageStartedAt,
    totalStudyDurationMs: totalStudyDurationMs ?? this.totalStudyDurationMs,
    blindListenPassCount: blindListenPassCount ?? this.blindListenPassCount,
    intensiveListenSentenceIndex: intensiveListenSentenceIndex.present
        ? intensiveListenSentenceIndex.value
        : this.intensiveListenSentenceIndex,
    intensiveListenDifficultCount: intensiveListenDifficultCount.present
        ? intensiveListenDifficultCount.value
        : this.intensiveListenDifficultCount,
    intensiveListenPassCount: intensiveListenPassCount.present
        ? intensiveListenPassCount.value
        : this.intensiveListenPassCount,
    shadowingPassCount: shadowingPassCount.present
        ? shadowingPassCount.value
        : this.shadowingPassCount,
    shadowingSentenceIndex: shadowingSentenceIndex.present
        ? shadowingSentenceIndex.value
        : this.shadowingSentenceIndex,
    difficultPracticeSentenceIndex: difficultPracticeSentenceIndex.present
        ? difficultPracticeSentenceIndex.value
        : this.difficultPracticeSentenceIndex,
    retellParagraphIndex: retellParagraphIndex.present
        ? retellParagraphIndex.value
        : this.retellParagraphIndex,
    retellPassCount: retellPassCount.present
        ? retellPassCount.value
        : this.retellPassCount,
    blindListenParagraphIndex: blindListenParagraphIndex.present
        ? blindListenParagraphIndex.value
        : this.blindListenParagraphIndex,
    freePlayBlindListenParagraphIndex: freePlayBlindListenParagraphIndex.present
        ? freePlayBlindListenParagraphIndex.value
        : this.freePlayBlindListenParagraphIndex,
    freePlayIntensiveListenSentenceIndex:
        freePlayIntensiveListenSentenceIndex.present
        ? freePlayIntensiveListenSentenceIndex.value
        : this.freePlayIntensiveListenSentenceIndex,
    freePlayShadowingSentenceIndex: freePlayShadowingSentenceIndex.present
        ? freePlayShadowingSentenceIndex.value
        : this.freePlayShadowingSentenceIndex,
    freePlayDifficultPracticeSentenceIndex:
        freePlayDifficultPracticeSentenceIndex.present
        ? freePlayDifficultPracticeSentenceIndex.value
        : this.freePlayDifficultPracticeSentenceIndex,
    freePlayRetellParagraphIndex: freePlayRetellParagraphIndex.present
        ? freePlayRetellParagraphIndex.value
        : this.freePlayRetellParagraphIndex,
    newLearningBreakpointSavedAt: newLearningBreakpointSavedAt.present
        ? newLearningBreakpointSavedAt.value
        : this.newLearningBreakpointSavedAt,
    freePlayBreakpointSavedAt: freePlayBreakpointSavedAt.present
        ? freePlayBreakpointSavedAt.value
        : this.freePlayBreakpointSavedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    skippedSubStages: skippedSubStages ?? this.skippedSubStages,
  );
  LearningProgressesData copyWithCompanion(LearningProgressesCompanion data) {
    return LearningProgressesData(
      audioItemId: data.audioItemId.present
          ? data.audioItemId.value
          : this.audioItemId,
      currentStage: data.currentStage.present
          ? data.currentStage.value
          : this.currentStage,
      currentSubStage: data.currentSubStage.present
          ? data.currentSubStage.value
          : this.currentSubStage,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      firstLearnCompletedAt: data.firstLearnCompletedAt.present
          ? data.firstLearnCompletedAt.value
          : this.firstLearnCompletedAt,
      lastStageCompletedAt: data.lastStageCompletedAt.present
          ? data.lastStageCompletedAt.value
          : this.lastStageCompletedAt,
      currentStageStartedAt: data.currentStageStartedAt.present
          ? data.currentStageStartedAt.value
          : this.currentStageStartedAt,
      totalStudyDurationMs: data.totalStudyDurationMs.present
          ? data.totalStudyDurationMs.value
          : this.totalStudyDurationMs,
      blindListenPassCount: data.blindListenPassCount.present
          ? data.blindListenPassCount.value
          : this.blindListenPassCount,
      intensiveListenSentenceIndex: data.intensiveListenSentenceIndex.present
          ? data.intensiveListenSentenceIndex.value
          : this.intensiveListenSentenceIndex,
      intensiveListenDifficultCount: data.intensiveListenDifficultCount.present
          ? data.intensiveListenDifficultCount.value
          : this.intensiveListenDifficultCount,
      intensiveListenPassCount: data.intensiveListenPassCount.present
          ? data.intensiveListenPassCount.value
          : this.intensiveListenPassCount,
      shadowingPassCount: data.shadowingPassCount.present
          ? data.shadowingPassCount.value
          : this.shadowingPassCount,
      shadowingSentenceIndex: data.shadowingSentenceIndex.present
          ? data.shadowingSentenceIndex.value
          : this.shadowingSentenceIndex,
      difficultPracticeSentenceIndex:
          data.difficultPracticeSentenceIndex.present
          ? data.difficultPracticeSentenceIndex.value
          : this.difficultPracticeSentenceIndex,
      retellParagraphIndex: data.retellParagraphIndex.present
          ? data.retellParagraphIndex.value
          : this.retellParagraphIndex,
      retellPassCount: data.retellPassCount.present
          ? data.retellPassCount.value
          : this.retellPassCount,
      blindListenParagraphIndex: data.blindListenParagraphIndex.present
          ? data.blindListenParagraphIndex.value
          : this.blindListenParagraphIndex,
      freePlayBlindListenParagraphIndex:
          data.freePlayBlindListenParagraphIndex.present
          ? data.freePlayBlindListenParagraphIndex.value
          : this.freePlayBlindListenParagraphIndex,
      freePlayIntensiveListenSentenceIndex:
          data.freePlayIntensiveListenSentenceIndex.present
          ? data.freePlayIntensiveListenSentenceIndex.value
          : this.freePlayIntensiveListenSentenceIndex,
      freePlayShadowingSentenceIndex:
          data.freePlayShadowingSentenceIndex.present
          ? data.freePlayShadowingSentenceIndex.value
          : this.freePlayShadowingSentenceIndex,
      freePlayDifficultPracticeSentenceIndex:
          data.freePlayDifficultPracticeSentenceIndex.present
          ? data.freePlayDifficultPracticeSentenceIndex.value
          : this.freePlayDifficultPracticeSentenceIndex,
      freePlayRetellParagraphIndex: data.freePlayRetellParagraphIndex.present
          ? data.freePlayRetellParagraphIndex.value
          : this.freePlayRetellParagraphIndex,
      newLearningBreakpointSavedAt: data.newLearningBreakpointSavedAt.present
          ? data.newLearningBreakpointSavedAt.value
          : this.newLearningBreakpointSavedAt,
      freePlayBreakpointSavedAt: data.freePlayBreakpointSavedAt.present
          ? data.freePlayBreakpointSavedAt.value
          : this.freePlayBreakpointSavedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      skippedSubStages: data.skippedSubStages.present
          ? data.skippedSubStages.value
          : this.skippedSubStages,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningProgressesData(')
          ..write('audioItemId: $audioItemId, ')
          ..write('currentStage: $currentStage, ')
          ..write('currentSubStage: $currentSubStage, ')
          ..write('difficulty: $difficulty, ')
          ..write('firstLearnCompletedAt: $firstLearnCompletedAt, ')
          ..write('lastStageCompletedAt: $lastStageCompletedAt, ')
          ..write('currentStageStartedAt: $currentStageStartedAt, ')
          ..write('totalStudyDurationMs: $totalStudyDurationMs, ')
          ..write('blindListenPassCount: $blindListenPassCount, ')
          ..write(
            'intensiveListenSentenceIndex: $intensiveListenSentenceIndex, ',
          )
          ..write(
            'intensiveListenDifficultCount: $intensiveListenDifficultCount, ',
          )
          ..write('intensiveListenPassCount: $intensiveListenPassCount, ')
          ..write('shadowingPassCount: $shadowingPassCount, ')
          ..write('shadowingSentenceIndex: $shadowingSentenceIndex, ')
          ..write(
            'difficultPracticeSentenceIndex: $difficultPracticeSentenceIndex, ',
          )
          ..write('retellParagraphIndex: $retellParagraphIndex, ')
          ..write('retellPassCount: $retellPassCount, ')
          ..write('blindListenParagraphIndex: $blindListenParagraphIndex, ')
          ..write(
            'freePlayBlindListenParagraphIndex: $freePlayBlindListenParagraphIndex, ',
          )
          ..write(
            'freePlayIntensiveListenSentenceIndex: $freePlayIntensiveListenSentenceIndex, ',
          )
          ..write(
            'freePlayShadowingSentenceIndex: $freePlayShadowingSentenceIndex, ',
          )
          ..write(
            'freePlayDifficultPracticeSentenceIndex: $freePlayDifficultPracticeSentenceIndex, ',
          )
          ..write(
            'freePlayRetellParagraphIndex: $freePlayRetellParagraphIndex, ',
          )
          ..write(
            'newLearningBreakpointSavedAt: $newLearningBreakpointSavedAt, ',
          )
          ..write('freePlayBreakpointSavedAt: $freePlayBreakpointSavedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('skippedSubStages: $skippedSubStages')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    audioItemId,
    currentStage,
    currentSubStage,
    difficulty,
    firstLearnCompletedAt,
    lastStageCompletedAt,
    currentStageStartedAt,
    totalStudyDurationMs,
    blindListenPassCount,
    intensiveListenSentenceIndex,
    intensiveListenDifficultCount,
    intensiveListenPassCount,
    shadowingPassCount,
    shadowingSentenceIndex,
    difficultPracticeSentenceIndex,
    retellParagraphIndex,
    retellPassCount,
    blindListenParagraphIndex,
    freePlayBlindListenParagraphIndex,
    freePlayIntensiveListenSentenceIndex,
    freePlayShadowingSentenceIndex,
    freePlayDifficultPracticeSentenceIndex,
    freePlayRetellParagraphIndex,
    newLearningBreakpointSavedAt,
    freePlayBreakpointSavedAt,
    updatedAt,
    skippedSubStages,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningProgressesData &&
          other.audioItemId == this.audioItemId &&
          other.currentStage == this.currentStage &&
          other.currentSubStage == this.currentSubStage &&
          other.difficulty == this.difficulty &&
          other.firstLearnCompletedAt == this.firstLearnCompletedAt &&
          other.lastStageCompletedAt == this.lastStageCompletedAt &&
          other.currentStageStartedAt == this.currentStageStartedAt &&
          other.totalStudyDurationMs == this.totalStudyDurationMs &&
          other.blindListenPassCount == this.blindListenPassCount &&
          other.intensiveListenSentenceIndex ==
              this.intensiveListenSentenceIndex &&
          other.intensiveListenDifficultCount ==
              this.intensiveListenDifficultCount &&
          other.intensiveListenPassCount == this.intensiveListenPassCount &&
          other.shadowingPassCount == this.shadowingPassCount &&
          other.shadowingSentenceIndex == this.shadowingSentenceIndex &&
          other.difficultPracticeSentenceIndex ==
              this.difficultPracticeSentenceIndex &&
          other.retellParagraphIndex == this.retellParagraphIndex &&
          other.retellPassCount == this.retellPassCount &&
          other.blindListenParagraphIndex == this.blindListenParagraphIndex &&
          other.freePlayBlindListenParagraphIndex ==
              this.freePlayBlindListenParagraphIndex &&
          other.freePlayIntensiveListenSentenceIndex ==
              this.freePlayIntensiveListenSentenceIndex &&
          other.freePlayShadowingSentenceIndex ==
              this.freePlayShadowingSentenceIndex &&
          other.freePlayDifficultPracticeSentenceIndex ==
              this.freePlayDifficultPracticeSentenceIndex &&
          other.freePlayRetellParagraphIndex ==
              this.freePlayRetellParagraphIndex &&
          other.newLearningBreakpointSavedAt ==
              this.newLearningBreakpointSavedAt &&
          other.freePlayBreakpointSavedAt == this.freePlayBreakpointSavedAt &&
          other.updatedAt == this.updatedAt &&
          other.skippedSubStages == this.skippedSubStages);
}

class LearningProgressesCompanion
    extends UpdateCompanion<LearningProgressesData> {
  final Value<String> audioItemId;
  final Value<String> currentStage;
  final Value<String> currentSubStage;
  final Value<int> difficulty;
  final Value<DateTime?> firstLearnCompletedAt;
  final Value<DateTime?> lastStageCompletedAt;
  final Value<DateTime?> currentStageStartedAt;
  final Value<int> totalStudyDurationMs;
  final Value<int> blindListenPassCount;
  final Value<int?> intensiveListenSentenceIndex;
  final Value<int?> intensiveListenDifficultCount;
  final Value<int?> intensiveListenPassCount;
  final Value<int?> shadowingPassCount;
  final Value<int?> shadowingSentenceIndex;
  final Value<int?> difficultPracticeSentenceIndex;
  final Value<int?> retellParagraphIndex;
  final Value<int?> retellPassCount;
  final Value<int?> blindListenParagraphIndex;
  final Value<int?> freePlayBlindListenParagraphIndex;
  final Value<int?> freePlayIntensiveListenSentenceIndex;
  final Value<int?> freePlayShadowingSentenceIndex;
  final Value<int?> freePlayDifficultPracticeSentenceIndex;
  final Value<int?> freePlayRetellParagraphIndex;
  final Value<DateTime?> newLearningBreakpointSavedAt;
  final Value<DateTime?> freePlayBreakpointSavedAt;
  final Value<DateTime> updatedAt;
  final Value<String> skippedSubStages;
  final Value<int> rowid;
  const LearningProgressesCompanion({
    this.audioItemId = const Value.absent(),
    this.currentStage = const Value.absent(),
    this.currentSubStage = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.firstLearnCompletedAt = const Value.absent(),
    this.lastStageCompletedAt = const Value.absent(),
    this.currentStageStartedAt = const Value.absent(),
    this.totalStudyDurationMs = const Value.absent(),
    this.blindListenPassCount = const Value.absent(),
    this.intensiveListenSentenceIndex = const Value.absent(),
    this.intensiveListenDifficultCount = const Value.absent(),
    this.intensiveListenPassCount = const Value.absent(),
    this.shadowingPassCount = const Value.absent(),
    this.shadowingSentenceIndex = const Value.absent(),
    this.difficultPracticeSentenceIndex = const Value.absent(),
    this.retellParagraphIndex = const Value.absent(),
    this.retellPassCount = const Value.absent(),
    this.blindListenParagraphIndex = const Value.absent(),
    this.freePlayBlindListenParagraphIndex = const Value.absent(),
    this.freePlayIntensiveListenSentenceIndex = const Value.absent(),
    this.freePlayShadowingSentenceIndex = const Value.absent(),
    this.freePlayDifficultPracticeSentenceIndex = const Value.absent(),
    this.freePlayRetellParagraphIndex = const Value.absent(),
    this.newLearningBreakpointSavedAt = const Value.absent(),
    this.freePlayBreakpointSavedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.skippedSubStages = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningProgressesCompanion.insert({
    required String audioItemId,
    this.currentStage = const Value.absent(),
    this.currentSubStage = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.firstLearnCompletedAt = const Value.absent(),
    this.lastStageCompletedAt = const Value.absent(),
    this.currentStageStartedAt = const Value.absent(),
    this.totalStudyDurationMs = const Value.absent(),
    this.blindListenPassCount = const Value.absent(),
    this.intensiveListenSentenceIndex = const Value.absent(),
    this.intensiveListenDifficultCount = const Value.absent(),
    this.intensiveListenPassCount = const Value.absent(),
    this.shadowingPassCount = const Value.absent(),
    this.shadowingSentenceIndex = const Value.absent(),
    this.difficultPracticeSentenceIndex = const Value.absent(),
    this.retellParagraphIndex = const Value.absent(),
    this.retellPassCount = const Value.absent(),
    this.blindListenParagraphIndex = const Value.absent(),
    this.freePlayBlindListenParagraphIndex = const Value.absent(),
    this.freePlayIntensiveListenSentenceIndex = const Value.absent(),
    this.freePlayShadowingSentenceIndex = const Value.absent(),
    this.freePlayDifficultPracticeSentenceIndex = const Value.absent(),
    this.freePlayRetellParagraphIndex = const Value.absent(),
    this.newLearningBreakpointSavedAt = const Value.absent(),
    this.freePlayBreakpointSavedAt = const Value.absent(),
    required DateTime updatedAt,
    this.skippedSubStages = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : audioItemId = Value(audioItemId),
       updatedAt = Value(updatedAt);
  static Insertable<LearningProgressesData> custom({
    Expression<String>? audioItemId,
    Expression<String>? currentStage,
    Expression<String>? currentSubStage,
    Expression<int>? difficulty,
    Expression<DateTime>? firstLearnCompletedAt,
    Expression<DateTime>? lastStageCompletedAt,
    Expression<DateTime>? currentStageStartedAt,
    Expression<int>? totalStudyDurationMs,
    Expression<int>? blindListenPassCount,
    Expression<int>? intensiveListenSentenceIndex,
    Expression<int>? intensiveListenDifficultCount,
    Expression<int>? intensiveListenPassCount,
    Expression<int>? shadowingPassCount,
    Expression<int>? shadowingSentenceIndex,
    Expression<int>? difficultPracticeSentenceIndex,
    Expression<int>? retellParagraphIndex,
    Expression<int>? retellPassCount,
    Expression<int>? blindListenParagraphIndex,
    Expression<int>? freePlayBlindListenParagraphIndex,
    Expression<int>? freePlayIntensiveListenSentenceIndex,
    Expression<int>? freePlayShadowingSentenceIndex,
    Expression<int>? freePlayDifficultPracticeSentenceIndex,
    Expression<int>? freePlayRetellParagraphIndex,
    Expression<DateTime>? newLearningBreakpointSavedAt,
    Expression<DateTime>? freePlayBreakpointSavedAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? skippedSubStages,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (audioItemId != null) 'audio_item_id': audioItemId,
      if (currentStage != null) 'current_stage': currentStage,
      if (currentSubStage != null) 'current_sub_stage': currentSubStage,
      if (difficulty != null) 'difficulty': difficulty,
      if (firstLearnCompletedAt != null)
        'first_learn_completed_at': firstLearnCompletedAt,
      if (lastStageCompletedAt != null)
        'last_stage_completed_at': lastStageCompletedAt,
      if (currentStageStartedAt != null)
        'current_stage_started_at': currentStageStartedAt,
      if (totalStudyDurationMs != null)
        'total_study_duration_ms': totalStudyDurationMs,
      if (blindListenPassCount != null)
        'blind_listen_pass_count': blindListenPassCount,
      if (intensiveListenSentenceIndex != null)
        'intensive_listen_sentence_index': intensiveListenSentenceIndex,
      if (intensiveListenDifficultCount != null)
        'intensive_listen_difficult_count': intensiveListenDifficultCount,
      if (intensiveListenPassCount != null)
        'intensive_listen_pass_count': intensiveListenPassCount,
      if (shadowingPassCount != null)
        'shadowing_pass_count': shadowingPassCount,
      if (shadowingSentenceIndex != null)
        'shadowing_sentence_index': shadowingSentenceIndex,
      if (difficultPracticeSentenceIndex != null)
        'difficult_practice_sentence_index': difficultPracticeSentenceIndex,
      if (retellParagraphIndex != null)
        'retell_paragraph_index': retellParagraphIndex,
      if (retellPassCount != null) 'retell_pass_count': retellPassCount,
      if (blindListenParagraphIndex != null)
        'blind_listen_paragraph_index': blindListenParagraphIndex,
      if (freePlayBlindListenParagraphIndex != null)
        'free_play_blind_listen_paragraph_index':
            freePlayBlindListenParagraphIndex,
      if (freePlayIntensiveListenSentenceIndex != null)
        'free_play_intensive_listen_sentence_index':
            freePlayIntensiveListenSentenceIndex,
      if (freePlayShadowingSentenceIndex != null)
        'free_play_shadowing_sentence_index': freePlayShadowingSentenceIndex,
      if (freePlayDifficultPracticeSentenceIndex != null)
        'free_play_difficult_practice_sentence_index':
            freePlayDifficultPracticeSentenceIndex,
      if (freePlayRetellParagraphIndex != null)
        'free_play_retell_paragraph_index': freePlayRetellParagraphIndex,
      if (newLearningBreakpointSavedAt != null)
        'new_learning_breakpoint_saved_at': newLearningBreakpointSavedAt,
      if (freePlayBreakpointSavedAt != null)
        'free_play_breakpoint_saved_at': freePlayBreakpointSavedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (skippedSubStages != null) 'skipped_sub_stages': skippedSubStages,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningProgressesCompanion copyWith({
    Value<String>? audioItemId,
    Value<String>? currentStage,
    Value<String>? currentSubStage,
    Value<int>? difficulty,
    Value<DateTime?>? firstLearnCompletedAt,
    Value<DateTime?>? lastStageCompletedAt,
    Value<DateTime?>? currentStageStartedAt,
    Value<int>? totalStudyDurationMs,
    Value<int>? blindListenPassCount,
    Value<int?>? intensiveListenSentenceIndex,
    Value<int?>? intensiveListenDifficultCount,
    Value<int?>? intensiveListenPassCount,
    Value<int?>? shadowingPassCount,
    Value<int?>? shadowingSentenceIndex,
    Value<int?>? difficultPracticeSentenceIndex,
    Value<int?>? retellParagraphIndex,
    Value<int?>? retellPassCount,
    Value<int?>? blindListenParagraphIndex,
    Value<int?>? freePlayBlindListenParagraphIndex,
    Value<int?>? freePlayIntensiveListenSentenceIndex,
    Value<int?>? freePlayShadowingSentenceIndex,
    Value<int?>? freePlayDifficultPracticeSentenceIndex,
    Value<int?>? freePlayRetellParagraphIndex,
    Value<DateTime?>? newLearningBreakpointSavedAt,
    Value<DateTime?>? freePlayBreakpointSavedAt,
    Value<DateTime>? updatedAt,
    Value<String>? skippedSubStages,
    Value<int>? rowid,
  }) {
    return LearningProgressesCompanion(
      audioItemId: audioItemId ?? this.audioItemId,
      currentStage: currentStage ?? this.currentStage,
      currentSubStage: currentSubStage ?? this.currentSubStage,
      difficulty: difficulty ?? this.difficulty,
      firstLearnCompletedAt:
          firstLearnCompletedAt ?? this.firstLearnCompletedAt,
      lastStageCompletedAt: lastStageCompletedAt ?? this.lastStageCompletedAt,
      currentStageStartedAt:
          currentStageStartedAt ?? this.currentStageStartedAt,
      totalStudyDurationMs: totalStudyDurationMs ?? this.totalStudyDurationMs,
      blindListenPassCount: blindListenPassCount ?? this.blindListenPassCount,
      intensiveListenSentenceIndex:
          intensiveListenSentenceIndex ?? this.intensiveListenSentenceIndex,
      intensiveListenDifficultCount:
          intensiveListenDifficultCount ?? this.intensiveListenDifficultCount,
      intensiveListenPassCount:
          intensiveListenPassCount ?? this.intensiveListenPassCount,
      shadowingPassCount: shadowingPassCount ?? this.shadowingPassCount,
      shadowingSentenceIndex:
          shadowingSentenceIndex ?? this.shadowingSentenceIndex,
      difficultPracticeSentenceIndex:
          difficultPracticeSentenceIndex ?? this.difficultPracticeSentenceIndex,
      retellParagraphIndex: retellParagraphIndex ?? this.retellParagraphIndex,
      retellPassCount: retellPassCount ?? this.retellPassCount,
      blindListenParagraphIndex:
          blindListenParagraphIndex ?? this.blindListenParagraphIndex,
      freePlayBlindListenParagraphIndex:
          freePlayBlindListenParagraphIndex ??
          this.freePlayBlindListenParagraphIndex,
      freePlayIntensiveListenSentenceIndex:
          freePlayIntensiveListenSentenceIndex ??
          this.freePlayIntensiveListenSentenceIndex,
      freePlayShadowingSentenceIndex:
          freePlayShadowingSentenceIndex ?? this.freePlayShadowingSentenceIndex,
      freePlayDifficultPracticeSentenceIndex:
          freePlayDifficultPracticeSentenceIndex ??
          this.freePlayDifficultPracticeSentenceIndex,
      freePlayRetellParagraphIndex:
          freePlayRetellParagraphIndex ?? this.freePlayRetellParagraphIndex,
      newLearningBreakpointSavedAt:
          newLearningBreakpointSavedAt ?? this.newLearningBreakpointSavedAt,
      freePlayBreakpointSavedAt:
          freePlayBreakpointSavedAt ?? this.freePlayBreakpointSavedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      skippedSubStages: skippedSubStages ?? this.skippedSubStages,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (audioItemId.present) {
      map['audio_item_id'] = Variable<String>(audioItemId.value);
    }
    if (currentStage.present) {
      map['current_stage'] = Variable<String>(currentStage.value);
    }
    if (currentSubStage.present) {
      map['current_sub_stage'] = Variable<String>(currentSubStage.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<int>(difficulty.value);
    }
    if (firstLearnCompletedAt.present) {
      map['first_learn_completed_at'] = Variable<DateTime>(
        firstLearnCompletedAt.value,
      );
    }
    if (lastStageCompletedAt.present) {
      map['last_stage_completed_at'] = Variable<DateTime>(
        lastStageCompletedAt.value,
      );
    }
    if (currentStageStartedAt.present) {
      map['current_stage_started_at'] = Variable<DateTime>(
        currentStageStartedAt.value,
      );
    }
    if (totalStudyDurationMs.present) {
      map['total_study_duration_ms'] = Variable<int>(
        totalStudyDurationMs.value,
      );
    }
    if (blindListenPassCount.present) {
      map['blind_listen_pass_count'] = Variable<int>(
        blindListenPassCount.value,
      );
    }
    if (intensiveListenSentenceIndex.present) {
      map['intensive_listen_sentence_index'] = Variable<int>(
        intensiveListenSentenceIndex.value,
      );
    }
    if (intensiveListenDifficultCount.present) {
      map['intensive_listen_difficult_count'] = Variable<int>(
        intensiveListenDifficultCount.value,
      );
    }
    if (intensiveListenPassCount.present) {
      map['intensive_listen_pass_count'] = Variable<int>(
        intensiveListenPassCount.value,
      );
    }
    if (shadowingPassCount.present) {
      map['shadowing_pass_count'] = Variable<int>(shadowingPassCount.value);
    }
    if (shadowingSentenceIndex.present) {
      map['shadowing_sentence_index'] = Variable<int>(
        shadowingSentenceIndex.value,
      );
    }
    if (difficultPracticeSentenceIndex.present) {
      map['difficult_practice_sentence_index'] = Variable<int>(
        difficultPracticeSentenceIndex.value,
      );
    }
    if (retellParagraphIndex.present) {
      map['retell_paragraph_index'] = Variable<int>(retellParagraphIndex.value);
    }
    if (retellPassCount.present) {
      map['retell_pass_count'] = Variable<int>(retellPassCount.value);
    }
    if (blindListenParagraphIndex.present) {
      map['blind_listen_paragraph_index'] = Variable<int>(
        blindListenParagraphIndex.value,
      );
    }
    if (freePlayBlindListenParagraphIndex.present) {
      map['free_play_blind_listen_paragraph_index'] = Variable<int>(
        freePlayBlindListenParagraphIndex.value,
      );
    }
    if (freePlayIntensiveListenSentenceIndex.present) {
      map['free_play_intensive_listen_sentence_index'] = Variable<int>(
        freePlayIntensiveListenSentenceIndex.value,
      );
    }
    if (freePlayShadowingSentenceIndex.present) {
      map['free_play_shadowing_sentence_index'] = Variable<int>(
        freePlayShadowingSentenceIndex.value,
      );
    }
    if (freePlayDifficultPracticeSentenceIndex.present) {
      map['free_play_difficult_practice_sentence_index'] = Variable<int>(
        freePlayDifficultPracticeSentenceIndex.value,
      );
    }
    if (freePlayRetellParagraphIndex.present) {
      map['free_play_retell_paragraph_index'] = Variable<int>(
        freePlayRetellParagraphIndex.value,
      );
    }
    if (newLearningBreakpointSavedAt.present) {
      map['new_learning_breakpoint_saved_at'] = Variable<DateTime>(
        newLearningBreakpointSavedAt.value,
      );
    }
    if (freePlayBreakpointSavedAt.present) {
      map['free_play_breakpoint_saved_at'] = Variable<DateTime>(
        freePlayBreakpointSavedAt.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (skippedSubStages.present) {
      map['skipped_sub_stages'] = Variable<String>(skippedSubStages.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningProgressesCompanion(')
          ..write('audioItemId: $audioItemId, ')
          ..write('currentStage: $currentStage, ')
          ..write('currentSubStage: $currentSubStage, ')
          ..write('difficulty: $difficulty, ')
          ..write('firstLearnCompletedAt: $firstLearnCompletedAt, ')
          ..write('lastStageCompletedAt: $lastStageCompletedAt, ')
          ..write('currentStageStartedAt: $currentStageStartedAt, ')
          ..write('totalStudyDurationMs: $totalStudyDurationMs, ')
          ..write('blindListenPassCount: $blindListenPassCount, ')
          ..write(
            'intensiveListenSentenceIndex: $intensiveListenSentenceIndex, ',
          )
          ..write(
            'intensiveListenDifficultCount: $intensiveListenDifficultCount, ',
          )
          ..write('intensiveListenPassCount: $intensiveListenPassCount, ')
          ..write('shadowingPassCount: $shadowingPassCount, ')
          ..write('shadowingSentenceIndex: $shadowingSentenceIndex, ')
          ..write(
            'difficultPracticeSentenceIndex: $difficultPracticeSentenceIndex, ',
          )
          ..write('retellParagraphIndex: $retellParagraphIndex, ')
          ..write('retellPassCount: $retellPassCount, ')
          ..write('blindListenParagraphIndex: $blindListenParagraphIndex, ')
          ..write(
            'freePlayBlindListenParagraphIndex: $freePlayBlindListenParagraphIndex, ',
          )
          ..write(
            'freePlayIntensiveListenSentenceIndex: $freePlayIntensiveListenSentenceIndex, ',
          )
          ..write(
            'freePlayShadowingSentenceIndex: $freePlayShadowingSentenceIndex, ',
          )
          ..write(
            'freePlayDifficultPracticeSentenceIndex: $freePlayDifficultPracticeSentenceIndex, ',
          )
          ..write(
            'freePlayRetellParagraphIndex: $freePlayRetellParagraphIndex, ',
          )
          ..write(
            'newLearningBreakpointSavedAt: $newLearningBreakpointSavedAt, ',
          )
          ..write('freePlayBreakpointSavedAt: $freePlayBreakpointSavedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('skippedSubStages: $skippedSubStages, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StageCompletionsTable extends StageCompletions
    with TableInfo<$StageCompletionsTable, StageCompletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StageCompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _audioItemIdMeta = const VerificationMeta(
    'audioItemId',
  );
  @override
  late final GeneratedColumn<String> audioItemId = GeneratedColumn<String>(
    'audio_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES audio_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subStageMeta = const VerificationMeta(
    'subStage',
  );
  @override
  late final GeneratedColumn<String> subStage = GeneratedColumn<String>(
    'sub_stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    audioItemId,
    stage,
    subStage,
    completedAt,
    durationMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stage_completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StageCompletion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('audio_item_id')) {
      context.handle(
        _audioItemIdMeta,
        audioItemId.isAcceptableOrUnknown(
          data['audio_item_id']!,
          _audioItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioItemIdMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('sub_stage')) {
      context.handle(
        _subStageMeta,
        subStage.isAcceptableOrUnknown(data['sub_stage']!, _subStageMeta),
      );
    } else if (isInserting) {
      context.missing(_subStageMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StageCompletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StageCompletion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      audioItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_item_id'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      subStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_stage'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
    );
  }

  @override
  $StageCompletionsTable createAlias(String alias) {
    return $StageCompletionsTable(attachedDatabase, alias);
  }
}

class StageCompletion extends DataClass implements Insertable<StageCompletion> {
  /// 自增主键
  final int id;

  /// 音频 ID，外键关联 audio_items（级联删除）
  final String audioItemId;

  /// 完成的大阶段键（对应 LearningStage.key）
  final String stage;

  /// 完成的子步骤键（对应 SubStageType.key）
  final String subStage;

  /// 完成时间
  final DateTime completedAt;

  /// 该步骤耗时（毫秒），默认 0
  final int durationMs;
  const StageCompletion({
    required this.id,
    required this.audioItemId,
    required this.stage,
    required this.subStage,
    required this.completedAt,
    required this.durationMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['audio_item_id'] = Variable<String>(audioItemId);
    map['stage'] = Variable<String>(stage);
    map['sub_stage'] = Variable<String>(subStage);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    return map;
  }

  StageCompletionsCompanion toCompanion(bool nullToAbsent) {
    return StageCompletionsCompanion(
      id: Value(id),
      audioItemId: Value(audioItemId),
      stage: Value(stage),
      subStage: Value(subStage),
      completedAt: Value(completedAt),
      durationMs: Value(durationMs),
    );
  }

  factory StageCompletion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StageCompletion(
      id: serializer.fromJson<int>(json['id']),
      audioItemId: serializer.fromJson<String>(json['audioItemId']),
      stage: serializer.fromJson<String>(json['stage']),
      subStage: serializer.fromJson<String>(json['subStage']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'audioItemId': serializer.toJson<String>(audioItemId),
      'stage': serializer.toJson<String>(stage),
      'subStage': serializer.toJson<String>(subStage),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'durationMs': serializer.toJson<int>(durationMs),
    };
  }

  StageCompletion copyWith({
    int? id,
    String? audioItemId,
    String? stage,
    String? subStage,
    DateTime? completedAt,
    int? durationMs,
  }) => StageCompletion(
    id: id ?? this.id,
    audioItemId: audioItemId ?? this.audioItemId,
    stage: stage ?? this.stage,
    subStage: subStage ?? this.subStage,
    completedAt: completedAt ?? this.completedAt,
    durationMs: durationMs ?? this.durationMs,
  );
  StageCompletion copyWithCompanion(StageCompletionsCompanion data) {
    return StageCompletion(
      id: data.id.present ? data.id.value : this.id,
      audioItemId: data.audioItemId.present
          ? data.audioItemId.value
          : this.audioItemId,
      stage: data.stage.present ? data.stage.value : this.stage,
      subStage: data.subStage.present ? data.subStage.value : this.subStage,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StageCompletion(')
          ..write('id: $id, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('stage: $stage, ')
          ..write('subStage: $subStage, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, audioItemId, stage, subStage, completedAt, durationMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StageCompletion &&
          other.id == this.id &&
          other.audioItemId == this.audioItemId &&
          other.stage == this.stage &&
          other.subStage == this.subStage &&
          other.completedAt == this.completedAt &&
          other.durationMs == this.durationMs);
}

class StageCompletionsCompanion extends UpdateCompanion<StageCompletion> {
  final Value<int> id;
  final Value<String> audioItemId;
  final Value<String> stage;
  final Value<String> subStage;
  final Value<DateTime> completedAt;
  final Value<int> durationMs;
  const StageCompletionsCompanion({
    this.id = const Value.absent(),
    this.audioItemId = const Value.absent(),
    this.stage = const Value.absent(),
    this.subStage = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
  });
  StageCompletionsCompanion.insert({
    this.id = const Value.absent(),
    required String audioItemId,
    required String stage,
    required String subStage,
    required DateTime completedAt,
    this.durationMs = const Value.absent(),
  }) : audioItemId = Value(audioItemId),
       stage = Value(stage),
       subStage = Value(subStage),
       completedAt = Value(completedAt);
  static Insertable<StageCompletion> custom({
    Expression<int>? id,
    Expression<String>? audioItemId,
    Expression<String>? stage,
    Expression<String>? subStage,
    Expression<DateTime>? completedAt,
    Expression<int>? durationMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (audioItemId != null) 'audio_item_id': audioItemId,
      if (stage != null) 'stage': stage,
      if (subStage != null) 'sub_stage': subStage,
      if (completedAt != null) 'completed_at': completedAt,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  StageCompletionsCompanion copyWith({
    Value<int>? id,
    Value<String>? audioItemId,
    Value<String>? stage,
    Value<String>? subStage,
    Value<DateTime>? completedAt,
    Value<int>? durationMs,
  }) {
    return StageCompletionsCompanion(
      id: id ?? this.id,
      audioItemId: audioItemId ?? this.audioItemId,
      stage: stage ?? this.stage,
      subStage: subStage ?? this.subStage,
      completedAt: completedAt ?? this.completedAt,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (audioItemId.present) {
      map['audio_item_id'] = Variable<String>(audioItemId.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (subStage.present) {
      map['sub_stage'] = Variable<String>(subStage.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StageCompletionsCompanion(')
          ..write('id: $id, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('stage: $stage, ')
          ..write('subStage: $subStage, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdDateMeta = const VerificationMeta(
    'createdDate',
  );
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
    'created_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    createdDate,
    updatedAt,
    deletedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
        _createdDateMeta,
        createdDate.isAcceptableOrUnknown(
          data['created_date']!,
          _createdDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      createdDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_date'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  /// UUID 主键
  final String id;

  /// 标签名称
  final String name;

  /// 标签颜色值（存储 Flutter Color.value）
  final int color;

  /// 创建时间
  final DateTime createdDate;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 同步状态
  final int syncStatus;
  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdDate,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['created_date'] = Variable<DateTime>(createdDate);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      createdDate: Value(createdDate),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    int? color,
    DateTime? createdDate,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    createdDate: createdDate ?? this.createdDate,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      createdDate: data.createdDate.present
          ? data.createdDate.value
          : this.createdDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdDate: $createdDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    createdDate,
    updatedAt,
    deletedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.createdDate == this.createdDate &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<DateTime> createdDate;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    required int color,
    required DateTime createdDate,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       color = Value(color),
       createdDate = Value(createdDate),
       updatedAt = Value(updatedAt);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (createdDate != null) 'created_date': createdDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? color,
    Value<DateTime>? createdDate,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdDate: createdDate ?? this.createdDate,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdDate: $createdDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioItemTagsTable extends AudioItemTags
    with TableInfo<$AudioItemTagsTable, AudioItemTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioItemTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _audioItemIdMeta = const VerificationMeta(
    'audioItemId',
  );
  @override
  late final GeneratedColumn<String> audioItemId = GeneratedColumn<String>(
    'audio_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES audio_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tagId, audioItemId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_item_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioItemTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('audio_item_id')) {
      context.handle(
        _audioItemIdMeta,
        audioItemId.isAcceptableOrUnknown(
          data['audio_item_id']!,
          _audioItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioItemIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tagId, audioItemId};
  @override
  AudioItemTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioItemTag(
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      audioItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_item_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $AudioItemTagsTable createAlias(String alias) {
    return $AudioItemTagsTable(attachedDatabase, alias);
  }
}

class AudioItemTag extends DataClass implements Insertable<AudioItemTag> {
  /// 标签 ID，外键关联 tags.id
  final String tagId;

  /// 音频 ID，外键关联 audio_items.id
  final String audioItemId;

  /// 添加时间
  final DateTime addedAt;
  const AudioItemTag({
    required this.tagId,
    required this.audioItemId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag_id'] = Variable<String>(tagId);
    map['audio_item_id'] = Variable<String>(audioItemId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  AudioItemTagsCompanion toCompanion(bool nullToAbsent) {
    return AudioItemTagsCompanion(
      tagId: Value(tagId),
      audioItemId: Value(audioItemId),
      addedAt: Value(addedAt),
    );
  }

  factory AudioItemTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioItemTag(
      tagId: serializer.fromJson<String>(json['tagId']),
      audioItemId: serializer.fromJson<String>(json['audioItemId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tagId': serializer.toJson<String>(tagId),
      'audioItemId': serializer.toJson<String>(audioItemId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  AudioItemTag copyWith({
    String? tagId,
    String? audioItemId,
    DateTime? addedAt,
  }) => AudioItemTag(
    tagId: tagId ?? this.tagId,
    audioItemId: audioItemId ?? this.audioItemId,
    addedAt: addedAt ?? this.addedAt,
  );
  AudioItemTag copyWithCompanion(AudioItemTagsCompanion data) {
    return AudioItemTag(
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      audioItemId: data.audioItemId.present
          ? data.audioItemId.value
          : this.audioItemId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioItemTag(')
          ..write('tagId: $tagId, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tagId, audioItemId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioItemTag &&
          other.tagId == this.tagId &&
          other.audioItemId == this.audioItemId &&
          other.addedAt == this.addedAt);
}

class AudioItemTagsCompanion extends UpdateCompanion<AudioItemTag> {
  final Value<String> tagId;
  final Value<String> audioItemId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const AudioItemTagsCompanion({
    this.tagId = const Value.absent(),
    this.audioItemId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioItemTagsCompanion.insert({
    required String tagId,
    required String audioItemId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : tagId = Value(tagId),
       audioItemId = Value(audioItemId),
       addedAt = Value(addedAt);
  static Insertable<AudioItemTag> custom({
    Expression<String>? tagId,
    Expression<String>? audioItemId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tagId != null) 'tag_id': tagId,
      if (audioItemId != null) 'audio_item_id': audioItemId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioItemTagsCompanion copyWith({
    Value<String>? tagId,
    Value<String>? audioItemId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return AudioItemTagsCompanion(
      tagId: tagId ?? this.tagId,
      audioItemId: audioItemId ?? this.audioItemId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (audioItemId.present) {
      map['audio_item_id'] = Variable<String>(audioItemId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioItemTagsCompanion(')
          ..write('tagId: $tagId, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SentenceAiCacheTable extends SentenceAiCache
    with TableInfo<$SentenceAiCacheTable, SentenceAiCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SentenceAiCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _textHashMeta = const VerificationMeta(
    'textHash',
  );
  @override
  late final GeneratedColumn<String> textHash = GeneratedColumn<String>(
    'text_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccessedAt =
      GeneratedColumn<DateTime>(
        'last_accessed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    textHash,
    type,
    result,
    createdAt,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sentence_ai_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<SentenceAiCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('text_hash')) {
      context.handle(
        _textHashMeta,
        textHash.isAcceptableOrUnknown(data['text_hash']!, _textHashMeta),
      );
    } else if (isInserting) {
      context.missing(_textHashMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {textHash, type},
  ];
  @override
  SentenceAiCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SentenceAiCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      textHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_hash'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $SentenceAiCacheTable createAlias(String alias) {
    return $SentenceAiCacheTable(attachedDatabase, alias);
  }
}

class SentenceAiCacheData extends DataClass
    implements Insertable<SentenceAiCacheData> {
  /// 自增主键
  final int id;

  /// 句子文本的 SHA-256 哈希值（归一化后）
  final String textHash;

  /// 结果类型：'translation' 或 'analysis'
  final String type;

  /// API 返回的 JSON 字符串
  final String result;

  /// 创建时间
  final DateTime createdAt;

  /// 最后访问时间（用于 LRU 清理）
  final DateTime lastAccessedAt;
  const SentenceAiCacheData({
    required this.id,
    required this.textHash,
    required this.type,
    required this.result,
    required this.createdAt,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['text_hash'] = Variable<String>(textHash);
    map['type'] = Variable<String>(type);
    map['result'] = Variable<String>(result);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt);
    return map;
  }

  SentenceAiCacheCompanion toCompanion(bool nullToAbsent) {
    return SentenceAiCacheCompanion(
      id: Value(id),
      textHash: Value(textHash),
      type: Value(type),
      result: Value(result),
      createdAt: Value(createdAt),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory SentenceAiCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SentenceAiCacheData(
      id: serializer.fromJson<int>(json['id']),
      textHash: serializer.fromJson<String>(json['textHash']),
      type: serializer.fromJson<String>(json['type']),
      result: serializer.fromJson<String>(json['result']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAccessedAt: serializer.fromJson<DateTime>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'textHash': serializer.toJson<String>(textHash),
      'type': serializer.toJson<String>(type),
      'result': serializer.toJson<String>(result),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAccessedAt': serializer.toJson<DateTime>(lastAccessedAt),
    };
  }

  SentenceAiCacheData copyWith({
    int? id,
    String? textHash,
    String? type,
    String? result,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
  }) => SentenceAiCacheData(
    id: id ?? this.id,
    textHash: textHash ?? this.textHash,
    type: type ?? this.type,
    result: result ?? this.result,
    createdAt: createdAt ?? this.createdAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  SentenceAiCacheData copyWithCompanion(SentenceAiCacheCompanion data) {
    return SentenceAiCacheData(
      id: data.id.present ? data.id.value : this.id,
      textHash: data.textHash.present ? data.textHash.value : this.textHash,
      type: data.type.present ? data.type.value : this.type,
      result: data.result.present ? data.result.value : this.result,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SentenceAiCacheData(')
          ..write('id: $id, ')
          ..write('textHash: $textHash, ')
          ..write('type: $type, ')
          ..write('result: $result, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, textHash, type, result, createdAt, lastAccessedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SentenceAiCacheData &&
          other.id == this.id &&
          other.textHash == this.textHash &&
          other.type == this.type &&
          other.result == this.result &&
          other.createdAt == this.createdAt &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class SentenceAiCacheCompanion extends UpdateCompanion<SentenceAiCacheData> {
  final Value<int> id;
  final Value<String> textHash;
  final Value<String> type;
  final Value<String> result;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastAccessedAt;
  const SentenceAiCacheCompanion({
    this.id = const Value.absent(),
    this.textHash = const Value.absent(),
    this.type = const Value.absent(),
    this.result = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
  });
  SentenceAiCacheCompanion.insert({
    this.id = const Value.absent(),
    required String textHash,
    required String type,
    required String result,
    required DateTime createdAt,
    required DateTime lastAccessedAt,
  }) : textHash = Value(textHash),
       type = Value(type),
       result = Value(result),
       createdAt = Value(createdAt),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<SentenceAiCacheData> custom({
    Expression<int>? id,
    Expression<String>? textHash,
    Expression<String>? type,
    Expression<String>? result,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAccessedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (textHash != null) 'text_hash': textHash,
      if (type != null) 'type': type,
      if (result != null) 'result': result,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
    });
  }

  SentenceAiCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? textHash,
    Value<String>? type,
    Value<String>? result,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastAccessedAt,
  }) {
    return SentenceAiCacheCompanion(
      id: id ?? this.id,
      textHash: textHash ?? this.textHash,
      type: type ?? this.type,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (textHash.present) {
      map['text_hash'] = Variable<String>(textHash.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SentenceAiCacheCompanion(')
          ..write('id: $id, ')
          ..write('textHash: $textHash, ')
          ..write('type: $type, ')
          ..write('result: $result, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }
}

class $SavedWordsTable extends SavedWords
    with TableInfo<$SavedWordsTable, SavedWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _audioItemIdMeta = const VerificationMeta(
    'audioItemId',
  );
  @override
  late final GeneratedColumn<String> audioItemId = GeneratedColumn<String>(
    'audio_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES audio_items (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sentenceIndexMeta = const VerificationMeta(
    'sentenceIndex',
  );
  @override
  late final GeneratedColumn<int> sentenceIndex = GeneratedColumn<int>(
    'sentence_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceTextMeta = const VerificationMeta(
    'sentenceText',
  );
  @override
  late final GeneratedColumn<String> sentenceText = GeneratedColumn<String>(
    'sentence_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceStartMsMeta = const VerificationMeta(
    'sentenceStartMs',
  );
  @override
  late final GeneratedColumn<int> sentenceStartMs = GeneratedColumn<int>(
    'sentence_start_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceEndMsMeta = const VerificationMeta(
    'sentenceEndMs',
  );
  @override
  late final GeneratedColumn<int> sentenceEndMs = GeneratedColumn<int>(
    'sentence_end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _practiceCountMeta = const VerificationMeta(
    'practiceCount',
  );
  @override
  late final GeneratedColumn<int> practiceCount = GeneratedColumn<int>(
    'practice_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalStudyMsMeta = const VerificationMeta(
    'totalStudyMs',
  );
  @override
  late final GeneratedColumn<int> totalStudyMs = GeneratedColumn<int>(
    'total_study_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _viewedBackMeta = const VerificationMeta(
    'viewedBack',
  );
  @override
  late final GeneratedColumn<bool> viewedBack = GeneratedColumn<bool>(
    'viewed_back',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("viewed_back" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastPracticedAtMeta = const VerificationMeta(
    'lastPracticedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPracticedAt =
      GeneratedColumn<DateTime>(
        'last_practiced_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    word,
    audioItemId,
    sentenceIndex,
    sentenceText,
    sentenceStartMs,
    sentenceEndMs,
    practiceCount,
    totalStudyMs,
    viewedBack,
    lastPracticedAt,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_words';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedWord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('audio_item_id')) {
      context.handle(
        _audioItemIdMeta,
        audioItemId.isAcceptableOrUnknown(
          data['audio_item_id']!,
          _audioItemIdMeta,
        ),
      );
    }
    if (data.containsKey('sentence_index')) {
      context.handle(
        _sentenceIndexMeta,
        sentenceIndex.isAcceptableOrUnknown(
          data['sentence_index']!,
          _sentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('sentence_text')) {
      context.handle(
        _sentenceTextMeta,
        sentenceText.isAcceptableOrUnknown(
          data['sentence_text']!,
          _sentenceTextMeta,
        ),
      );
    }
    if (data.containsKey('sentence_start_ms')) {
      context.handle(
        _sentenceStartMsMeta,
        sentenceStartMs.isAcceptableOrUnknown(
          data['sentence_start_ms']!,
          _sentenceStartMsMeta,
        ),
      );
    }
    if (data.containsKey('sentence_end_ms')) {
      context.handle(
        _sentenceEndMsMeta,
        sentenceEndMs.isAcceptableOrUnknown(
          data['sentence_end_ms']!,
          _sentenceEndMsMeta,
        ),
      );
    }
    if (data.containsKey('practice_count')) {
      context.handle(
        _practiceCountMeta,
        practiceCount.isAcceptableOrUnknown(
          data['practice_count']!,
          _practiceCountMeta,
        ),
      );
    }
    if (data.containsKey('total_study_ms')) {
      context.handle(
        _totalStudyMsMeta,
        totalStudyMs.isAcceptableOrUnknown(
          data['total_study_ms']!,
          _totalStudyMsMeta,
        ),
      );
    }
    if (data.containsKey('viewed_back')) {
      context.handle(
        _viewedBackMeta,
        viewedBack.isAcceptableOrUnknown(data['viewed_back']!, _viewedBackMeta),
      );
    }
    if (data.containsKey('last_practiced_at')) {
      context.handle(
        _lastPracticedAtMeta,
        lastPracticedAt.isAcceptableOrUnknown(
          data['last_practiced_at']!,
          _lastPracticedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedWord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      audioItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_item_id'],
      ),
      sentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_index'],
      ),
      sentenceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_text'],
      ),
      sentenceStartMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_start_ms'],
      ),
      sentenceEndMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_end_ms'],
      ),
      practiceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}practice_count'],
      )!,
      totalStudyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_study_ms'],
      )!,
      viewedBack: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}viewed_back'],
      )!,
      lastPracticedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_practiced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $SavedWordsTable createAlias(String alias) {
    return $SavedWordsTable(attachedDatabase, alias);
  }
}

class SavedWord extends DataClass implements Insertable<SavedWord> {
  /// 自增主键
  final int id;

  /// 单词原形（小写，lemmatized），全局唯一
  final String word;

  /// 来源音频 ID，FK → audio_items，音频删除时置空
  final String? audioItemId;

  /// 来源句子索引
  final int? sentenceIndex;

  /// 来源句子文本（冗余存储，防止索引错位或音频删除后丢失上下文）
  final String? sentenceText;

  /// 来源句子起始时间（毫秒），冗余存储，删除字幕后仍可播放
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒），冗余存储，删除字幕后仍可播放
  final int? sentenceEndMs;

  /// 练习次数（Flashcard 翻转到背面计为 1 次）
  final int practiceCount;

  /// 累计学习时长（毫秒），单张卡片最长 60 秒截断
  final int totalStudyMs;

  /// 是否曾翻转到背面查看释义
  final bool viewedBack;

  /// 最近一次练习时间
  final DateTime? lastPracticedAt;

  /// 收藏时间
  final DateTime createdAt;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 同步状态（预留）
  final int syncStatus;
  const SavedWord({
    required this.id,
    required this.word,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
    required this.practiceCount,
    required this.totalStudyMs,
    required this.viewedBack,
    this.lastPracticedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word'] = Variable<String>(word);
    if (!nullToAbsent || audioItemId != null) {
      map['audio_item_id'] = Variable<String>(audioItemId);
    }
    if (!nullToAbsent || sentenceIndex != null) {
      map['sentence_index'] = Variable<int>(sentenceIndex);
    }
    if (!nullToAbsent || sentenceText != null) {
      map['sentence_text'] = Variable<String>(sentenceText);
    }
    if (!nullToAbsent || sentenceStartMs != null) {
      map['sentence_start_ms'] = Variable<int>(sentenceStartMs);
    }
    if (!nullToAbsent || sentenceEndMs != null) {
      map['sentence_end_ms'] = Variable<int>(sentenceEndMs);
    }
    map['practice_count'] = Variable<int>(practiceCount);
    map['total_study_ms'] = Variable<int>(totalStudyMs);
    map['viewed_back'] = Variable<bool>(viewedBack);
    if (!nullToAbsent || lastPracticedAt != null) {
      map['last_practiced_at'] = Variable<DateTime>(lastPracticedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  SavedWordsCompanion toCompanion(bool nullToAbsent) {
    return SavedWordsCompanion(
      id: Value(id),
      word: Value(word),
      audioItemId: audioItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(audioItemId),
      sentenceIndex: sentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceIndex),
      sentenceText: sentenceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceText),
      sentenceStartMs: sentenceStartMs == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceStartMs),
      sentenceEndMs: sentenceEndMs == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceEndMs),
      practiceCount: Value(practiceCount),
      totalStudyMs: Value(totalStudyMs),
      viewedBack: Value(viewedBack),
      lastPracticedAt: lastPracticedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPracticedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory SavedWord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedWord(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      audioItemId: serializer.fromJson<String?>(json['audioItemId']),
      sentenceIndex: serializer.fromJson<int?>(json['sentenceIndex']),
      sentenceText: serializer.fromJson<String?>(json['sentenceText']),
      sentenceStartMs: serializer.fromJson<int?>(json['sentenceStartMs']),
      sentenceEndMs: serializer.fromJson<int?>(json['sentenceEndMs']),
      practiceCount: serializer.fromJson<int>(json['practiceCount']),
      totalStudyMs: serializer.fromJson<int>(json['totalStudyMs']),
      viewedBack: serializer.fromJson<bool>(json['viewedBack']),
      lastPracticedAt: serializer.fromJson<DateTime?>(json['lastPracticedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'audioItemId': serializer.toJson<String?>(audioItemId),
      'sentenceIndex': serializer.toJson<int?>(sentenceIndex),
      'sentenceText': serializer.toJson<String?>(sentenceText),
      'sentenceStartMs': serializer.toJson<int?>(sentenceStartMs),
      'sentenceEndMs': serializer.toJson<int?>(sentenceEndMs),
      'practiceCount': serializer.toJson<int>(practiceCount),
      'totalStudyMs': serializer.toJson<int>(totalStudyMs),
      'viewedBack': serializer.toJson<bool>(viewedBack),
      'lastPracticedAt': serializer.toJson<DateTime?>(lastPracticedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  SavedWord copyWith({
    int? id,
    String? word,
    Value<String?> audioItemId = const Value.absent(),
    Value<int?> sentenceIndex = const Value.absent(),
    Value<String?> sentenceText = const Value.absent(),
    Value<int?> sentenceStartMs = const Value.absent(),
    Value<int?> sentenceEndMs = const Value.absent(),
    int? practiceCount,
    int? totalStudyMs,
    bool? viewedBack,
    Value<DateTime?> lastPracticedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => SavedWord(
    id: id ?? this.id,
    word: word ?? this.word,
    audioItemId: audioItemId.present ? audioItemId.value : this.audioItemId,
    sentenceIndex: sentenceIndex.present
        ? sentenceIndex.value
        : this.sentenceIndex,
    sentenceText: sentenceText.present ? sentenceText.value : this.sentenceText,
    sentenceStartMs: sentenceStartMs.present
        ? sentenceStartMs.value
        : this.sentenceStartMs,
    sentenceEndMs: sentenceEndMs.present
        ? sentenceEndMs.value
        : this.sentenceEndMs,
    practiceCount: practiceCount ?? this.practiceCount,
    totalStudyMs: totalStudyMs ?? this.totalStudyMs,
    viewedBack: viewedBack ?? this.viewedBack,
    lastPracticedAt: lastPracticedAt.present
        ? lastPracticedAt.value
        : this.lastPracticedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  SavedWord copyWithCompanion(SavedWordsCompanion data) {
    return SavedWord(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      audioItemId: data.audioItemId.present
          ? data.audioItemId.value
          : this.audioItemId,
      sentenceIndex: data.sentenceIndex.present
          ? data.sentenceIndex.value
          : this.sentenceIndex,
      sentenceText: data.sentenceText.present
          ? data.sentenceText.value
          : this.sentenceText,
      sentenceStartMs: data.sentenceStartMs.present
          ? data.sentenceStartMs.value
          : this.sentenceStartMs,
      sentenceEndMs: data.sentenceEndMs.present
          ? data.sentenceEndMs.value
          : this.sentenceEndMs,
      practiceCount: data.practiceCount.present
          ? data.practiceCount.value
          : this.practiceCount,
      totalStudyMs: data.totalStudyMs.present
          ? data.totalStudyMs.value
          : this.totalStudyMs,
      viewedBack: data.viewedBack.present
          ? data.viewedBack.value
          : this.viewedBack,
      lastPracticedAt: data.lastPracticedAt.present
          ? data.lastPracticedAt.value
          : this.lastPracticedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedWord(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('sentenceText: $sentenceText, ')
          ..write('sentenceStartMs: $sentenceStartMs, ')
          ..write('sentenceEndMs: $sentenceEndMs, ')
          ..write('practiceCount: $practiceCount, ')
          ..write('totalStudyMs: $totalStudyMs, ')
          ..write('viewedBack: $viewedBack, ')
          ..write('lastPracticedAt: $lastPracticedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    word,
    audioItemId,
    sentenceIndex,
    sentenceText,
    sentenceStartMs,
    sentenceEndMs,
    practiceCount,
    totalStudyMs,
    viewedBack,
    lastPracticedAt,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedWord &&
          other.id == this.id &&
          other.word == this.word &&
          other.audioItemId == this.audioItemId &&
          other.sentenceIndex == this.sentenceIndex &&
          other.sentenceText == this.sentenceText &&
          other.sentenceStartMs == this.sentenceStartMs &&
          other.sentenceEndMs == this.sentenceEndMs &&
          other.practiceCount == this.practiceCount &&
          other.totalStudyMs == this.totalStudyMs &&
          other.viewedBack == this.viewedBack &&
          other.lastPracticedAt == this.lastPracticedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class SavedWordsCompanion extends UpdateCompanion<SavedWord> {
  final Value<int> id;
  final Value<String> word;
  final Value<String?> audioItemId;
  final Value<int?> sentenceIndex;
  final Value<String?> sentenceText;
  final Value<int?> sentenceStartMs;
  final Value<int?> sentenceEndMs;
  final Value<int> practiceCount;
  final Value<int> totalStudyMs;
  final Value<bool> viewedBack;
  final Value<DateTime?> lastPracticedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  const SavedWordsCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.audioItemId = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.sentenceText = const Value.absent(),
    this.sentenceStartMs = const Value.absent(),
    this.sentenceEndMs = const Value.absent(),
    this.practiceCount = const Value.absent(),
    this.totalStudyMs = const Value.absent(),
    this.viewedBack = const Value.absent(),
    this.lastPracticedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  SavedWordsCompanion.insert({
    this.id = const Value.absent(),
    required String word,
    this.audioItemId = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.sentenceText = const Value.absent(),
    this.sentenceStartMs = const Value.absent(),
    this.sentenceEndMs = const Value.absent(),
    this.practiceCount = const Value.absent(),
    this.totalStudyMs = const Value.absent(),
    this.viewedBack = const Value.absent(),
    this.lastPracticedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : word = Value(word),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SavedWord> custom({
    Expression<int>? id,
    Expression<String>? word,
    Expression<String>? audioItemId,
    Expression<int>? sentenceIndex,
    Expression<String>? sentenceText,
    Expression<int>? sentenceStartMs,
    Expression<int>? sentenceEndMs,
    Expression<int>? practiceCount,
    Expression<int>? totalStudyMs,
    Expression<bool>? viewedBack,
    Expression<DateTime>? lastPracticedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (audioItemId != null) 'audio_item_id': audioItemId,
      if (sentenceIndex != null) 'sentence_index': sentenceIndex,
      if (sentenceText != null) 'sentence_text': sentenceText,
      if (sentenceStartMs != null) 'sentence_start_ms': sentenceStartMs,
      if (sentenceEndMs != null) 'sentence_end_ms': sentenceEndMs,
      if (practiceCount != null) 'practice_count': practiceCount,
      if (totalStudyMs != null) 'total_study_ms': totalStudyMs,
      if (viewedBack != null) 'viewed_back': viewedBack,
      if (lastPracticedAt != null) 'last_practiced_at': lastPracticedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  SavedWordsCompanion copyWith({
    Value<int>? id,
    Value<String>? word,
    Value<String?>? audioItemId,
    Value<int?>? sentenceIndex,
    Value<String?>? sentenceText,
    Value<int?>? sentenceStartMs,
    Value<int?>? sentenceEndMs,
    Value<int>? practiceCount,
    Value<int>? totalStudyMs,
    Value<bool>? viewedBack,
    Value<DateTime?>? lastPracticedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
  }) {
    return SavedWordsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      audioItemId: audioItemId ?? this.audioItemId,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      sentenceText: sentenceText ?? this.sentenceText,
      sentenceStartMs: sentenceStartMs ?? this.sentenceStartMs,
      sentenceEndMs: sentenceEndMs ?? this.sentenceEndMs,
      practiceCount: practiceCount ?? this.practiceCount,
      totalStudyMs: totalStudyMs ?? this.totalStudyMs,
      viewedBack: viewedBack ?? this.viewedBack,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (audioItemId.present) {
      map['audio_item_id'] = Variable<String>(audioItemId.value);
    }
    if (sentenceIndex.present) {
      map['sentence_index'] = Variable<int>(sentenceIndex.value);
    }
    if (sentenceText.present) {
      map['sentence_text'] = Variable<String>(sentenceText.value);
    }
    if (sentenceStartMs.present) {
      map['sentence_start_ms'] = Variable<int>(sentenceStartMs.value);
    }
    if (sentenceEndMs.present) {
      map['sentence_end_ms'] = Variable<int>(sentenceEndMs.value);
    }
    if (practiceCount.present) {
      map['practice_count'] = Variable<int>(practiceCount.value);
    }
    if (totalStudyMs.present) {
      map['total_study_ms'] = Variable<int>(totalStudyMs.value);
    }
    if (viewedBack.present) {
      map['viewed_back'] = Variable<bool>(viewedBack.value);
    }
    if (lastPracticedAt.present) {
      map['last_practiced_at'] = Variable<DateTime>(lastPracticedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedWordsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('sentenceText: $sentenceText, ')
          ..write('sentenceStartMs: $sentenceStartMs, ')
          ..write('sentenceEndMs: $sentenceEndMs, ')
          ..write('practiceCount: $practiceCount, ')
          ..write('totalStudyMs: $totalStudyMs, ')
          ..write('viewedBack: $viewedBack, ')
          ..write('lastPracticedAt: $lastPracticedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $SavedSenseGroupsTable extends SavedSenseGroups
    with TableInfo<$SavedSenseGroupsTable, SavedSenseGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedSenseGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _phraseTextMeta = const VerificationMeta(
    'phraseText',
  );
  @override
  late final GeneratedColumn<String> phraseText = GeneratedColumn<String>(
    'phrase_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayTextMeta = const VerificationMeta(
    'displayText',
  );
  @override
  late final GeneratedColumn<String> displayText = GeneratedColumn<String>(
    'display_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioItemIdMeta = const VerificationMeta(
    'audioItemId',
  );
  @override
  late final GeneratedColumn<String> audioItemId = GeneratedColumn<String>(
    'audio_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES audio_items (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sentenceIndexMeta = const VerificationMeta(
    'sentenceIndex',
  );
  @override
  late final GeneratedColumn<int> sentenceIndex = GeneratedColumn<int>(
    'sentence_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceTextMeta = const VerificationMeta(
    'sentenceText',
  );
  @override
  late final GeneratedColumn<String> sentenceText = GeneratedColumn<String>(
    'sentence_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceStartMsMeta = const VerificationMeta(
    'sentenceStartMs',
  );
  @override
  late final GeneratedColumn<int> sentenceStartMs = GeneratedColumn<int>(
    'sentence_start_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceEndMsMeta = const VerificationMeta(
    'sentenceEndMs',
  );
  @override
  late final GeneratedColumn<int> sentenceEndMs = GeneratedColumn<int>(
    'sentence_end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupStartMsMeta = const VerificationMeta(
    'groupStartMs',
  );
  @override
  late final GeneratedColumn<int> groupStartMs = GeneratedColumn<int>(
    'group_start_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupEndMsMeta = const VerificationMeta(
    'groupEndMs',
  );
  @override
  late final GeneratedColumn<int> groupEndMs = GeneratedColumn<int>(
    'group_end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _practiceCountMeta = const VerificationMeta(
    'practiceCount',
  );
  @override
  late final GeneratedColumn<int> practiceCount = GeneratedColumn<int>(
    'practice_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalStudyMsMeta = const VerificationMeta(
    'totalStudyMs',
  );
  @override
  late final GeneratedColumn<int> totalStudyMs = GeneratedColumn<int>(
    'total_study_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _viewedBackMeta = const VerificationMeta(
    'viewedBack',
  );
  @override
  late final GeneratedColumn<bool> viewedBack = GeneratedColumn<bool>(
    'viewed_back',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("viewed_back" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastPracticedAtMeta = const VerificationMeta(
    'lastPracticedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPracticedAt =
      GeneratedColumn<DateTime>(
        'last_practiced_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    phraseText,
    displayText,
    audioItemId,
    sentenceIndex,
    sentenceText,
    sentenceStartMs,
    sentenceEndMs,
    groupStartMs,
    groupEndMs,
    practiceCount,
    totalStudyMs,
    viewedBack,
    lastPracticedAt,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_sense_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedSenseGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('phrase_text')) {
      context.handle(
        _phraseTextMeta,
        phraseText.isAcceptableOrUnknown(data['phrase_text']!, _phraseTextMeta),
      );
    } else if (isInserting) {
      context.missing(_phraseTextMeta);
    }
    if (data.containsKey('display_text')) {
      context.handle(
        _displayTextMeta,
        displayText.isAcceptableOrUnknown(
          data['display_text']!,
          _displayTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayTextMeta);
    }
    if (data.containsKey('audio_item_id')) {
      context.handle(
        _audioItemIdMeta,
        audioItemId.isAcceptableOrUnknown(
          data['audio_item_id']!,
          _audioItemIdMeta,
        ),
      );
    }
    if (data.containsKey('sentence_index')) {
      context.handle(
        _sentenceIndexMeta,
        sentenceIndex.isAcceptableOrUnknown(
          data['sentence_index']!,
          _sentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('sentence_text')) {
      context.handle(
        _sentenceTextMeta,
        sentenceText.isAcceptableOrUnknown(
          data['sentence_text']!,
          _sentenceTextMeta,
        ),
      );
    }
    if (data.containsKey('sentence_start_ms')) {
      context.handle(
        _sentenceStartMsMeta,
        sentenceStartMs.isAcceptableOrUnknown(
          data['sentence_start_ms']!,
          _sentenceStartMsMeta,
        ),
      );
    }
    if (data.containsKey('sentence_end_ms')) {
      context.handle(
        _sentenceEndMsMeta,
        sentenceEndMs.isAcceptableOrUnknown(
          data['sentence_end_ms']!,
          _sentenceEndMsMeta,
        ),
      );
    }
    if (data.containsKey('group_start_ms')) {
      context.handle(
        _groupStartMsMeta,
        groupStartMs.isAcceptableOrUnknown(
          data['group_start_ms']!,
          _groupStartMsMeta,
        ),
      );
    }
    if (data.containsKey('group_end_ms')) {
      context.handle(
        _groupEndMsMeta,
        groupEndMs.isAcceptableOrUnknown(
          data['group_end_ms']!,
          _groupEndMsMeta,
        ),
      );
    }
    if (data.containsKey('practice_count')) {
      context.handle(
        _practiceCountMeta,
        practiceCount.isAcceptableOrUnknown(
          data['practice_count']!,
          _practiceCountMeta,
        ),
      );
    }
    if (data.containsKey('total_study_ms')) {
      context.handle(
        _totalStudyMsMeta,
        totalStudyMs.isAcceptableOrUnknown(
          data['total_study_ms']!,
          _totalStudyMsMeta,
        ),
      );
    }
    if (data.containsKey('viewed_back')) {
      context.handle(
        _viewedBackMeta,
        viewedBack.isAcceptableOrUnknown(data['viewed_back']!, _viewedBackMeta),
      );
    }
    if (data.containsKey('last_practiced_at')) {
      context.handle(
        _lastPracticedAtMeta,
        lastPracticedAt.isAcceptableOrUnknown(
          data['last_practiced_at']!,
          _lastPracticedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedSenseGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedSenseGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      phraseText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase_text'],
      )!,
      displayText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_text'],
      )!,
      audioItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_item_id'],
      ),
      sentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_index'],
      ),
      sentenceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_text'],
      ),
      sentenceStartMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_start_ms'],
      ),
      sentenceEndMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_end_ms'],
      ),
      groupStartMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_start_ms'],
      ),
      groupEndMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_end_ms'],
      ),
      practiceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}practice_count'],
      )!,
      totalStudyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_study_ms'],
      )!,
      viewedBack: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}viewed_back'],
      )!,
      lastPracticedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_practiced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $SavedSenseGroupsTable createAlias(String alias) {
    return $SavedSenseGroupsTable(attachedDatabase, alias);
  }
}

class SavedSenseGroup extends DataClass implements Insertable<SavedSenseGroup> {
  /// 自增主键
  final int id;

  /// 意群文本（归一化：小写 + trim + 去句末标点，保留撇号），全局唯一
  final String phraseText;

  /// 意群原始文本（保留大小写，用于展示）
  final String displayText;

  /// 来源音频 ID，FK → audio_items，音频删除时置空
  final String? audioItemId;

  /// 来源句子索引
  final int? sentenceIndex;

  /// 来源句子文本（冗余存储，闪卡复习时展示上下文）
  final String? sentenceText;

  /// 来源句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// 意群精确起始时间（毫秒），用于收藏页直接播放意群片段
  final int? groupStartMs;

  /// 意群精确结束时间（毫秒）
  final int? groupEndMs;

  /// 练习次数（Flashcard 翻转到背面计为 1 次）
  final int practiceCount;

  /// 累计学习时长（毫秒），单张卡片最长 60 秒截断
  final int totalStudyMs;

  /// 是否曾翻转到背面查看释义
  final bool viewedBack;

  /// 最近一次练习时间
  final DateTime? lastPracticedAt;

  /// 收藏时间
  final DateTime createdAt;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 同步状态（预留）
  final int syncStatus;
  const SavedSenseGroup({
    required this.id,
    required this.phraseText,
    required this.displayText,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.groupStartMs,
    this.groupEndMs,
    required this.practiceCount,
    required this.totalStudyMs,
    required this.viewedBack,
    this.lastPracticedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['phrase_text'] = Variable<String>(phraseText);
    map['display_text'] = Variable<String>(displayText);
    if (!nullToAbsent || audioItemId != null) {
      map['audio_item_id'] = Variable<String>(audioItemId);
    }
    if (!nullToAbsent || sentenceIndex != null) {
      map['sentence_index'] = Variable<int>(sentenceIndex);
    }
    if (!nullToAbsent || sentenceText != null) {
      map['sentence_text'] = Variable<String>(sentenceText);
    }
    if (!nullToAbsent || sentenceStartMs != null) {
      map['sentence_start_ms'] = Variable<int>(sentenceStartMs);
    }
    if (!nullToAbsent || sentenceEndMs != null) {
      map['sentence_end_ms'] = Variable<int>(sentenceEndMs);
    }
    if (!nullToAbsent || groupStartMs != null) {
      map['group_start_ms'] = Variable<int>(groupStartMs);
    }
    if (!nullToAbsent || groupEndMs != null) {
      map['group_end_ms'] = Variable<int>(groupEndMs);
    }
    map['practice_count'] = Variable<int>(practiceCount);
    map['total_study_ms'] = Variable<int>(totalStudyMs);
    map['viewed_back'] = Variable<bool>(viewedBack);
    if (!nullToAbsent || lastPracticedAt != null) {
      map['last_practiced_at'] = Variable<DateTime>(lastPracticedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  SavedSenseGroupsCompanion toCompanion(bool nullToAbsent) {
    return SavedSenseGroupsCompanion(
      id: Value(id),
      phraseText: Value(phraseText),
      displayText: Value(displayText),
      audioItemId: audioItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(audioItemId),
      sentenceIndex: sentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceIndex),
      sentenceText: sentenceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceText),
      sentenceStartMs: sentenceStartMs == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceStartMs),
      sentenceEndMs: sentenceEndMs == null && nullToAbsent
          ? const Value.absent()
          : Value(sentenceEndMs),
      groupStartMs: groupStartMs == null && nullToAbsent
          ? const Value.absent()
          : Value(groupStartMs),
      groupEndMs: groupEndMs == null && nullToAbsent
          ? const Value.absent()
          : Value(groupEndMs),
      practiceCount: Value(practiceCount),
      totalStudyMs: Value(totalStudyMs),
      viewedBack: Value(viewedBack),
      lastPracticedAt: lastPracticedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPracticedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory SavedSenseGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedSenseGroup(
      id: serializer.fromJson<int>(json['id']),
      phraseText: serializer.fromJson<String>(json['phraseText']),
      displayText: serializer.fromJson<String>(json['displayText']),
      audioItemId: serializer.fromJson<String?>(json['audioItemId']),
      sentenceIndex: serializer.fromJson<int?>(json['sentenceIndex']),
      sentenceText: serializer.fromJson<String?>(json['sentenceText']),
      sentenceStartMs: serializer.fromJson<int?>(json['sentenceStartMs']),
      sentenceEndMs: serializer.fromJson<int?>(json['sentenceEndMs']),
      groupStartMs: serializer.fromJson<int?>(json['groupStartMs']),
      groupEndMs: serializer.fromJson<int?>(json['groupEndMs']),
      practiceCount: serializer.fromJson<int>(json['practiceCount']),
      totalStudyMs: serializer.fromJson<int>(json['totalStudyMs']),
      viewedBack: serializer.fromJson<bool>(json['viewedBack']),
      lastPracticedAt: serializer.fromJson<DateTime?>(json['lastPracticedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'phraseText': serializer.toJson<String>(phraseText),
      'displayText': serializer.toJson<String>(displayText),
      'audioItemId': serializer.toJson<String?>(audioItemId),
      'sentenceIndex': serializer.toJson<int?>(sentenceIndex),
      'sentenceText': serializer.toJson<String?>(sentenceText),
      'sentenceStartMs': serializer.toJson<int?>(sentenceStartMs),
      'sentenceEndMs': serializer.toJson<int?>(sentenceEndMs),
      'groupStartMs': serializer.toJson<int?>(groupStartMs),
      'groupEndMs': serializer.toJson<int?>(groupEndMs),
      'practiceCount': serializer.toJson<int>(practiceCount),
      'totalStudyMs': serializer.toJson<int>(totalStudyMs),
      'viewedBack': serializer.toJson<bool>(viewedBack),
      'lastPracticedAt': serializer.toJson<DateTime?>(lastPracticedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  SavedSenseGroup copyWith({
    int? id,
    String? phraseText,
    String? displayText,
    Value<String?> audioItemId = const Value.absent(),
    Value<int?> sentenceIndex = const Value.absent(),
    Value<String?> sentenceText = const Value.absent(),
    Value<int?> sentenceStartMs = const Value.absent(),
    Value<int?> sentenceEndMs = const Value.absent(),
    Value<int?> groupStartMs = const Value.absent(),
    Value<int?> groupEndMs = const Value.absent(),
    int? practiceCount,
    int? totalStudyMs,
    bool? viewedBack,
    Value<DateTime?> lastPracticedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => SavedSenseGroup(
    id: id ?? this.id,
    phraseText: phraseText ?? this.phraseText,
    displayText: displayText ?? this.displayText,
    audioItemId: audioItemId.present ? audioItemId.value : this.audioItemId,
    sentenceIndex: sentenceIndex.present
        ? sentenceIndex.value
        : this.sentenceIndex,
    sentenceText: sentenceText.present ? sentenceText.value : this.sentenceText,
    sentenceStartMs: sentenceStartMs.present
        ? sentenceStartMs.value
        : this.sentenceStartMs,
    sentenceEndMs: sentenceEndMs.present
        ? sentenceEndMs.value
        : this.sentenceEndMs,
    groupStartMs: groupStartMs.present ? groupStartMs.value : this.groupStartMs,
    groupEndMs: groupEndMs.present ? groupEndMs.value : this.groupEndMs,
    practiceCount: practiceCount ?? this.practiceCount,
    totalStudyMs: totalStudyMs ?? this.totalStudyMs,
    viewedBack: viewedBack ?? this.viewedBack,
    lastPracticedAt: lastPracticedAt.present
        ? lastPracticedAt.value
        : this.lastPracticedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  SavedSenseGroup copyWithCompanion(SavedSenseGroupsCompanion data) {
    return SavedSenseGroup(
      id: data.id.present ? data.id.value : this.id,
      phraseText: data.phraseText.present
          ? data.phraseText.value
          : this.phraseText,
      displayText: data.displayText.present
          ? data.displayText.value
          : this.displayText,
      audioItemId: data.audioItemId.present
          ? data.audioItemId.value
          : this.audioItemId,
      sentenceIndex: data.sentenceIndex.present
          ? data.sentenceIndex.value
          : this.sentenceIndex,
      sentenceText: data.sentenceText.present
          ? data.sentenceText.value
          : this.sentenceText,
      sentenceStartMs: data.sentenceStartMs.present
          ? data.sentenceStartMs.value
          : this.sentenceStartMs,
      sentenceEndMs: data.sentenceEndMs.present
          ? data.sentenceEndMs.value
          : this.sentenceEndMs,
      groupStartMs: data.groupStartMs.present
          ? data.groupStartMs.value
          : this.groupStartMs,
      groupEndMs: data.groupEndMs.present
          ? data.groupEndMs.value
          : this.groupEndMs,
      practiceCount: data.practiceCount.present
          ? data.practiceCount.value
          : this.practiceCount,
      totalStudyMs: data.totalStudyMs.present
          ? data.totalStudyMs.value
          : this.totalStudyMs,
      viewedBack: data.viewedBack.present
          ? data.viewedBack.value
          : this.viewedBack,
      lastPracticedAt: data.lastPracticedAt.present
          ? data.lastPracticedAt.value
          : this.lastPracticedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedSenseGroup(')
          ..write('id: $id, ')
          ..write('phraseText: $phraseText, ')
          ..write('displayText: $displayText, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('sentenceText: $sentenceText, ')
          ..write('sentenceStartMs: $sentenceStartMs, ')
          ..write('sentenceEndMs: $sentenceEndMs, ')
          ..write('groupStartMs: $groupStartMs, ')
          ..write('groupEndMs: $groupEndMs, ')
          ..write('practiceCount: $practiceCount, ')
          ..write('totalStudyMs: $totalStudyMs, ')
          ..write('viewedBack: $viewedBack, ')
          ..write('lastPracticedAt: $lastPracticedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    phraseText,
    displayText,
    audioItemId,
    sentenceIndex,
    sentenceText,
    sentenceStartMs,
    sentenceEndMs,
    groupStartMs,
    groupEndMs,
    practiceCount,
    totalStudyMs,
    viewedBack,
    lastPracticedAt,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedSenseGroup &&
          other.id == this.id &&
          other.phraseText == this.phraseText &&
          other.displayText == this.displayText &&
          other.audioItemId == this.audioItemId &&
          other.sentenceIndex == this.sentenceIndex &&
          other.sentenceText == this.sentenceText &&
          other.sentenceStartMs == this.sentenceStartMs &&
          other.sentenceEndMs == this.sentenceEndMs &&
          other.groupStartMs == this.groupStartMs &&
          other.groupEndMs == this.groupEndMs &&
          other.practiceCount == this.practiceCount &&
          other.totalStudyMs == this.totalStudyMs &&
          other.viewedBack == this.viewedBack &&
          other.lastPracticedAt == this.lastPracticedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class SavedSenseGroupsCompanion extends UpdateCompanion<SavedSenseGroup> {
  final Value<int> id;
  final Value<String> phraseText;
  final Value<String> displayText;
  final Value<String?> audioItemId;
  final Value<int?> sentenceIndex;
  final Value<String?> sentenceText;
  final Value<int?> sentenceStartMs;
  final Value<int?> sentenceEndMs;
  final Value<int?> groupStartMs;
  final Value<int?> groupEndMs;
  final Value<int> practiceCount;
  final Value<int> totalStudyMs;
  final Value<bool> viewedBack;
  final Value<DateTime?> lastPracticedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  const SavedSenseGroupsCompanion({
    this.id = const Value.absent(),
    this.phraseText = const Value.absent(),
    this.displayText = const Value.absent(),
    this.audioItemId = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.sentenceText = const Value.absent(),
    this.sentenceStartMs = const Value.absent(),
    this.sentenceEndMs = const Value.absent(),
    this.groupStartMs = const Value.absent(),
    this.groupEndMs = const Value.absent(),
    this.practiceCount = const Value.absent(),
    this.totalStudyMs = const Value.absent(),
    this.viewedBack = const Value.absent(),
    this.lastPracticedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  SavedSenseGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String phraseText,
    required String displayText,
    this.audioItemId = const Value.absent(),
    this.sentenceIndex = const Value.absent(),
    this.sentenceText = const Value.absent(),
    this.sentenceStartMs = const Value.absent(),
    this.sentenceEndMs = const Value.absent(),
    this.groupStartMs = const Value.absent(),
    this.groupEndMs = const Value.absent(),
    this.practiceCount = const Value.absent(),
    this.totalStudyMs = const Value.absent(),
    this.viewedBack = const Value.absent(),
    this.lastPracticedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : phraseText = Value(phraseText),
       displayText = Value(displayText),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SavedSenseGroup> custom({
    Expression<int>? id,
    Expression<String>? phraseText,
    Expression<String>? displayText,
    Expression<String>? audioItemId,
    Expression<int>? sentenceIndex,
    Expression<String>? sentenceText,
    Expression<int>? sentenceStartMs,
    Expression<int>? sentenceEndMs,
    Expression<int>? groupStartMs,
    Expression<int>? groupEndMs,
    Expression<int>? practiceCount,
    Expression<int>? totalStudyMs,
    Expression<bool>? viewedBack,
    Expression<DateTime>? lastPracticedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (phraseText != null) 'phrase_text': phraseText,
      if (displayText != null) 'display_text': displayText,
      if (audioItemId != null) 'audio_item_id': audioItemId,
      if (sentenceIndex != null) 'sentence_index': sentenceIndex,
      if (sentenceText != null) 'sentence_text': sentenceText,
      if (sentenceStartMs != null) 'sentence_start_ms': sentenceStartMs,
      if (sentenceEndMs != null) 'sentence_end_ms': sentenceEndMs,
      if (groupStartMs != null) 'group_start_ms': groupStartMs,
      if (groupEndMs != null) 'group_end_ms': groupEndMs,
      if (practiceCount != null) 'practice_count': practiceCount,
      if (totalStudyMs != null) 'total_study_ms': totalStudyMs,
      if (viewedBack != null) 'viewed_back': viewedBack,
      if (lastPracticedAt != null) 'last_practiced_at': lastPracticedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  SavedSenseGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? phraseText,
    Value<String>? displayText,
    Value<String?>? audioItemId,
    Value<int?>? sentenceIndex,
    Value<String?>? sentenceText,
    Value<int?>? sentenceStartMs,
    Value<int?>? sentenceEndMs,
    Value<int?>? groupStartMs,
    Value<int?>? groupEndMs,
    Value<int>? practiceCount,
    Value<int>? totalStudyMs,
    Value<bool>? viewedBack,
    Value<DateTime?>? lastPracticedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
  }) {
    return SavedSenseGroupsCompanion(
      id: id ?? this.id,
      phraseText: phraseText ?? this.phraseText,
      displayText: displayText ?? this.displayText,
      audioItemId: audioItemId ?? this.audioItemId,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      sentenceText: sentenceText ?? this.sentenceText,
      sentenceStartMs: sentenceStartMs ?? this.sentenceStartMs,
      sentenceEndMs: sentenceEndMs ?? this.sentenceEndMs,
      groupStartMs: groupStartMs ?? this.groupStartMs,
      groupEndMs: groupEndMs ?? this.groupEndMs,
      practiceCount: practiceCount ?? this.practiceCount,
      totalStudyMs: totalStudyMs ?? this.totalStudyMs,
      viewedBack: viewedBack ?? this.viewedBack,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (phraseText.present) {
      map['phrase_text'] = Variable<String>(phraseText.value);
    }
    if (displayText.present) {
      map['display_text'] = Variable<String>(displayText.value);
    }
    if (audioItemId.present) {
      map['audio_item_id'] = Variable<String>(audioItemId.value);
    }
    if (sentenceIndex.present) {
      map['sentence_index'] = Variable<int>(sentenceIndex.value);
    }
    if (sentenceText.present) {
      map['sentence_text'] = Variable<String>(sentenceText.value);
    }
    if (sentenceStartMs.present) {
      map['sentence_start_ms'] = Variable<int>(sentenceStartMs.value);
    }
    if (sentenceEndMs.present) {
      map['sentence_end_ms'] = Variable<int>(sentenceEndMs.value);
    }
    if (groupStartMs.present) {
      map['group_start_ms'] = Variable<int>(groupStartMs.value);
    }
    if (groupEndMs.present) {
      map['group_end_ms'] = Variable<int>(groupEndMs.value);
    }
    if (practiceCount.present) {
      map['practice_count'] = Variable<int>(practiceCount.value);
    }
    if (totalStudyMs.present) {
      map['total_study_ms'] = Variable<int>(totalStudyMs.value);
    }
    if (viewedBack.present) {
      map['viewed_back'] = Variable<bool>(viewedBack.value);
    }
    if (lastPracticedAt.present) {
      map['last_practiced_at'] = Variable<DateTime>(lastPracticedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedSenseGroupsCompanion(')
          ..write('id: $id, ')
          ..write('phraseText: $phraseText, ')
          ..write('displayText: $displayText, ')
          ..write('audioItemId: $audioItemId, ')
          ..write('sentenceIndex: $sentenceIndex, ')
          ..write('sentenceText: $sentenceText, ')
          ..write('sentenceStartMs: $sentenceStartMs, ')
          ..write('sentenceEndMs: $sentenceEndMs, ')
          ..write('groupStartMs: $groupStartMs, ')
          ..write('groupEndMs: $groupEndMs, ')
          ..write('practiceCount: $practiceCount, ')
          ..write('totalStudyMs: $totalStudyMs, ')
          ..write('viewedBack: $viewedBack, ')
          ..write('lastPracticedAt: $lastPracticedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $LearnedWordFormsTable extends LearnedWordForms
    with TableInfo<$LearnedWordFormsTable, LearnedWordForm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearnedWordFormsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wordFormMeta = const VerificationMeta(
    'wordForm',
  );
  @override
  late final GeneratedColumn<String> wordForm = GeneratedColumn<String>(
    'word_form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _firstLearnedAtMeta = const VerificationMeta(
    'firstLearnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstLearnedAt =
      GeneratedColumn<DateTime>(
        'first_learned_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [id, wordForm, firstLearnedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learned_word_forms';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearnedWordForm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word_form')) {
      context.handle(
        _wordFormMeta,
        wordForm.isAcceptableOrUnknown(data['word_form']!, _wordFormMeta),
      );
    } else if (isInserting) {
      context.missing(_wordFormMeta);
    }
    if (data.containsKey('first_learned_at')) {
      context.handle(
        _firstLearnedAtMeta,
        firstLearnedAt.isAcceptableOrUnknown(
          data['first_learned_at']!,
          _firstLearnedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstLearnedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearnedWordForm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearnedWordForm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      wordForm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_form'],
      )!,
      firstLearnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_learned_at'],
      )!,
    );
  }

  @override
  $LearnedWordFormsTable createAlias(String alias) {
    return $LearnedWordFormsTable(attachedDatabase, alias);
  }
}

class LearnedWordForm extends DataClass implements Insertable<LearnedWordForm> {
  /// 自增主键
  final int id;

  /// 统一清洗后的小写词形，全局唯一
  final String wordForm;

  /// 首次学习时间
  final DateTime firstLearnedAt;
  const LearnedWordForm({
    required this.id,
    required this.wordForm,
    required this.firstLearnedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word_form'] = Variable<String>(wordForm);
    map['first_learned_at'] = Variable<DateTime>(firstLearnedAt);
    return map;
  }

  LearnedWordFormsCompanion toCompanion(bool nullToAbsent) {
    return LearnedWordFormsCompanion(
      id: Value(id),
      wordForm: Value(wordForm),
      firstLearnedAt: Value(firstLearnedAt),
    );
  }

  factory LearnedWordForm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearnedWordForm(
      id: serializer.fromJson<int>(json['id']),
      wordForm: serializer.fromJson<String>(json['wordForm']),
      firstLearnedAt: serializer.fromJson<DateTime>(json['firstLearnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wordForm': serializer.toJson<String>(wordForm),
      'firstLearnedAt': serializer.toJson<DateTime>(firstLearnedAt),
    };
  }

  LearnedWordForm copyWith({
    int? id,
    String? wordForm,
    DateTime? firstLearnedAt,
  }) => LearnedWordForm(
    id: id ?? this.id,
    wordForm: wordForm ?? this.wordForm,
    firstLearnedAt: firstLearnedAt ?? this.firstLearnedAt,
  );
  LearnedWordForm copyWithCompanion(LearnedWordFormsCompanion data) {
    return LearnedWordForm(
      id: data.id.present ? data.id.value : this.id,
      wordForm: data.wordForm.present ? data.wordForm.value : this.wordForm,
      firstLearnedAt: data.firstLearnedAt.present
          ? data.firstLearnedAt.value
          : this.firstLearnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearnedWordForm(')
          ..write('id: $id, ')
          ..write('wordForm: $wordForm, ')
          ..write('firstLearnedAt: $firstLearnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, wordForm, firstLearnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnedWordForm &&
          other.id == this.id &&
          other.wordForm == this.wordForm &&
          other.firstLearnedAt == this.firstLearnedAt);
}

class LearnedWordFormsCompanion extends UpdateCompanion<LearnedWordForm> {
  final Value<int> id;
  final Value<String> wordForm;
  final Value<DateTime> firstLearnedAt;
  const LearnedWordFormsCompanion({
    this.id = const Value.absent(),
    this.wordForm = const Value.absent(),
    this.firstLearnedAt = const Value.absent(),
  });
  LearnedWordFormsCompanion.insert({
    this.id = const Value.absent(),
    required String wordForm,
    required DateTime firstLearnedAt,
  }) : wordForm = Value(wordForm),
       firstLearnedAt = Value(firstLearnedAt);
  static Insertable<LearnedWordForm> custom({
    Expression<int>? id,
    Expression<String>? wordForm,
    Expression<DateTime>? firstLearnedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wordForm != null) 'word_form': wordForm,
      if (firstLearnedAt != null) 'first_learned_at': firstLearnedAt,
    });
  }

  LearnedWordFormsCompanion copyWith({
    Value<int>? id,
    Value<String>? wordForm,
    Value<DateTime>? firstLearnedAt,
  }) {
    return LearnedWordFormsCompanion(
      id: id ?? this.id,
      wordForm: wordForm ?? this.wordForm,
      firstLearnedAt: firstLearnedAt ?? this.firstLearnedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wordForm.present) {
      map['word_form'] = Variable<String>(wordForm.value);
    }
    if (firstLearnedAt.present) {
      map['first_learned_at'] = Variable<DateTime>(firstLearnedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearnedWordFormsCompanion(')
          ..write('id: $id, ')
          ..write('wordForm: $wordForm, ')
          ..write('firstLearnedAt: $firstLearnedAt')
          ..write(')'))
        .toString();
  }
}

class $DailyStudyRecordsTable extends DailyStudyRecords
    with TableInfo<$DailyStudyRecordsTable, DailyStudyRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStudyRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _studyTimeSecondsMeta = const VerificationMeta(
    'studyTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> studyTimeSeconds = GeneratedColumn<int>(
    'study_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inputWordsMeta = const VerificationMeta(
    'inputWords',
  );
  @override
  late final GeneratedColumn<int> inputWords = GeneratedColumn<int>(
    'input_words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outputWordsMeta = const VerificationMeta(
    'outputWords',
  );
  @override
  late final GeneratedColumn<int> outputWords = GeneratedColumn<int>(
    'output_words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inputTimeSecondsMeta = const VerificationMeta(
    'inputTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> inputTimeSeconds = GeneratedColumn<int>(
    'input_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outputTimeSecondsMeta = const VerificationMeta(
    'outputTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> outputTimeSeconds = GeneratedColumn<int>(
    'output_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    studyTimeSeconds,
    inputWords,
    outputWords,
    inputTimeSeconds,
    outputTimeSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_study_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyStudyRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('study_time_seconds')) {
      context.handle(
        _studyTimeSecondsMeta,
        studyTimeSeconds.isAcceptableOrUnknown(
          data['study_time_seconds']!,
          _studyTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('input_words')) {
      context.handle(
        _inputWordsMeta,
        inputWords.isAcceptableOrUnknown(data['input_words']!, _inputWordsMeta),
      );
    }
    if (data.containsKey('output_words')) {
      context.handle(
        _outputWordsMeta,
        outputWords.isAcceptableOrUnknown(
          data['output_words']!,
          _outputWordsMeta,
        ),
      );
    }
    if (data.containsKey('input_time_seconds')) {
      context.handle(
        _inputTimeSecondsMeta,
        inputTimeSeconds.isAcceptableOrUnknown(
          data['input_time_seconds']!,
          _inputTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('output_time_seconds')) {
      context.handle(
        _outputTimeSecondsMeta,
        outputTimeSeconds.isAcceptableOrUnknown(
          data['output_time_seconds']!,
          _outputTimeSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyStudyRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStudyRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      studyTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}study_time_seconds'],
      )!,
      inputWords: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_words'],
      )!,
      outputWords: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_words'],
      )!,
      inputTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_time_seconds'],
      )!,
      outputTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_time_seconds'],
      )!,
    );
  }

  @override
  $DailyStudyRecordsTable createAlias(String alias) {
    return $DailyStudyRecordsTable(attachedDatabase, alias);
  }
}

class DailyStudyRecord extends DataClass
    implements Insertable<DailyStudyRecord> {
  /// 自增主键
  final int id;

  /// 日期（唯一），只保留年月日
  final DateTime date;

  /// 当日累计学习时长（秒）
  final int studyTimeSeconds;

  /// 当日输入词数（听了多少词）
  final int inputWords;

  /// 当日输出词数（跟读/复述了多少词）
  final int outputWords;

  /// 当日输入时间（秒）— 音频播放时间
  final int inputTimeSeconds;

  /// 当日输出时间（秒）— 跟读/复述暂停时间
  final int outputTimeSeconds;
  const DailyStudyRecord({
    required this.id,
    required this.date,
    required this.studyTimeSeconds,
    required this.inputWords,
    required this.outputWords,
    required this.inputTimeSeconds,
    required this.outputTimeSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['study_time_seconds'] = Variable<int>(studyTimeSeconds);
    map['input_words'] = Variable<int>(inputWords);
    map['output_words'] = Variable<int>(outputWords);
    map['input_time_seconds'] = Variable<int>(inputTimeSeconds);
    map['output_time_seconds'] = Variable<int>(outputTimeSeconds);
    return map;
  }

  DailyStudyRecordsCompanion toCompanion(bool nullToAbsent) {
    return DailyStudyRecordsCompanion(
      id: Value(id),
      date: Value(date),
      studyTimeSeconds: Value(studyTimeSeconds),
      inputWords: Value(inputWords),
      outputWords: Value(outputWords),
      inputTimeSeconds: Value(inputTimeSeconds),
      outputTimeSeconds: Value(outputTimeSeconds),
    );
  }

  factory DailyStudyRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStudyRecord(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      studyTimeSeconds: serializer.fromJson<int>(json['studyTimeSeconds']),
      inputWords: serializer.fromJson<int>(json['inputWords']),
      outputWords: serializer.fromJson<int>(json['outputWords']),
      inputTimeSeconds: serializer.fromJson<int>(json['inputTimeSeconds']),
      outputTimeSeconds: serializer.fromJson<int>(json['outputTimeSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'studyTimeSeconds': serializer.toJson<int>(studyTimeSeconds),
      'inputWords': serializer.toJson<int>(inputWords),
      'outputWords': serializer.toJson<int>(outputWords),
      'inputTimeSeconds': serializer.toJson<int>(inputTimeSeconds),
      'outputTimeSeconds': serializer.toJson<int>(outputTimeSeconds),
    };
  }

  DailyStudyRecord copyWith({
    int? id,
    DateTime? date,
    int? studyTimeSeconds,
    int? inputWords,
    int? outputWords,
    int? inputTimeSeconds,
    int? outputTimeSeconds,
  }) => DailyStudyRecord(
    id: id ?? this.id,
    date: date ?? this.date,
    studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
    inputWords: inputWords ?? this.inputWords,
    outputWords: outputWords ?? this.outputWords,
    inputTimeSeconds: inputTimeSeconds ?? this.inputTimeSeconds,
    outputTimeSeconds: outputTimeSeconds ?? this.outputTimeSeconds,
  );
  DailyStudyRecord copyWithCompanion(DailyStudyRecordsCompanion data) {
    return DailyStudyRecord(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      studyTimeSeconds: data.studyTimeSeconds.present
          ? data.studyTimeSeconds.value
          : this.studyTimeSeconds,
      inputWords: data.inputWords.present
          ? data.inputWords.value
          : this.inputWords,
      outputWords: data.outputWords.present
          ? data.outputWords.value
          : this.outputWords,
      inputTimeSeconds: data.inputTimeSeconds.present
          ? data.inputTimeSeconds.value
          : this.inputTimeSeconds,
      outputTimeSeconds: data.outputTimeSeconds.present
          ? data.outputTimeSeconds.value
          : this.outputTimeSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStudyRecord(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('studyTimeSeconds: $studyTimeSeconds, ')
          ..write('inputWords: $inputWords, ')
          ..write('outputWords: $outputWords, ')
          ..write('inputTimeSeconds: $inputTimeSeconds, ')
          ..write('outputTimeSeconds: $outputTimeSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    studyTimeSeconds,
    inputWords,
    outputWords,
    inputTimeSeconds,
    outputTimeSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStudyRecord &&
          other.id == this.id &&
          other.date == this.date &&
          other.studyTimeSeconds == this.studyTimeSeconds &&
          other.inputWords == this.inputWords &&
          other.outputWords == this.outputWords &&
          other.inputTimeSeconds == this.inputTimeSeconds &&
          other.outputTimeSeconds == this.outputTimeSeconds);
}

class DailyStudyRecordsCompanion extends UpdateCompanion<DailyStudyRecord> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<int> studyTimeSeconds;
  final Value<int> inputWords;
  final Value<int> outputWords;
  final Value<int> inputTimeSeconds;
  final Value<int> outputTimeSeconds;
  const DailyStudyRecordsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.studyTimeSeconds = const Value.absent(),
    this.inputWords = const Value.absent(),
    this.outputWords = const Value.absent(),
    this.inputTimeSeconds = const Value.absent(),
    this.outputTimeSeconds = const Value.absent(),
  });
  DailyStudyRecordsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    this.studyTimeSeconds = const Value.absent(),
    this.inputWords = const Value.absent(),
    this.outputWords = const Value.absent(),
    this.inputTimeSeconds = const Value.absent(),
    this.outputTimeSeconds = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DailyStudyRecord> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? studyTimeSeconds,
    Expression<int>? inputWords,
    Expression<int>? outputWords,
    Expression<int>? inputTimeSeconds,
    Expression<int>? outputTimeSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (studyTimeSeconds != null) 'study_time_seconds': studyTimeSeconds,
      if (inputWords != null) 'input_words': inputWords,
      if (outputWords != null) 'output_words': outputWords,
      if (inputTimeSeconds != null) 'input_time_seconds': inputTimeSeconds,
      if (outputTimeSeconds != null) 'output_time_seconds': outputTimeSeconds,
    });
  }

  DailyStudyRecordsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<int>? studyTimeSeconds,
    Value<int>? inputWords,
    Value<int>? outputWords,
    Value<int>? inputTimeSeconds,
    Value<int>? outputTimeSeconds,
  }) {
    return DailyStudyRecordsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
      inputWords: inputWords ?? this.inputWords,
      outputWords: outputWords ?? this.outputWords,
      inputTimeSeconds: inputTimeSeconds ?? this.inputTimeSeconds,
      outputTimeSeconds: outputTimeSeconds ?? this.outputTimeSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (studyTimeSeconds.present) {
      map['study_time_seconds'] = Variable<int>(studyTimeSeconds.value);
    }
    if (inputWords.present) {
      map['input_words'] = Variable<int>(inputWords.value);
    }
    if (outputWords.present) {
      map['output_words'] = Variable<int>(outputWords.value);
    }
    if (inputTimeSeconds.present) {
      map['input_time_seconds'] = Variable<int>(inputTimeSeconds.value);
    }
    if (outputTimeSeconds.present) {
      map['output_time_seconds'] = Variable<int>(outputTimeSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStudyRecordsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('studyTimeSeconds: $studyTimeSeconds, ')
          ..write('inputWords: $inputWords, ')
          ..write('outputWords: $outputWords, ')
          ..write('inputTimeSeconds: $inputTimeSeconds, ')
          ..write('outputTimeSeconds: $outputTimeSeconds')
          ..write(')'))
        .toString();
  }
}

class $DailyStageStudyRecordsTable extends DailyStageStudyRecords
    with TableInfo<$DailyStageStudyRecordsTable, DailyStageStudyRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStageStudyRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StudyStage, int> stage =
      GeneratedColumn<int>(
        'stage',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<StudyStage>($DailyStageStudyRecordsTable.$converterstage);
  static const VerificationMeta _studyTimeSecondsMeta = const VerificationMeta(
    'studyTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> studyTimeSeconds = GeneratedColumn<int>(
    'study_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inputTimeSecondsMeta = const VerificationMeta(
    'inputTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> inputTimeSeconds = GeneratedColumn<int>(
    'input_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outputTimeSecondsMeta = const VerificationMeta(
    'outputTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> outputTimeSeconds = GeneratedColumn<int>(
    'output_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    stage,
    studyTimeSeconds,
    inputTimeSeconds,
    outputTimeSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_stage_study_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyStageStudyRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('study_time_seconds')) {
      context.handle(
        _studyTimeSecondsMeta,
        studyTimeSeconds.isAcceptableOrUnknown(
          data['study_time_seconds']!,
          _studyTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('input_time_seconds')) {
      context.handle(
        _inputTimeSecondsMeta,
        inputTimeSeconds.isAcceptableOrUnknown(
          data['input_time_seconds']!,
          _inputTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('output_time_seconds')) {
      context.handle(
        _outputTimeSecondsMeta,
        outputTimeSeconds.isAcceptableOrUnknown(
          data['output_time_seconds']!,
          _outputTimeSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date, stage},
  ];
  @override
  DailyStageStudyRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStageStudyRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      stage: $DailyStageStudyRecordsTable.$converterstage.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}stage'],
        )!,
      ),
      studyTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}study_time_seconds'],
      )!,
      inputTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_time_seconds'],
      )!,
      outputTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_time_seconds'],
      )!,
    );
  }

  @override
  $DailyStageStudyRecordsTable createAlias(String alias) {
    return $DailyStageStudyRecordsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StudyStage, int, int> $converterstage =
      const EnumIndexConverter<StudyStage>(StudyStage.values);
}

class DailyStageStudyRecord extends DataClass
    implements Insertable<DailyStageStudyRecord> {
  /// 自增主键
  final int id;

  /// 日期（只保留年月日）
  final DateTime date;

  /// 学习阶段（intEnum，按 StudyStage.index 存储）
  final StudyStage stage;

  /// 当日该阶段累计学习时长（秒）
  final int studyTimeSeconds;

  /// 当日该阶段输入时间（秒）— 音频播放时间
  final int inputTimeSeconds;

  /// 当日该阶段输出时间（秒）— 跟读/复述时间
  final int outputTimeSeconds;
  const DailyStageStudyRecord({
    required this.id,
    required this.date,
    required this.stage,
    required this.studyTimeSeconds,
    required this.inputTimeSeconds,
    required this.outputTimeSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    {
      map['stage'] = Variable<int>(
        $DailyStageStudyRecordsTable.$converterstage.toSql(stage),
      );
    }
    map['study_time_seconds'] = Variable<int>(studyTimeSeconds);
    map['input_time_seconds'] = Variable<int>(inputTimeSeconds);
    map['output_time_seconds'] = Variable<int>(outputTimeSeconds);
    return map;
  }

  DailyStageStudyRecordsCompanion toCompanion(bool nullToAbsent) {
    return DailyStageStudyRecordsCompanion(
      id: Value(id),
      date: Value(date),
      stage: Value(stage),
      studyTimeSeconds: Value(studyTimeSeconds),
      inputTimeSeconds: Value(inputTimeSeconds),
      outputTimeSeconds: Value(outputTimeSeconds),
    );
  }

  factory DailyStageStudyRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStageStudyRecord(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      stage: $DailyStageStudyRecordsTable.$converterstage.fromJson(
        serializer.fromJson<int>(json['stage']),
      ),
      studyTimeSeconds: serializer.fromJson<int>(json['studyTimeSeconds']),
      inputTimeSeconds: serializer.fromJson<int>(json['inputTimeSeconds']),
      outputTimeSeconds: serializer.fromJson<int>(json['outputTimeSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'stage': serializer.toJson<int>(
        $DailyStageStudyRecordsTable.$converterstage.toJson(stage),
      ),
      'studyTimeSeconds': serializer.toJson<int>(studyTimeSeconds),
      'inputTimeSeconds': serializer.toJson<int>(inputTimeSeconds),
      'outputTimeSeconds': serializer.toJson<int>(outputTimeSeconds),
    };
  }

  DailyStageStudyRecord copyWith({
    int? id,
    DateTime? date,
    StudyStage? stage,
    int? studyTimeSeconds,
    int? inputTimeSeconds,
    int? outputTimeSeconds,
  }) => DailyStageStudyRecord(
    id: id ?? this.id,
    date: date ?? this.date,
    stage: stage ?? this.stage,
    studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
    inputTimeSeconds: inputTimeSeconds ?? this.inputTimeSeconds,
    outputTimeSeconds: outputTimeSeconds ?? this.outputTimeSeconds,
  );
  DailyStageStudyRecord copyWithCompanion(
    DailyStageStudyRecordsCompanion data,
  ) {
    return DailyStageStudyRecord(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      stage: data.stage.present ? data.stage.value : this.stage,
      studyTimeSeconds: data.studyTimeSeconds.present
          ? data.studyTimeSeconds.value
          : this.studyTimeSeconds,
      inputTimeSeconds: data.inputTimeSeconds.present
          ? data.inputTimeSeconds.value
          : this.inputTimeSeconds,
      outputTimeSeconds: data.outputTimeSeconds.present
          ? data.outputTimeSeconds.value
          : this.outputTimeSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStageStudyRecord(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('stage: $stage, ')
          ..write('studyTimeSeconds: $studyTimeSeconds, ')
          ..write('inputTimeSeconds: $inputTimeSeconds, ')
          ..write('outputTimeSeconds: $outputTimeSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    stage,
    studyTimeSeconds,
    inputTimeSeconds,
    outputTimeSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStageStudyRecord &&
          other.id == this.id &&
          other.date == this.date &&
          other.stage == this.stage &&
          other.studyTimeSeconds == this.studyTimeSeconds &&
          other.inputTimeSeconds == this.inputTimeSeconds &&
          other.outputTimeSeconds == this.outputTimeSeconds);
}

class DailyStageStudyRecordsCompanion
    extends UpdateCompanion<DailyStageStudyRecord> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<StudyStage> stage;
  final Value<int> studyTimeSeconds;
  final Value<int> inputTimeSeconds;
  final Value<int> outputTimeSeconds;
  const DailyStageStudyRecordsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.stage = const Value.absent(),
    this.studyTimeSeconds = const Value.absent(),
    this.inputTimeSeconds = const Value.absent(),
    this.outputTimeSeconds = const Value.absent(),
  });
  DailyStageStudyRecordsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required StudyStage stage,
    this.studyTimeSeconds = const Value.absent(),
    this.inputTimeSeconds = const Value.absent(),
    this.outputTimeSeconds = const Value.absent(),
  }) : date = Value(date),
       stage = Value(stage);
  static Insertable<DailyStageStudyRecord> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? stage,
    Expression<int>? studyTimeSeconds,
    Expression<int>? inputTimeSeconds,
    Expression<int>? outputTimeSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (stage != null) 'stage': stage,
      if (studyTimeSeconds != null) 'study_time_seconds': studyTimeSeconds,
      if (inputTimeSeconds != null) 'input_time_seconds': inputTimeSeconds,
      if (outputTimeSeconds != null) 'output_time_seconds': outputTimeSeconds,
    });
  }

  DailyStageStudyRecordsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<StudyStage>? stage,
    Value<int>? studyTimeSeconds,
    Value<int>? inputTimeSeconds,
    Value<int>? outputTimeSeconds,
  }) {
    return DailyStageStudyRecordsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      stage: stage ?? this.stage,
      studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
      inputTimeSeconds: inputTimeSeconds ?? this.inputTimeSeconds,
      outputTimeSeconds: outputTimeSeconds ?? this.outputTimeSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (stage.present) {
      map['stage'] = Variable<int>(
        $DailyStageStudyRecordsTable.$converterstage.toSql(stage.value),
      );
    }
    if (studyTimeSeconds.present) {
      map['study_time_seconds'] = Variable<int>(studyTimeSeconds.value);
    }
    if (inputTimeSeconds.present) {
      map['input_time_seconds'] = Variable<int>(inputTimeSeconds.value);
    }
    if (outputTimeSeconds.present) {
      map['output_time_seconds'] = Variable<int>(outputTimeSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStageStudyRecordsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('stage: $stage, ')
          ..write('studyTimeSeconds: $studyTimeSeconds, ')
          ..write('inputTimeSeconds: $inputTimeSeconds, ')
          ..write('outputTimeSeconds: $outputTimeSeconds')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AudioItemsTable audioItems = $AudioItemsTable(this);
  late final $CollectionsTable collections = $CollectionsTable(this);
  late final $CollectionAudioItemsTable collectionAudioItems =
      $CollectionAudioItemsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $PlaybackStatesTable playbackStates = $PlaybackStatesTable(this);
  late final $LearningProgressesTable learningProgresses =
      $LearningProgressesTable(this);
  late final $StageCompletionsTable stageCompletions = $StageCompletionsTable(
    this,
  );
  late final $TagsTable tags = $TagsTable(this);
  late final $AudioItemTagsTable audioItemTags = $AudioItemTagsTable(this);
  late final $SentenceAiCacheTable sentenceAiCache = $SentenceAiCacheTable(
    this,
  );
  late final $SavedWordsTable savedWords = $SavedWordsTable(this);
  late final $SavedSenseGroupsTable savedSenseGroups = $SavedSenseGroupsTable(
    this,
  );
  late final $LearnedWordFormsTable learnedWordForms = $LearnedWordFormsTable(
    this,
  );
  late final $DailyStudyRecordsTable dailyStudyRecords =
      $DailyStudyRecordsTable(this);
  late final $DailyStageStudyRecordsTable dailyStageStudyRecords =
      $DailyStageStudyRecordsTable(this);
  late final AudioItemDao audioItemDao = AudioItemDao(this as AppDatabase);
  late final CollectionDao collectionDao = CollectionDao(this as AppDatabase);
  late final BookmarkDao bookmarkDao = BookmarkDao(this as AppDatabase);
  late final PlaybackStateDao playbackStateDao = PlaybackStateDao(
    this as AppDatabase,
  );
  late final LearningProgressDao learningProgressDao = LearningProgressDao(
    this as AppDatabase,
  );
  late final StageCompletionDao stageCompletionDao = StageCompletionDao(
    this as AppDatabase,
  );
  late final TagDao tagDao = TagDao(this as AppDatabase);
  late final SentenceAiCacheDao sentenceAiCacheDao = SentenceAiCacheDao(
    this as AppDatabase,
  );
  late final SavedWordDao savedWordDao = SavedWordDao(this as AppDatabase);
  late final SavedSenseGroupDao savedSenseGroupDao = SavedSenseGroupDao(
    this as AppDatabase,
  );
  late final LearnedWordFormDao learnedWordFormDao = LearnedWordFormDao(
    this as AppDatabase,
  );
  late final DailyStudyRecordDao dailyStudyRecordDao = DailyStudyRecordDao(
    this as AppDatabase,
  );
  late final DailyStageStudyRecordDao dailyStageStudyRecordDao =
      DailyStageStudyRecordDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    audioItems,
    collections,
    collectionAudioItems,
    bookmarks,
    playbackStates,
    learningProgresses,
    stageCompletions,
    tags,
    audioItemTags,
    sentenceAiCache,
    savedWords,
    savedSenseGroups,
    learnedWordForms,
    dailyStudyRecords,
    dailyStageStudyRecords,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('collection_audio_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'audio_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('collection_audio_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'audio_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bookmarks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'audio_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playback_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'audio_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learning_progresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'audio_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stage_completions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audio_item_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'audio_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audio_item_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'audio_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_words', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'audio_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_sense_groups', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$AudioItemsTableCreateCompanionBuilder =
    AudioItemsCompanion Function({
      required String id,
      required String name,
      Value<String?> audioPath,
      Value<String?> transcriptPath,
      required DateTime addedDate,
      Value<int> totalDuration,
      Value<int> sentenceCount,
      Value<int> wordCount,
      Value<bool> isPinned,
      Value<int?> transcriptSource,
      Value<String?> audioSha256,
      Value<String?> transcriptLanguage,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<String?> wordTimestampsJson,
      Value<int> syncStatus,
      Value<String?> remoteAudioId,
      Value<DateTime?> originalDate,
      Value<int> rowid,
    });
typedef $$AudioItemsTableUpdateCompanionBuilder =
    AudioItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> audioPath,
      Value<String?> transcriptPath,
      Value<DateTime> addedDate,
      Value<int> totalDuration,
      Value<int> sentenceCount,
      Value<int> wordCount,
      Value<bool> isPinned,
      Value<int?> transcriptSource,
      Value<String?> audioSha256,
      Value<String?> transcriptLanguage,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String?> wordTimestampsJson,
      Value<int> syncStatus,
      Value<String?> remoteAudioId,
      Value<DateTime?> originalDate,
      Value<int> rowid,
    });

final class $$AudioItemsTableReferences
    extends BaseReferences<_$AppDatabase, $AudioItemsTable, AudioItem> {
  $$AudioItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CollectionAudioItemsTable,
    List<CollectionAudioItem>
  >
  _collectionAudioItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.collectionAudioItems,
        aliasName: $_aliasNameGenerator(
          db.audioItems.id,
          db.collectionAudioItems.audioItemId,
        ),
      );

  $$CollectionAudioItemsTableProcessedTableManager
  get collectionAudioItemsRefs {
    final manager = $$CollectionAudioItemsTableTableManager(
      $_db,
      $_db.collectionAudioItems,
    ).filter((f) => f.audioItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _collectionAudioItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<Bookmark>>
  _bookmarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: $_aliasNameGenerator(db.audioItems.id, db.bookmarks.audioItemId),
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.audioItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaybackStatesTable, List<PlaybackState>>
  _playbackStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playbackStates,
    aliasName: $_aliasNameGenerator(
      db.audioItems.id,
      db.playbackStates.audioItemId,
    ),
  );

  $$PlaybackStatesTableProcessedTableManager get playbackStatesRefs {
    final manager = $$PlaybackStatesTableTableManager(
      $_db,
      $_db.playbackStates,
    ).filter((f) => f.audioItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playbackStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LearningProgressesTable,
    List<LearningProgressesData>
  >
  _learningProgressesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.learningProgresses,
        aliasName: $_aliasNameGenerator(
          db.audioItems.id,
          db.learningProgresses.audioItemId,
        ),
      );

  $$LearningProgressesTableProcessedTableManager get learningProgressesRefs {
    final manager = $$LearningProgressesTableTableManager(
      $_db,
      $_db.learningProgresses,
    ).filter((f) => f.audioItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _learningProgressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StageCompletionsTable, List<StageCompletion>>
  _stageCompletionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stageCompletions,
    aliasName: $_aliasNameGenerator(
      db.audioItems.id,
      db.stageCompletions.audioItemId,
    ),
  );

  $$StageCompletionsTableProcessedTableManager get stageCompletionsRefs {
    final manager = $$StageCompletionsTableTableManager(
      $_db,
      $_db.stageCompletions,
    ).filter((f) => f.audioItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stageCompletionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AudioItemTagsTable, List<AudioItemTag>>
  _audioItemTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.audioItemTags,
    aliasName: $_aliasNameGenerator(
      db.audioItems.id,
      db.audioItemTags.audioItemId,
    ),
  );

  $$AudioItemTagsTableProcessedTableManager get audioItemTagsRefs {
    final manager = $$AudioItemTagsTableTableManager(
      $_db,
      $_db.audioItemTags,
    ).filter((f) => f.audioItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_audioItemTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SavedWordsTable, List<SavedWord>>
  _savedWordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.savedWords,
    aliasName: $_aliasNameGenerator(
      db.audioItems.id,
      db.savedWords.audioItemId,
    ),
  );

  $$SavedWordsTableProcessedTableManager get savedWordsRefs {
    final manager = $$SavedWordsTableTableManager(
      $_db,
      $_db.savedWords,
    ).filter((f) => f.audioItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedWordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SavedSenseGroupsTable, List<SavedSenseGroup>>
  _savedSenseGroupsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.savedSenseGroups,
    aliasName: $_aliasNameGenerator(
      db.audioItems.id,
      db.savedSenseGroups.audioItemId,
    ),
  );

  $$SavedSenseGroupsTableProcessedTableManager get savedSenseGroupsRefs {
    final manager = $$SavedSenseGroupsTableTableManager(
      $_db,
      $_db.savedSenseGroups,
    ).filter((f) => f.audioItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedSenseGroupsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AudioItemsTableFilterComposer
    extends Composer<_$AppDatabase, $AudioItemsTable> {
  $$AudioItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedDate => $composableBuilder(
    column: $table.addedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceCount => $composableBuilder(
    column: $table.sentenceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transcriptSource => $composableBuilder(
    column: $table.transcriptSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioSha256 => $composableBuilder(
    column: $table.audioSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordTimestampsJson => $composableBuilder(
    column: $table.wordTimestampsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteAudioId => $composableBuilder(
    column: $table.remoteAudioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> collectionAudioItemsRefs(
    Expression<bool> Function($$CollectionAudioItemsTableFilterComposer f) f,
  ) {
    final $$CollectionAudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionAudioItems,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionAudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.collectionAudioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playbackStatesRefs(
    Expression<bool> Function($$PlaybackStatesTableFilterComposer f) f,
  ) {
    final $$PlaybackStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playbackStates,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackStatesTableFilterComposer(
            $db: $db,
            $table: $db.playbackStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningProgressesRefs(
    Expression<bool> Function($$LearningProgressesTableFilterComposer f) f,
  ) {
    final $$LearningProgressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningProgresses,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningProgressesTableFilterComposer(
            $db: $db,
            $table: $db.learningProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stageCompletionsRefs(
    Expression<bool> Function($$StageCompletionsTableFilterComposer f) f,
  ) {
    final $$StageCompletionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stageCompletions,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StageCompletionsTableFilterComposer(
            $db: $db,
            $table: $db.stageCompletions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> audioItemTagsRefs(
    Expression<bool> Function($$AudioItemTagsTableFilterComposer f) f,
  ) {
    final $$AudioItemTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioItemTags,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemTagsTableFilterComposer(
            $db: $db,
            $table: $db.audioItemTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> savedWordsRefs(
    Expression<bool> Function($$SavedWordsTableFilterComposer f) f,
  ) {
    final $$SavedWordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedWords,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedWordsTableFilterComposer(
            $db: $db,
            $table: $db.savedWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> savedSenseGroupsRefs(
    Expression<bool> Function($$SavedSenseGroupsTableFilterComposer f) f,
  ) {
    final $$SavedSenseGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedSenseGroups,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedSenseGroupsTableFilterComposer(
            $db: $db,
            $table: $db.savedSenseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AudioItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioItemsTable> {
  $$AudioItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedDate => $composableBuilder(
    column: $table.addedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceCount => $composableBuilder(
    column: $table.sentenceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transcriptSource => $composableBuilder(
    column: $table.transcriptSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioSha256 => $composableBuilder(
    column: $table.audioSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordTimestampsJson => $composableBuilder(
    column: $table.wordTimestampsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteAudioId => $composableBuilder(
    column: $table.remoteAudioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioItemsTable> {
  $$AudioItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get transcriptPath => $composableBuilder(
    column: $table.transcriptPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedDate =>
      $composableBuilder(column: $table.addedDate, builder: (column) => column);

  GeneratedColumn<int> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentenceCount => $composableBuilder(
    column: $table.sentenceCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get transcriptSource => $composableBuilder(
    column: $table.transcriptSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioSha256 => $composableBuilder(
    column: $table.audioSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get wordTimestampsJson => $composableBuilder(
    column: $table.wordTimestampsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteAudioId => $composableBuilder(
    column: $table.remoteAudioId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => column,
  );

  Expression<T> collectionAudioItemsRefs<T extends Object>(
    Expression<T> Function($$CollectionAudioItemsTableAnnotationComposer a) f,
  ) {
    final $$CollectionAudioItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.collectionAudioItems,
          getReferencedColumn: (t) => t.audioItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CollectionAudioItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.collectionAudioItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playbackStatesRefs<T extends Object>(
    Expression<T> Function($$PlaybackStatesTableAnnotationComposer a) f,
  ) {
    final $$PlaybackStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playbackStates,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningProgressesRefs<T extends Object>(
    Expression<T> Function($$LearningProgressesTableAnnotationComposer a) f,
  ) {
    final $$LearningProgressesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.learningProgresses,
          getReferencedColumn: (t) => t.audioItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LearningProgressesTableAnnotationComposer(
                $db: $db,
                $table: $db.learningProgresses,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> stageCompletionsRefs<T extends Object>(
    Expression<T> Function($$StageCompletionsTableAnnotationComposer a) f,
  ) {
    final $$StageCompletionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stageCompletions,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StageCompletionsTableAnnotationComposer(
            $db: $db,
            $table: $db.stageCompletions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> audioItemTagsRefs<T extends Object>(
    Expression<T> Function($$AudioItemTagsTableAnnotationComposer a) f,
  ) {
    final $$AudioItemTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioItemTags,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItemTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> savedWordsRefs<T extends Object>(
    Expression<T> Function($$SavedWordsTableAnnotationComposer a) f,
  ) {
    final $$SavedWordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedWords,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedWordsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> savedSenseGroupsRefs<T extends Object>(
    Expression<T> Function($$SavedSenseGroupsTableAnnotationComposer a) f,
  ) {
    final $$SavedSenseGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedSenseGroups,
      getReferencedColumn: (t) => t.audioItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedSenseGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedSenseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AudioItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioItemsTable,
          AudioItem,
          $$AudioItemsTableFilterComposer,
          $$AudioItemsTableOrderingComposer,
          $$AudioItemsTableAnnotationComposer,
          $$AudioItemsTableCreateCompanionBuilder,
          $$AudioItemsTableUpdateCompanionBuilder,
          (AudioItem, $$AudioItemsTableReferences),
          AudioItem,
          PrefetchHooks Function({
            bool collectionAudioItemsRefs,
            bool bookmarksRefs,
            bool playbackStatesRefs,
            bool learningProgressesRefs,
            bool stageCompletionsRefs,
            bool audioItemTagsRefs,
            bool savedWordsRefs,
            bool savedSenseGroupsRefs,
          })
        > {
  $$AudioItemsTableTableManager(_$AppDatabase db, $AudioItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> transcriptPath = const Value.absent(),
                Value<DateTime> addedDate = const Value.absent(),
                Value<int> totalDuration = const Value.absent(),
                Value<int> sentenceCount = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int?> transcriptSource = const Value.absent(),
                Value<String?> audioSha256 = const Value.absent(),
                Value<String?> transcriptLanguage = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> wordTimestampsJson = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> remoteAudioId = const Value.absent(),
                Value<DateTime?> originalDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioItemsCompanion(
                id: id,
                name: name,
                audioPath: audioPath,
                transcriptPath: transcriptPath,
                addedDate: addedDate,
                totalDuration: totalDuration,
                sentenceCount: sentenceCount,
                wordCount: wordCount,
                isPinned: isPinned,
                transcriptSource: transcriptSource,
                audioSha256: audioSha256,
                transcriptLanguage: transcriptLanguage,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                wordTimestampsJson: wordTimestampsJson,
                syncStatus: syncStatus,
                remoteAudioId: remoteAudioId,
                originalDate: originalDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> audioPath = const Value.absent(),
                Value<String?> transcriptPath = const Value.absent(),
                required DateTime addedDate,
                Value<int> totalDuration = const Value.absent(),
                Value<int> sentenceCount = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int?> transcriptSource = const Value.absent(),
                Value<String?> audioSha256 = const Value.absent(),
                Value<String?> transcriptLanguage = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> wordTimestampsJson = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> remoteAudioId = const Value.absent(),
                Value<DateTime?> originalDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioItemsCompanion.insert(
                id: id,
                name: name,
                audioPath: audioPath,
                transcriptPath: transcriptPath,
                addedDate: addedDate,
                totalDuration: totalDuration,
                sentenceCount: sentenceCount,
                wordCount: wordCount,
                isPinned: isPinned,
                transcriptSource: transcriptSource,
                audioSha256: audioSha256,
                transcriptLanguage: transcriptLanguage,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                wordTimestampsJson: wordTimestampsJson,
                syncStatus: syncStatus,
                remoteAudioId: remoteAudioId,
                originalDate: originalDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AudioItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                collectionAudioItemsRefs = false,
                bookmarksRefs = false,
                playbackStatesRefs = false,
                learningProgressesRefs = false,
                stageCompletionsRefs = false,
                audioItemTagsRefs = false,
                savedWordsRefs = false,
                savedSenseGroupsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (collectionAudioItemsRefs) db.collectionAudioItems,
                    if (bookmarksRefs) db.bookmarks,
                    if (playbackStatesRefs) db.playbackStates,
                    if (learningProgressesRefs) db.learningProgresses,
                    if (stageCompletionsRefs) db.stageCompletions,
                    if (audioItemTagsRefs) db.audioItemTags,
                    if (savedWordsRefs) db.savedWords,
                    if (savedSenseGroupsRefs) db.savedSenseGroups,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (collectionAudioItemsRefs)
                        await $_getPrefetchedData<
                          AudioItem,
                          $AudioItemsTable,
                          CollectionAudioItem
                        >(
                          currentTable: table,
                          referencedTable: $$AudioItemsTableReferences
                              ._collectionAudioItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AudioItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).collectionAudioItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.audioItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<
                          AudioItem,
                          $AudioItemsTable,
                          Bookmark
                        >(
                          currentTable: table,
                          referencedTable: $$AudioItemsTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AudioItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.audioItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playbackStatesRefs)
                        await $_getPrefetchedData<
                          AudioItem,
                          $AudioItemsTable,
                          PlaybackState
                        >(
                          currentTable: table,
                          referencedTable: $$AudioItemsTableReferences
                              ._playbackStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AudioItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).playbackStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.audioItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningProgressesRefs)
                        await $_getPrefetchedData<
                          AudioItem,
                          $AudioItemsTable,
                          LearningProgressesData
                        >(
                          currentTable: table,
                          referencedTable: $$AudioItemsTableReferences
                              ._learningProgressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AudioItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).learningProgressesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.audioItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stageCompletionsRefs)
                        await $_getPrefetchedData<
                          AudioItem,
                          $AudioItemsTable,
                          StageCompletion
                        >(
                          currentTable: table,
                          referencedTable: $$AudioItemsTableReferences
                              ._stageCompletionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AudioItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).stageCompletionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.audioItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (audioItemTagsRefs)
                        await $_getPrefetchedData<
                          AudioItem,
                          $AudioItemsTable,
                          AudioItemTag
                        >(
                          currentTable: table,
                          referencedTable: $$AudioItemsTableReferences
                              ._audioItemTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AudioItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).audioItemTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.audioItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (savedWordsRefs)
                        await $_getPrefetchedData<
                          AudioItem,
                          $AudioItemsTable,
                          SavedWord
                        >(
                          currentTable: table,
                          referencedTable: $$AudioItemsTableReferences
                              ._savedWordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AudioItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).savedWordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.audioItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (savedSenseGroupsRefs)
                        await $_getPrefetchedData<
                          AudioItem,
                          $AudioItemsTable,
                          SavedSenseGroup
                        >(
                          currentTable: table,
                          referencedTable: $$AudioItemsTableReferences
                              ._savedSenseGroupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AudioItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).savedSenseGroupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.audioItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AudioItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioItemsTable,
      AudioItem,
      $$AudioItemsTableFilterComposer,
      $$AudioItemsTableOrderingComposer,
      $$AudioItemsTableAnnotationComposer,
      $$AudioItemsTableCreateCompanionBuilder,
      $$AudioItemsTableUpdateCompanionBuilder,
      (AudioItem, $$AudioItemsTableReferences),
      AudioItem,
      PrefetchHooks Function({
        bool collectionAudioItemsRefs,
        bool bookmarksRefs,
        bool playbackStatesRefs,
        bool learningProgressesRefs,
        bool stageCompletionsRefs,
        bool audioItemTagsRefs,
        bool savedWordsRefs,
        bool savedSenseGroupsRefs,
      })
    >;
typedef $$CollectionsTableCreateCompanionBuilder =
    CollectionsCompanion Function({
      required String id,
      required String name,
      required DateTime createdDate,
      Value<bool> isPinned,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<String> source,
      Value<String?> remoteId,
      Value<String?> coverUrl,
      Value<String?> description,
      Value<DateTime?> deprecatedAt,
      Value<int> rowid,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdDate,
      Value<bool> isPinned,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<String> source,
      Value<String?> remoteId,
      Value<String?> coverUrl,
      Value<String?> description,
      Value<DateTime?> deprecatedAt,
      Value<int> rowid,
    });

final class $$CollectionsTableReferences
    extends BaseReferences<_$AppDatabase, $CollectionsTable, Collection> {
  $$CollectionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CollectionAudioItemsTable,
    List<CollectionAudioItem>
  >
  _collectionAudioItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.collectionAudioItems,
        aliasName: $_aliasNameGenerator(
          db.collections.id,
          db.collectionAudioItems.collectionId,
        ),
      );

  $$CollectionAudioItemsTableProcessedTableManager
  get collectionAudioItemsRefs {
    final manager = $$CollectionAudioItemsTableTableManager(
      $_db,
      $_db.collectionAudioItems,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _collectionAudioItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
    column: $table.createdDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deprecatedAt => $composableBuilder(
    column: $table.deprecatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> collectionAudioItemsRefs(
    Expression<bool> Function($$CollectionAudioItemsTableFilterComposer f) f,
  ) {
    final $$CollectionAudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionAudioItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionAudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.collectionAudioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
    column: $table.createdDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deprecatedAt => $composableBuilder(
    column: $table.deprecatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
    column: $table.createdDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deprecatedAt => $composableBuilder(
    column: $table.deprecatedAt,
    builder: (column) => column,
  );

  Expression<T> collectionAudioItemsRefs<T extends Object>(
    Expression<T> Function($$CollectionAudioItemsTableAnnotationComposer a) f,
  ) {
    final $$CollectionAudioItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.collectionAudioItems,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CollectionAudioItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.collectionAudioItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionsTable,
          Collection,
          $$CollectionsTableFilterComposer,
          $$CollectionsTableOrderingComposer,
          $$CollectionsTableAnnotationComposer,
          $$CollectionsTableCreateCompanionBuilder,
          $$CollectionsTableUpdateCompanionBuilder,
          (Collection, $$CollectionsTableReferences),
          Collection,
          PrefetchHooks Function({bool collectionAudioItemsRefs})
        > {
  $$CollectionsTableTableManager(_$AppDatabase db, $CollectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdDate = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime?> deprecatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                createdDate: createdDate,
                isPinned: isPinned,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                source: source,
                remoteId: remoteId,
                coverUrl: coverUrl,
                description: description,
                deprecatedAt: deprecatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdDate,
                Value<bool> isPinned = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime?> deprecatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                createdDate: createdDate,
                isPinned: isPinned,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                source: source,
                remoteId: remoteId,
                coverUrl: coverUrl,
                description: description,
                deprecatedAt: deprecatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionAudioItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (collectionAudioItemsRefs) db.collectionAudioItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (collectionAudioItemsRefs)
                    await $_getPrefetchedData<
                      Collection,
                      $CollectionsTable,
                      CollectionAudioItem
                    >(
                      currentTable: table,
                      referencedTable: $$CollectionsTableReferences
                          ._collectionAudioItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CollectionsTableReferences(
                            db,
                            table,
                            p0,
                          ).collectionAudioItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.collectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionsTable,
      Collection,
      $$CollectionsTableFilterComposer,
      $$CollectionsTableOrderingComposer,
      $$CollectionsTableAnnotationComposer,
      $$CollectionsTableCreateCompanionBuilder,
      $$CollectionsTableUpdateCompanionBuilder,
      (Collection, $$CollectionsTableReferences),
      Collection,
      PrefetchHooks Function({bool collectionAudioItemsRefs})
    >;
typedef $$CollectionAudioItemsTableCreateCompanionBuilder =
    CollectionAudioItemsCompanion Function({
      required String collectionId,
      required String audioItemId,
      Value<int> sortOrder,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$CollectionAudioItemsTableUpdateCompanionBuilder =
    CollectionAudioItemsCompanion Function({
      Value<String> collectionId,
      Value<String> audioItemId,
      Value<int> sortOrder,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$CollectionAudioItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CollectionAudioItemsTable,
          CollectionAudioItem
        > {
  $$CollectionAudioItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CollectionsTable _collectionIdTable(_$AppDatabase db) =>
      db.collections.createAlias(
        $_aliasNameGenerator(
          db.collectionAudioItems.collectionId,
          db.collections.id,
        ),
      );

  $$CollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<String>('collection_id')!;

    final manager = $$CollectionsTableTableManager(
      $_db,
      $_db.collections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AudioItemsTable _audioItemIdTable(_$AppDatabase db) =>
      db.audioItems.createAlias(
        $_aliasNameGenerator(
          db.collectionAudioItems.audioItemId,
          db.audioItems.id,
        ),
      );

  $$AudioItemsTableProcessedTableManager get audioItemId {
    final $_column = $_itemColumn<String>('audio_item_id')!;

    final manager = $$AudioItemsTableTableManager(
      $_db,
      $_db.audioItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_audioItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CollectionAudioItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionAudioItemsTable> {
  $$CollectionAudioItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CollectionsTableFilterComposer get collectionId {
    final $$CollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableFilterComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AudioItemsTableFilterComposer get audioItemId {
    final $$AudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionAudioItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionAudioItemsTable> {
  $$CollectionAudioItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CollectionsTableOrderingComposer get collectionId {
    final $$CollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AudioItemsTableOrderingComposer get audioItemId {
    final $$AudioItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableOrderingComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionAudioItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionAudioItemsTable> {
  $$CollectionAudioItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$CollectionsTableAnnotationComposer get collectionId {
    final $$CollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AudioItemsTableAnnotationComposer get audioItemId {
    final $$AudioItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionAudioItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionAudioItemsTable,
          CollectionAudioItem,
          $$CollectionAudioItemsTableFilterComposer,
          $$CollectionAudioItemsTableOrderingComposer,
          $$CollectionAudioItemsTableAnnotationComposer,
          $$CollectionAudioItemsTableCreateCompanionBuilder,
          $$CollectionAudioItemsTableUpdateCompanionBuilder,
          (CollectionAudioItem, $$CollectionAudioItemsTableReferences),
          CollectionAudioItem,
          PrefetchHooks Function({bool collectionId, bool audioItemId})
        > {
  $$CollectionAudioItemsTableTableManager(
    _$AppDatabase db,
    $CollectionAudioItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionAudioItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionAudioItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CollectionAudioItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> collectionId = const Value.absent(),
                Value<String> audioItemId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionAudioItemsCompanion(
                collectionId: collectionId,
                audioItemId: audioItemId,
                sortOrder: sortOrder,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionId,
                required String audioItemId,
                Value<int> sortOrder = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => CollectionAudioItemsCompanion.insert(
                collectionId: collectionId,
                audioItemId: audioItemId,
                sortOrder: sortOrder,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CollectionAudioItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionId = false, audioItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (collectionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.collectionId,
                                referencedTable:
                                    $$CollectionAudioItemsTableReferences
                                        ._collectionIdTable(db),
                                referencedColumn:
                                    $$CollectionAudioItemsTableReferences
                                        ._collectionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (audioItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.audioItemId,
                                referencedTable:
                                    $$CollectionAudioItemsTableReferences
                                        ._audioItemIdTable(db),
                                referencedColumn:
                                    $$CollectionAudioItemsTableReferences
                                        ._audioItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CollectionAudioItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionAudioItemsTable,
      CollectionAudioItem,
      $$CollectionAudioItemsTableFilterComposer,
      $$CollectionAudioItemsTableOrderingComposer,
      $$CollectionAudioItemsTableAnnotationComposer,
      $$CollectionAudioItemsTableCreateCompanionBuilder,
      $$CollectionAudioItemsTableUpdateCompanionBuilder,
      (CollectionAudioItem, $$CollectionAudioItemsTableReferences),
      CollectionAudioItem,
      PrefetchHooks Function({bool collectionId, bool audioItemId})
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      required String audioItemId,
      required int sentenceIndex,
      required String sentenceText,
      required double startTime,
      required double endTime,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<String> audioItemId,
      Value<int> sentenceIndex,
      Value<String> sentenceText,
      Value<double> startTime,
      Value<double> endTime,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
    });

final class $$BookmarksTableReferences
    extends BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark> {
  $$BookmarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AudioItemsTable _audioItemIdTable(_$AppDatabase db) =>
      db.audioItems.createAlias(
        $_aliasNameGenerator(db.bookmarks.audioItemId, db.audioItems.id),
      );

  $$AudioItemsTableProcessedTableManager get audioItemId {
    final $_column = $_itemColumn<String>('audio_item_id')!;

    final manager = $$AudioItemsTableTableManager(
      $_db,
      $_db.audioItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_audioItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$AudioItemsTableFilterComposer get audioItemId {
    final $$AudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$AudioItemsTableOrderingComposer get audioItemId {
    final $$AudioItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableOrderingComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => column,
  );

  GeneratedColumn<double> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<double> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$AudioItemsTableAnnotationComposer get audioItemId {
    final $$AudioItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, $$BookmarksTableReferences),
          Bookmark,
          PrefetchHooks Function({bool audioItemId})
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> audioItemId = const Value.absent(),
                Value<int> sentenceIndex = const Value.absent(),
                Value<String> sentenceText = const Value.absent(),
                Value<double> startTime = const Value.absent(),
                Value<double> endTime = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                sentenceText: sentenceText,
                startTime: startTime,
                endTime: endTime,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String audioItemId,
                required int sentenceIndex,
                required String sentenceText,
                required double startTime,
                required double endTime,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                sentenceText: sentenceText,
                startTime: startTime,
                endTime: endTime,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookmarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({audioItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (audioItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.audioItemId,
                                referencedTable: $$BookmarksTableReferences
                                    ._audioItemIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._audioItemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, $$BookmarksTableReferences),
      Bookmark,
      PrefetchHooks Function({bool audioItemId})
    >;
typedef $$PlaybackStatesTableCreateCompanionBuilder =
    PlaybackStatesCompanion Function({
      required String audioItemId,
      required int positionMs,
      Value<int> playlistMode,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$PlaybackStatesTableUpdateCompanionBuilder =
    PlaybackStatesCompanion Function({
      Value<String> audioItemId,
      Value<int> positionMs,
      Value<int> playlistMode,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

final class $$PlaybackStatesTableReferences
    extends BaseReferences<_$AppDatabase, $PlaybackStatesTable, PlaybackState> {
  $$PlaybackStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AudioItemsTable _audioItemIdTable(_$AppDatabase db) =>
      db.audioItems.createAlias(
        $_aliasNameGenerator(db.playbackStates.audioItemId, db.audioItems.id),
      );

  $$AudioItemsTableProcessedTableManager get audioItemId {
    final $_column = $_itemColumn<String>('audio_item_id')!;

    final manager = $$AudioItemsTableTableManager(
      $_db,
      $_db.audioItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_audioItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaybackStatesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playlistMode => $composableBuilder(
    column: $table.playlistMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AudioItemsTableFilterComposer get audioItemId {
    final $$AudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playlistMode => $composableBuilder(
    column: $table.playlistMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AudioItemsTableOrderingComposer get audioItemId {
    final $$AudioItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableOrderingComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playlistMode => $composableBuilder(
    column: $table.playlistMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  $$AudioItemsTableAnnotationComposer get audioItemId {
    final $$AudioItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackStatesTable,
          PlaybackState,
          $$PlaybackStatesTableFilterComposer,
          $$PlaybackStatesTableOrderingComposer,
          $$PlaybackStatesTableAnnotationComposer,
          $$PlaybackStatesTableCreateCompanionBuilder,
          $$PlaybackStatesTableUpdateCompanionBuilder,
          (PlaybackState, $$PlaybackStatesTableReferences),
          PlaybackState,
          PrefetchHooks Function({bool audioItemId})
        > {
  $$PlaybackStatesTableTableManager(
    _$AppDatabase db,
    $PlaybackStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> audioItemId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> playlistMode = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackStatesCompanion(
                audioItemId: audioItemId,
                positionMs: positionMs,
                playlistMode: playlistMode,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String audioItemId,
                required int positionMs,
                Value<int> playlistMode = const Value.absent(),
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackStatesCompanion.insert(
                audioItemId: audioItemId,
                positionMs: positionMs,
                playlistMode: playlistMode,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaybackStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({audioItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (audioItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.audioItemId,
                                referencedTable: $$PlaybackStatesTableReferences
                                    ._audioItemIdTable(db),
                                referencedColumn:
                                    $$PlaybackStatesTableReferences
                                        ._audioItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaybackStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackStatesTable,
      PlaybackState,
      $$PlaybackStatesTableFilterComposer,
      $$PlaybackStatesTableOrderingComposer,
      $$PlaybackStatesTableAnnotationComposer,
      $$PlaybackStatesTableCreateCompanionBuilder,
      $$PlaybackStatesTableUpdateCompanionBuilder,
      (PlaybackState, $$PlaybackStatesTableReferences),
      PlaybackState,
      PrefetchHooks Function({bool audioItemId})
    >;
typedef $$LearningProgressesTableCreateCompanionBuilder =
    LearningProgressesCompanion Function({
      required String audioItemId,
      Value<String> currentStage,
      Value<String> currentSubStage,
      Value<int> difficulty,
      Value<DateTime?> firstLearnCompletedAt,
      Value<DateTime?> lastStageCompletedAt,
      Value<DateTime?> currentStageStartedAt,
      Value<int> totalStudyDurationMs,
      Value<int> blindListenPassCount,
      Value<int?> intensiveListenSentenceIndex,
      Value<int?> intensiveListenDifficultCount,
      Value<int?> intensiveListenPassCount,
      Value<int?> shadowingPassCount,
      Value<int?> shadowingSentenceIndex,
      Value<int?> difficultPracticeSentenceIndex,
      Value<int?> retellParagraphIndex,
      Value<int?> retellPassCount,
      Value<int?> blindListenParagraphIndex,
      Value<int?> freePlayBlindListenParagraphIndex,
      Value<int?> freePlayIntensiveListenSentenceIndex,
      Value<int?> freePlayShadowingSentenceIndex,
      Value<int?> freePlayDifficultPracticeSentenceIndex,
      Value<int?> freePlayRetellParagraphIndex,
      Value<DateTime?> newLearningBreakpointSavedAt,
      Value<DateTime?> freePlayBreakpointSavedAt,
      required DateTime updatedAt,
      Value<String> skippedSubStages,
      Value<int> rowid,
    });
typedef $$LearningProgressesTableUpdateCompanionBuilder =
    LearningProgressesCompanion Function({
      Value<String> audioItemId,
      Value<String> currentStage,
      Value<String> currentSubStage,
      Value<int> difficulty,
      Value<DateTime?> firstLearnCompletedAt,
      Value<DateTime?> lastStageCompletedAt,
      Value<DateTime?> currentStageStartedAt,
      Value<int> totalStudyDurationMs,
      Value<int> blindListenPassCount,
      Value<int?> intensiveListenSentenceIndex,
      Value<int?> intensiveListenDifficultCount,
      Value<int?> intensiveListenPassCount,
      Value<int?> shadowingPassCount,
      Value<int?> shadowingSentenceIndex,
      Value<int?> difficultPracticeSentenceIndex,
      Value<int?> retellParagraphIndex,
      Value<int?> retellPassCount,
      Value<int?> blindListenParagraphIndex,
      Value<int?> freePlayBlindListenParagraphIndex,
      Value<int?> freePlayIntensiveListenSentenceIndex,
      Value<int?> freePlayShadowingSentenceIndex,
      Value<int?> freePlayDifficultPracticeSentenceIndex,
      Value<int?> freePlayRetellParagraphIndex,
      Value<DateTime?> newLearningBreakpointSavedAt,
      Value<DateTime?> freePlayBreakpointSavedAt,
      Value<DateTime> updatedAt,
      Value<String> skippedSubStages,
      Value<int> rowid,
    });

final class $$LearningProgressesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LearningProgressesTable,
          LearningProgressesData
        > {
  $$LearningProgressesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AudioItemsTable _audioItemIdTable(_$AppDatabase db) =>
      db.audioItems.createAlias(
        $_aliasNameGenerator(
          db.learningProgresses.audioItemId,
          db.audioItems.id,
        ),
      );

  $$AudioItemsTableProcessedTableManager get audioItemId {
    final $_column = $_itemColumn<String>('audio_item_id')!;

    final manager = $$AudioItemsTableTableManager(
      $_db,
      $_db.audioItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_audioItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $LearningProgressesTable> {
  $$LearningProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get currentStage => $composableBuilder(
    column: $table.currentStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentSubStage => $composableBuilder(
    column: $table.currentSubStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstLearnCompletedAt => $composableBuilder(
    column: $table.firstLearnCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastStageCompletedAt => $composableBuilder(
    column: $table.lastStageCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get currentStageStartedAt => $composableBuilder(
    column: $table.currentStageStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalStudyDurationMs => $composableBuilder(
    column: $table.totalStudyDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blindListenPassCount => $composableBuilder(
    column: $table.blindListenPassCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intensiveListenSentenceIndex => $composableBuilder(
    column: $table.intensiveListenSentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intensiveListenDifficultCount => $composableBuilder(
    column: $table.intensiveListenDifficultCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intensiveListenPassCount => $composableBuilder(
    column: $table.intensiveListenPassCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shadowingPassCount => $composableBuilder(
    column: $table.shadowingPassCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shadowingSentenceIndex => $composableBuilder(
    column: $table.shadowingSentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difficultPracticeSentenceIndex => $composableBuilder(
    column: $table.difficultPracticeSentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retellParagraphIndex => $composableBuilder(
    column: $table.retellParagraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retellPassCount => $composableBuilder(
    column: $table.retellPassCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blindListenParagraphIndex => $composableBuilder(
    column: $table.blindListenParagraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freePlayBlindListenParagraphIndex =>
      $composableBuilder(
        column: $table.freePlayBlindListenParagraphIndex,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<int> get freePlayIntensiveListenSentenceIndex =>
      $composableBuilder(
        column: $table.freePlayIntensiveListenSentenceIndex,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<int> get freePlayShadowingSentenceIndex => $composableBuilder(
    column: $table.freePlayShadowingSentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freePlayDifficultPracticeSentenceIndex =>
      $composableBuilder(
        column: $table.freePlayDifficultPracticeSentenceIndex,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<int> get freePlayRetellParagraphIndex => $composableBuilder(
    column: $table.freePlayRetellParagraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get newLearningBreakpointSavedAt =>
      $composableBuilder(
        column: $table.newLearningBreakpointSavedAt,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<DateTime> get freePlayBreakpointSavedAt => $composableBuilder(
    column: $table.freePlayBreakpointSavedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skippedSubStages => $composableBuilder(
    column: $table.skippedSubStages,
    builder: (column) => ColumnFilters(column),
  );

  $$AudioItemsTableFilterComposer get audioItemId {
    final $$AudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningProgressesTable> {
  $$LearningProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get currentStage => $composableBuilder(
    column: $table.currentStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentSubStage => $composableBuilder(
    column: $table.currentSubStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstLearnCompletedAt => $composableBuilder(
    column: $table.firstLearnCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastStageCompletedAt => $composableBuilder(
    column: $table.lastStageCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get currentStageStartedAt => $composableBuilder(
    column: $table.currentStageStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalStudyDurationMs => $composableBuilder(
    column: $table.totalStudyDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blindListenPassCount => $composableBuilder(
    column: $table.blindListenPassCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intensiveListenSentenceIndex => $composableBuilder(
    column: $table.intensiveListenSentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intensiveListenDifficultCount => $composableBuilder(
    column: $table.intensiveListenDifficultCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intensiveListenPassCount => $composableBuilder(
    column: $table.intensiveListenPassCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shadowingPassCount => $composableBuilder(
    column: $table.shadowingPassCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shadowingSentenceIndex => $composableBuilder(
    column: $table.shadowingSentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difficultPracticeSentenceIndex => $composableBuilder(
    column: $table.difficultPracticeSentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retellParagraphIndex => $composableBuilder(
    column: $table.retellParagraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retellPassCount => $composableBuilder(
    column: $table.retellPassCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blindListenParagraphIndex => $composableBuilder(
    column: $table.blindListenParagraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freePlayBlindListenParagraphIndex =>
      $composableBuilder(
        column: $table.freePlayBlindListenParagraphIndex,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get freePlayIntensiveListenSentenceIndex =>
      $composableBuilder(
        column: $table.freePlayIntensiveListenSentenceIndex,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get freePlayShadowingSentenceIndex => $composableBuilder(
    column: $table.freePlayShadowingSentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freePlayDifficultPracticeSentenceIndex =>
      $composableBuilder(
        column: $table.freePlayDifficultPracticeSentenceIndex,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get freePlayRetellParagraphIndex => $composableBuilder(
    column: $table.freePlayRetellParagraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get newLearningBreakpointSavedAt =>
      $composableBuilder(
        column: $table.newLearningBreakpointSavedAt,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<DateTime> get freePlayBreakpointSavedAt => $composableBuilder(
    column: $table.freePlayBreakpointSavedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skippedSubStages => $composableBuilder(
    column: $table.skippedSubStages,
    builder: (column) => ColumnOrderings(column),
  );

  $$AudioItemsTableOrderingComposer get audioItemId {
    final $$AudioItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableOrderingComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningProgressesTable> {
  $$LearningProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get currentStage => $composableBuilder(
    column: $table.currentStage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentSubStage => $composableBuilder(
    column: $table.currentSubStage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstLearnCompletedAt => $composableBuilder(
    column: $table.firstLearnCompletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastStageCompletedAt => $composableBuilder(
    column: $table.lastStageCompletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get currentStageStartedAt => $composableBuilder(
    column: $table.currentStageStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalStudyDurationMs => $composableBuilder(
    column: $table.totalStudyDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blindListenPassCount => $composableBuilder(
    column: $table.blindListenPassCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intensiveListenSentenceIndex => $composableBuilder(
    column: $table.intensiveListenSentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intensiveListenDifficultCount => $composableBuilder(
    column: $table.intensiveListenDifficultCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intensiveListenPassCount => $composableBuilder(
    column: $table.intensiveListenPassCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get shadowingPassCount => $composableBuilder(
    column: $table.shadowingPassCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get shadowingSentenceIndex => $composableBuilder(
    column: $table.shadowingSentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get difficultPracticeSentenceIndex => $composableBuilder(
    column: $table.difficultPracticeSentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retellParagraphIndex => $composableBuilder(
    column: $table.retellParagraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retellPassCount => $composableBuilder(
    column: $table.retellPassCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blindListenParagraphIndex => $composableBuilder(
    column: $table.blindListenParagraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get freePlayBlindListenParagraphIndex =>
      $composableBuilder(
        column: $table.freePlayBlindListenParagraphIndex,
        builder: (column) => column,
      );

  GeneratedColumn<int> get freePlayIntensiveListenSentenceIndex =>
      $composableBuilder(
        column: $table.freePlayIntensiveListenSentenceIndex,
        builder: (column) => column,
      );

  GeneratedColumn<int> get freePlayShadowingSentenceIndex => $composableBuilder(
    column: $table.freePlayShadowingSentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get freePlayDifficultPracticeSentenceIndex =>
      $composableBuilder(
        column: $table.freePlayDifficultPracticeSentenceIndex,
        builder: (column) => column,
      );

  GeneratedColumn<int> get freePlayRetellParagraphIndex => $composableBuilder(
    column: $table.freePlayRetellParagraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get newLearningBreakpointSavedAt =>
      $composableBuilder(
        column: $table.newLearningBreakpointSavedAt,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get freePlayBreakpointSavedAt => $composableBuilder(
    column: $table.freePlayBreakpointSavedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get skippedSubStages => $composableBuilder(
    column: $table.skippedSubStages,
    builder: (column) => column,
  );

  $$AudioItemsTableAnnotationComposer get audioItemId {
    final $$AudioItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningProgressesTable,
          LearningProgressesData,
          $$LearningProgressesTableFilterComposer,
          $$LearningProgressesTableOrderingComposer,
          $$LearningProgressesTableAnnotationComposer,
          $$LearningProgressesTableCreateCompanionBuilder,
          $$LearningProgressesTableUpdateCompanionBuilder,
          (LearningProgressesData, $$LearningProgressesTableReferences),
          LearningProgressesData,
          PrefetchHooks Function({bool audioItemId})
        > {
  $$LearningProgressesTableTableManager(
    _$AppDatabase db,
    $LearningProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> audioItemId = const Value.absent(),
                Value<String> currentStage = const Value.absent(),
                Value<String> currentSubStage = const Value.absent(),
                Value<int> difficulty = const Value.absent(),
                Value<DateTime?> firstLearnCompletedAt = const Value.absent(),
                Value<DateTime?> lastStageCompletedAt = const Value.absent(),
                Value<DateTime?> currentStageStartedAt = const Value.absent(),
                Value<int> totalStudyDurationMs = const Value.absent(),
                Value<int> blindListenPassCount = const Value.absent(),
                Value<int?> intensiveListenSentenceIndex = const Value.absent(),
                Value<int?> intensiveListenDifficultCount =
                    const Value.absent(),
                Value<int?> intensiveListenPassCount = const Value.absent(),
                Value<int?> shadowingPassCount = const Value.absent(),
                Value<int?> shadowingSentenceIndex = const Value.absent(),
                Value<int?> difficultPracticeSentenceIndex =
                    const Value.absent(),
                Value<int?> retellParagraphIndex = const Value.absent(),
                Value<int?> retellPassCount = const Value.absent(),
                Value<int?> blindListenParagraphIndex = const Value.absent(),
                Value<int?> freePlayBlindListenParagraphIndex =
                    const Value.absent(),
                Value<int?> freePlayIntensiveListenSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayShadowingSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayDifficultPracticeSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayRetellParagraphIndex = const Value.absent(),
                Value<DateTime?> newLearningBreakpointSavedAt =
                    const Value.absent(),
                Value<DateTime?> freePlayBreakpointSavedAt =
                    const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> skippedSubStages = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningProgressesCompanion(
                audioItemId: audioItemId,
                currentStage: currentStage,
                currentSubStage: currentSubStage,
                difficulty: difficulty,
                firstLearnCompletedAt: firstLearnCompletedAt,
                lastStageCompletedAt: lastStageCompletedAt,
                currentStageStartedAt: currentStageStartedAt,
                totalStudyDurationMs: totalStudyDurationMs,
                blindListenPassCount: blindListenPassCount,
                intensiveListenSentenceIndex: intensiveListenSentenceIndex,
                intensiveListenDifficultCount: intensiveListenDifficultCount,
                intensiveListenPassCount: intensiveListenPassCount,
                shadowingPassCount: shadowingPassCount,
                shadowingSentenceIndex: shadowingSentenceIndex,
                difficultPracticeSentenceIndex: difficultPracticeSentenceIndex,
                retellParagraphIndex: retellParagraphIndex,
                retellPassCount: retellPassCount,
                blindListenParagraphIndex: blindListenParagraphIndex,
                freePlayBlindListenParagraphIndex:
                    freePlayBlindListenParagraphIndex,
                freePlayIntensiveListenSentenceIndex:
                    freePlayIntensiveListenSentenceIndex,
                freePlayShadowingSentenceIndex: freePlayShadowingSentenceIndex,
                freePlayDifficultPracticeSentenceIndex:
                    freePlayDifficultPracticeSentenceIndex,
                freePlayRetellParagraphIndex: freePlayRetellParagraphIndex,
                newLearningBreakpointSavedAt: newLearningBreakpointSavedAt,
                freePlayBreakpointSavedAt: freePlayBreakpointSavedAt,
                updatedAt: updatedAt,
                skippedSubStages: skippedSubStages,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String audioItemId,
                Value<String> currentStage = const Value.absent(),
                Value<String> currentSubStage = const Value.absent(),
                Value<int> difficulty = const Value.absent(),
                Value<DateTime?> firstLearnCompletedAt = const Value.absent(),
                Value<DateTime?> lastStageCompletedAt = const Value.absent(),
                Value<DateTime?> currentStageStartedAt = const Value.absent(),
                Value<int> totalStudyDurationMs = const Value.absent(),
                Value<int> blindListenPassCount = const Value.absent(),
                Value<int?> intensiveListenSentenceIndex = const Value.absent(),
                Value<int?> intensiveListenDifficultCount =
                    const Value.absent(),
                Value<int?> intensiveListenPassCount = const Value.absent(),
                Value<int?> shadowingPassCount = const Value.absent(),
                Value<int?> shadowingSentenceIndex = const Value.absent(),
                Value<int?> difficultPracticeSentenceIndex =
                    const Value.absent(),
                Value<int?> retellParagraphIndex = const Value.absent(),
                Value<int?> retellPassCount = const Value.absent(),
                Value<int?> blindListenParagraphIndex = const Value.absent(),
                Value<int?> freePlayBlindListenParagraphIndex =
                    const Value.absent(),
                Value<int?> freePlayIntensiveListenSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayShadowingSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayDifficultPracticeSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayRetellParagraphIndex = const Value.absent(),
                Value<DateTime?> newLearningBreakpointSavedAt =
                    const Value.absent(),
                Value<DateTime?> freePlayBreakpointSavedAt =
                    const Value.absent(),
                required DateTime updatedAt,
                Value<String> skippedSubStages = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningProgressesCompanion.insert(
                audioItemId: audioItemId,
                currentStage: currentStage,
                currentSubStage: currentSubStage,
                difficulty: difficulty,
                firstLearnCompletedAt: firstLearnCompletedAt,
                lastStageCompletedAt: lastStageCompletedAt,
                currentStageStartedAt: currentStageStartedAt,
                totalStudyDurationMs: totalStudyDurationMs,
                blindListenPassCount: blindListenPassCount,
                intensiveListenSentenceIndex: intensiveListenSentenceIndex,
                intensiveListenDifficultCount: intensiveListenDifficultCount,
                intensiveListenPassCount: intensiveListenPassCount,
                shadowingPassCount: shadowingPassCount,
                shadowingSentenceIndex: shadowingSentenceIndex,
                difficultPracticeSentenceIndex: difficultPracticeSentenceIndex,
                retellParagraphIndex: retellParagraphIndex,
                retellPassCount: retellPassCount,
                blindListenParagraphIndex: blindListenParagraphIndex,
                freePlayBlindListenParagraphIndex:
                    freePlayBlindListenParagraphIndex,
                freePlayIntensiveListenSentenceIndex:
                    freePlayIntensiveListenSentenceIndex,
                freePlayShadowingSentenceIndex: freePlayShadowingSentenceIndex,
                freePlayDifficultPracticeSentenceIndex:
                    freePlayDifficultPracticeSentenceIndex,
                freePlayRetellParagraphIndex: freePlayRetellParagraphIndex,
                newLearningBreakpointSavedAt: newLearningBreakpointSavedAt,
                freePlayBreakpointSavedAt: freePlayBreakpointSavedAt,
                updatedAt: updatedAt,
                skippedSubStages: skippedSubStages,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LearningProgressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({audioItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (audioItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.audioItemId,
                                referencedTable:
                                    $$LearningProgressesTableReferences
                                        ._audioItemIdTable(db),
                                referencedColumn:
                                    $$LearningProgressesTableReferences
                                        ._audioItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningProgressesTable,
      LearningProgressesData,
      $$LearningProgressesTableFilterComposer,
      $$LearningProgressesTableOrderingComposer,
      $$LearningProgressesTableAnnotationComposer,
      $$LearningProgressesTableCreateCompanionBuilder,
      $$LearningProgressesTableUpdateCompanionBuilder,
      (LearningProgressesData, $$LearningProgressesTableReferences),
      LearningProgressesData,
      PrefetchHooks Function({bool audioItemId})
    >;
typedef $$StageCompletionsTableCreateCompanionBuilder =
    StageCompletionsCompanion Function({
      Value<int> id,
      required String audioItemId,
      required String stage,
      required String subStage,
      required DateTime completedAt,
      Value<int> durationMs,
    });
typedef $$StageCompletionsTableUpdateCompanionBuilder =
    StageCompletionsCompanion Function({
      Value<int> id,
      Value<String> audioItemId,
      Value<String> stage,
      Value<String> subStage,
      Value<DateTime> completedAt,
      Value<int> durationMs,
    });

final class $$StageCompletionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $StageCompletionsTable, StageCompletion> {
  $$StageCompletionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AudioItemsTable _audioItemIdTable(_$AppDatabase db) =>
      db.audioItems.createAlias(
        $_aliasNameGenerator(db.stageCompletions.audioItemId, db.audioItems.id),
      );

  $$AudioItemsTableProcessedTableManager get audioItemId {
    final $_column = $_itemColumn<String>('audio_item_id')!;

    final manager = $$AudioItemsTableTableManager(
      $_db,
      $_db.audioItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_audioItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StageCompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $StageCompletionsTable> {
  $$StageCompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subStage => $composableBuilder(
    column: $table.subStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  $$AudioItemsTableFilterComposer get audioItemId {
    final $$AudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageCompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StageCompletionsTable> {
  $$StageCompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subStage => $composableBuilder(
    column: $table.subStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$AudioItemsTableOrderingComposer get audioItemId {
    final $$AudioItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableOrderingComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageCompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StageCompletionsTable> {
  $$StageCompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get subStage =>
      $composableBuilder(column: $table.subStage, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  $$AudioItemsTableAnnotationComposer get audioItemId {
    final $$AudioItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageCompletionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StageCompletionsTable,
          StageCompletion,
          $$StageCompletionsTableFilterComposer,
          $$StageCompletionsTableOrderingComposer,
          $$StageCompletionsTableAnnotationComposer,
          $$StageCompletionsTableCreateCompanionBuilder,
          $$StageCompletionsTableUpdateCompanionBuilder,
          (StageCompletion, $$StageCompletionsTableReferences),
          StageCompletion,
          PrefetchHooks Function({bool audioItemId})
        > {
  $$StageCompletionsTableTableManager(
    _$AppDatabase db,
    $StageCompletionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StageCompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StageCompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StageCompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> audioItemId = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<String> subStage = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
              }) => StageCompletionsCompanion(
                id: id,
                audioItemId: audioItemId,
                stage: stage,
                subStage: subStage,
                completedAt: completedAt,
                durationMs: durationMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String audioItemId,
                required String stage,
                required String subStage,
                required DateTime completedAt,
                Value<int> durationMs = const Value.absent(),
              }) => StageCompletionsCompanion.insert(
                id: id,
                audioItemId: audioItemId,
                stage: stage,
                subStage: subStage,
                completedAt: completedAt,
                durationMs: durationMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StageCompletionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({audioItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (audioItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.audioItemId,
                                referencedTable:
                                    $$StageCompletionsTableReferences
                                        ._audioItemIdTable(db),
                                referencedColumn:
                                    $$StageCompletionsTableReferences
                                        ._audioItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StageCompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StageCompletionsTable,
      StageCompletion,
      $$StageCompletionsTableFilterComposer,
      $$StageCompletionsTableOrderingComposer,
      $$StageCompletionsTableAnnotationComposer,
      $$StageCompletionsTableCreateCompanionBuilder,
      $$StageCompletionsTableUpdateCompanionBuilder,
      (StageCompletion, $$StageCompletionsTableReferences),
      StageCompletion,
      PrefetchHooks Function({bool audioItemId})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      required int color,
      required DateTime createdDate,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> color,
      Value<DateTime> createdDate,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AudioItemTagsTable, List<AudioItemTag>>
  _audioItemTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.audioItemTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.audioItemTags.tagId),
  );

  $$AudioItemTagsTableProcessedTableManager get audioItemTagsRefs {
    final manager = $$AudioItemTagsTableTableManager(
      $_db,
      $_db.audioItemTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_audioItemTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
    column: $table.createdDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> audioItemTagsRefs(
    Expression<bool> Function($$AudioItemTagsTableFilterComposer f) f,
  ) {
    final $$AudioItemTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioItemTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemTagsTableFilterComposer(
            $db: $db,
            $table: $db.audioItemTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
    column: $table.createdDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
    column: $table.createdDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  Expression<T> audioItemTagsRefs<T extends Object>(
    Expression<T> Function($$AudioItemTagsTableAnnotationComposer a) f,
  ) {
    final $$AudioItemTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioItemTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItemTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool audioItemTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<DateTime> createdDate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                color: color,
                createdDate: createdDate,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int color,
                required DateTime createdDate,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                createdDate: createdDate,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({audioItemTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (audioItemTagsRefs) db.audioItemTags,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (audioItemTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, AudioItemTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._audioItemTagsRefsTable(db),
                      managerFromTypedResult: (p0) => $$TagsTableReferences(
                        db,
                        table,
                        p0,
                      ).audioItemTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool audioItemTagsRefs})
    >;
typedef $$AudioItemTagsTableCreateCompanionBuilder =
    AudioItemTagsCompanion Function({
      required String tagId,
      required String audioItemId,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$AudioItemTagsTableUpdateCompanionBuilder =
    AudioItemTagsCompanion Function({
      Value<String> tagId,
      Value<String> audioItemId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$AudioItemTagsTableReferences
    extends BaseReferences<_$AppDatabase, $AudioItemTagsTable, AudioItemTag> {
  $$AudioItemTagsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TagsTable _tagIdTable(_$AppDatabase db) => db.tags.createAlias(
    $_aliasNameGenerator(db.audioItemTags.tagId, db.tags.id),
  );

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AudioItemsTable _audioItemIdTable(_$AppDatabase db) =>
      db.audioItems.createAlias(
        $_aliasNameGenerator(db.audioItemTags.audioItemId, db.audioItems.id),
      );

  $$AudioItemsTableProcessedTableManager get audioItemId {
    final $_column = $_itemColumn<String>('audio_item_id')!;

    final manager = $$AudioItemsTableTableManager(
      $_db,
      $_db.audioItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_audioItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AudioItemTagsTableFilterComposer
    extends Composer<_$AppDatabase, $AudioItemTagsTable> {
  $$AudioItemTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AudioItemsTableFilterComposer get audioItemId {
    final $$AudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioItemTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioItemTagsTable> {
  $$AudioItemTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AudioItemsTableOrderingComposer get audioItemId {
    final $$AudioItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableOrderingComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioItemTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioItemTagsTable> {
  $$AudioItemTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AudioItemsTableAnnotationComposer get audioItemId {
    final $$AudioItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioItemTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioItemTagsTable,
          AudioItemTag,
          $$AudioItemTagsTableFilterComposer,
          $$AudioItemTagsTableOrderingComposer,
          $$AudioItemTagsTableAnnotationComposer,
          $$AudioItemTagsTableCreateCompanionBuilder,
          $$AudioItemTagsTableUpdateCompanionBuilder,
          (AudioItemTag, $$AudioItemTagsTableReferences),
          AudioItemTag,
          PrefetchHooks Function({bool tagId, bool audioItemId})
        > {
  $$AudioItemTagsTableTableManager(_$AppDatabase db, $AudioItemTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioItemTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioItemTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioItemTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tagId = const Value.absent(),
                Value<String> audioItemId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioItemTagsCompanion(
                tagId: tagId,
                audioItemId: audioItemId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tagId,
                required String audioItemId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => AudioItemTagsCompanion.insert(
                tagId: tagId,
                audioItemId: audioItemId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AudioItemTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagId = false, audioItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$AudioItemTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$AudioItemTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (audioItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.audioItemId,
                                referencedTable: $$AudioItemTagsTableReferences
                                    ._audioItemIdTable(db),
                                referencedColumn: $$AudioItemTagsTableReferences
                                    ._audioItemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AudioItemTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioItemTagsTable,
      AudioItemTag,
      $$AudioItemTagsTableFilterComposer,
      $$AudioItemTagsTableOrderingComposer,
      $$AudioItemTagsTableAnnotationComposer,
      $$AudioItemTagsTableCreateCompanionBuilder,
      $$AudioItemTagsTableUpdateCompanionBuilder,
      (AudioItemTag, $$AudioItemTagsTableReferences),
      AudioItemTag,
      PrefetchHooks Function({bool tagId, bool audioItemId})
    >;
typedef $$SentenceAiCacheTableCreateCompanionBuilder =
    SentenceAiCacheCompanion Function({
      Value<int> id,
      required String textHash,
      required String type,
      required String result,
      required DateTime createdAt,
      required DateTime lastAccessedAt,
    });
typedef $$SentenceAiCacheTableUpdateCompanionBuilder =
    SentenceAiCacheCompanion Function({
      Value<int> id,
      Value<String> textHash,
      Value<String> type,
      Value<String> result,
      Value<DateTime> createdAt,
      Value<DateTime> lastAccessedAt,
    });

class $$SentenceAiCacheTableFilterComposer
    extends Composer<_$AppDatabase, $SentenceAiCacheTable> {
  $$SentenceAiCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SentenceAiCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $SentenceAiCacheTable> {
  $$SentenceAiCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SentenceAiCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $SentenceAiCacheTable> {
  $$SentenceAiCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get textHash =>
      $composableBuilder(column: $table.textHash, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );
}

class $$SentenceAiCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SentenceAiCacheTable,
          SentenceAiCacheData,
          $$SentenceAiCacheTableFilterComposer,
          $$SentenceAiCacheTableOrderingComposer,
          $$SentenceAiCacheTableAnnotationComposer,
          $$SentenceAiCacheTableCreateCompanionBuilder,
          $$SentenceAiCacheTableUpdateCompanionBuilder,
          (
            SentenceAiCacheData,
            BaseReferences<
              _$AppDatabase,
              $SentenceAiCacheTable,
              SentenceAiCacheData
            >,
          ),
          SentenceAiCacheData,
          PrefetchHooks Function()
        > {
  $$SentenceAiCacheTableTableManager(
    _$AppDatabase db,
    $SentenceAiCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SentenceAiCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SentenceAiCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SentenceAiCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> textHash = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
              }) => SentenceAiCacheCompanion(
                id: id,
                textHash: textHash,
                type: type,
                result: result,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String textHash,
                required String type,
                required String result,
                required DateTime createdAt,
                required DateTime lastAccessedAt,
              }) => SentenceAiCacheCompanion.insert(
                id: id,
                textHash: textHash,
                type: type,
                result: result,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SentenceAiCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SentenceAiCacheTable,
      SentenceAiCacheData,
      $$SentenceAiCacheTableFilterComposer,
      $$SentenceAiCacheTableOrderingComposer,
      $$SentenceAiCacheTableAnnotationComposer,
      $$SentenceAiCacheTableCreateCompanionBuilder,
      $$SentenceAiCacheTableUpdateCompanionBuilder,
      (
        SentenceAiCacheData,
        BaseReferences<
          _$AppDatabase,
          $SentenceAiCacheTable,
          SentenceAiCacheData
        >,
      ),
      SentenceAiCacheData,
      PrefetchHooks Function()
    >;
typedef $$SavedWordsTableCreateCompanionBuilder =
    SavedWordsCompanion Function({
      Value<int> id,
      required String word,
      Value<String?> audioItemId,
      Value<int?> sentenceIndex,
      Value<String?> sentenceText,
      Value<int?> sentenceStartMs,
      Value<int?> sentenceEndMs,
      Value<int> practiceCount,
      Value<int> totalStudyMs,
      Value<bool> viewedBack,
      Value<DateTime?> lastPracticedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
    });
typedef $$SavedWordsTableUpdateCompanionBuilder =
    SavedWordsCompanion Function({
      Value<int> id,
      Value<String> word,
      Value<String?> audioItemId,
      Value<int?> sentenceIndex,
      Value<String?> sentenceText,
      Value<int?> sentenceStartMs,
      Value<int?> sentenceEndMs,
      Value<int> practiceCount,
      Value<int> totalStudyMs,
      Value<bool> viewedBack,
      Value<DateTime?> lastPracticedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
    });

final class $$SavedWordsTableReferences
    extends BaseReferences<_$AppDatabase, $SavedWordsTable, SavedWord> {
  $$SavedWordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AudioItemsTable _audioItemIdTable(_$AppDatabase db) =>
      db.audioItems.createAlias(
        $_aliasNameGenerator(db.savedWords.audioItemId, db.audioItems.id),
      );

  $$AudioItemsTableProcessedTableManager? get audioItemId {
    final $_column = $_itemColumn<String>('audio_item_id');
    if ($_column == null) return null;
    final manager = $$AudioItemsTableTableManager(
      $_db,
      $_db.audioItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_audioItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedWordsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedWordsTable> {
  $$SavedWordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceStartMs => $composableBuilder(
    column: $table.sentenceStartMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceEndMs => $composableBuilder(
    column: $table.sentenceEndMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get practiceCount => $composableBuilder(
    column: $table.practiceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalStudyMs => $composableBuilder(
    column: $table.totalStudyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get viewedBack => $composableBuilder(
    column: $table.viewedBack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPracticedAt => $composableBuilder(
    column: $table.lastPracticedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$AudioItemsTableFilterComposer get audioItemId {
    final $$AudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedWordsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedWordsTable> {
  $$SavedWordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceStartMs => $composableBuilder(
    column: $table.sentenceStartMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceEndMs => $composableBuilder(
    column: $table.sentenceEndMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get practiceCount => $composableBuilder(
    column: $table.practiceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalStudyMs => $composableBuilder(
    column: $table.totalStudyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get viewedBack => $composableBuilder(
    column: $table.viewedBack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPracticedAt => $composableBuilder(
    column: $table.lastPracticedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$AudioItemsTableOrderingComposer get audioItemId {
    final $$AudioItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableOrderingComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedWordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedWordsTable> {
  $$SavedWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentenceStartMs => $composableBuilder(
    column: $table.sentenceStartMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentenceEndMs => $composableBuilder(
    column: $table.sentenceEndMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get practiceCount => $composableBuilder(
    column: $table.practiceCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalStudyMs => $composableBuilder(
    column: $table.totalStudyMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get viewedBack => $composableBuilder(
    column: $table.viewedBack,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPracticedAt => $composableBuilder(
    column: $table.lastPracticedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$AudioItemsTableAnnotationComposer get audioItemId {
    final $$AudioItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedWordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedWordsTable,
          SavedWord,
          $$SavedWordsTableFilterComposer,
          $$SavedWordsTableOrderingComposer,
          $$SavedWordsTableAnnotationComposer,
          $$SavedWordsTableCreateCompanionBuilder,
          $$SavedWordsTableUpdateCompanionBuilder,
          (SavedWord, $$SavedWordsTableReferences),
          SavedWord,
          PrefetchHooks Function({bool audioItemId})
        > {
  $$SavedWordsTableTableManager(_$AppDatabase db, $SavedWordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedWordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedWordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String?> audioItemId = const Value.absent(),
                Value<int?> sentenceIndex = const Value.absent(),
                Value<String?> sentenceText = const Value.absent(),
                Value<int?> sentenceStartMs = const Value.absent(),
                Value<int?> sentenceEndMs = const Value.absent(),
                Value<int> practiceCount = const Value.absent(),
                Value<int> totalStudyMs = const Value.absent(),
                Value<bool> viewedBack = const Value.absent(),
                Value<DateTime?> lastPracticedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => SavedWordsCompanion(
                id: id,
                word: word,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                sentenceText: sentenceText,
                sentenceStartMs: sentenceStartMs,
                sentenceEndMs: sentenceEndMs,
                practiceCount: practiceCount,
                totalStudyMs: totalStudyMs,
                viewedBack: viewedBack,
                lastPracticedAt: lastPracticedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String word,
                Value<String?> audioItemId = const Value.absent(),
                Value<int?> sentenceIndex = const Value.absent(),
                Value<String?> sentenceText = const Value.absent(),
                Value<int?> sentenceStartMs = const Value.absent(),
                Value<int?> sentenceEndMs = const Value.absent(),
                Value<int> practiceCount = const Value.absent(),
                Value<int> totalStudyMs = const Value.absent(),
                Value<bool> viewedBack = const Value.absent(),
                Value<DateTime?> lastPracticedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => SavedWordsCompanion.insert(
                id: id,
                word: word,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                sentenceText: sentenceText,
                sentenceStartMs: sentenceStartMs,
                sentenceEndMs: sentenceEndMs,
                practiceCount: practiceCount,
                totalStudyMs: totalStudyMs,
                viewedBack: viewedBack,
                lastPracticedAt: lastPracticedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedWordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({audioItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (audioItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.audioItemId,
                                referencedTable: $$SavedWordsTableReferences
                                    ._audioItemIdTable(db),
                                referencedColumn: $$SavedWordsTableReferences
                                    ._audioItemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedWordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedWordsTable,
      SavedWord,
      $$SavedWordsTableFilterComposer,
      $$SavedWordsTableOrderingComposer,
      $$SavedWordsTableAnnotationComposer,
      $$SavedWordsTableCreateCompanionBuilder,
      $$SavedWordsTableUpdateCompanionBuilder,
      (SavedWord, $$SavedWordsTableReferences),
      SavedWord,
      PrefetchHooks Function({bool audioItemId})
    >;
typedef $$SavedSenseGroupsTableCreateCompanionBuilder =
    SavedSenseGroupsCompanion Function({
      Value<int> id,
      required String phraseText,
      required String displayText,
      Value<String?> audioItemId,
      Value<int?> sentenceIndex,
      Value<String?> sentenceText,
      Value<int?> sentenceStartMs,
      Value<int?> sentenceEndMs,
      Value<int?> groupStartMs,
      Value<int?> groupEndMs,
      Value<int> practiceCount,
      Value<int> totalStudyMs,
      Value<bool> viewedBack,
      Value<DateTime?> lastPracticedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
    });
typedef $$SavedSenseGroupsTableUpdateCompanionBuilder =
    SavedSenseGroupsCompanion Function({
      Value<int> id,
      Value<String> phraseText,
      Value<String> displayText,
      Value<String?> audioItemId,
      Value<int?> sentenceIndex,
      Value<String?> sentenceText,
      Value<int?> sentenceStartMs,
      Value<int?> sentenceEndMs,
      Value<int?> groupStartMs,
      Value<int?> groupEndMs,
      Value<int> practiceCount,
      Value<int> totalStudyMs,
      Value<bool> viewedBack,
      Value<DateTime?> lastPracticedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
    });

final class $$SavedSenseGroupsTableReferences
    extends
        BaseReferences<_$AppDatabase, $SavedSenseGroupsTable, SavedSenseGroup> {
  $$SavedSenseGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AudioItemsTable _audioItemIdTable(_$AppDatabase db) =>
      db.audioItems.createAlias(
        $_aliasNameGenerator(db.savedSenseGroups.audioItemId, db.audioItems.id),
      );

  $$AudioItemsTableProcessedTableManager? get audioItemId {
    final $_column = $_itemColumn<String>('audio_item_id');
    if ($_column == null) return null;
    final manager = $$AudioItemsTableTableManager(
      $_db,
      $_db.audioItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_audioItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedSenseGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedSenseGroupsTable> {
  $$SavedSenseGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phraseText => $composableBuilder(
    column: $table.phraseText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayText => $composableBuilder(
    column: $table.displayText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceStartMs => $composableBuilder(
    column: $table.sentenceStartMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceEndMs => $composableBuilder(
    column: $table.sentenceEndMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groupStartMs => $composableBuilder(
    column: $table.groupStartMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groupEndMs => $composableBuilder(
    column: $table.groupEndMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get practiceCount => $composableBuilder(
    column: $table.practiceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalStudyMs => $composableBuilder(
    column: $table.totalStudyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get viewedBack => $composableBuilder(
    column: $table.viewedBack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPracticedAt => $composableBuilder(
    column: $table.lastPracticedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$AudioItemsTableFilterComposer get audioItemId {
    final $$AudioItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableFilterComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedSenseGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedSenseGroupsTable> {
  $$SavedSenseGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phraseText => $composableBuilder(
    column: $table.phraseText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayText => $composableBuilder(
    column: $table.displayText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceStartMs => $composableBuilder(
    column: $table.sentenceStartMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceEndMs => $composableBuilder(
    column: $table.sentenceEndMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groupStartMs => $composableBuilder(
    column: $table.groupStartMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groupEndMs => $composableBuilder(
    column: $table.groupEndMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get practiceCount => $composableBuilder(
    column: $table.practiceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalStudyMs => $composableBuilder(
    column: $table.totalStudyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get viewedBack => $composableBuilder(
    column: $table.viewedBack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPracticedAt => $composableBuilder(
    column: $table.lastPracticedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$AudioItemsTableOrderingComposer get audioItemId {
    final $$AudioItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableOrderingComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedSenseGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedSenseGroupsTable> {
  $$SavedSenseGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get phraseText => $composableBuilder(
    column: $table.phraseText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayText => $composableBuilder(
    column: $table.displayText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentenceIndex => $composableBuilder(
    column: $table.sentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sentenceText => $composableBuilder(
    column: $table.sentenceText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentenceStartMs => $composableBuilder(
    column: $table.sentenceStartMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentenceEndMs => $composableBuilder(
    column: $table.sentenceEndMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get groupStartMs => $composableBuilder(
    column: $table.groupStartMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get groupEndMs => $composableBuilder(
    column: $table.groupEndMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get practiceCount => $composableBuilder(
    column: $table.practiceCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalStudyMs => $composableBuilder(
    column: $table.totalStudyMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get viewedBack => $composableBuilder(
    column: $table.viewedBack,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPracticedAt => $composableBuilder(
    column: $table.lastPracticedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$AudioItemsTableAnnotationComposer get audioItemId {
    final $$AudioItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.audioItemId,
      referencedTable: $db.audioItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedSenseGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedSenseGroupsTable,
          SavedSenseGroup,
          $$SavedSenseGroupsTableFilterComposer,
          $$SavedSenseGroupsTableOrderingComposer,
          $$SavedSenseGroupsTableAnnotationComposer,
          $$SavedSenseGroupsTableCreateCompanionBuilder,
          $$SavedSenseGroupsTableUpdateCompanionBuilder,
          (SavedSenseGroup, $$SavedSenseGroupsTableReferences),
          SavedSenseGroup,
          PrefetchHooks Function({bool audioItemId})
        > {
  $$SavedSenseGroupsTableTableManager(
    _$AppDatabase db,
    $SavedSenseGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedSenseGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedSenseGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedSenseGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> phraseText = const Value.absent(),
                Value<String> displayText = const Value.absent(),
                Value<String?> audioItemId = const Value.absent(),
                Value<int?> sentenceIndex = const Value.absent(),
                Value<String?> sentenceText = const Value.absent(),
                Value<int?> sentenceStartMs = const Value.absent(),
                Value<int?> sentenceEndMs = const Value.absent(),
                Value<int?> groupStartMs = const Value.absent(),
                Value<int?> groupEndMs = const Value.absent(),
                Value<int> practiceCount = const Value.absent(),
                Value<int> totalStudyMs = const Value.absent(),
                Value<bool> viewedBack = const Value.absent(),
                Value<DateTime?> lastPracticedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => SavedSenseGroupsCompanion(
                id: id,
                phraseText: phraseText,
                displayText: displayText,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                sentenceText: sentenceText,
                sentenceStartMs: sentenceStartMs,
                sentenceEndMs: sentenceEndMs,
                groupStartMs: groupStartMs,
                groupEndMs: groupEndMs,
                practiceCount: practiceCount,
                totalStudyMs: totalStudyMs,
                viewedBack: viewedBack,
                lastPracticedAt: lastPracticedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String phraseText,
                required String displayText,
                Value<String?> audioItemId = const Value.absent(),
                Value<int?> sentenceIndex = const Value.absent(),
                Value<String?> sentenceText = const Value.absent(),
                Value<int?> sentenceStartMs = const Value.absent(),
                Value<int?> sentenceEndMs = const Value.absent(),
                Value<int?> groupStartMs = const Value.absent(),
                Value<int?> groupEndMs = const Value.absent(),
                Value<int> practiceCount = const Value.absent(),
                Value<int> totalStudyMs = const Value.absent(),
                Value<bool> viewedBack = const Value.absent(),
                Value<DateTime?> lastPracticedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => SavedSenseGroupsCompanion.insert(
                id: id,
                phraseText: phraseText,
                displayText: displayText,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                sentenceText: sentenceText,
                sentenceStartMs: sentenceStartMs,
                sentenceEndMs: sentenceEndMs,
                groupStartMs: groupStartMs,
                groupEndMs: groupEndMs,
                practiceCount: practiceCount,
                totalStudyMs: totalStudyMs,
                viewedBack: viewedBack,
                lastPracticedAt: lastPracticedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedSenseGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({audioItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (audioItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.audioItemId,
                                referencedTable:
                                    $$SavedSenseGroupsTableReferences
                                        ._audioItemIdTable(db),
                                referencedColumn:
                                    $$SavedSenseGroupsTableReferences
                                        ._audioItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedSenseGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedSenseGroupsTable,
      SavedSenseGroup,
      $$SavedSenseGroupsTableFilterComposer,
      $$SavedSenseGroupsTableOrderingComposer,
      $$SavedSenseGroupsTableAnnotationComposer,
      $$SavedSenseGroupsTableCreateCompanionBuilder,
      $$SavedSenseGroupsTableUpdateCompanionBuilder,
      (SavedSenseGroup, $$SavedSenseGroupsTableReferences),
      SavedSenseGroup,
      PrefetchHooks Function({bool audioItemId})
    >;
typedef $$LearnedWordFormsTableCreateCompanionBuilder =
    LearnedWordFormsCompanion Function({
      Value<int> id,
      required String wordForm,
      required DateTime firstLearnedAt,
    });
typedef $$LearnedWordFormsTableUpdateCompanionBuilder =
    LearnedWordFormsCompanion Function({
      Value<int> id,
      Value<String> wordForm,
      Value<DateTime> firstLearnedAt,
    });

class $$LearnedWordFormsTableFilterComposer
    extends Composer<_$AppDatabase, $LearnedWordFormsTable> {
  $$LearnedWordFormsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordForm => $composableBuilder(
    column: $table.wordForm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstLearnedAt => $composableBuilder(
    column: $table.firstLearnedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearnedWordFormsTableOrderingComposer
    extends Composer<_$AppDatabase, $LearnedWordFormsTable> {
  $$LearnedWordFormsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordForm => $composableBuilder(
    column: $table.wordForm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstLearnedAt => $composableBuilder(
    column: $table.firstLearnedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearnedWordFormsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearnedWordFormsTable> {
  $$LearnedWordFormsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get wordForm =>
      $composableBuilder(column: $table.wordForm, builder: (column) => column);

  GeneratedColumn<DateTime> get firstLearnedAt => $composableBuilder(
    column: $table.firstLearnedAt,
    builder: (column) => column,
  );
}

class $$LearnedWordFormsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearnedWordFormsTable,
          LearnedWordForm,
          $$LearnedWordFormsTableFilterComposer,
          $$LearnedWordFormsTableOrderingComposer,
          $$LearnedWordFormsTableAnnotationComposer,
          $$LearnedWordFormsTableCreateCompanionBuilder,
          $$LearnedWordFormsTableUpdateCompanionBuilder,
          (
            LearnedWordForm,
            BaseReferences<
              _$AppDatabase,
              $LearnedWordFormsTable,
              LearnedWordForm
            >,
          ),
          LearnedWordForm,
          PrefetchHooks Function()
        > {
  $$LearnedWordFormsTableTableManager(
    _$AppDatabase db,
    $LearnedWordFormsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearnedWordFormsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearnedWordFormsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearnedWordFormsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> wordForm = const Value.absent(),
                Value<DateTime> firstLearnedAt = const Value.absent(),
              }) => LearnedWordFormsCompanion(
                id: id,
                wordForm: wordForm,
                firstLearnedAt: firstLearnedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String wordForm,
                required DateTime firstLearnedAt,
              }) => LearnedWordFormsCompanion.insert(
                id: id,
                wordForm: wordForm,
                firstLearnedAt: firstLearnedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearnedWordFormsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearnedWordFormsTable,
      LearnedWordForm,
      $$LearnedWordFormsTableFilterComposer,
      $$LearnedWordFormsTableOrderingComposer,
      $$LearnedWordFormsTableAnnotationComposer,
      $$LearnedWordFormsTableCreateCompanionBuilder,
      $$LearnedWordFormsTableUpdateCompanionBuilder,
      (
        LearnedWordForm,
        BaseReferences<_$AppDatabase, $LearnedWordFormsTable, LearnedWordForm>,
      ),
      LearnedWordForm,
      PrefetchHooks Function()
    >;
typedef $$DailyStudyRecordsTableCreateCompanionBuilder =
    DailyStudyRecordsCompanion Function({
      Value<int> id,
      required DateTime date,
      Value<int> studyTimeSeconds,
      Value<int> inputWords,
      Value<int> outputWords,
      Value<int> inputTimeSeconds,
      Value<int> outputTimeSeconds,
    });
typedef $$DailyStudyRecordsTableUpdateCompanionBuilder =
    DailyStudyRecordsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<int> studyTimeSeconds,
      Value<int> inputWords,
      Value<int> outputWords,
      Value<int> inputTimeSeconds,
      Value<int> outputTimeSeconds,
    });

class $$DailyStudyRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyStudyRecordsTable> {
  $$DailyStudyRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get studyTimeSeconds => $composableBuilder(
    column: $table.studyTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputWords => $composableBuilder(
    column: $table.inputWords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputWords => $composableBuilder(
    column: $table.outputWords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyStudyRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyStudyRecordsTable> {
  $$DailyStudyRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get studyTimeSeconds => $composableBuilder(
    column: $table.studyTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputWords => $composableBuilder(
    column: $table.inputWords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputWords => $composableBuilder(
    column: $table.outputWords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyStudyRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyStudyRecordsTable> {
  $$DailyStudyRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get studyTimeSeconds => $composableBuilder(
    column: $table.studyTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputWords => $composableBuilder(
    column: $table.inputWords,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputWords => $composableBuilder(
    column: $table.outputWords,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => column,
  );
}

class $$DailyStudyRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStudyRecordsTable,
          DailyStudyRecord,
          $$DailyStudyRecordsTableFilterComposer,
          $$DailyStudyRecordsTableOrderingComposer,
          $$DailyStudyRecordsTableAnnotationComposer,
          $$DailyStudyRecordsTableCreateCompanionBuilder,
          $$DailyStudyRecordsTableUpdateCompanionBuilder,
          (
            DailyStudyRecord,
            BaseReferences<
              _$AppDatabase,
              $DailyStudyRecordsTable,
              DailyStudyRecord
            >,
          ),
          DailyStudyRecord,
          PrefetchHooks Function()
        > {
  $$DailyStudyRecordsTableTableManager(
    _$AppDatabase db,
    $DailyStudyRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyStudyRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyStudyRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyStudyRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> studyTimeSeconds = const Value.absent(),
                Value<int> inputWords = const Value.absent(),
                Value<int> outputWords = const Value.absent(),
                Value<int> inputTimeSeconds = const Value.absent(),
                Value<int> outputTimeSeconds = const Value.absent(),
              }) => DailyStudyRecordsCompanion(
                id: id,
                date: date,
                studyTimeSeconds: studyTimeSeconds,
                inputWords: inputWords,
                outputWords: outputWords,
                inputTimeSeconds: inputTimeSeconds,
                outputTimeSeconds: outputTimeSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                Value<int> studyTimeSeconds = const Value.absent(),
                Value<int> inputWords = const Value.absent(),
                Value<int> outputWords = const Value.absent(),
                Value<int> inputTimeSeconds = const Value.absent(),
                Value<int> outputTimeSeconds = const Value.absent(),
              }) => DailyStudyRecordsCompanion.insert(
                id: id,
                date: date,
                studyTimeSeconds: studyTimeSeconds,
                inputWords: inputWords,
                outputWords: outputWords,
                inputTimeSeconds: inputTimeSeconds,
                outputTimeSeconds: outputTimeSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStudyRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStudyRecordsTable,
      DailyStudyRecord,
      $$DailyStudyRecordsTableFilterComposer,
      $$DailyStudyRecordsTableOrderingComposer,
      $$DailyStudyRecordsTableAnnotationComposer,
      $$DailyStudyRecordsTableCreateCompanionBuilder,
      $$DailyStudyRecordsTableUpdateCompanionBuilder,
      (
        DailyStudyRecord,
        BaseReferences<
          _$AppDatabase,
          $DailyStudyRecordsTable,
          DailyStudyRecord
        >,
      ),
      DailyStudyRecord,
      PrefetchHooks Function()
    >;
typedef $$DailyStageStudyRecordsTableCreateCompanionBuilder =
    DailyStageStudyRecordsCompanion Function({
      Value<int> id,
      required DateTime date,
      required StudyStage stage,
      Value<int> studyTimeSeconds,
      Value<int> inputTimeSeconds,
      Value<int> outputTimeSeconds,
    });
typedef $$DailyStageStudyRecordsTableUpdateCompanionBuilder =
    DailyStageStudyRecordsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<StudyStage> stage,
      Value<int> studyTimeSeconds,
      Value<int> inputTimeSeconds,
      Value<int> outputTimeSeconds,
    });

class $$DailyStageStudyRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyStageStudyRecordsTable> {
  $$DailyStageStudyRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StudyStage, StudyStage, int> get stage =>
      $composableBuilder(
        column: $table.stage,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get studyTimeSeconds => $composableBuilder(
    column: $table.studyTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyStageStudyRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyStageStudyRecordsTable> {
  $$DailyStageStudyRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get studyTimeSeconds => $composableBuilder(
    column: $table.studyTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyStageStudyRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyStageStudyRecordsTable> {
  $$DailyStageStudyRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StudyStage, int> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<int> get studyTimeSeconds => $composableBuilder(
    column: $table.studyTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => column,
  );
}

class $$DailyStageStudyRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStageStudyRecordsTable,
          DailyStageStudyRecord,
          $$DailyStageStudyRecordsTableFilterComposer,
          $$DailyStageStudyRecordsTableOrderingComposer,
          $$DailyStageStudyRecordsTableAnnotationComposer,
          $$DailyStageStudyRecordsTableCreateCompanionBuilder,
          $$DailyStageStudyRecordsTableUpdateCompanionBuilder,
          (
            DailyStageStudyRecord,
            BaseReferences<
              _$AppDatabase,
              $DailyStageStudyRecordsTable,
              DailyStageStudyRecord
            >,
          ),
          DailyStageStudyRecord,
          PrefetchHooks Function()
        > {
  $$DailyStageStudyRecordsTableTableManager(
    _$AppDatabase db,
    $DailyStageStudyRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyStageStudyRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DailyStageStudyRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DailyStageStudyRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<StudyStage> stage = const Value.absent(),
                Value<int> studyTimeSeconds = const Value.absent(),
                Value<int> inputTimeSeconds = const Value.absent(),
                Value<int> outputTimeSeconds = const Value.absent(),
              }) => DailyStageStudyRecordsCompanion(
                id: id,
                date: date,
                stage: stage,
                studyTimeSeconds: studyTimeSeconds,
                inputTimeSeconds: inputTimeSeconds,
                outputTimeSeconds: outputTimeSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required StudyStage stage,
                Value<int> studyTimeSeconds = const Value.absent(),
                Value<int> inputTimeSeconds = const Value.absent(),
                Value<int> outputTimeSeconds = const Value.absent(),
              }) => DailyStageStudyRecordsCompanion.insert(
                id: id,
                date: date,
                stage: stage,
                studyTimeSeconds: studyTimeSeconds,
                inputTimeSeconds: inputTimeSeconds,
                outputTimeSeconds: outputTimeSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStageStudyRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStageStudyRecordsTable,
      DailyStageStudyRecord,
      $$DailyStageStudyRecordsTableFilterComposer,
      $$DailyStageStudyRecordsTableOrderingComposer,
      $$DailyStageStudyRecordsTableAnnotationComposer,
      $$DailyStageStudyRecordsTableCreateCompanionBuilder,
      $$DailyStageStudyRecordsTableUpdateCompanionBuilder,
      (
        DailyStageStudyRecord,
        BaseReferences<
          _$AppDatabase,
          $DailyStageStudyRecordsTable,
          DailyStageStudyRecord
        >,
      ),
      DailyStageStudyRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db, _db.audioItems);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db, _db.collections);
  $$CollectionAudioItemsTableTableManager get collectionAudioItems =>
      $$CollectionAudioItemsTableTableManager(_db, _db.collectionAudioItems);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$PlaybackStatesTableTableManager get playbackStates =>
      $$PlaybackStatesTableTableManager(_db, _db.playbackStates);
  $$LearningProgressesTableTableManager get learningProgresses =>
      $$LearningProgressesTableTableManager(_db, _db.learningProgresses);
  $$StageCompletionsTableTableManager get stageCompletions =>
      $$StageCompletionsTableTableManager(_db, _db.stageCompletions);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$AudioItemTagsTableTableManager get audioItemTags =>
      $$AudioItemTagsTableTableManager(_db, _db.audioItemTags);
  $$SentenceAiCacheTableTableManager get sentenceAiCache =>
      $$SentenceAiCacheTableTableManager(_db, _db.sentenceAiCache);
  $$SavedWordsTableTableManager get savedWords =>
      $$SavedWordsTableTableManager(_db, _db.savedWords);
  $$SavedSenseGroupsTableTableManager get savedSenseGroups =>
      $$SavedSenseGroupsTableTableManager(_db, _db.savedSenseGroups);
  $$LearnedWordFormsTableTableManager get learnedWordForms =>
      $$LearnedWordFormsTableTableManager(_db, _db.learnedWordForms);
  $$DailyStudyRecordsTableTableManager get dailyStudyRecords =>
      $$DailyStudyRecordsTableTableManager(_db, _db.dailyStudyRecords);
  $$DailyStageStudyRecordsTableTableManager get dailyStageStudyRecords =>
      $$DailyStageStudyRecordsTableTableManager(
        _db,
        _db.dailyStageStudyRecords,
      );
}
