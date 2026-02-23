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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _isStarredMeta = const VerificationMeta(
    'isStarred',
  );
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
    'is_starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_starred" IN (0, 1))',
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
    isStarred,
    updatedAt,
    deletedAt,
    syncStatus,
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
    } else if (isInserting) {
      context.missing(_audioPathMeta);
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
    if (data.containsKey('is_starred')) {
      context.handle(
        _isStarredMeta,
        isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta),
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
      )!,
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
      isStarred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_starred'],
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
  $AudioItemsTable createAlias(String alias) {
    return $AudioItemsTable(attachedDatabase, alias);
  }
}

class AudioItem extends DataClass implements Insertable<AudioItem> {
  /// UUID 主键
  final String id;

  /// 音频名称
  final String name;

  /// 音频文件相对路径
  final String audioPath;

  /// 字幕文件相对路径（可选）
  final String? transcriptPath;

  /// 添加时间
  final DateTime addedDate;

  /// 时长（秒）
  final int totalDuration;

  /// 字幕句子数
  final int sentenceCount;

  /// 字幕单词数
  final int wordCount;

  /// 是否星标
  final bool isStarred;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 同步状态：0=synced, 1=pendingUpload, 2=pendingDelete
  final int syncStatus;
  const AudioItem({
    required this.id,
    required this.name,
    required this.audioPath,
    this.transcriptPath,
    required this.addedDate,
    required this.totalDuration,
    required this.sentenceCount,
    required this.wordCount,
    required this.isStarred,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['audio_path'] = Variable<String>(audioPath);
    if (!nullToAbsent || transcriptPath != null) {
      map['transcript_path'] = Variable<String>(transcriptPath);
    }
    map['added_date'] = Variable<DateTime>(addedDate);
    map['total_duration'] = Variable<int>(totalDuration);
    map['sentence_count'] = Variable<int>(sentenceCount);
    map['word_count'] = Variable<int>(wordCount);
    map['is_starred'] = Variable<bool>(isStarred);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  AudioItemsCompanion toCompanion(bool nullToAbsent) {
    return AudioItemsCompanion(
      id: Value(id),
      name: Value(name),
      audioPath: Value(audioPath),
      transcriptPath: transcriptPath == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptPath),
      addedDate: Value(addedDate),
      totalDuration: Value(totalDuration),
      sentenceCount: Value(sentenceCount),
      wordCount: Value(wordCount),
      isStarred: Value(isStarred),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
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
      audioPath: serializer.fromJson<String>(json['audioPath']),
      transcriptPath: serializer.fromJson<String?>(json['transcriptPath']),
      addedDate: serializer.fromJson<DateTime>(json['addedDate']),
      totalDuration: serializer.fromJson<int>(json['totalDuration']),
      sentenceCount: serializer.fromJson<int>(json['sentenceCount']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      isStarred: serializer.fromJson<bool>(json['isStarred']),
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
      'audioPath': serializer.toJson<String>(audioPath),
      'transcriptPath': serializer.toJson<String?>(transcriptPath),
      'addedDate': serializer.toJson<DateTime>(addedDate),
      'totalDuration': serializer.toJson<int>(totalDuration),
      'sentenceCount': serializer.toJson<int>(sentenceCount),
      'wordCount': serializer.toJson<int>(wordCount),
      'isStarred': serializer.toJson<bool>(isStarred),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  AudioItem copyWith({
    String? id,
    String? name,
    String? audioPath,
    Value<String?> transcriptPath = const Value.absent(),
    DateTime? addedDate,
    int? totalDuration,
    int? sentenceCount,
    int? wordCount,
    bool? isStarred,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => AudioItem(
    id: id ?? this.id,
    name: name ?? this.name,
    audioPath: audioPath ?? this.audioPath,
    transcriptPath: transcriptPath.present
        ? transcriptPath.value
        : this.transcriptPath,
    addedDate: addedDate ?? this.addedDate,
    totalDuration: totalDuration ?? this.totalDuration,
    sentenceCount: sentenceCount ?? this.sentenceCount,
    wordCount: wordCount ?? this.wordCount,
    isStarred: isStarred ?? this.isStarred,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
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
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
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
          ..write('isStarred: $isStarred, ')
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
    audioPath,
    transcriptPath,
    addedDate,
    totalDuration,
    sentenceCount,
    wordCount,
    isStarred,
    updatedAt,
    deletedAt,
    syncStatus,
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
          other.isStarred == this.isStarred &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class AudioItemsCompanion extends UpdateCompanion<AudioItem> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> audioPath;
  final Value<String?> transcriptPath;
  final Value<DateTime> addedDate;
  final Value<int> totalDuration;
  final Value<int> sentenceCount;
  final Value<int> wordCount;
  final Value<bool> isStarred;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
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
    this.isStarred = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioItemsCompanion.insert({
    required String id,
    required String name,
    required String audioPath,
    this.transcriptPath = const Value.absent(),
    required DateTime addedDate,
    this.totalDuration = const Value.absent(),
    this.sentenceCount = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.isStarred = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       audioPath = Value(audioPath),
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
    Expression<bool>? isStarred,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? syncStatus,
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
      if (isStarred != null) 'is_starred': isStarred,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? audioPath,
    Value<String?>? transcriptPath,
    Value<DateTime>? addedDate,
    Value<int>? totalDuration,
    Value<int>? sentenceCount,
    Value<int>? wordCount,
    Value<bool>? isStarred,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
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
      isStarred: isStarred ?? this.isStarred,
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
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
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
    return (StringBuffer('AudioItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('audioPath: $audioPath, ')
          ..write('transcriptPath: $transcriptPath, ')
          ..write('addedDate: $addedDate, ')
          ..write('totalDuration: $totalDuration, ')
          ..write('sentenceCount: $sentenceCount, ')
          ..write('wordCount: $wordCount, ')
          ..write('isStarred: $isStarred, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
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
  static const VerificationMeta _isStarredMeta = const VerificationMeta(
    'isStarred',
  );
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
    'is_starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_starred" IN (0, 1))',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdDate,
    isStarred,
    updatedAt,
    deletedAt,
    syncStatus,
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
    if (data.containsKey('is_starred')) {
      context.handle(
        _isStarredMeta,
        isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta),
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
      isStarred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_starred'],
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

  /// 星标
  final bool isStarred;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 同步状态
  final int syncStatus;
  const Collection({
    required this.id,
    required this.name,
    required this.createdDate,
    required this.isStarred,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_date'] = Variable<DateTime>(createdDate);
    map['is_starred'] = Variable<bool>(isStarred);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      createdDate: Value(createdDate),
      isStarred: Value(isStarred),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
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
      isStarred: serializer.fromJson<bool>(json['isStarred']),
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
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'isStarred': serializer.toJson<bool>(isStarred),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  Collection copyWith({
    String? id,
    String? name,
    DateTime? createdDate,
    bool? isStarred,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    createdDate: createdDate ?? this.createdDate,
    isStarred: isStarred ?? this.isStarred,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Collection copyWithCompanion(CollectionsCompanion data) {
    return Collection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdDate: data.createdDate.present
          ? data.createdDate.value
          : this.createdDate,
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdDate: $createdDate, ')
          ..write('isStarred: $isStarred, ')
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
    createdDate,
    isStarred,
    updatedAt,
    deletedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdDate == this.createdDate &&
          other.isStarred == this.isStarred &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdDate;
  final Value<bool> isStarred;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  final Value<int> rowid;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdDate,
    this.isStarred = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdDate = Value(createdDate),
       updatedAt = Value(updatedAt);
  static Insertable<Collection> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdDate,
    Expression<bool>? isStarred,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdDate != null) 'created_date': createdDate,
      if (isStarred != null) 'is_starred': isStarred,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdDate,
    Value<bool>? isStarred,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
    Value<int>? rowid,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdDate: createdDate ?? this.createdDate,
      isStarred: isStarred ?? this.isStarred,
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
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
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
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdDate: $createdDate, ')
          ..write('isStarred: $isStarred, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
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
    updatedAt,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
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

  /// 首学完成时间（复习间隔计算基准，首学完成前为 null）
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

  /// 最后更新时间
  final DateTime updatedAt;
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
    required this.updatedAt,
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
    map['updated_at'] = Variable<DateTime>(updatedAt);
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
      updatedAt: Value(updatedAt),
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
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
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
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
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
    DateTime? updatedAt,
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
    updatedAt: updatedAt ?? this.updatedAt,
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
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
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
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
    updatedAt,
  );
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
          other.updatedAt == this.updatedAt);
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
  final Value<DateTime> updatedAt;
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
    this.updatedAt = const Value.absent(),
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
    required DateTime updatedAt,
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
    Expression<DateTime>? updatedAt,
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
      if (updatedAt != null) 'updated_at': updatedAt,
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
    Value<DateTime>? updatedAt,
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
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
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
          ..write('updatedAt: $updatedAt, ')
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
  ]);
}

typedef $$AudioItemsTableCreateCompanionBuilder =
    AudioItemsCompanion Function({
      required String id,
      required String name,
      required String audioPath,
      Value<String?> transcriptPath,
      required DateTime addedDate,
      Value<int> totalDuration,
      Value<int> sentenceCount,
      Value<int> wordCount,
      Value<bool> isStarred,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });
typedef $$AudioItemsTableUpdateCompanionBuilder =
    AudioItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> audioPath,
      Value<String?> transcriptPath,
      Value<DateTime> addedDate,
      Value<int> totalDuration,
      Value<int> sentenceCount,
      Value<int> wordCount,
      Value<bool> isStarred,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
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

  ColumnFilters<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
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

  ColumnOrderings<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
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

  GeneratedColumn<bool> get isStarred =>
      $composableBuilder(column: $table.isStarred, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
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
                Value<String> audioPath = const Value.absent(),
                Value<String?> transcriptPath = const Value.absent(),
                Value<DateTime> addedDate = const Value.absent(),
                Value<int> totalDuration = const Value.absent(),
                Value<int> sentenceCount = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
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
                isStarred: isStarred,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String audioPath,
                Value<String?> transcriptPath = const Value.absent(),
                required DateTime addedDate,
                Value<int> totalDuration = const Value.absent(),
                Value<int> sentenceCount = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
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
                isStarred: isStarred,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
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
      })
    >;
typedef $$CollectionsTableCreateCompanionBuilder =
    CollectionsCompanion Function({
      required String id,
      required String name,
      required DateTime createdDate,
      Value<bool> isStarred,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdDate,
      Value<bool> isStarred,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
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

  ColumnFilters<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
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

  ColumnOrderings<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
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

  GeneratedColumn<bool> get isStarred =>
      $composableBuilder(column: $table.isStarred, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
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
                Value<bool> isStarred = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                createdDate: createdDate,
                isStarred: isStarred,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdDate,
                Value<bool> isStarred = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                createdDate: createdDate,
                isStarred: isStarred,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
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
      required DateTime updatedAt,
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
      Value<DateTime> updatedAt,
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

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
                Value<DateTime> updatedAt = const Value.absent(),
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
                updatedAt: updatedAt,
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
                required DateTime updatedAt,
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
                updatedAt: updatedAt,
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
}
