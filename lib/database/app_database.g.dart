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
  static const VerificationMeta _originalAudioSha256Meta =
      const VerificationMeta('originalAudioSha256');
  @override
  late final GeneratedColumn<String> originalAudioSha256 =
      GeneratedColumn<String>(
        'original_audio_sha256',
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
  static const VerificationMeta _audioContentStatusMeta =
      const VerificationMeta('audioContentStatus');
  @override
  late final GeneratedColumn<int> audioContentStatus = GeneratedColumn<int>(
    'audio_content_status',
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
  static const VerificationMeta _transcriptSrtMeta = const VerificationMeta(
    'transcriptSrt',
  );
  @override
  late final GeneratedColumn<String> transcriptSrt = GeneratedColumn<String>(
    'transcript_srt',
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
  static const VerificationMeta _communityUnavailableAtMeta =
      const VerificationMeta('communityUnavailableAt');
  @override
  late final GeneratedColumn<DateTime> communityUnavailableAt =
      GeneratedColumn<DateTime>(
        'community_unavailable_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _communityDifficultyMeta =
      const VerificationMeta('communityDifficulty');
  @override
  late final GeneratedColumn<String> communityDifficulty =
      GeneratedColumn<String>(
        'community_difficulty',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _importSourceTypeMeta = const VerificationMeta(
    'importSourceType',
  );
  @override
  late final GeneratedColumn<String> importSourceType = GeneratedColumn<String>(
    'import_source_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importSourceUrlMeta = const VerificationMeta(
    'importSourceUrl',
  );
  @override
  late final GeneratedColumn<String> importSourceUrl = GeneratedColumn<String>(
    'import_source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _podcastEpisodeGuidMeta =
      const VerificationMeta('podcastEpisodeGuid');
  @override
  late final GeneratedColumn<String> podcastEpisodeGuid =
      GeneratedColumn<String>(
        'podcast_episode_guid',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _podcastEnclosureUrlMeta =
      const VerificationMeta('podcastEnclosureUrl');
  @override
  late final GeneratedColumn<String> podcastEnclosureUrl =
      GeneratedColumn<String>(
        'podcast_enclosure_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _podcastEnclosureTypeMeta =
      const VerificationMeta('podcastEnclosureType');
  @override
  late final GeneratedColumn<String> podcastEnclosureType =
      GeneratedColumn<String>(
        'podcast_enclosure_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _podcastDescriptionMeta =
      const VerificationMeta('podcastDescription');
  @override
  late final GeneratedColumn<String> podcastDescription =
      GeneratedColumn<String>(
        'podcast_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _podcastImageUrlMeta = const VerificationMeta(
    'podcastImageUrl',
  );
  @override
  late final GeneratedColumn<String> podcastImageUrl = GeneratedColumn<String>(
    'podcast_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _podcastLinkMeta = const VerificationMeta(
    'podcastLink',
  );
  @override
  late final GeneratedColumn<String> podcastLink = GeneratedColumn<String>(
    'podcast_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    originalAudioSha256,
    transcriptLanguage,
    audioContentStatus,
    updatedAt,
    deletedAt,
    wordTimestampsJson,
    transcriptSrt,
    syncStatus,
    remoteAudioId,
    originalDate,
    communityUnavailableAt,
    communityDifficulty,
    importSourceType,
    importSourceUrl,
    podcastEpisodeGuid,
    podcastEnclosureUrl,
    podcastEnclosureType,
    podcastDescription,
    podcastImageUrl,
    podcastLink,
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
    if (data.containsKey('original_audio_sha256')) {
      context.handle(
        _originalAudioSha256Meta,
        originalAudioSha256.isAcceptableOrUnknown(
          data['original_audio_sha256']!,
          _originalAudioSha256Meta,
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
    if (data.containsKey('audio_content_status')) {
      context.handle(
        _audioContentStatusMeta,
        audioContentStatus.isAcceptableOrUnknown(
          data['audio_content_status']!,
          _audioContentStatusMeta,
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
    if (data.containsKey('transcript_srt')) {
      context.handle(
        _transcriptSrtMeta,
        transcriptSrt.isAcceptableOrUnknown(
          data['transcript_srt']!,
          _transcriptSrtMeta,
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
    if (data.containsKey('community_unavailable_at')) {
      context.handle(
        _communityUnavailableAtMeta,
        communityUnavailableAt.isAcceptableOrUnknown(
          data['community_unavailable_at']!,
          _communityUnavailableAtMeta,
        ),
      );
    }
    if (data.containsKey('community_difficulty')) {
      context.handle(
        _communityDifficultyMeta,
        communityDifficulty.isAcceptableOrUnknown(
          data['community_difficulty']!,
          _communityDifficultyMeta,
        ),
      );
    }
    if (data.containsKey('import_source_type')) {
      context.handle(
        _importSourceTypeMeta,
        importSourceType.isAcceptableOrUnknown(
          data['import_source_type']!,
          _importSourceTypeMeta,
        ),
      );
    }
    if (data.containsKey('import_source_url')) {
      context.handle(
        _importSourceUrlMeta,
        importSourceUrl.isAcceptableOrUnknown(
          data['import_source_url']!,
          _importSourceUrlMeta,
        ),
      );
    }
    if (data.containsKey('podcast_episode_guid')) {
      context.handle(
        _podcastEpisodeGuidMeta,
        podcastEpisodeGuid.isAcceptableOrUnknown(
          data['podcast_episode_guid']!,
          _podcastEpisodeGuidMeta,
        ),
      );
    }
    if (data.containsKey('podcast_enclosure_url')) {
      context.handle(
        _podcastEnclosureUrlMeta,
        podcastEnclosureUrl.isAcceptableOrUnknown(
          data['podcast_enclosure_url']!,
          _podcastEnclosureUrlMeta,
        ),
      );
    }
    if (data.containsKey('podcast_enclosure_type')) {
      context.handle(
        _podcastEnclosureTypeMeta,
        podcastEnclosureType.isAcceptableOrUnknown(
          data['podcast_enclosure_type']!,
          _podcastEnclosureTypeMeta,
        ),
      );
    }
    if (data.containsKey('podcast_description')) {
      context.handle(
        _podcastDescriptionMeta,
        podcastDescription.isAcceptableOrUnknown(
          data['podcast_description']!,
          _podcastDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('podcast_image_url')) {
      context.handle(
        _podcastImageUrlMeta,
        podcastImageUrl.isAcceptableOrUnknown(
          data['podcast_image_url']!,
          _podcastImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('podcast_link')) {
      context.handle(
        _podcastLinkMeta,
        podcastLink.isAcceptableOrUnknown(
          data['podcast_link']!,
          _podcastLinkMeta,
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
      originalAudioSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_audio_sha256'],
      ),
      transcriptLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_language'],
      ),
      audioContentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_content_status'],
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
      transcriptSrt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_srt'],
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
      communityUnavailableAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}community_unavailable_at'],
      ),
      communityDifficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}community_difficulty'],
      ),
      importSourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_source_type'],
      ),
      importSourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_source_url'],
      ),
      podcastEpisodeGuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_episode_guid'],
      ),
      podcastEnclosureUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_enclosure_url'],
      ),
      podcastEnclosureType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_enclosure_type'],
      ),
      podcastDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_description'],
      ),
      podcastImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_image_url'],
      ),
      podcastLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_link'],
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

  /// 主媒体文件相对路径（音频或视频，音频落 `audios/`、视频落 `videos/`）。
  ///
  /// NULL 表示媒体尚未就绪（社区合集加入后、下载完成前）；非 NULL 表示文件已在本地。
  /// 是「媒体是否可用」的单一真实来源，同时是媒体类型判定依据（按扩展名派生 video/audio）。
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

  /// 媒体文件 SHA256 指纹（缓存，避免重复计算）。纯文件哈希，音视频通用。
  final String? audioSha256;

  /// 转码前原始媒体 SHA256 指纹。
  ///
  /// AI 转录优先用该值作为后端字幕缓存 key；为空时回退 [audioSha256]。
  /// 视频不转码（保留原始文件），此值等同原始文件指纹，音视频通用。
  final String? originalAudioSha256;

  /// AI 转录使用的语言（'en' / 'multi'）
  final String? transcriptLanguage;

  /// 媒体内容有效性状态：0=ok, 1=damaged, 2=silent, null=未检测。
  /// 新下载时检测一次（短解码失败判 damaged，可解码但静音判 silent）。
  /// 视频条目跳过检测，恒为 null（见 `audio_library_provider.checkAudioContent`）。
  final int? audioContentStatus;

  /// 最后修改时间
  final DateTime updatedAt;

  /// 软删除标记
  final DateTime? deletedAt;

  /// 词级时间戳 JSON（AI 转录时由后端返回，与字幕一起管理）
  final String? wordTimestampsJson;

  /// 字幕内容（完整 SRT 文本）。
  ///
  /// DB 成为字幕的唯一真相源后，本列保存整段 SRT。NULL 表示无字幕，或旧行尚未
  /// backfill（由启动时全量 backfill 从 [transcriptPath] 指向的文件读入）。
  /// 大字段，与 [wordTimestampsJson] 一样不进列表查询，仅按需读写。
  final String? transcriptSrt;

  /// 同步状态：0=synced, 1=pendingUpload, 2=pendingDelete
  final int syncStatus;

  /// 社区合集中该音频在后端的 UUID；仅社区合集音频有值。
  /// 用于同步比对（通过 remoteAudioId 反查本地行）。
  final String? remoteAudioId;

  /// 原始发布/播出日期。社区合集音频从后端 catalog 同步（如 VOA 某期的播出日期）；
  /// 用户自建音频保持 NULL。用于社区合集详情页「最早/最新发布」排序。
  final DateTime? originalDate;

  /// 社区合集文件从服务端消失的时间。
  ///
  /// 非 NULL 时表示该条目仍保留本地学习记录，但远端文件已不可用；
  /// 文件重新出现在 v2 列表后由同步清空。
  final DateTime? communityUnavailableAt;

  /// 社区合集文件由服务端维护的 CEFR 难度（A1–C2）；普通媒体保持 NULL。
  final String? communityDifficulty;

  /// 用户导入来源类型：local / direct_url / cloud_drive。
  ///
  /// 社区合集不使用该字段，继续由 remoteAudioId 和 collections.source 标识。
  final String? importSourceType;

  /// 用户导入来源 URL。直链导入记录原始 URL；本地文件导入保持 NULL。
  final String? importSourceUrl;

  /// Podcast episode 的 RSS guid；用于同一合集内去重。
  /// 无 guid 的 episode 不导入。
  final String? podcastEpisodeGuid;

  /// Episode 音频文件的 enclosure URL（RSS `<enclosure url="...">`）
  final String? podcastEnclosureUrl;

  /// Enclosure MIME type，如 audio/mpeg
  final String? podcastEnclosureType;

  /// Episode 简介文本，来自 RSS item description。
  final String? podcastDescription;

  /// Episode 封面图 URL，来自 RSS item itunes:image。
  final String? podcastImageUrl;

  /// Episode 网页链接，来自 RSS item link。
  final String? podcastLink;
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
    this.originalAudioSha256,
    this.transcriptLanguage,
    this.audioContentStatus,
    required this.updatedAt,
    this.deletedAt,
    this.wordTimestampsJson,
    this.transcriptSrt,
    required this.syncStatus,
    this.remoteAudioId,
    this.originalDate,
    this.communityUnavailableAt,
    this.communityDifficulty,
    this.importSourceType,
    this.importSourceUrl,
    this.podcastEpisodeGuid,
    this.podcastEnclosureUrl,
    this.podcastEnclosureType,
    this.podcastDescription,
    this.podcastImageUrl,
    this.podcastLink,
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
    if (!nullToAbsent || originalAudioSha256 != null) {
      map['original_audio_sha256'] = Variable<String>(originalAudioSha256);
    }
    if (!nullToAbsent || transcriptLanguage != null) {
      map['transcript_language'] = Variable<String>(transcriptLanguage);
    }
    if (!nullToAbsent || audioContentStatus != null) {
      map['audio_content_status'] = Variable<int>(audioContentStatus);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || wordTimestampsJson != null) {
      map['word_timestamps_json'] = Variable<String>(wordTimestampsJson);
    }
    if (!nullToAbsent || transcriptSrt != null) {
      map['transcript_srt'] = Variable<String>(transcriptSrt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    if (!nullToAbsent || remoteAudioId != null) {
      map['remote_audio_id'] = Variable<String>(remoteAudioId);
    }
    if (!nullToAbsent || originalDate != null) {
      map['original_date'] = Variable<DateTime>(originalDate);
    }
    if (!nullToAbsent || communityUnavailableAt != null) {
      map['community_unavailable_at'] = Variable<DateTime>(
        communityUnavailableAt,
      );
    }
    if (!nullToAbsent || communityDifficulty != null) {
      map['community_difficulty'] = Variable<String>(communityDifficulty);
    }
    if (!nullToAbsent || importSourceType != null) {
      map['import_source_type'] = Variable<String>(importSourceType);
    }
    if (!nullToAbsent || importSourceUrl != null) {
      map['import_source_url'] = Variable<String>(importSourceUrl);
    }
    if (!nullToAbsent || podcastEpisodeGuid != null) {
      map['podcast_episode_guid'] = Variable<String>(podcastEpisodeGuid);
    }
    if (!nullToAbsent || podcastEnclosureUrl != null) {
      map['podcast_enclosure_url'] = Variable<String>(podcastEnclosureUrl);
    }
    if (!nullToAbsent || podcastEnclosureType != null) {
      map['podcast_enclosure_type'] = Variable<String>(podcastEnclosureType);
    }
    if (!nullToAbsent || podcastDescription != null) {
      map['podcast_description'] = Variable<String>(podcastDescription);
    }
    if (!nullToAbsent || podcastImageUrl != null) {
      map['podcast_image_url'] = Variable<String>(podcastImageUrl);
    }
    if (!nullToAbsent || podcastLink != null) {
      map['podcast_link'] = Variable<String>(podcastLink);
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
      originalAudioSha256: originalAudioSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(originalAudioSha256),
      transcriptLanguage: transcriptLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptLanguage),
      audioContentStatus: audioContentStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(audioContentStatus),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      wordTimestampsJson: wordTimestampsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(wordTimestampsJson),
      transcriptSrt: transcriptSrt == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptSrt),
      syncStatus: Value(syncStatus),
      remoteAudioId: remoteAudioId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteAudioId),
      originalDate: originalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(originalDate),
      communityUnavailableAt: communityUnavailableAt == null && nullToAbsent
          ? const Value.absent()
          : Value(communityUnavailableAt),
      communityDifficulty: communityDifficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(communityDifficulty),
      importSourceType: importSourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(importSourceType),
      importSourceUrl: importSourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(importSourceUrl),
      podcastEpisodeGuid: podcastEpisodeGuid == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastEpisodeGuid),
      podcastEnclosureUrl: podcastEnclosureUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastEnclosureUrl),
      podcastEnclosureType: podcastEnclosureType == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastEnclosureType),
      podcastDescription: podcastDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastDescription),
      podcastImageUrl: podcastImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastImageUrl),
      podcastLink: podcastLink == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastLink),
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
      originalAudioSha256: serializer.fromJson<String?>(
        json['originalAudioSha256'],
      ),
      transcriptLanguage: serializer.fromJson<String?>(
        json['transcriptLanguage'],
      ),
      audioContentStatus: serializer.fromJson<int?>(json['audioContentStatus']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      wordTimestampsJson: serializer.fromJson<String?>(
        json['wordTimestampsJson'],
      ),
      transcriptSrt: serializer.fromJson<String?>(json['transcriptSrt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      remoteAudioId: serializer.fromJson<String?>(json['remoteAudioId']),
      originalDate: serializer.fromJson<DateTime?>(json['originalDate']),
      communityUnavailableAt: serializer.fromJson<DateTime?>(
        json['communityUnavailableAt'],
      ),
      communityDifficulty: serializer.fromJson<String?>(
        json['communityDifficulty'],
      ),
      importSourceType: serializer.fromJson<String?>(json['importSourceType']),
      importSourceUrl: serializer.fromJson<String?>(json['importSourceUrl']),
      podcastEpisodeGuid: serializer.fromJson<String?>(
        json['podcastEpisodeGuid'],
      ),
      podcastEnclosureUrl: serializer.fromJson<String?>(
        json['podcastEnclosureUrl'],
      ),
      podcastEnclosureType: serializer.fromJson<String?>(
        json['podcastEnclosureType'],
      ),
      podcastDescription: serializer.fromJson<String?>(
        json['podcastDescription'],
      ),
      podcastImageUrl: serializer.fromJson<String?>(json['podcastImageUrl']),
      podcastLink: serializer.fromJson<String?>(json['podcastLink']),
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
      'originalAudioSha256': serializer.toJson<String?>(originalAudioSha256),
      'transcriptLanguage': serializer.toJson<String?>(transcriptLanguage),
      'audioContentStatus': serializer.toJson<int?>(audioContentStatus),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'wordTimestampsJson': serializer.toJson<String?>(wordTimestampsJson),
      'transcriptSrt': serializer.toJson<String?>(transcriptSrt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'remoteAudioId': serializer.toJson<String?>(remoteAudioId),
      'originalDate': serializer.toJson<DateTime?>(originalDate),
      'communityUnavailableAt': serializer.toJson<DateTime?>(
        communityUnavailableAt,
      ),
      'communityDifficulty': serializer.toJson<String?>(communityDifficulty),
      'importSourceType': serializer.toJson<String?>(importSourceType),
      'importSourceUrl': serializer.toJson<String?>(importSourceUrl),
      'podcastEpisodeGuid': serializer.toJson<String?>(podcastEpisodeGuid),
      'podcastEnclosureUrl': serializer.toJson<String?>(podcastEnclosureUrl),
      'podcastEnclosureType': serializer.toJson<String?>(podcastEnclosureType),
      'podcastDescription': serializer.toJson<String?>(podcastDescription),
      'podcastImageUrl': serializer.toJson<String?>(podcastImageUrl),
      'podcastLink': serializer.toJson<String?>(podcastLink),
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
    Value<String?> originalAudioSha256 = const Value.absent(),
    Value<String?> transcriptLanguage = const Value.absent(),
    Value<int?> audioContentStatus = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> wordTimestampsJson = const Value.absent(),
    Value<String?> transcriptSrt = const Value.absent(),
    int? syncStatus,
    Value<String?> remoteAudioId = const Value.absent(),
    Value<DateTime?> originalDate = const Value.absent(),
    Value<DateTime?> communityUnavailableAt = const Value.absent(),
    Value<String?> communityDifficulty = const Value.absent(),
    Value<String?> importSourceType = const Value.absent(),
    Value<String?> importSourceUrl = const Value.absent(),
    Value<String?> podcastEpisodeGuid = const Value.absent(),
    Value<String?> podcastEnclosureUrl = const Value.absent(),
    Value<String?> podcastEnclosureType = const Value.absent(),
    Value<String?> podcastDescription = const Value.absent(),
    Value<String?> podcastImageUrl = const Value.absent(),
    Value<String?> podcastLink = const Value.absent(),
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
    originalAudioSha256: originalAudioSha256.present
        ? originalAudioSha256.value
        : this.originalAudioSha256,
    transcriptLanguage: transcriptLanguage.present
        ? transcriptLanguage.value
        : this.transcriptLanguage,
    audioContentStatus: audioContentStatus.present
        ? audioContentStatus.value
        : this.audioContentStatus,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    wordTimestampsJson: wordTimestampsJson.present
        ? wordTimestampsJson.value
        : this.wordTimestampsJson,
    transcriptSrt: transcriptSrt.present
        ? transcriptSrt.value
        : this.transcriptSrt,
    syncStatus: syncStatus ?? this.syncStatus,
    remoteAudioId: remoteAudioId.present
        ? remoteAudioId.value
        : this.remoteAudioId,
    originalDate: originalDate.present ? originalDate.value : this.originalDate,
    communityUnavailableAt: communityUnavailableAt.present
        ? communityUnavailableAt.value
        : this.communityUnavailableAt,
    communityDifficulty: communityDifficulty.present
        ? communityDifficulty.value
        : this.communityDifficulty,
    importSourceType: importSourceType.present
        ? importSourceType.value
        : this.importSourceType,
    importSourceUrl: importSourceUrl.present
        ? importSourceUrl.value
        : this.importSourceUrl,
    podcastEpisodeGuid: podcastEpisodeGuid.present
        ? podcastEpisodeGuid.value
        : this.podcastEpisodeGuid,
    podcastEnclosureUrl: podcastEnclosureUrl.present
        ? podcastEnclosureUrl.value
        : this.podcastEnclosureUrl,
    podcastEnclosureType: podcastEnclosureType.present
        ? podcastEnclosureType.value
        : this.podcastEnclosureType,
    podcastDescription: podcastDescription.present
        ? podcastDescription.value
        : this.podcastDescription,
    podcastImageUrl: podcastImageUrl.present
        ? podcastImageUrl.value
        : this.podcastImageUrl,
    podcastLink: podcastLink.present ? podcastLink.value : this.podcastLink,
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
      originalAudioSha256: data.originalAudioSha256.present
          ? data.originalAudioSha256.value
          : this.originalAudioSha256,
      transcriptLanguage: data.transcriptLanguage.present
          ? data.transcriptLanguage.value
          : this.transcriptLanguage,
      audioContentStatus: data.audioContentStatus.present
          ? data.audioContentStatus.value
          : this.audioContentStatus,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      wordTimestampsJson: data.wordTimestampsJson.present
          ? data.wordTimestampsJson.value
          : this.wordTimestampsJson,
      transcriptSrt: data.transcriptSrt.present
          ? data.transcriptSrt.value
          : this.transcriptSrt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      remoteAudioId: data.remoteAudioId.present
          ? data.remoteAudioId.value
          : this.remoteAudioId,
      originalDate: data.originalDate.present
          ? data.originalDate.value
          : this.originalDate,
      communityUnavailableAt: data.communityUnavailableAt.present
          ? data.communityUnavailableAt.value
          : this.communityUnavailableAt,
      communityDifficulty: data.communityDifficulty.present
          ? data.communityDifficulty.value
          : this.communityDifficulty,
      importSourceType: data.importSourceType.present
          ? data.importSourceType.value
          : this.importSourceType,
      importSourceUrl: data.importSourceUrl.present
          ? data.importSourceUrl.value
          : this.importSourceUrl,
      podcastEpisodeGuid: data.podcastEpisodeGuid.present
          ? data.podcastEpisodeGuid.value
          : this.podcastEpisodeGuid,
      podcastEnclosureUrl: data.podcastEnclosureUrl.present
          ? data.podcastEnclosureUrl.value
          : this.podcastEnclosureUrl,
      podcastEnclosureType: data.podcastEnclosureType.present
          ? data.podcastEnclosureType.value
          : this.podcastEnclosureType,
      podcastDescription: data.podcastDescription.present
          ? data.podcastDescription.value
          : this.podcastDescription,
      podcastImageUrl: data.podcastImageUrl.present
          ? data.podcastImageUrl.value
          : this.podcastImageUrl,
      podcastLink: data.podcastLink.present
          ? data.podcastLink.value
          : this.podcastLink,
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
          ..write('originalAudioSha256: $originalAudioSha256, ')
          ..write('transcriptLanguage: $transcriptLanguage, ')
          ..write('audioContentStatus: $audioContentStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('wordTimestampsJson: $wordTimestampsJson, ')
          ..write('transcriptSrt: $transcriptSrt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('remoteAudioId: $remoteAudioId, ')
          ..write('originalDate: $originalDate, ')
          ..write('communityUnavailableAt: $communityUnavailableAt, ')
          ..write('communityDifficulty: $communityDifficulty, ')
          ..write('importSourceType: $importSourceType, ')
          ..write('importSourceUrl: $importSourceUrl, ')
          ..write('podcastEpisodeGuid: $podcastEpisodeGuid, ')
          ..write('podcastEnclosureUrl: $podcastEnclosureUrl, ')
          ..write('podcastEnclosureType: $podcastEnclosureType, ')
          ..write('podcastDescription: $podcastDescription, ')
          ..write('podcastImageUrl: $podcastImageUrl, ')
          ..write('podcastLink: $podcastLink')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    originalAudioSha256,
    transcriptLanguage,
    audioContentStatus,
    updatedAt,
    deletedAt,
    wordTimestampsJson,
    transcriptSrt,
    syncStatus,
    remoteAudioId,
    originalDate,
    communityUnavailableAt,
    communityDifficulty,
    importSourceType,
    importSourceUrl,
    podcastEpisodeGuid,
    podcastEnclosureUrl,
    podcastEnclosureType,
    podcastDescription,
    podcastImageUrl,
    podcastLink,
  ]);
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
          other.originalAudioSha256 == this.originalAudioSha256 &&
          other.transcriptLanguage == this.transcriptLanguage &&
          other.audioContentStatus == this.audioContentStatus &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.wordTimestampsJson == this.wordTimestampsJson &&
          other.transcriptSrt == this.transcriptSrt &&
          other.syncStatus == this.syncStatus &&
          other.remoteAudioId == this.remoteAudioId &&
          other.originalDate == this.originalDate &&
          other.communityUnavailableAt == this.communityUnavailableAt &&
          other.communityDifficulty == this.communityDifficulty &&
          other.importSourceType == this.importSourceType &&
          other.importSourceUrl == this.importSourceUrl &&
          other.podcastEpisodeGuid == this.podcastEpisodeGuid &&
          other.podcastEnclosureUrl == this.podcastEnclosureUrl &&
          other.podcastEnclosureType == this.podcastEnclosureType &&
          other.podcastDescription == this.podcastDescription &&
          other.podcastImageUrl == this.podcastImageUrl &&
          other.podcastLink == this.podcastLink);
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
  final Value<String?> originalAudioSha256;
  final Value<String?> transcriptLanguage;
  final Value<int?> audioContentStatus;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> wordTimestampsJson;
  final Value<String?> transcriptSrt;
  final Value<int> syncStatus;
  final Value<String?> remoteAudioId;
  final Value<DateTime?> originalDate;
  final Value<DateTime?> communityUnavailableAt;
  final Value<String?> communityDifficulty;
  final Value<String?> importSourceType;
  final Value<String?> importSourceUrl;
  final Value<String?> podcastEpisodeGuid;
  final Value<String?> podcastEnclosureUrl;
  final Value<String?> podcastEnclosureType;
  final Value<String?> podcastDescription;
  final Value<String?> podcastImageUrl;
  final Value<String?> podcastLink;
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
    this.originalAudioSha256 = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.audioContentStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.wordTimestampsJson = const Value.absent(),
    this.transcriptSrt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.remoteAudioId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.communityUnavailableAt = const Value.absent(),
    this.communityDifficulty = const Value.absent(),
    this.importSourceType = const Value.absent(),
    this.importSourceUrl = const Value.absent(),
    this.podcastEpisodeGuid = const Value.absent(),
    this.podcastEnclosureUrl = const Value.absent(),
    this.podcastEnclosureType = const Value.absent(),
    this.podcastDescription = const Value.absent(),
    this.podcastImageUrl = const Value.absent(),
    this.podcastLink = const Value.absent(),
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
    this.originalAudioSha256 = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.audioContentStatus = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.wordTimestampsJson = const Value.absent(),
    this.transcriptSrt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.remoteAudioId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.communityUnavailableAt = const Value.absent(),
    this.communityDifficulty = const Value.absent(),
    this.importSourceType = const Value.absent(),
    this.importSourceUrl = const Value.absent(),
    this.podcastEpisodeGuid = const Value.absent(),
    this.podcastEnclosureUrl = const Value.absent(),
    this.podcastEnclosureType = const Value.absent(),
    this.podcastDescription = const Value.absent(),
    this.podcastImageUrl = const Value.absent(),
    this.podcastLink = const Value.absent(),
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
    Expression<String>? originalAudioSha256,
    Expression<String>? transcriptLanguage,
    Expression<int>? audioContentStatus,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? wordTimestampsJson,
    Expression<String>? transcriptSrt,
    Expression<int>? syncStatus,
    Expression<String>? remoteAudioId,
    Expression<DateTime>? originalDate,
    Expression<DateTime>? communityUnavailableAt,
    Expression<String>? communityDifficulty,
    Expression<String>? importSourceType,
    Expression<String>? importSourceUrl,
    Expression<String>? podcastEpisodeGuid,
    Expression<String>? podcastEnclosureUrl,
    Expression<String>? podcastEnclosureType,
    Expression<String>? podcastDescription,
    Expression<String>? podcastImageUrl,
    Expression<String>? podcastLink,
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
      if (originalAudioSha256 != null)
        'original_audio_sha256': originalAudioSha256,
      if (transcriptLanguage != null) 'transcript_language': transcriptLanguage,
      if (audioContentStatus != null)
        'audio_content_status': audioContentStatus,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (wordTimestampsJson != null)
        'word_timestamps_json': wordTimestampsJson,
      if (transcriptSrt != null) 'transcript_srt': transcriptSrt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (remoteAudioId != null) 'remote_audio_id': remoteAudioId,
      if (originalDate != null) 'original_date': originalDate,
      if (communityUnavailableAt != null)
        'community_unavailable_at': communityUnavailableAt,
      if (communityDifficulty != null)
        'community_difficulty': communityDifficulty,
      if (importSourceType != null) 'import_source_type': importSourceType,
      if (importSourceUrl != null) 'import_source_url': importSourceUrl,
      if (podcastEpisodeGuid != null)
        'podcast_episode_guid': podcastEpisodeGuid,
      if (podcastEnclosureUrl != null)
        'podcast_enclosure_url': podcastEnclosureUrl,
      if (podcastEnclosureType != null)
        'podcast_enclosure_type': podcastEnclosureType,
      if (podcastDescription != null) 'podcast_description': podcastDescription,
      if (podcastImageUrl != null) 'podcast_image_url': podcastImageUrl,
      if (podcastLink != null) 'podcast_link': podcastLink,
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
    Value<String?>? originalAudioSha256,
    Value<String?>? transcriptLanguage,
    Value<int?>? audioContentStatus,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String?>? wordTimestampsJson,
    Value<String?>? transcriptSrt,
    Value<int>? syncStatus,
    Value<String?>? remoteAudioId,
    Value<DateTime?>? originalDate,
    Value<DateTime?>? communityUnavailableAt,
    Value<String?>? communityDifficulty,
    Value<String?>? importSourceType,
    Value<String?>? importSourceUrl,
    Value<String?>? podcastEpisodeGuid,
    Value<String?>? podcastEnclosureUrl,
    Value<String?>? podcastEnclosureType,
    Value<String?>? podcastDescription,
    Value<String?>? podcastImageUrl,
    Value<String?>? podcastLink,
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
      originalAudioSha256: originalAudioSha256 ?? this.originalAudioSha256,
      transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
      audioContentStatus: audioContentStatus ?? this.audioContentStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      wordTimestampsJson: wordTimestampsJson ?? this.wordTimestampsJson,
      transcriptSrt: transcriptSrt ?? this.transcriptSrt,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteAudioId: remoteAudioId ?? this.remoteAudioId,
      originalDate: originalDate ?? this.originalDate,
      communityUnavailableAt:
          communityUnavailableAt ?? this.communityUnavailableAt,
      communityDifficulty: communityDifficulty ?? this.communityDifficulty,
      importSourceType: importSourceType ?? this.importSourceType,
      importSourceUrl: importSourceUrl ?? this.importSourceUrl,
      podcastEpisodeGuid: podcastEpisodeGuid ?? this.podcastEpisodeGuid,
      podcastEnclosureUrl: podcastEnclosureUrl ?? this.podcastEnclosureUrl,
      podcastEnclosureType: podcastEnclosureType ?? this.podcastEnclosureType,
      podcastDescription: podcastDescription ?? this.podcastDescription,
      podcastImageUrl: podcastImageUrl ?? this.podcastImageUrl,
      podcastLink: podcastLink ?? this.podcastLink,
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
    if (originalAudioSha256.present) {
      map['original_audio_sha256'] = Variable<String>(
        originalAudioSha256.value,
      );
    }
    if (transcriptLanguage.present) {
      map['transcript_language'] = Variable<String>(transcriptLanguage.value);
    }
    if (audioContentStatus.present) {
      map['audio_content_status'] = Variable<int>(audioContentStatus.value);
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
    if (transcriptSrt.present) {
      map['transcript_srt'] = Variable<String>(transcriptSrt.value);
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
    if (communityUnavailableAt.present) {
      map['community_unavailable_at'] = Variable<DateTime>(
        communityUnavailableAt.value,
      );
    }
    if (communityDifficulty.present) {
      map['community_difficulty'] = Variable<String>(communityDifficulty.value);
    }
    if (importSourceType.present) {
      map['import_source_type'] = Variable<String>(importSourceType.value);
    }
    if (importSourceUrl.present) {
      map['import_source_url'] = Variable<String>(importSourceUrl.value);
    }
    if (podcastEpisodeGuid.present) {
      map['podcast_episode_guid'] = Variable<String>(podcastEpisodeGuid.value);
    }
    if (podcastEnclosureUrl.present) {
      map['podcast_enclosure_url'] = Variable<String>(
        podcastEnclosureUrl.value,
      );
    }
    if (podcastEnclosureType.present) {
      map['podcast_enclosure_type'] = Variable<String>(
        podcastEnclosureType.value,
      );
    }
    if (podcastDescription.present) {
      map['podcast_description'] = Variable<String>(podcastDescription.value);
    }
    if (podcastImageUrl.present) {
      map['podcast_image_url'] = Variable<String>(podcastImageUrl.value);
    }
    if (podcastLink.present) {
      map['podcast_link'] = Variable<String>(podcastLink.value);
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
          ..write('originalAudioSha256: $originalAudioSha256, ')
          ..write('transcriptLanguage: $transcriptLanguage, ')
          ..write('audioContentStatus: $audioContentStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('wordTimestampsJson: $wordTimestampsJson, ')
          ..write('transcriptSrt: $transcriptSrt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('remoteAudioId: $remoteAudioId, ')
          ..write('originalDate: $originalDate, ')
          ..write('communityUnavailableAt: $communityUnavailableAt, ')
          ..write('communityDifficulty: $communityDifficulty, ')
          ..write('importSourceType: $importSourceType, ')
          ..write('importSourceUrl: $importSourceUrl, ')
          ..write('podcastEpisodeGuid: $podcastEpisodeGuid, ')
          ..write('podcastEnclosureUrl: $podcastEnclosureUrl, ')
          ..write('podcastEnclosureType: $podcastEnclosureType, ')
          ..write('podcastDescription: $podcastDescription, ')
          ..write('podcastImageUrl: $podcastImageUrl, ')
          ..write('podcastLink: $podcastLink, ')
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
  static const VerificationMeta _coverUrlChinaMeta = const VerificationMeta(
    'coverUrlChina',
  );
  @override
  late final GeneratedColumn<String> coverUrlChina = GeneratedColumn<String>(
    'cover_url_china',
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
  static const VerificationMeta _authorNicknameMeta = const VerificationMeta(
    'authorNickname',
  );
  @override
  late final GeneratedColumn<String> authorNickname = GeneratedColumn<String>(
    'author_nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _podcastInputUrlMeta = const VerificationMeta(
    'podcastInputUrl',
  );
  @override
  late final GeneratedColumn<String> podcastInputUrl = GeneratedColumn<String>(
    'podcast_input_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _podcastFeedUrlMeta = const VerificationMeta(
    'podcastFeedUrl',
  );
  @override
  late final GeneratedColumn<String> podcastFeedUrl = GeneratedColumn<String>(
    'podcast_feed_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _podcastMetaJsonMeta = const VerificationMeta(
    'podcastMetaJson',
  );
  @override
  late final GeneratedColumn<String> podcastMetaJson = GeneratedColumn<String>(
    'podcast_meta_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _podcastLastRefreshedAtMeta =
      const VerificationMeta('podcastLastRefreshedAt');
  @override
  late final GeneratedColumn<DateTime> podcastLastRefreshedAt =
      GeneratedColumn<DateTime>(
        'podcast_last_refreshed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _podcastLastRefreshErrorMeta =
      const VerificationMeta('podcastLastRefreshError');
  @override
  late final GeneratedColumn<String> podcastLastRefreshError =
      GeneratedColumn<String>(
        'podcast_last_refresh_error',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
    coverUrlChina,
    description,
    authorNickname,
    publishedAt,
    deprecatedAt,
    podcastInputUrl,
    podcastFeedUrl,
    podcastMetaJson,
    podcastLastRefreshedAt,
    podcastLastRefreshError,
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
    if (data.containsKey('cover_url_china')) {
      context.handle(
        _coverUrlChinaMeta,
        coverUrlChina.isAcceptableOrUnknown(
          data['cover_url_china']!,
          _coverUrlChinaMeta,
        ),
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
    if (data.containsKey('author_nickname')) {
      context.handle(
        _authorNicknameMeta,
        authorNickname.isAcceptableOrUnknown(
          data['author_nickname']!,
          _authorNicknameMeta,
        ),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
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
    if (data.containsKey('podcast_input_url')) {
      context.handle(
        _podcastInputUrlMeta,
        podcastInputUrl.isAcceptableOrUnknown(
          data['podcast_input_url']!,
          _podcastInputUrlMeta,
        ),
      );
    }
    if (data.containsKey('podcast_feed_url')) {
      context.handle(
        _podcastFeedUrlMeta,
        podcastFeedUrl.isAcceptableOrUnknown(
          data['podcast_feed_url']!,
          _podcastFeedUrlMeta,
        ),
      );
    }
    if (data.containsKey('podcast_meta_json')) {
      context.handle(
        _podcastMetaJsonMeta,
        podcastMetaJson.isAcceptableOrUnknown(
          data['podcast_meta_json']!,
          _podcastMetaJsonMeta,
        ),
      );
    }
    if (data.containsKey('podcast_last_refreshed_at')) {
      context.handle(
        _podcastLastRefreshedAtMeta,
        podcastLastRefreshedAt.isAcceptableOrUnknown(
          data['podcast_last_refreshed_at']!,
          _podcastLastRefreshedAtMeta,
        ),
      );
    }
    if (data.containsKey('podcast_last_refresh_error')) {
      context.handle(
        _podcastLastRefreshErrorMeta,
        podcastLastRefreshError.isAcceptableOrUnknown(
          data['podcast_last_refresh_error']!,
          _podcastLastRefreshErrorMeta,
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
      coverUrlChina: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url_china'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      authorNickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_nickname'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      deprecatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deprecated_at'],
      ),
      podcastInputUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_input_url'],
      ),
      podcastFeedUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_feed_url'],
      ),
      podcastMetaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_meta_json'],
      ),
      podcastLastRefreshedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}podcast_last_refreshed_at'],
      ),
      podcastLastRefreshError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}podcast_last_refresh_error'],
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

  /// 合集来源：`local`（用户自建）| `community`（从后端加入的社区合集）
  ///
  /// 老数据默认 `local`。不可变 —— 决定了 UI 是否显示社区 badge、
  /// 长按菜单是否允许重命名/删除音频、移除流程是否彻底清空等。
  final String source;

  /// 社区合集在后端的 UUID；仅 source='community' 时有值。
  /// 与 [source]=community 联合唯一。
  final String? remoteId;

  /// 社区合集封面图 URL；用户自建合集目前为 null。
  final String? coverUrl;

  /// 已同步到中国 CDN 的社区合集封面图 URL。
  final String? coverUrlChina;

  /// 社区合集描述；用户自建合集目前为 null。
  final String? description;

  /// 社区合集发布者昵称；老数据及匿名发布者保持 null。
  final String? authorNickname;

  /// 社区合集发布日期；老数据保持 null。
  final DateTime? publishedAt;

  /// 社区合集被后端标记下架的时间；非 null 时 UI 置灰、sync 不再请求。
  /// source='local' 永远为 null。
  final DateTime? deprecatedAt;

  /// 用户输入的原始 URL（Apple Podcasts 链接或直接 RSS 链接）
  final String? podcastInputUrl;

  /// 解析后的 RSS Feed URL（Apple 链接经 iTunes lookup 后得到；直接 RSS 直通）
  final String? podcastFeedUrl;

  /// Feed 元信息 JSON（title / author / imageUrl / description 等）
  final String? podcastMetaJson;

  /// 最后一次刷新时间；成功/失败都会更新，用于节流和 UI 展示
  final DateTime? podcastLastRefreshedAt;

  /// 最后一次刷新错误；成功刷新后清空
  final String? podcastLastRefreshError;
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
    this.coverUrlChina,
    this.description,
    this.authorNickname,
    this.publishedAt,
    this.deprecatedAt,
    this.podcastInputUrl,
    this.podcastFeedUrl,
    this.podcastMetaJson,
    this.podcastLastRefreshedAt,
    this.podcastLastRefreshError,
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
    if (!nullToAbsent || coverUrlChina != null) {
      map['cover_url_china'] = Variable<String>(coverUrlChina);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || authorNickname != null) {
      map['author_nickname'] = Variable<String>(authorNickname);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || deprecatedAt != null) {
      map['deprecated_at'] = Variable<DateTime>(deprecatedAt);
    }
    if (!nullToAbsent || podcastInputUrl != null) {
      map['podcast_input_url'] = Variable<String>(podcastInputUrl);
    }
    if (!nullToAbsent || podcastFeedUrl != null) {
      map['podcast_feed_url'] = Variable<String>(podcastFeedUrl);
    }
    if (!nullToAbsent || podcastMetaJson != null) {
      map['podcast_meta_json'] = Variable<String>(podcastMetaJson);
    }
    if (!nullToAbsent || podcastLastRefreshedAt != null) {
      map['podcast_last_refreshed_at'] = Variable<DateTime>(
        podcastLastRefreshedAt,
      );
    }
    if (!nullToAbsent || podcastLastRefreshError != null) {
      map['podcast_last_refresh_error'] = Variable<String>(
        podcastLastRefreshError,
      );
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
      coverUrlChina: coverUrlChina == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrlChina),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      authorNickname: authorNickname == null && nullToAbsent
          ? const Value.absent()
          : Value(authorNickname),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      deprecatedAt: deprecatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deprecatedAt),
      podcastInputUrl: podcastInputUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastInputUrl),
      podcastFeedUrl: podcastFeedUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastFeedUrl),
      podcastMetaJson: podcastMetaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastMetaJson),
      podcastLastRefreshedAt: podcastLastRefreshedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastLastRefreshedAt),
      podcastLastRefreshError: podcastLastRefreshError == null && nullToAbsent
          ? const Value.absent()
          : Value(podcastLastRefreshError),
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
      coverUrlChina: serializer.fromJson<String?>(json['coverUrlChina']),
      description: serializer.fromJson<String?>(json['description']),
      authorNickname: serializer.fromJson<String?>(json['authorNickname']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      deprecatedAt: serializer.fromJson<DateTime?>(json['deprecatedAt']),
      podcastInputUrl: serializer.fromJson<String?>(json['podcastInputUrl']),
      podcastFeedUrl: serializer.fromJson<String?>(json['podcastFeedUrl']),
      podcastMetaJson: serializer.fromJson<String?>(json['podcastMetaJson']),
      podcastLastRefreshedAt: serializer.fromJson<DateTime?>(
        json['podcastLastRefreshedAt'],
      ),
      podcastLastRefreshError: serializer.fromJson<String?>(
        json['podcastLastRefreshError'],
      ),
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
      'coverUrlChina': serializer.toJson<String?>(coverUrlChina),
      'description': serializer.toJson<String?>(description),
      'authorNickname': serializer.toJson<String?>(authorNickname),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'deprecatedAt': serializer.toJson<DateTime?>(deprecatedAt),
      'podcastInputUrl': serializer.toJson<String?>(podcastInputUrl),
      'podcastFeedUrl': serializer.toJson<String?>(podcastFeedUrl),
      'podcastMetaJson': serializer.toJson<String?>(podcastMetaJson),
      'podcastLastRefreshedAt': serializer.toJson<DateTime?>(
        podcastLastRefreshedAt,
      ),
      'podcastLastRefreshError': serializer.toJson<String?>(
        podcastLastRefreshError,
      ),
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
    Value<String?> coverUrlChina = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> authorNickname = const Value.absent(),
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<DateTime?> deprecatedAt = const Value.absent(),
    Value<String?> podcastInputUrl = const Value.absent(),
    Value<String?> podcastFeedUrl = const Value.absent(),
    Value<String?> podcastMetaJson = const Value.absent(),
    Value<DateTime?> podcastLastRefreshedAt = const Value.absent(),
    Value<String?> podcastLastRefreshError = const Value.absent(),
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
    coverUrlChina: coverUrlChina.present
        ? coverUrlChina.value
        : this.coverUrlChina,
    description: description.present ? description.value : this.description,
    authorNickname: authorNickname.present
        ? authorNickname.value
        : this.authorNickname,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    deprecatedAt: deprecatedAt.present ? deprecatedAt.value : this.deprecatedAt,
    podcastInputUrl: podcastInputUrl.present
        ? podcastInputUrl.value
        : this.podcastInputUrl,
    podcastFeedUrl: podcastFeedUrl.present
        ? podcastFeedUrl.value
        : this.podcastFeedUrl,
    podcastMetaJson: podcastMetaJson.present
        ? podcastMetaJson.value
        : this.podcastMetaJson,
    podcastLastRefreshedAt: podcastLastRefreshedAt.present
        ? podcastLastRefreshedAt.value
        : this.podcastLastRefreshedAt,
    podcastLastRefreshError: podcastLastRefreshError.present
        ? podcastLastRefreshError.value
        : this.podcastLastRefreshError,
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
      coverUrlChina: data.coverUrlChina.present
          ? data.coverUrlChina.value
          : this.coverUrlChina,
      description: data.description.present
          ? data.description.value
          : this.description,
      authorNickname: data.authorNickname.present
          ? data.authorNickname.value
          : this.authorNickname,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      deprecatedAt: data.deprecatedAt.present
          ? data.deprecatedAt.value
          : this.deprecatedAt,
      podcastInputUrl: data.podcastInputUrl.present
          ? data.podcastInputUrl.value
          : this.podcastInputUrl,
      podcastFeedUrl: data.podcastFeedUrl.present
          ? data.podcastFeedUrl.value
          : this.podcastFeedUrl,
      podcastMetaJson: data.podcastMetaJson.present
          ? data.podcastMetaJson.value
          : this.podcastMetaJson,
      podcastLastRefreshedAt: data.podcastLastRefreshedAt.present
          ? data.podcastLastRefreshedAt.value
          : this.podcastLastRefreshedAt,
      podcastLastRefreshError: data.podcastLastRefreshError.present
          ? data.podcastLastRefreshError.value
          : this.podcastLastRefreshError,
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
          ..write('coverUrlChina: $coverUrlChina, ')
          ..write('description: $description, ')
          ..write('authorNickname: $authorNickname, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('deprecatedAt: $deprecatedAt, ')
          ..write('podcastInputUrl: $podcastInputUrl, ')
          ..write('podcastFeedUrl: $podcastFeedUrl, ')
          ..write('podcastMetaJson: $podcastMetaJson, ')
          ..write('podcastLastRefreshedAt: $podcastLastRefreshedAt, ')
          ..write('podcastLastRefreshError: $podcastLastRefreshError')
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
    coverUrlChina,
    description,
    authorNickname,
    publishedAt,
    deprecatedAt,
    podcastInputUrl,
    podcastFeedUrl,
    podcastMetaJson,
    podcastLastRefreshedAt,
    podcastLastRefreshError,
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
          other.coverUrlChina == this.coverUrlChina &&
          other.description == this.description &&
          other.authorNickname == this.authorNickname &&
          other.publishedAt == this.publishedAt &&
          other.deprecatedAt == this.deprecatedAt &&
          other.podcastInputUrl == this.podcastInputUrl &&
          other.podcastFeedUrl == this.podcastFeedUrl &&
          other.podcastMetaJson == this.podcastMetaJson &&
          other.podcastLastRefreshedAt == this.podcastLastRefreshedAt &&
          other.podcastLastRefreshError == this.podcastLastRefreshError);
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
  final Value<String?> coverUrlChina;
  final Value<String?> description;
  final Value<String?> authorNickname;
  final Value<DateTime?> publishedAt;
  final Value<DateTime?> deprecatedAt;
  final Value<String?> podcastInputUrl;
  final Value<String?> podcastFeedUrl;
  final Value<String?> podcastMetaJson;
  final Value<DateTime?> podcastLastRefreshedAt;
  final Value<String?> podcastLastRefreshError;
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
    this.coverUrlChina = const Value.absent(),
    this.description = const Value.absent(),
    this.authorNickname = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.deprecatedAt = const Value.absent(),
    this.podcastInputUrl = const Value.absent(),
    this.podcastFeedUrl = const Value.absent(),
    this.podcastMetaJson = const Value.absent(),
    this.podcastLastRefreshedAt = const Value.absent(),
    this.podcastLastRefreshError = const Value.absent(),
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
    this.coverUrlChina = const Value.absent(),
    this.description = const Value.absent(),
    this.authorNickname = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.deprecatedAt = const Value.absent(),
    this.podcastInputUrl = const Value.absent(),
    this.podcastFeedUrl = const Value.absent(),
    this.podcastMetaJson = const Value.absent(),
    this.podcastLastRefreshedAt = const Value.absent(),
    this.podcastLastRefreshError = const Value.absent(),
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
    Expression<String>? coverUrlChina,
    Expression<String>? description,
    Expression<String>? authorNickname,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? deprecatedAt,
    Expression<String>? podcastInputUrl,
    Expression<String>? podcastFeedUrl,
    Expression<String>? podcastMetaJson,
    Expression<DateTime>? podcastLastRefreshedAt,
    Expression<String>? podcastLastRefreshError,
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
      if (coverUrlChina != null) 'cover_url_china': coverUrlChina,
      if (description != null) 'description': description,
      if (authorNickname != null) 'author_nickname': authorNickname,
      if (publishedAt != null) 'published_at': publishedAt,
      if (deprecatedAt != null) 'deprecated_at': deprecatedAt,
      if (podcastInputUrl != null) 'podcast_input_url': podcastInputUrl,
      if (podcastFeedUrl != null) 'podcast_feed_url': podcastFeedUrl,
      if (podcastMetaJson != null) 'podcast_meta_json': podcastMetaJson,
      if (podcastLastRefreshedAt != null)
        'podcast_last_refreshed_at': podcastLastRefreshedAt,
      if (podcastLastRefreshError != null)
        'podcast_last_refresh_error': podcastLastRefreshError,
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
    Value<String?>? coverUrlChina,
    Value<String?>? description,
    Value<String?>? authorNickname,
    Value<DateTime?>? publishedAt,
    Value<DateTime?>? deprecatedAt,
    Value<String?>? podcastInputUrl,
    Value<String?>? podcastFeedUrl,
    Value<String?>? podcastMetaJson,
    Value<DateTime?>? podcastLastRefreshedAt,
    Value<String?>? podcastLastRefreshError,
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
      coverUrlChina: coverUrlChina ?? this.coverUrlChina,
      description: description ?? this.description,
      authorNickname: authorNickname ?? this.authorNickname,
      publishedAt: publishedAt ?? this.publishedAt,
      deprecatedAt: deprecatedAt ?? this.deprecatedAt,
      podcastInputUrl: podcastInputUrl ?? this.podcastInputUrl,
      podcastFeedUrl: podcastFeedUrl ?? this.podcastFeedUrl,
      podcastMetaJson: podcastMetaJson ?? this.podcastMetaJson,
      podcastLastRefreshedAt:
          podcastLastRefreshedAt ?? this.podcastLastRefreshedAt,
      podcastLastRefreshError:
          podcastLastRefreshError ?? this.podcastLastRefreshError,
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
    if (coverUrlChina.present) {
      map['cover_url_china'] = Variable<String>(coverUrlChina.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (authorNickname.present) {
      map['author_nickname'] = Variable<String>(authorNickname.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (deprecatedAt.present) {
      map['deprecated_at'] = Variable<DateTime>(deprecatedAt.value);
    }
    if (podcastInputUrl.present) {
      map['podcast_input_url'] = Variable<String>(podcastInputUrl.value);
    }
    if (podcastFeedUrl.present) {
      map['podcast_feed_url'] = Variable<String>(podcastFeedUrl.value);
    }
    if (podcastMetaJson.present) {
      map['podcast_meta_json'] = Variable<String>(podcastMetaJson.value);
    }
    if (podcastLastRefreshedAt.present) {
      map['podcast_last_refreshed_at'] = Variable<DateTime>(
        podcastLastRefreshedAt.value,
      );
    }
    if (podcastLastRefreshError.present) {
      map['podcast_last_refresh_error'] = Variable<String>(
        podcastLastRefreshError.value,
      );
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
          ..write('coverUrlChina: $coverUrlChina, ')
          ..write('description: $description, ')
          ..write('authorNickname: $authorNickname, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('deprecatedAt: $deprecatedAt, ')
          ..write('podcastInputUrl: $podcastInputUrl, ')
          ..write('podcastFeedUrl: $podcastFeedUrl, ')
          ..write('podcastMetaJson: $podcastMetaJson, ')
          ..write('podcastLastRefreshedAt: $podcastLastRefreshedAt, ')
          ..write('podcastLastRefreshError: $podcastLastRefreshError, ')
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
  static const VerificationMeta _memorySubjectIdMeta = const VerificationMeta(
    'memorySubjectId',
  );
  @override
  late final GeneratedColumn<String> memorySubjectId = GeneratedColumn<String>(
    'memory_subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    memorySubjectId,
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
    if (data.containsKey('memory_subject_id')) {
      context.handle(
        _memorySubjectIdMeta,
        memorySubjectId.isAcceptableOrUnknown(
          data['memory_subject_id']!,
          _memorySubjectIdMeta,
        ),
      );
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
      memorySubjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_subject_id'],
      ),
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

  /// 跨数据库迁移和字幕重解析仍保持稳定的记忆主体 ID。
  final String? memorySubjectId;

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
    this.memorySubjectId,
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
    if (!nullToAbsent || memorySubjectId != null) {
      map['memory_subject_id'] = Variable<String>(memorySubjectId);
    }
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
      memorySubjectId: memorySubjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(memorySubjectId),
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
      memorySubjectId: serializer.fromJson<String?>(json['memorySubjectId']),
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
      'memorySubjectId': serializer.toJson<String?>(memorySubjectId),
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
    Value<String?> memorySubjectId = const Value.absent(),
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
    memorySubjectId: memorySubjectId.present
        ? memorySubjectId.value
        : this.memorySubjectId,
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
      memorySubjectId: data.memorySubjectId.present
          ? data.memorySubjectId.value
          : this.memorySubjectId,
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
          ..write('memorySubjectId: $memorySubjectId, ')
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
    memorySubjectId,
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
          other.memorySubjectId == this.memorySubjectId &&
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
  final Value<String?> memorySubjectId;
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
    this.memorySubjectId = const Value.absent(),
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
    this.memorySubjectId = const Value.absent(),
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
    Expression<String>? memorySubjectId,
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
      if (memorySubjectId != null) 'memory_subject_id': memorySubjectId,
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
    Value<String?>? memorySubjectId,
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
      memorySubjectId: memorySubjectId ?? this.memorySubjectId,
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
    if (memorySubjectId.present) {
      map['memory_subject_id'] = Variable<String>(memorySubjectId.value);
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
          ..write('memorySubjectId: $memorySubjectId, ')
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
  static const VerificationMeta _retellSentenceIndexMeta =
      const VerificationMeta('retellSentenceIndex');
  @override
  late final GeneratedColumn<int> retellSentenceIndex = GeneratedColumn<int>(
    'retell_sentence_index',
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
  static const VerificationMeta _blindListenSentenceIndexMeta =
      const VerificationMeta('blindListenSentenceIndex');
  @override
  late final GeneratedColumn<int> blindListenSentenceIndex =
      GeneratedColumn<int>(
        'blind_listen_sentence_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freePlayBlindListenSentenceIndexMeta =
      const VerificationMeta('freePlayBlindListenSentenceIndex');
  @override
  late final GeneratedColumn<int> freePlayBlindListenSentenceIndex =
      GeneratedColumn<int>(
        'free_play_blind_listen_sentence_index',
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
  static const VerificationMeta _freePlayRetellSentenceIndexMeta =
      const VerificationMeta('freePlayRetellSentenceIndex');
  @override
  late final GeneratedColumn<int> freePlayRetellSentenceIndex =
      GeneratedColumn<int>(
        'free_play_retell_sentence_index',
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
  static const VerificationMeta _isPausedMeta = const VerificationMeta(
    'isPaused',
  );
  @override
  late final GeneratedColumn<bool> isPaused = GeneratedColumn<bool>(
    'is_paused',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_paused" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _manualUnlockAtMeta = const VerificationMeta(
    'manualUnlockAt',
  );
  @override
  late final GeneratedColumn<DateTime> manualUnlockAt =
      GeneratedColumn<DateTime>(
        'manual_unlock_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _planVersionsJsonMeta = const VerificationMeta(
    'planVersionsJson',
  );
  @override
  late final GeneratedColumn<String> planVersionsJson = GeneratedColumn<String>(
    'plan_versions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
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
    retellSentenceIndex,
    retellPassCount,
    blindListenSentenceIndex,
    freePlayBlindListenSentenceIndex,
    freePlayIntensiveListenSentenceIndex,
    freePlayShadowingSentenceIndex,
    freePlayDifficultPracticeSentenceIndex,
    freePlayRetellSentenceIndex,
    newLearningBreakpointSavedAt,
    freePlayBreakpointSavedAt,
    updatedAt,
    skippedSubStages,
    isPaused,
    manualUnlockAt,
    planVersionsJson,
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
    if (data.containsKey('retell_sentence_index')) {
      context.handle(
        _retellSentenceIndexMeta,
        retellSentenceIndex.isAcceptableOrUnknown(
          data['retell_sentence_index']!,
          _retellSentenceIndexMeta,
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
    if (data.containsKey('blind_listen_sentence_index')) {
      context.handle(
        _blindListenSentenceIndexMeta,
        blindListenSentenceIndex.isAcceptableOrUnknown(
          data['blind_listen_sentence_index']!,
          _blindListenSentenceIndexMeta,
        ),
      );
    }
    if (data.containsKey('free_play_blind_listen_sentence_index')) {
      context.handle(
        _freePlayBlindListenSentenceIndexMeta,
        freePlayBlindListenSentenceIndex.isAcceptableOrUnknown(
          data['free_play_blind_listen_sentence_index']!,
          _freePlayBlindListenSentenceIndexMeta,
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
    if (data.containsKey('free_play_retell_sentence_index')) {
      context.handle(
        _freePlayRetellSentenceIndexMeta,
        freePlayRetellSentenceIndex.isAcceptableOrUnknown(
          data['free_play_retell_sentence_index']!,
          _freePlayRetellSentenceIndexMeta,
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
    if (data.containsKey('is_paused')) {
      context.handle(
        _isPausedMeta,
        isPaused.isAcceptableOrUnknown(data['is_paused']!, _isPausedMeta),
      );
    }
    if (data.containsKey('manual_unlock_at')) {
      context.handle(
        _manualUnlockAtMeta,
        manualUnlockAt.isAcceptableOrUnknown(
          data['manual_unlock_at']!,
          _manualUnlockAtMeta,
        ),
      );
    }
    if (data.containsKey('plan_versions_json')) {
      context.handle(
        _planVersionsJsonMeta,
        planVersionsJson.isAcceptableOrUnknown(
          data['plan_versions_json']!,
          _planVersionsJsonMeta,
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
      retellSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retell_sentence_index'],
      ),
      retellPassCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retell_pass_count'],
      ),
      blindListenSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blind_listen_sentence_index'],
      ),
      freePlayBlindListenSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_play_blind_listen_sentence_index'],
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
      freePlayRetellSentenceIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}free_play_retell_sentence_index'],
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
      isPaused: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_paused'],
      )!,
      manualUnlockAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}manual_unlock_at'],
      ),
      planVersionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_versions_json'],
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

  /// 难度等级（5 档：0=veryEasy, 1=easy, 2=medium, 3=hard, 4=veryHard）
  ///
  /// DB 列 default 为历史值 1；新建 LearningProgress 行的代码层（ensureProgress）
  /// 会显式写入 2 (medium)，所以该 default 实际不会生效，但出于谨慎不在此处变更，
  /// 避免触发 drift schema 重新校验。
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

  /// 复述断点续学句子索引（全局句子 index，null 表示从头开始）
  ///
  /// 段内位置：恢复时按句子 index 反查段，并在段时长 > 10s 时段内从该句开播。
  final int? retellSentenceIndex;

  /// 复述总完成遍数（每次完成复述 +1）
  final int? retellPassCount;

  /// 盲听断点续学句子索引（全局句子 index，null 表示从头开始）
  ///
  /// 段内位置：恢复时按句子 index 反查段，并在段时长 > 10s 时段内从该句开播。
  final int? blindListenSentenceIndex;

  /// 自由练习-盲听断点句子索引（全局句子 index）
  final int? freePlayBlindListenSentenceIndex;

  /// 自由练习-精听断点句子索引
  final int? freePlayIntensiveListenSentenceIndex;

  /// 自由练习-跟读断点句子索引
  final int? freePlayShadowingSentenceIndex;

  /// 自由练习-难句补练断点句子索引
  final int? freePlayDifficultPracticeSentenceIndex;

  /// 自由练习-复述断点句子索引（全局句子 index）
  final int? freePlayRetellSentenceIndex;

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

  /// 是否暂停学习（true 表示该音频不参与复习调度，可由用户随时恢复）
  final bool isPaused;

  /// 手动解锁当前复习轮的时刻（null = 未手动解锁）
  ///
  /// 用户点击「立即解锁」时写入，使当前复习轮跳过时间锁提前可学。
  /// 不篡改 [lastStageCompletedAt]，后续轮次仍按实际完成时间顺延。
  /// 跨 stage 推进时必须清除。
  final DateTime? manualUnlockAt;

  /// 每个 [LearningStage] 的 plan 版本快照（dense map，JSON 存储）。
  ///
  /// 格式：JSON object，key = `LearningStage.key`，value = 整数版本号。例：
  /// `{"firstLearn":1,"review0":2,"review1":2,...,"review28":2}`
  ///
  /// **不包含 `completed`**：completed 是毕业终态标记、无 plan，不参与版本系统。
  ///
  /// **写入规则**：snapshot-per-entity 模式。仅在创建 progress / 迁移时
  /// 由系统 stamp。日常用户操作（完成 / 跳过 substep、暂停等）**都不修改**
  /// 此字段。区别于 `stage_completions`（持续累加）。
  /// 如未来需要让存量 audio 升级到新版，需写显式迁移修改本字段。
  ///
  /// 写入时机：
  /// - 新建 progress：stamp `kLatestPlanVersions`
  /// - v33→v34 迁移：每条 audio baseline 全 v1 + 按 stage 是否有 completion 判定：
  ///   该 stage 在 `stage_completions` 表里**无任何记录** → 升级到 v2
  ///   （未碰过的轮次用新版；碰过的轮次锁旧版保留体验）
  ///
  /// 派生函数：`LearningPlan.standard(stagePlanVersions: ...)`。
  final String planVersionsJson;
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
    this.retellSentenceIndex,
    this.retellPassCount,
    this.blindListenSentenceIndex,
    this.freePlayBlindListenSentenceIndex,
    this.freePlayIntensiveListenSentenceIndex,
    this.freePlayShadowingSentenceIndex,
    this.freePlayDifficultPracticeSentenceIndex,
    this.freePlayRetellSentenceIndex,
    this.newLearningBreakpointSavedAt,
    this.freePlayBreakpointSavedAt,
    required this.updatedAt,
    required this.skippedSubStages,
    required this.isPaused,
    this.manualUnlockAt,
    required this.planVersionsJson,
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
    if (!nullToAbsent || retellSentenceIndex != null) {
      map['retell_sentence_index'] = Variable<int>(retellSentenceIndex);
    }
    if (!nullToAbsent || retellPassCount != null) {
      map['retell_pass_count'] = Variable<int>(retellPassCount);
    }
    if (!nullToAbsent || blindListenSentenceIndex != null) {
      map['blind_listen_sentence_index'] = Variable<int>(
        blindListenSentenceIndex,
      );
    }
    if (!nullToAbsent || freePlayBlindListenSentenceIndex != null) {
      map['free_play_blind_listen_sentence_index'] = Variable<int>(
        freePlayBlindListenSentenceIndex,
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
    if (!nullToAbsent || freePlayRetellSentenceIndex != null) {
      map['free_play_retell_sentence_index'] = Variable<int>(
        freePlayRetellSentenceIndex,
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
    map['is_paused'] = Variable<bool>(isPaused);
    if (!nullToAbsent || manualUnlockAt != null) {
      map['manual_unlock_at'] = Variable<DateTime>(manualUnlockAt);
    }
    map['plan_versions_json'] = Variable<String>(planVersionsJson);
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
      retellSentenceIndex: retellSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(retellSentenceIndex),
      retellPassCount: retellPassCount == null && nullToAbsent
          ? const Value.absent()
          : Value(retellPassCount),
      blindListenSentenceIndex: blindListenSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(blindListenSentenceIndex),
      freePlayBlindListenSentenceIndex:
          freePlayBlindListenSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(freePlayBlindListenSentenceIndex),
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
      freePlayRetellSentenceIndex:
          freePlayRetellSentenceIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(freePlayRetellSentenceIndex),
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
      isPaused: Value(isPaused),
      manualUnlockAt: manualUnlockAt == null && nullToAbsent
          ? const Value.absent()
          : Value(manualUnlockAt),
      planVersionsJson: Value(planVersionsJson),
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
      retellSentenceIndex: serializer.fromJson<int?>(
        json['retellSentenceIndex'],
      ),
      retellPassCount: serializer.fromJson<int?>(json['retellPassCount']),
      blindListenSentenceIndex: serializer.fromJson<int?>(
        json['blindListenSentenceIndex'],
      ),
      freePlayBlindListenSentenceIndex: serializer.fromJson<int?>(
        json['freePlayBlindListenSentenceIndex'],
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
      freePlayRetellSentenceIndex: serializer.fromJson<int?>(
        json['freePlayRetellSentenceIndex'],
      ),
      newLearningBreakpointSavedAt: serializer.fromJson<DateTime?>(
        json['newLearningBreakpointSavedAt'],
      ),
      freePlayBreakpointSavedAt: serializer.fromJson<DateTime?>(
        json['freePlayBreakpointSavedAt'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      skippedSubStages: serializer.fromJson<String>(json['skippedSubStages']),
      isPaused: serializer.fromJson<bool>(json['isPaused']),
      manualUnlockAt: serializer.fromJson<DateTime?>(json['manualUnlockAt']),
      planVersionsJson: serializer.fromJson<String>(json['planVersionsJson']),
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
      'retellSentenceIndex': serializer.toJson<int?>(retellSentenceIndex),
      'retellPassCount': serializer.toJson<int?>(retellPassCount),
      'blindListenSentenceIndex': serializer.toJson<int?>(
        blindListenSentenceIndex,
      ),
      'freePlayBlindListenSentenceIndex': serializer.toJson<int?>(
        freePlayBlindListenSentenceIndex,
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
      'freePlayRetellSentenceIndex': serializer.toJson<int?>(
        freePlayRetellSentenceIndex,
      ),
      'newLearningBreakpointSavedAt': serializer.toJson<DateTime?>(
        newLearningBreakpointSavedAt,
      ),
      'freePlayBreakpointSavedAt': serializer.toJson<DateTime?>(
        freePlayBreakpointSavedAt,
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'skippedSubStages': serializer.toJson<String>(skippedSubStages),
      'isPaused': serializer.toJson<bool>(isPaused),
      'manualUnlockAt': serializer.toJson<DateTime?>(manualUnlockAt),
      'planVersionsJson': serializer.toJson<String>(planVersionsJson),
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
    Value<int?> retellSentenceIndex = const Value.absent(),
    Value<int?> retellPassCount = const Value.absent(),
    Value<int?> blindListenSentenceIndex = const Value.absent(),
    Value<int?> freePlayBlindListenSentenceIndex = const Value.absent(),
    Value<int?> freePlayIntensiveListenSentenceIndex = const Value.absent(),
    Value<int?> freePlayShadowingSentenceIndex = const Value.absent(),
    Value<int?> freePlayDifficultPracticeSentenceIndex = const Value.absent(),
    Value<int?> freePlayRetellSentenceIndex = const Value.absent(),
    Value<DateTime?> newLearningBreakpointSavedAt = const Value.absent(),
    Value<DateTime?> freePlayBreakpointSavedAt = const Value.absent(),
    DateTime? updatedAt,
    String? skippedSubStages,
    bool? isPaused,
    Value<DateTime?> manualUnlockAt = const Value.absent(),
    String? planVersionsJson,
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
    retellSentenceIndex: retellSentenceIndex.present
        ? retellSentenceIndex.value
        : this.retellSentenceIndex,
    retellPassCount: retellPassCount.present
        ? retellPassCount.value
        : this.retellPassCount,
    blindListenSentenceIndex: blindListenSentenceIndex.present
        ? blindListenSentenceIndex.value
        : this.blindListenSentenceIndex,
    freePlayBlindListenSentenceIndex: freePlayBlindListenSentenceIndex.present
        ? freePlayBlindListenSentenceIndex.value
        : this.freePlayBlindListenSentenceIndex,
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
    freePlayRetellSentenceIndex: freePlayRetellSentenceIndex.present
        ? freePlayRetellSentenceIndex.value
        : this.freePlayRetellSentenceIndex,
    newLearningBreakpointSavedAt: newLearningBreakpointSavedAt.present
        ? newLearningBreakpointSavedAt.value
        : this.newLearningBreakpointSavedAt,
    freePlayBreakpointSavedAt: freePlayBreakpointSavedAt.present
        ? freePlayBreakpointSavedAt.value
        : this.freePlayBreakpointSavedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    skippedSubStages: skippedSubStages ?? this.skippedSubStages,
    isPaused: isPaused ?? this.isPaused,
    manualUnlockAt: manualUnlockAt.present
        ? manualUnlockAt.value
        : this.manualUnlockAt,
    planVersionsJson: planVersionsJson ?? this.planVersionsJson,
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
      retellSentenceIndex: data.retellSentenceIndex.present
          ? data.retellSentenceIndex.value
          : this.retellSentenceIndex,
      retellPassCount: data.retellPassCount.present
          ? data.retellPassCount.value
          : this.retellPassCount,
      blindListenSentenceIndex: data.blindListenSentenceIndex.present
          ? data.blindListenSentenceIndex.value
          : this.blindListenSentenceIndex,
      freePlayBlindListenSentenceIndex:
          data.freePlayBlindListenSentenceIndex.present
          ? data.freePlayBlindListenSentenceIndex.value
          : this.freePlayBlindListenSentenceIndex,
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
      freePlayRetellSentenceIndex: data.freePlayRetellSentenceIndex.present
          ? data.freePlayRetellSentenceIndex.value
          : this.freePlayRetellSentenceIndex,
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
      isPaused: data.isPaused.present ? data.isPaused.value : this.isPaused,
      manualUnlockAt: data.manualUnlockAt.present
          ? data.manualUnlockAt.value
          : this.manualUnlockAt,
      planVersionsJson: data.planVersionsJson.present
          ? data.planVersionsJson.value
          : this.planVersionsJson,
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
          ..write('retellSentenceIndex: $retellSentenceIndex, ')
          ..write('retellPassCount: $retellPassCount, ')
          ..write('blindListenSentenceIndex: $blindListenSentenceIndex, ')
          ..write(
            'freePlayBlindListenSentenceIndex: $freePlayBlindListenSentenceIndex, ',
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
          ..write('freePlayRetellSentenceIndex: $freePlayRetellSentenceIndex, ')
          ..write(
            'newLearningBreakpointSavedAt: $newLearningBreakpointSavedAt, ',
          )
          ..write('freePlayBreakpointSavedAt: $freePlayBreakpointSavedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('skippedSubStages: $skippedSubStages, ')
          ..write('isPaused: $isPaused, ')
          ..write('manualUnlockAt: $manualUnlockAt, ')
          ..write('planVersionsJson: $planVersionsJson')
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
    retellSentenceIndex,
    retellPassCount,
    blindListenSentenceIndex,
    freePlayBlindListenSentenceIndex,
    freePlayIntensiveListenSentenceIndex,
    freePlayShadowingSentenceIndex,
    freePlayDifficultPracticeSentenceIndex,
    freePlayRetellSentenceIndex,
    newLearningBreakpointSavedAt,
    freePlayBreakpointSavedAt,
    updatedAt,
    skippedSubStages,
    isPaused,
    manualUnlockAt,
    planVersionsJson,
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
          other.retellSentenceIndex == this.retellSentenceIndex &&
          other.retellPassCount == this.retellPassCount &&
          other.blindListenSentenceIndex == this.blindListenSentenceIndex &&
          other.freePlayBlindListenSentenceIndex ==
              this.freePlayBlindListenSentenceIndex &&
          other.freePlayIntensiveListenSentenceIndex ==
              this.freePlayIntensiveListenSentenceIndex &&
          other.freePlayShadowingSentenceIndex ==
              this.freePlayShadowingSentenceIndex &&
          other.freePlayDifficultPracticeSentenceIndex ==
              this.freePlayDifficultPracticeSentenceIndex &&
          other.freePlayRetellSentenceIndex ==
              this.freePlayRetellSentenceIndex &&
          other.newLearningBreakpointSavedAt ==
              this.newLearningBreakpointSavedAt &&
          other.freePlayBreakpointSavedAt == this.freePlayBreakpointSavedAt &&
          other.updatedAt == this.updatedAt &&
          other.skippedSubStages == this.skippedSubStages &&
          other.isPaused == this.isPaused &&
          other.manualUnlockAt == this.manualUnlockAt &&
          other.planVersionsJson == this.planVersionsJson);
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
  final Value<int?> retellSentenceIndex;
  final Value<int?> retellPassCount;
  final Value<int?> blindListenSentenceIndex;
  final Value<int?> freePlayBlindListenSentenceIndex;
  final Value<int?> freePlayIntensiveListenSentenceIndex;
  final Value<int?> freePlayShadowingSentenceIndex;
  final Value<int?> freePlayDifficultPracticeSentenceIndex;
  final Value<int?> freePlayRetellSentenceIndex;
  final Value<DateTime?> newLearningBreakpointSavedAt;
  final Value<DateTime?> freePlayBreakpointSavedAt;
  final Value<DateTime> updatedAt;
  final Value<String> skippedSubStages;
  final Value<bool> isPaused;
  final Value<DateTime?> manualUnlockAt;
  final Value<String> planVersionsJson;
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
    this.retellSentenceIndex = const Value.absent(),
    this.retellPassCount = const Value.absent(),
    this.blindListenSentenceIndex = const Value.absent(),
    this.freePlayBlindListenSentenceIndex = const Value.absent(),
    this.freePlayIntensiveListenSentenceIndex = const Value.absent(),
    this.freePlayShadowingSentenceIndex = const Value.absent(),
    this.freePlayDifficultPracticeSentenceIndex = const Value.absent(),
    this.freePlayRetellSentenceIndex = const Value.absent(),
    this.newLearningBreakpointSavedAt = const Value.absent(),
    this.freePlayBreakpointSavedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.skippedSubStages = const Value.absent(),
    this.isPaused = const Value.absent(),
    this.manualUnlockAt = const Value.absent(),
    this.planVersionsJson = const Value.absent(),
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
    this.retellSentenceIndex = const Value.absent(),
    this.retellPassCount = const Value.absent(),
    this.blindListenSentenceIndex = const Value.absent(),
    this.freePlayBlindListenSentenceIndex = const Value.absent(),
    this.freePlayIntensiveListenSentenceIndex = const Value.absent(),
    this.freePlayShadowingSentenceIndex = const Value.absent(),
    this.freePlayDifficultPracticeSentenceIndex = const Value.absent(),
    this.freePlayRetellSentenceIndex = const Value.absent(),
    this.newLearningBreakpointSavedAt = const Value.absent(),
    this.freePlayBreakpointSavedAt = const Value.absent(),
    required DateTime updatedAt,
    this.skippedSubStages = const Value.absent(),
    this.isPaused = const Value.absent(),
    this.manualUnlockAt = const Value.absent(),
    this.planVersionsJson = const Value.absent(),
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
    Expression<int>? retellSentenceIndex,
    Expression<int>? retellPassCount,
    Expression<int>? blindListenSentenceIndex,
    Expression<int>? freePlayBlindListenSentenceIndex,
    Expression<int>? freePlayIntensiveListenSentenceIndex,
    Expression<int>? freePlayShadowingSentenceIndex,
    Expression<int>? freePlayDifficultPracticeSentenceIndex,
    Expression<int>? freePlayRetellSentenceIndex,
    Expression<DateTime>? newLearningBreakpointSavedAt,
    Expression<DateTime>? freePlayBreakpointSavedAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? skippedSubStages,
    Expression<bool>? isPaused,
    Expression<DateTime>? manualUnlockAt,
    Expression<String>? planVersionsJson,
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
      if (retellSentenceIndex != null)
        'retell_sentence_index': retellSentenceIndex,
      if (retellPassCount != null) 'retell_pass_count': retellPassCount,
      if (blindListenSentenceIndex != null)
        'blind_listen_sentence_index': blindListenSentenceIndex,
      if (freePlayBlindListenSentenceIndex != null)
        'free_play_blind_listen_sentence_index':
            freePlayBlindListenSentenceIndex,
      if (freePlayIntensiveListenSentenceIndex != null)
        'free_play_intensive_listen_sentence_index':
            freePlayIntensiveListenSentenceIndex,
      if (freePlayShadowingSentenceIndex != null)
        'free_play_shadowing_sentence_index': freePlayShadowingSentenceIndex,
      if (freePlayDifficultPracticeSentenceIndex != null)
        'free_play_difficult_practice_sentence_index':
            freePlayDifficultPracticeSentenceIndex,
      if (freePlayRetellSentenceIndex != null)
        'free_play_retell_sentence_index': freePlayRetellSentenceIndex,
      if (newLearningBreakpointSavedAt != null)
        'new_learning_breakpoint_saved_at': newLearningBreakpointSavedAt,
      if (freePlayBreakpointSavedAt != null)
        'free_play_breakpoint_saved_at': freePlayBreakpointSavedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (skippedSubStages != null) 'skipped_sub_stages': skippedSubStages,
      if (isPaused != null) 'is_paused': isPaused,
      if (manualUnlockAt != null) 'manual_unlock_at': manualUnlockAt,
      if (planVersionsJson != null) 'plan_versions_json': planVersionsJson,
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
    Value<int?>? retellSentenceIndex,
    Value<int?>? retellPassCount,
    Value<int?>? blindListenSentenceIndex,
    Value<int?>? freePlayBlindListenSentenceIndex,
    Value<int?>? freePlayIntensiveListenSentenceIndex,
    Value<int?>? freePlayShadowingSentenceIndex,
    Value<int?>? freePlayDifficultPracticeSentenceIndex,
    Value<int?>? freePlayRetellSentenceIndex,
    Value<DateTime?>? newLearningBreakpointSavedAt,
    Value<DateTime?>? freePlayBreakpointSavedAt,
    Value<DateTime>? updatedAt,
    Value<String>? skippedSubStages,
    Value<bool>? isPaused,
    Value<DateTime?>? manualUnlockAt,
    Value<String>? planVersionsJson,
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
      retellSentenceIndex: retellSentenceIndex ?? this.retellSentenceIndex,
      retellPassCount: retellPassCount ?? this.retellPassCount,
      blindListenSentenceIndex:
          blindListenSentenceIndex ?? this.blindListenSentenceIndex,
      freePlayBlindListenSentenceIndex:
          freePlayBlindListenSentenceIndex ??
          this.freePlayBlindListenSentenceIndex,
      freePlayIntensiveListenSentenceIndex:
          freePlayIntensiveListenSentenceIndex ??
          this.freePlayIntensiveListenSentenceIndex,
      freePlayShadowingSentenceIndex:
          freePlayShadowingSentenceIndex ?? this.freePlayShadowingSentenceIndex,
      freePlayDifficultPracticeSentenceIndex:
          freePlayDifficultPracticeSentenceIndex ??
          this.freePlayDifficultPracticeSentenceIndex,
      freePlayRetellSentenceIndex:
          freePlayRetellSentenceIndex ?? this.freePlayRetellSentenceIndex,
      newLearningBreakpointSavedAt:
          newLearningBreakpointSavedAt ?? this.newLearningBreakpointSavedAt,
      freePlayBreakpointSavedAt:
          freePlayBreakpointSavedAt ?? this.freePlayBreakpointSavedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      skippedSubStages: skippedSubStages ?? this.skippedSubStages,
      isPaused: isPaused ?? this.isPaused,
      manualUnlockAt: manualUnlockAt ?? this.manualUnlockAt,
      planVersionsJson: planVersionsJson ?? this.planVersionsJson,
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
    if (retellSentenceIndex.present) {
      map['retell_sentence_index'] = Variable<int>(retellSentenceIndex.value);
    }
    if (retellPassCount.present) {
      map['retell_pass_count'] = Variable<int>(retellPassCount.value);
    }
    if (blindListenSentenceIndex.present) {
      map['blind_listen_sentence_index'] = Variable<int>(
        blindListenSentenceIndex.value,
      );
    }
    if (freePlayBlindListenSentenceIndex.present) {
      map['free_play_blind_listen_sentence_index'] = Variable<int>(
        freePlayBlindListenSentenceIndex.value,
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
    if (freePlayRetellSentenceIndex.present) {
      map['free_play_retell_sentence_index'] = Variable<int>(
        freePlayRetellSentenceIndex.value,
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
    if (isPaused.present) {
      map['is_paused'] = Variable<bool>(isPaused.value);
    }
    if (manualUnlockAt.present) {
      map['manual_unlock_at'] = Variable<DateTime>(manualUnlockAt.value);
    }
    if (planVersionsJson.present) {
      map['plan_versions_json'] = Variable<String>(planVersionsJson.value);
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
          ..write('retellSentenceIndex: $retellSentenceIndex, ')
          ..write('retellPassCount: $retellPassCount, ')
          ..write('blindListenSentenceIndex: $blindListenSentenceIndex, ')
          ..write(
            'freePlayBlindListenSentenceIndex: $freePlayBlindListenSentenceIndex, ',
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
          ..write('freePlayRetellSentenceIndex: $freePlayRetellSentenceIndex, ')
          ..write(
            'newLearningBreakpointSavedAt: $newLearningBreakpointSavedAt, ',
          )
          ..write('freePlayBreakpointSavedAt: $freePlayBreakpointSavedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('skippedSubStages: $skippedSubStages, ')
          ..write('isPaused: $isPaused, ')
          ..write('manualUnlockAt: $manualUnlockAt, ')
          ..write('planVersionsJson: $planVersionsJson, ')
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

  /// 被缓存文本的 SHA-256 哈希值（归一化后）。
  /// 句子级 type 用句子文本；词级 type（如 `ai_dictionary`）用 `词|目标语言`。
  final String textHash;

  /// 结果类型，区分同表不同来源：
  /// `translation`（句子翻译）/ `analysis`（句子解析）/ `ai_dictionary`（AI 词典）。
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
  static const VerificationMeta _memorySubjectIdMeta = const VerificationMeta(
    'memorySubjectId',
  );
  @override
  late final GeneratedColumn<String> memorySubjectId = GeneratedColumn<String>(
    'memory_subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    memorySubjectId,
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
    if (data.containsKey('memory_subject_id')) {
      context.handle(
        _memorySubjectIdMeta,
        memorySubjectId.isAcceptableOrUnknown(
          data['memory_subject_id']!,
          _memorySubjectIdMeta,
        ),
      );
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
      memorySubjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_subject_id'],
      ),
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

  /// 稳定关联 FSRS 调度快照的业务主体 ID（不可变 UUID）。
  ///
  /// 与 [word] 解耦：调度身份不依赖可编辑/可合并的展示文本。
  final String? memorySubjectId;

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
    this.memorySubjectId,
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
    if (!nullToAbsent || memorySubjectId != null) {
      map['memory_subject_id'] = Variable<String>(memorySubjectId);
    }
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
      memorySubjectId: memorySubjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(memorySubjectId),
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
      memorySubjectId: serializer.fromJson<String?>(json['memorySubjectId']),
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
      'memorySubjectId': serializer.toJson<String?>(memorySubjectId),
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
    Value<String?> memorySubjectId = const Value.absent(),
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
    memorySubjectId: memorySubjectId.present
        ? memorySubjectId.value
        : this.memorySubjectId,
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
      memorySubjectId: data.memorySubjectId.present
          ? data.memorySubjectId.value
          : this.memorySubjectId,
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
          ..write('memorySubjectId: $memorySubjectId, ')
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
    memorySubjectId,
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
          other.memorySubjectId == this.memorySubjectId &&
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
  final Value<String?> memorySubjectId;
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
    this.memorySubjectId = const Value.absent(),
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
    this.memorySubjectId = const Value.absent(),
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
    Expression<String>? memorySubjectId,
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
      if (memorySubjectId != null) 'memory_subject_id': memorySubjectId,
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
    Value<String?>? memorySubjectId,
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
      memorySubjectId: memorySubjectId ?? this.memorySubjectId,
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
    if (memorySubjectId.present) {
      map['memory_subject_id'] = Variable<String>(memorySubjectId.value);
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
          ..write('memorySubjectId: $memorySubjectId, ')
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
  static const VerificationMeta _memorySubjectIdMeta = const VerificationMeta(
    'memorySubjectId',
  );
  @override
  late final GeneratedColumn<String> memorySubjectId = GeneratedColumn<String>(
    'memory_subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    memorySubjectId,
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
    if (data.containsKey('memory_subject_id')) {
      context.handle(
        _memorySubjectIdMeta,
        memorySubjectId.isAcceptableOrUnknown(
          data['memory_subject_id']!,
          _memorySubjectIdMeta,
        ),
      );
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
      memorySubjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_subject_id'],
      ),
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

  /// 稳定关联 FSRS 调度快照的业务主体 ID（不可变 UUID）。
  ///
  /// 与 [phraseText] 解耦：调度身份不依赖可编辑/可合并的展示文本。
  final String? memorySubjectId;

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
    this.memorySubjectId,
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
    if (!nullToAbsent || memorySubjectId != null) {
      map['memory_subject_id'] = Variable<String>(memorySubjectId);
    }
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
      memorySubjectId: memorySubjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(memorySubjectId),
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
      memorySubjectId: serializer.fromJson<String?>(json['memorySubjectId']),
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
      'memorySubjectId': serializer.toJson<String?>(memorySubjectId),
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
    Value<String?> memorySubjectId = const Value.absent(),
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
    memorySubjectId: memorySubjectId.present
        ? memorySubjectId.value
        : this.memorySubjectId,
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
      memorySubjectId: data.memorySubjectId.present
          ? data.memorySubjectId.value
          : this.memorySubjectId,
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
          ..write('memorySubjectId: $memorySubjectId, ')
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
    memorySubjectId,
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
          other.memorySubjectId == this.memorySubjectId &&
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
  final Value<String?> memorySubjectId;
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
    this.memorySubjectId = const Value.absent(),
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
    this.memorySubjectId = const Value.absent(),
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
    Expression<String>? memorySubjectId,
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
      if (memorySubjectId != null) 'memory_subject_id': memorySubjectId,
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
    Value<String?>? memorySubjectId,
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
      memorySubjectId: memorySubjectId ?? this.memorySubjectId,
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
    if (memorySubjectId.present) {
      map['memory_subject_id'] = Variable<String>(memorySubjectId.value);
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
          ..write('memorySubjectId: $memorySubjectId, ')
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
  static const VerificationMeta _studyTimeMillisecondsMeta =
      const VerificationMeta('studyTimeMilliseconds');
  @override
  late final GeneratedColumn<int> studyTimeMilliseconds = GeneratedColumn<int>(
    'study_time_milliseconds',
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
  static const VerificationMeta _inputTimeMillisecondsMeta =
      const VerificationMeta('inputTimeMilliseconds');
  @override
  late final GeneratedColumn<int> inputTimeMilliseconds = GeneratedColumn<int>(
    'input_time_milliseconds',
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
  static const VerificationMeta _outputTimeMillisecondsMeta =
      const VerificationMeta('outputTimeMilliseconds');
  @override
  late final GeneratedColumn<int> outputTimeMilliseconds = GeneratedColumn<int>(
    'output_time_milliseconds',
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
    studyTimeMilliseconds,
    inputWords,
    outputWords,
    inputTimeSeconds,
    inputTimeMilliseconds,
    outputTimeSeconds,
    outputTimeMilliseconds,
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
    if (data.containsKey('study_time_milliseconds')) {
      context.handle(
        _studyTimeMillisecondsMeta,
        studyTimeMilliseconds.isAcceptableOrUnknown(
          data['study_time_milliseconds']!,
          _studyTimeMillisecondsMeta,
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
    if (data.containsKey('input_time_milliseconds')) {
      context.handle(
        _inputTimeMillisecondsMeta,
        inputTimeMilliseconds.isAcceptableOrUnknown(
          data['input_time_milliseconds']!,
          _inputTimeMillisecondsMeta,
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
    if (data.containsKey('output_time_milliseconds')) {
      context.handle(
        _outputTimeMillisecondsMeta,
        outputTimeMilliseconds.isAcceptableOrUnknown(
          data['output_time_milliseconds']!,
          _outputTimeMillisecondsMeta,
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
      studyTimeMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}study_time_milliseconds'],
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
      inputTimeMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_time_milliseconds'],
      )!,
      outputTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_time_seconds'],
      )!,
      outputTimeMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_time_milliseconds'],
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

  /// 旧版当日累计学习时长（秒）。仅保留用于旧备份/历史迁移兼容，业务不读取。
  final int studyTimeSeconds;

  /// 当日累计学习时长（毫秒）；新统计写入的真实精度来源。
  final int studyTimeMilliseconds;

  /// 当日输入词数（听了多少词）
  final int inputWords;

  /// 当日输出词数（跟读/复述了多少词）
  final int outputWords;

  /// 旧版当日输入时间（秒）。仅保留用于旧备份/历史迁移兼容，业务不读取。
  final int inputTimeSeconds;

  /// 当日累计输入时间（毫秒）。
  final int inputTimeMilliseconds;

  /// 旧版当日输出时间（秒）。仅保留用于旧备份/历史迁移兼容，业务不读取。
  final int outputTimeSeconds;

  /// 当日累计输出时间（毫秒）。
  final int outputTimeMilliseconds;
  const DailyStudyRecord({
    required this.id,
    required this.date,
    required this.studyTimeSeconds,
    required this.studyTimeMilliseconds,
    required this.inputWords,
    required this.outputWords,
    required this.inputTimeSeconds,
    required this.inputTimeMilliseconds,
    required this.outputTimeSeconds,
    required this.outputTimeMilliseconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['study_time_seconds'] = Variable<int>(studyTimeSeconds);
    map['study_time_milliseconds'] = Variable<int>(studyTimeMilliseconds);
    map['input_words'] = Variable<int>(inputWords);
    map['output_words'] = Variable<int>(outputWords);
    map['input_time_seconds'] = Variable<int>(inputTimeSeconds);
    map['input_time_milliseconds'] = Variable<int>(inputTimeMilliseconds);
    map['output_time_seconds'] = Variable<int>(outputTimeSeconds);
    map['output_time_milliseconds'] = Variable<int>(outputTimeMilliseconds);
    return map;
  }

  DailyStudyRecordsCompanion toCompanion(bool nullToAbsent) {
    return DailyStudyRecordsCompanion(
      id: Value(id),
      date: Value(date),
      studyTimeSeconds: Value(studyTimeSeconds),
      studyTimeMilliseconds: Value(studyTimeMilliseconds),
      inputWords: Value(inputWords),
      outputWords: Value(outputWords),
      inputTimeSeconds: Value(inputTimeSeconds),
      inputTimeMilliseconds: Value(inputTimeMilliseconds),
      outputTimeSeconds: Value(outputTimeSeconds),
      outputTimeMilliseconds: Value(outputTimeMilliseconds),
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
      studyTimeMilliseconds: serializer.fromJson<int>(
        json['studyTimeMilliseconds'],
      ),
      inputWords: serializer.fromJson<int>(json['inputWords']),
      outputWords: serializer.fromJson<int>(json['outputWords']),
      inputTimeSeconds: serializer.fromJson<int>(json['inputTimeSeconds']),
      inputTimeMilliseconds: serializer.fromJson<int>(
        json['inputTimeMilliseconds'],
      ),
      outputTimeSeconds: serializer.fromJson<int>(json['outputTimeSeconds']),
      outputTimeMilliseconds: serializer.fromJson<int>(
        json['outputTimeMilliseconds'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'studyTimeSeconds': serializer.toJson<int>(studyTimeSeconds),
      'studyTimeMilliseconds': serializer.toJson<int>(studyTimeMilliseconds),
      'inputWords': serializer.toJson<int>(inputWords),
      'outputWords': serializer.toJson<int>(outputWords),
      'inputTimeSeconds': serializer.toJson<int>(inputTimeSeconds),
      'inputTimeMilliseconds': serializer.toJson<int>(inputTimeMilliseconds),
      'outputTimeSeconds': serializer.toJson<int>(outputTimeSeconds),
      'outputTimeMilliseconds': serializer.toJson<int>(outputTimeMilliseconds),
    };
  }

  DailyStudyRecord copyWith({
    int? id,
    DateTime? date,
    int? studyTimeSeconds,
    int? studyTimeMilliseconds,
    int? inputWords,
    int? outputWords,
    int? inputTimeSeconds,
    int? inputTimeMilliseconds,
    int? outputTimeSeconds,
    int? outputTimeMilliseconds,
  }) => DailyStudyRecord(
    id: id ?? this.id,
    date: date ?? this.date,
    studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
    studyTimeMilliseconds: studyTimeMilliseconds ?? this.studyTimeMilliseconds,
    inputWords: inputWords ?? this.inputWords,
    outputWords: outputWords ?? this.outputWords,
    inputTimeSeconds: inputTimeSeconds ?? this.inputTimeSeconds,
    inputTimeMilliseconds: inputTimeMilliseconds ?? this.inputTimeMilliseconds,
    outputTimeSeconds: outputTimeSeconds ?? this.outputTimeSeconds,
    outputTimeMilliseconds:
        outputTimeMilliseconds ?? this.outputTimeMilliseconds,
  );
  DailyStudyRecord copyWithCompanion(DailyStudyRecordsCompanion data) {
    return DailyStudyRecord(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      studyTimeSeconds: data.studyTimeSeconds.present
          ? data.studyTimeSeconds.value
          : this.studyTimeSeconds,
      studyTimeMilliseconds: data.studyTimeMilliseconds.present
          ? data.studyTimeMilliseconds.value
          : this.studyTimeMilliseconds,
      inputWords: data.inputWords.present
          ? data.inputWords.value
          : this.inputWords,
      outputWords: data.outputWords.present
          ? data.outputWords.value
          : this.outputWords,
      inputTimeSeconds: data.inputTimeSeconds.present
          ? data.inputTimeSeconds.value
          : this.inputTimeSeconds,
      inputTimeMilliseconds: data.inputTimeMilliseconds.present
          ? data.inputTimeMilliseconds.value
          : this.inputTimeMilliseconds,
      outputTimeSeconds: data.outputTimeSeconds.present
          ? data.outputTimeSeconds.value
          : this.outputTimeSeconds,
      outputTimeMilliseconds: data.outputTimeMilliseconds.present
          ? data.outputTimeMilliseconds.value
          : this.outputTimeMilliseconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStudyRecord(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('studyTimeSeconds: $studyTimeSeconds, ')
          ..write('studyTimeMilliseconds: $studyTimeMilliseconds, ')
          ..write('inputWords: $inputWords, ')
          ..write('outputWords: $outputWords, ')
          ..write('inputTimeSeconds: $inputTimeSeconds, ')
          ..write('inputTimeMilliseconds: $inputTimeMilliseconds, ')
          ..write('outputTimeSeconds: $outputTimeSeconds, ')
          ..write('outputTimeMilliseconds: $outputTimeMilliseconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    studyTimeSeconds,
    studyTimeMilliseconds,
    inputWords,
    outputWords,
    inputTimeSeconds,
    inputTimeMilliseconds,
    outputTimeSeconds,
    outputTimeMilliseconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStudyRecord &&
          other.id == this.id &&
          other.date == this.date &&
          other.studyTimeSeconds == this.studyTimeSeconds &&
          other.studyTimeMilliseconds == this.studyTimeMilliseconds &&
          other.inputWords == this.inputWords &&
          other.outputWords == this.outputWords &&
          other.inputTimeSeconds == this.inputTimeSeconds &&
          other.inputTimeMilliseconds == this.inputTimeMilliseconds &&
          other.outputTimeSeconds == this.outputTimeSeconds &&
          other.outputTimeMilliseconds == this.outputTimeMilliseconds);
}

class DailyStudyRecordsCompanion extends UpdateCompanion<DailyStudyRecord> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<int> studyTimeSeconds;
  final Value<int> studyTimeMilliseconds;
  final Value<int> inputWords;
  final Value<int> outputWords;
  final Value<int> inputTimeSeconds;
  final Value<int> inputTimeMilliseconds;
  final Value<int> outputTimeSeconds;
  final Value<int> outputTimeMilliseconds;
  const DailyStudyRecordsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.studyTimeSeconds = const Value.absent(),
    this.studyTimeMilliseconds = const Value.absent(),
    this.inputWords = const Value.absent(),
    this.outputWords = const Value.absent(),
    this.inputTimeSeconds = const Value.absent(),
    this.inputTimeMilliseconds = const Value.absent(),
    this.outputTimeSeconds = const Value.absent(),
    this.outputTimeMilliseconds = const Value.absent(),
  });
  DailyStudyRecordsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    this.studyTimeSeconds = const Value.absent(),
    this.studyTimeMilliseconds = const Value.absent(),
    this.inputWords = const Value.absent(),
    this.outputWords = const Value.absent(),
    this.inputTimeSeconds = const Value.absent(),
    this.inputTimeMilliseconds = const Value.absent(),
    this.outputTimeSeconds = const Value.absent(),
    this.outputTimeMilliseconds = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DailyStudyRecord> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? studyTimeSeconds,
    Expression<int>? studyTimeMilliseconds,
    Expression<int>? inputWords,
    Expression<int>? outputWords,
    Expression<int>? inputTimeSeconds,
    Expression<int>? inputTimeMilliseconds,
    Expression<int>? outputTimeSeconds,
    Expression<int>? outputTimeMilliseconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (studyTimeSeconds != null) 'study_time_seconds': studyTimeSeconds,
      if (studyTimeMilliseconds != null)
        'study_time_milliseconds': studyTimeMilliseconds,
      if (inputWords != null) 'input_words': inputWords,
      if (outputWords != null) 'output_words': outputWords,
      if (inputTimeSeconds != null) 'input_time_seconds': inputTimeSeconds,
      if (inputTimeMilliseconds != null)
        'input_time_milliseconds': inputTimeMilliseconds,
      if (outputTimeSeconds != null) 'output_time_seconds': outputTimeSeconds,
      if (outputTimeMilliseconds != null)
        'output_time_milliseconds': outputTimeMilliseconds,
    });
  }

  DailyStudyRecordsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<int>? studyTimeSeconds,
    Value<int>? studyTimeMilliseconds,
    Value<int>? inputWords,
    Value<int>? outputWords,
    Value<int>? inputTimeSeconds,
    Value<int>? inputTimeMilliseconds,
    Value<int>? outputTimeSeconds,
    Value<int>? outputTimeMilliseconds,
  }) {
    return DailyStudyRecordsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
      studyTimeMilliseconds:
          studyTimeMilliseconds ?? this.studyTimeMilliseconds,
      inputWords: inputWords ?? this.inputWords,
      outputWords: outputWords ?? this.outputWords,
      inputTimeSeconds: inputTimeSeconds ?? this.inputTimeSeconds,
      inputTimeMilliseconds:
          inputTimeMilliseconds ?? this.inputTimeMilliseconds,
      outputTimeSeconds: outputTimeSeconds ?? this.outputTimeSeconds,
      outputTimeMilliseconds:
          outputTimeMilliseconds ?? this.outputTimeMilliseconds,
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
    if (studyTimeMilliseconds.present) {
      map['study_time_milliseconds'] = Variable<int>(
        studyTimeMilliseconds.value,
      );
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
    if (inputTimeMilliseconds.present) {
      map['input_time_milliseconds'] = Variable<int>(
        inputTimeMilliseconds.value,
      );
    }
    if (outputTimeSeconds.present) {
      map['output_time_seconds'] = Variable<int>(outputTimeSeconds.value);
    }
    if (outputTimeMilliseconds.present) {
      map['output_time_milliseconds'] = Variable<int>(
        outputTimeMilliseconds.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStudyRecordsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('studyTimeSeconds: $studyTimeSeconds, ')
          ..write('studyTimeMilliseconds: $studyTimeMilliseconds, ')
          ..write('inputWords: $inputWords, ')
          ..write('outputWords: $outputWords, ')
          ..write('inputTimeSeconds: $inputTimeSeconds, ')
          ..write('inputTimeMilliseconds: $inputTimeMilliseconds, ')
          ..write('outputTimeSeconds: $outputTimeSeconds, ')
          ..write('outputTimeMilliseconds: $outputTimeMilliseconds')
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
  static const VerificationMeta _studyTimeMillisecondsMeta =
      const VerificationMeta('studyTimeMilliseconds');
  @override
  late final GeneratedColumn<int> studyTimeMilliseconds = GeneratedColumn<int>(
    'study_time_milliseconds',
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
  static const VerificationMeta _inputTimeMillisecondsMeta =
      const VerificationMeta('inputTimeMilliseconds');
  @override
  late final GeneratedColumn<int> inputTimeMilliseconds = GeneratedColumn<int>(
    'input_time_milliseconds',
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
  static const VerificationMeta _outputTimeMillisecondsMeta =
      const VerificationMeta('outputTimeMilliseconds');
  @override
  late final GeneratedColumn<int> outputTimeMilliseconds = GeneratedColumn<int>(
    'output_time_milliseconds',
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
    studyTimeMilliseconds,
    inputTimeSeconds,
    inputTimeMilliseconds,
    outputTimeSeconds,
    outputTimeMilliseconds,
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
    if (data.containsKey('study_time_milliseconds')) {
      context.handle(
        _studyTimeMillisecondsMeta,
        studyTimeMilliseconds.isAcceptableOrUnknown(
          data['study_time_milliseconds']!,
          _studyTimeMillisecondsMeta,
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
    if (data.containsKey('input_time_milliseconds')) {
      context.handle(
        _inputTimeMillisecondsMeta,
        inputTimeMilliseconds.isAcceptableOrUnknown(
          data['input_time_milliseconds']!,
          _inputTimeMillisecondsMeta,
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
    if (data.containsKey('output_time_milliseconds')) {
      context.handle(
        _outputTimeMillisecondsMeta,
        outputTimeMilliseconds.isAcceptableOrUnknown(
          data['output_time_milliseconds']!,
          _outputTimeMillisecondsMeta,
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
      studyTimeMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}study_time_milliseconds'],
      )!,
      inputTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_time_seconds'],
      )!,
      inputTimeMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_time_milliseconds'],
      )!,
      outputTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_time_seconds'],
      )!,
      outputTimeMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_time_milliseconds'],
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

  /// 旧版当日该阶段累计学习时长（秒）。仅保留用于旧备份/历史迁移兼容，业务不读取。
  final int studyTimeSeconds;

  /// 当日该阶段累计学习时长（毫秒）。
  final int studyTimeMilliseconds;

  /// 旧版当日该阶段输入时间（秒）— 音频播放时间。仅保留用于旧备份/历史迁移兼容，业务不读取。
  final int inputTimeSeconds;

  /// 当日该阶段累计输入时间（毫秒）。
  final int inputTimeMilliseconds;

  /// 旧版当日该阶段输出时间（秒）— 跟读/复述时间。仅保留用于旧备份/历史迁移兼容，业务不读取。
  final int outputTimeSeconds;

  /// 当日该阶段累计输出时间（毫秒）。
  final int outputTimeMilliseconds;
  const DailyStageStudyRecord({
    required this.id,
    required this.date,
    required this.stage,
    required this.studyTimeSeconds,
    required this.studyTimeMilliseconds,
    required this.inputTimeSeconds,
    required this.inputTimeMilliseconds,
    required this.outputTimeSeconds,
    required this.outputTimeMilliseconds,
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
    map['study_time_milliseconds'] = Variable<int>(studyTimeMilliseconds);
    map['input_time_seconds'] = Variable<int>(inputTimeSeconds);
    map['input_time_milliseconds'] = Variable<int>(inputTimeMilliseconds);
    map['output_time_seconds'] = Variable<int>(outputTimeSeconds);
    map['output_time_milliseconds'] = Variable<int>(outputTimeMilliseconds);
    return map;
  }

  DailyStageStudyRecordsCompanion toCompanion(bool nullToAbsent) {
    return DailyStageStudyRecordsCompanion(
      id: Value(id),
      date: Value(date),
      stage: Value(stage),
      studyTimeSeconds: Value(studyTimeSeconds),
      studyTimeMilliseconds: Value(studyTimeMilliseconds),
      inputTimeSeconds: Value(inputTimeSeconds),
      inputTimeMilliseconds: Value(inputTimeMilliseconds),
      outputTimeSeconds: Value(outputTimeSeconds),
      outputTimeMilliseconds: Value(outputTimeMilliseconds),
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
      studyTimeMilliseconds: serializer.fromJson<int>(
        json['studyTimeMilliseconds'],
      ),
      inputTimeSeconds: serializer.fromJson<int>(json['inputTimeSeconds']),
      inputTimeMilliseconds: serializer.fromJson<int>(
        json['inputTimeMilliseconds'],
      ),
      outputTimeSeconds: serializer.fromJson<int>(json['outputTimeSeconds']),
      outputTimeMilliseconds: serializer.fromJson<int>(
        json['outputTimeMilliseconds'],
      ),
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
      'studyTimeMilliseconds': serializer.toJson<int>(studyTimeMilliseconds),
      'inputTimeSeconds': serializer.toJson<int>(inputTimeSeconds),
      'inputTimeMilliseconds': serializer.toJson<int>(inputTimeMilliseconds),
      'outputTimeSeconds': serializer.toJson<int>(outputTimeSeconds),
      'outputTimeMilliseconds': serializer.toJson<int>(outputTimeMilliseconds),
    };
  }

  DailyStageStudyRecord copyWith({
    int? id,
    DateTime? date,
    StudyStage? stage,
    int? studyTimeSeconds,
    int? studyTimeMilliseconds,
    int? inputTimeSeconds,
    int? inputTimeMilliseconds,
    int? outputTimeSeconds,
    int? outputTimeMilliseconds,
  }) => DailyStageStudyRecord(
    id: id ?? this.id,
    date: date ?? this.date,
    stage: stage ?? this.stage,
    studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
    studyTimeMilliseconds: studyTimeMilliseconds ?? this.studyTimeMilliseconds,
    inputTimeSeconds: inputTimeSeconds ?? this.inputTimeSeconds,
    inputTimeMilliseconds: inputTimeMilliseconds ?? this.inputTimeMilliseconds,
    outputTimeSeconds: outputTimeSeconds ?? this.outputTimeSeconds,
    outputTimeMilliseconds:
        outputTimeMilliseconds ?? this.outputTimeMilliseconds,
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
      studyTimeMilliseconds: data.studyTimeMilliseconds.present
          ? data.studyTimeMilliseconds.value
          : this.studyTimeMilliseconds,
      inputTimeSeconds: data.inputTimeSeconds.present
          ? data.inputTimeSeconds.value
          : this.inputTimeSeconds,
      inputTimeMilliseconds: data.inputTimeMilliseconds.present
          ? data.inputTimeMilliseconds.value
          : this.inputTimeMilliseconds,
      outputTimeSeconds: data.outputTimeSeconds.present
          ? data.outputTimeSeconds.value
          : this.outputTimeSeconds,
      outputTimeMilliseconds: data.outputTimeMilliseconds.present
          ? data.outputTimeMilliseconds.value
          : this.outputTimeMilliseconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStageStudyRecord(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('stage: $stage, ')
          ..write('studyTimeSeconds: $studyTimeSeconds, ')
          ..write('studyTimeMilliseconds: $studyTimeMilliseconds, ')
          ..write('inputTimeSeconds: $inputTimeSeconds, ')
          ..write('inputTimeMilliseconds: $inputTimeMilliseconds, ')
          ..write('outputTimeSeconds: $outputTimeSeconds, ')
          ..write('outputTimeMilliseconds: $outputTimeMilliseconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    stage,
    studyTimeSeconds,
    studyTimeMilliseconds,
    inputTimeSeconds,
    inputTimeMilliseconds,
    outputTimeSeconds,
    outputTimeMilliseconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStageStudyRecord &&
          other.id == this.id &&
          other.date == this.date &&
          other.stage == this.stage &&
          other.studyTimeSeconds == this.studyTimeSeconds &&
          other.studyTimeMilliseconds == this.studyTimeMilliseconds &&
          other.inputTimeSeconds == this.inputTimeSeconds &&
          other.inputTimeMilliseconds == this.inputTimeMilliseconds &&
          other.outputTimeSeconds == this.outputTimeSeconds &&
          other.outputTimeMilliseconds == this.outputTimeMilliseconds);
}

class DailyStageStudyRecordsCompanion
    extends UpdateCompanion<DailyStageStudyRecord> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<StudyStage> stage;
  final Value<int> studyTimeSeconds;
  final Value<int> studyTimeMilliseconds;
  final Value<int> inputTimeSeconds;
  final Value<int> inputTimeMilliseconds;
  final Value<int> outputTimeSeconds;
  final Value<int> outputTimeMilliseconds;
  const DailyStageStudyRecordsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.stage = const Value.absent(),
    this.studyTimeSeconds = const Value.absent(),
    this.studyTimeMilliseconds = const Value.absent(),
    this.inputTimeSeconds = const Value.absent(),
    this.inputTimeMilliseconds = const Value.absent(),
    this.outputTimeSeconds = const Value.absent(),
    this.outputTimeMilliseconds = const Value.absent(),
  });
  DailyStageStudyRecordsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required StudyStage stage,
    this.studyTimeSeconds = const Value.absent(),
    this.studyTimeMilliseconds = const Value.absent(),
    this.inputTimeSeconds = const Value.absent(),
    this.inputTimeMilliseconds = const Value.absent(),
    this.outputTimeSeconds = const Value.absent(),
    this.outputTimeMilliseconds = const Value.absent(),
  }) : date = Value(date),
       stage = Value(stage);
  static Insertable<DailyStageStudyRecord> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? stage,
    Expression<int>? studyTimeSeconds,
    Expression<int>? studyTimeMilliseconds,
    Expression<int>? inputTimeSeconds,
    Expression<int>? inputTimeMilliseconds,
    Expression<int>? outputTimeSeconds,
    Expression<int>? outputTimeMilliseconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (stage != null) 'stage': stage,
      if (studyTimeSeconds != null) 'study_time_seconds': studyTimeSeconds,
      if (studyTimeMilliseconds != null)
        'study_time_milliseconds': studyTimeMilliseconds,
      if (inputTimeSeconds != null) 'input_time_seconds': inputTimeSeconds,
      if (inputTimeMilliseconds != null)
        'input_time_milliseconds': inputTimeMilliseconds,
      if (outputTimeSeconds != null) 'output_time_seconds': outputTimeSeconds,
      if (outputTimeMilliseconds != null)
        'output_time_milliseconds': outputTimeMilliseconds,
    });
  }

  DailyStageStudyRecordsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<StudyStage>? stage,
    Value<int>? studyTimeSeconds,
    Value<int>? studyTimeMilliseconds,
    Value<int>? inputTimeSeconds,
    Value<int>? inputTimeMilliseconds,
    Value<int>? outputTimeSeconds,
    Value<int>? outputTimeMilliseconds,
  }) {
    return DailyStageStudyRecordsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      stage: stage ?? this.stage,
      studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
      studyTimeMilliseconds:
          studyTimeMilliseconds ?? this.studyTimeMilliseconds,
      inputTimeSeconds: inputTimeSeconds ?? this.inputTimeSeconds,
      inputTimeMilliseconds:
          inputTimeMilliseconds ?? this.inputTimeMilliseconds,
      outputTimeSeconds: outputTimeSeconds ?? this.outputTimeSeconds,
      outputTimeMilliseconds:
          outputTimeMilliseconds ?? this.outputTimeMilliseconds,
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
    if (studyTimeMilliseconds.present) {
      map['study_time_milliseconds'] = Variable<int>(
        studyTimeMilliseconds.value,
      );
    }
    if (inputTimeSeconds.present) {
      map['input_time_seconds'] = Variable<int>(inputTimeSeconds.value);
    }
    if (inputTimeMilliseconds.present) {
      map['input_time_milliseconds'] = Variable<int>(
        inputTimeMilliseconds.value,
      );
    }
    if (outputTimeSeconds.present) {
      map['output_time_seconds'] = Variable<int>(outputTimeSeconds.value);
    }
    if (outputTimeMilliseconds.present) {
      map['output_time_milliseconds'] = Variable<int>(
        outputTimeMilliseconds.value,
      );
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
          ..write('studyTimeMilliseconds: $studyTimeMilliseconds, ')
          ..write('inputTimeSeconds: $inputTimeSeconds, ')
          ..write('inputTimeMilliseconds: $inputTimeMilliseconds, ')
          ..write('outputTimeSeconds: $outputTimeSeconds, ')
          ..write('outputTimeMilliseconds: $outputTimeMilliseconds')
          ..write(')'))
        .toString();
  }
}

class $TtsCacheTable extends TtsCache
    with TableInfo<$TtsCacheTable, TtsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TtsCacheTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
    'engine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voiceMeta = const VerificationMeta('voice');
  @override
  late final GeneratedColumn<String> voice = GeneratedColumn<String>(
    'voice',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cacheKey,
    textHash,
    sourceText,
    engine,
    voice,
    languageCode,
    speed,
    format,
    filePath,
    fileSize,
    createdAt,
    lastAccessedAt,
    expiresAt,
    isPinned,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tts_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<TtsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('text_hash')) {
      context.handle(
        _textHashMeta,
        textHash.isAcceptableOrUnknown(data['text_hash']!, _textHashMeta),
      );
    } else if (isInserting) {
      context.missing(_textHashMeta);
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTextMeta);
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    } else if (isInserting) {
      context.missing(_engineMeta);
    }
    if (data.containsKey('voice')) {
      context.handle(
        _voiceMeta,
        voice.isAcceptableOrUnknown(data['voice']!, _voiceMeta),
      );
    } else if (isInserting) {
      context.missing(_voiceMeta);
    }
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_languageCodeMeta);
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    } else if (isInserting) {
      context.missing(_speedMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
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
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {cacheKey},
  ];
  @override
  TtsCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TtsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      textHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_hash'],
      )!,
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      )!,
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      )!,
      voice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice'],
      )!,
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
    );
  }

  @override
  $TtsCacheTable createAlias(String alias) {
    return $TtsCacheTable(attachedDatabase, alias);
  }
}

class TtsCacheData extends DataClass implements Insertable<TtsCacheData> {
  /// 自增主键。
  final int id;

  /// 缓存键（唯一），由 `sha256(textHash|engine|voice|speed|format)` 派生。
  /// 同一文本在不同引擎/音色/语速/格式下生成不同条目，互不串音。
  final String cacheKey;

  /// 被合成文本的 SHA-256 哈希（归一化后），用于去重与统计。
  final String textHash;

  /// 被合成的原始文本（可读），用于调试时识别每条缓存对应的内容。
  /// 缓存对象为单词/例句/示范句等短文本，存储成本可忽略。
  final String sourceText;

  /// 合成引擎标识（`platform` / 未来 `kokoro`）。
  final String engine;

  /// 音色/口音标识（如 `en-US` / `en-GB`，或未来具体 voice name）。
  final String voice;

  /// 语言标签（`en-US` / `en-GB`）。
  final String languageCode;

  /// 语速（归一化值）。
  final double speed;

  /// 音频格式（平台 TTS：Android `wav` / iOS·macOS `caf`）。
  final String format;

  /// 本地音频文件绝对路径。
  final String filePath;

  /// 文件字节数（用于容量统计与 LRU 淘汰）。
  final int fileSize;

  /// 创建时间。
  final DateTime createdAt;

  /// 最后访问时间（LRU 淘汰依据）。
  final DateTime lastAccessedAt;

  /// 过期时间（可空）。null 表示不按时间过期（永久缓存）。
  final DateTime? expiresAt;

  /// 是否永久保留（不自动清理）。本期恒 false，为未来长文音频预留。
  final bool isPinned;
  const TtsCacheData({
    required this.id,
    required this.cacheKey,
    required this.textHash,
    required this.sourceText,
    required this.engine,
    required this.voice,
    required this.languageCode,
    required this.speed,
    required this.format,
    required this.filePath,
    required this.fileSize,
    required this.createdAt,
    required this.lastAccessedAt,
    this.expiresAt,
    required this.isPinned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cache_key'] = Variable<String>(cacheKey);
    map['text_hash'] = Variable<String>(textHash);
    map['source_text'] = Variable<String>(sourceText);
    map['engine'] = Variable<String>(engine);
    map['voice'] = Variable<String>(voice);
    map['language_code'] = Variable<String>(languageCode);
    map['speed'] = Variable<double>(speed);
    map['format'] = Variable<String>(format);
    map['file_path'] = Variable<String>(filePath);
    map['file_size'] = Variable<int>(fileSize);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    return map;
  }

  TtsCacheCompanion toCompanion(bool nullToAbsent) {
    return TtsCacheCompanion(
      id: Value(id),
      cacheKey: Value(cacheKey),
      textHash: Value(textHash),
      sourceText: Value(sourceText),
      engine: Value(engine),
      voice: Value(voice),
      languageCode: Value(languageCode),
      speed: Value(speed),
      format: Value(format),
      filePath: Value(filePath),
      fileSize: Value(fileSize),
      createdAt: Value(createdAt),
      lastAccessedAt: Value(lastAccessedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      isPinned: Value(isPinned),
    );
  }

  factory TtsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TtsCacheData(
      id: serializer.fromJson<int>(json['id']),
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      textHash: serializer.fromJson<String>(json['textHash']),
      sourceText: serializer.fromJson<String>(json['sourceText']),
      engine: serializer.fromJson<String>(json['engine']),
      voice: serializer.fromJson<String>(json['voice']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      speed: serializer.fromJson<double>(json['speed']),
      format: serializer.fromJson<String>(json['format']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAccessedAt: serializer.fromJson<DateTime>(json['lastAccessedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cacheKey': serializer.toJson<String>(cacheKey),
      'textHash': serializer.toJson<String>(textHash),
      'sourceText': serializer.toJson<String>(sourceText),
      'engine': serializer.toJson<String>(engine),
      'voice': serializer.toJson<String>(voice),
      'languageCode': serializer.toJson<String>(languageCode),
      'speed': serializer.toJson<double>(speed),
      'format': serializer.toJson<String>(format),
      'filePath': serializer.toJson<String>(filePath),
      'fileSize': serializer.toJson<int>(fileSize),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAccessedAt': serializer.toJson<DateTime>(lastAccessedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'isPinned': serializer.toJson<bool>(isPinned),
    };
  }

  TtsCacheData copyWith({
    int? id,
    String? cacheKey,
    String? textHash,
    String? sourceText,
    String? engine,
    String? voice,
    String? languageCode,
    double? speed,
    String? format,
    String? filePath,
    int? fileSize,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    Value<DateTime?> expiresAt = const Value.absent(),
    bool? isPinned,
  }) => TtsCacheData(
    id: id ?? this.id,
    cacheKey: cacheKey ?? this.cacheKey,
    textHash: textHash ?? this.textHash,
    sourceText: sourceText ?? this.sourceText,
    engine: engine ?? this.engine,
    voice: voice ?? this.voice,
    languageCode: languageCode ?? this.languageCode,
    speed: speed ?? this.speed,
    format: format ?? this.format,
    filePath: filePath ?? this.filePath,
    fileSize: fileSize ?? this.fileSize,
    createdAt: createdAt ?? this.createdAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    isPinned: isPinned ?? this.isPinned,
  );
  TtsCacheData copyWithCompanion(TtsCacheCompanion data) {
    return TtsCacheData(
      id: data.id.present ? data.id.value : this.id,
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      textHash: data.textHash.present ? data.textHash.value : this.textHash,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      engine: data.engine.present ? data.engine.value : this.engine,
      voice: data.voice.present ? data.voice.value : this.voice,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      speed: data.speed.present ? data.speed.value : this.speed,
      format: data.format.present ? data.format.value : this.format,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TtsCacheData(')
          ..write('id: $id, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('textHash: $textHash, ')
          ..write('sourceText: $sourceText, ')
          ..write('engine: $engine, ')
          ..write('voice: $voice, ')
          ..write('languageCode: $languageCode, ')
          ..write('speed: $speed, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('isPinned: $isPinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cacheKey,
    textHash,
    sourceText,
    engine,
    voice,
    languageCode,
    speed,
    format,
    filePath,
    fileSize,
    createdAt,
    lastAccessedAt,
    expiresAt,
    isPinned,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TtsCacheData &&
          other.id == this.id &&
          other.cacheKey == this.cacheKey &&
          other.textHash == this.textHash &&
          other.sourceText == this.sourceText &&
          other.engine == this.engine &&
          other.voice == this.voice &&
          other.languageCode == this.languageCode &&
          other.speed == this.speed &&
          other.format == this.format &&
          other.filePath == this.filePath &&
          other.fileSize == this.fileSize &&
          other.createdAt == this.createdAt &&
          other.lastAccessedAt == this.lastAccessedAt &&
          other.expiresAt == this.expiresAt &&
          other.isPinned == this.isPinned);
}

class TtsCacheCompanion extends UpdateCompanion<TtsCacheData> {
  final Value<int> id;
  final Value<String> cacheKey;
  final Value<String> textHash;
  final Value<String> sourceText;
  final Value<String> engine;
  final Value<String> voice;
  final Value<String> languageCode;
  final Value<double> speed;
  final Value<String> format;
  final Value<String> filePath;
  final Value<int> fileSize;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastAccessedAt;
  final Value<DateTime?> expiresAt;
  final Value<bool> isPinned;
  const TtsCacheCompanion({
    this.id = const Value.absent(),
    this.cacheKey = const Value.absent(),
    this.textHash = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.engine = const Value.absent(),
    this.voice = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.speed = const Value.absent(),
    this.format = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.isPinned = const Value.absent(),
  });
  TtsCacheCompanion.insert({
    this.id = const Value.absent(),
    required String cacheKey,
    required String textHash,
    required String sourceText,
    required String engine,
    required String voice,
    required String languageCode,
    required double speed,
    required String format,
    required String filePath,
    required int fileSize,
    required DateTime createdAt,
    required DateTime lastAccessedAt,
    this.expiresAt = const Value.absent(),
    this.isPinned = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       textHash = Value(textHash),
       sourceText = Value(sourceText),
       engine = Value(engine),
       voice = Value(voice),
       languageCode = Value(languageCode),
       speed = Value(speed),
       format = Value(format),
       filePath = Value(filePath),
       fileSize = Value(fileSize),
       createdAt = Value(createdAt),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<TtsCacheData> custom({
    Expression<int>? id,
    Expression<String>? cacheKey,
    Expression<String>? textHash,
    Expression<String>? sourceText,
    Expression<String>? engine,
    Expression<String>? voice,
    Expression<String>? languageCode,
    Expression<double>? speed,
    Expression<String>? format,
    Expression<String>? filePath,
    Expression<int>? fileSize,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAccessedAt,
    Expression<DateTime>? expiresAt,
    Expression<bool>? isPinned,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cacheKey != null) 'cache_key': cacheKey,
      if (textHash != null) 'text_hash': textHash,
      if (sourceText != null) 'source_text': sourceText,
      if (engine != null) 'engine': engine,
      if (voice != null) 'voice': voice,
      if (languageCode != null) 'language_code': languageCode,
      if (speed != null) 'speed': speed,
      if (format != null) 'format': format,
      if (filePath != null) 'file_path': filePath,
      if (fileSize != null) 'file_size': fileSize,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (isPinned != null) 'is_pinned': isPinned,
    });
  }

  TtsCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? cacheKey,
    Value<String>? textHash,
    Value<String>? sourceText,
    Value<String>? engine,
    Value<String>? voice,
    Value<String>? languageCode,
    Value<double>? speed,
    Value<String>? format,
    Value<String>? filePath,
    Value<int>? fileSize,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastAccessedAt,
    Value<DateTime?>? expiresAt,
    Value<bool>? isPinned,
  }) {
    return TtsCacheCompanion(
      id: id ?? this.id,
      cacheKey: cacheKey ?? this.cacheKey,
      textHash: textHash ?? this.textHash,
      sourceText: sourceText ?? this.sourceText,
      engine: engine ?? this.engine,
      voice: voice ?? this.voice,
      languageCode: languageCode ?? this.languageCode,
      speed: speed ?? this.speed,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (textHash.present) {
      map['text_hash'] = Variable<String>(textHash.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (voice.present) {
      map['voice'] = Variable<String>(voice.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TtsCacheCompanion(')
          ..write('id: $id, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('textHash: $textHash, ')
          ..write('sourceText: $sourceText, ')
          ..write('engine: $engine, ')
          ..write('voice: $voice, ')
          ..write('languageCode: $languageCode, ')
          ..write('speed: $speed, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('isPinned: $isPinned')
          ..write(')'))
        .toString();
  }
}

class $MemorySchedulesTable extends MemorySchedules
    with TableInfo<$MemorySchedulesTable, MemorySchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemorySchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namespaceMeta = const VerificationMeta(
    'namespace',
  );
  @override
  late final GeneratedColumn<String> namespace = GeneratedColumn<String>(
    'namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileVersionMeta = const VerificationMeta(
    'profileVersion',
  );
  @override
  late final GeneratedColumn<int> profileVersion = GeneratedColumn<int>(
    'profile_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelStateVersionMeta = const VerificationMeta(
    'modelStateVersion',
  );
  @override
  late final GeneratedColumn<int> modelStateVersion = GeneratedColumn<int>(
    'model_state_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelStateJsonMeta = const VerificationMeta(
    'modelStateJson',
  );
  @override
  late final GeneratedColumn<String> modelStateJson = GeneratedColumn<String>(
    'model_state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta(
    'lastReviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewedAt =
      GeneratedColumn<DateTime>(
        'last_reviewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reviewCountMeta = const VerificationMeta(
    'reviewCount',
  );
  @override
  late final GeneratedColumn<int> reviewCount = GeneratedColumn<int>(
    'review_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapseCountMeta = const VerificationMeta(
    'lapseCount',
  );
  @override
  late final GeneratedColumn<int> lapseCount = GeneratedColumn<int>(
    'lapse_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    namespace,
    subjectId,
    profileId,
    profileVersion,
    modelId,
    modelStateVersion,
    modelStateJson,
    phase,
    status,
    dueAt,
    lastReviewedAt,
    reviewCount,
    lapseCount,
    revision,
    createdAt,
    updatedAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemorySchedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('namespace')) {
      context.handle(
        _namespaceMeta,
        namespace.isAcceptableOrUnknown(data['namespace']!, _namespaceMeta),
      );
    } else if (isInserting) {
      context.missing(_namespaceMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('profile_version')) {
      context.handle(
        _profileVersionMeta,
        profileVersion.isAcceptableOrUnknown(
          data['profile_version']!,
          _profileVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profileVersionMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('model_state_version')) {
      context.handle(
        _modelStateVersionMeta,
        modelStateVersion.isAcceptableOrUnknown(
          data['model_state_version']!,
          _modelStateVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelStateVersionMeta);
    }
    if (data.containsKey('model_state_json')) {
      context.handle(
        _modelStateJsonMeta,
        modelStateJson.isAcceptableOrUnknown(
          data['model_state_json']!,
          _modelStateJsonMeta,
        ),
      );
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(
          data['last_reviewed_at']!,
          _lastReviewedAtMeta,
        ),
      );
    }
    if (data.containsKey('review_count')) {
      context.handle(
        _reviewCountMeta,
        reviewCount.isAcceptableOrUnknown(
          data['review_count']!,
          _reviewCountMeta,
        ),
      );
    }
    if (data.containsKey('lapse_count')) {
      context.handle(
        _lapseCountMeta,
        lapseCount.isAcceptableOrUnknown(data['lapse_count']!, _lapseCountMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {namespace, subjectId},
  ];
  @override
  MemorySchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemorySchedule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      namespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}namespace'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      profileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_version'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      modelStateVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}model_state_version'],
      )!,
      modelStateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_state_json'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed_at'],
      ),
      reviewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_count'],
      )!,
      lapseCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapse_count'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $MemorySchedulesTable createAlias(String alias) {
    return $MemorySchedulesTable(attachedDatabase, alias);
  }
}

class MemorySchedule extends DataClass implements Insertable<MemorySchedule> {
  final String id;
  final String namespace;
  final String subjectId;
  final String profileId;
  final int profileVersion;
  final String modelId;
  final int modelStateVersion;
  final String modelStateJson;
  final String phase;
  final String status;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;
  final int lapseCount;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  const MemorySchedule({
    required this.id,
    required this.namespace,
    required this.subjectId,
    required this.profileId,
    required this.profileVersion,
    required this.modelId,
    required this.modelStateVersion,
    required this.modelStateJson,
    required this.phase,
    required this.status,
    required this.dueAt,
    this.lastReviewedAt,
    required this.reviewCount,
    required this.lapseCount,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['namespace'] = Variable<String>(namespace);
    map['subject_id'] = Variable<String>(subjectId);
    map['profile_id'] = Variable<String>(profileId);
    map['profile_version'] = Variable<int>(profileVersion);
    map['model_id'] = Variable<String>(modelId);
    map['model_state_version'] = Variable<int>(modelStateVersion);
    map['model_state_json'] = Variable<String>(modelStateJson);
    map['phase'] = Variable<String>(phase);
    map['status'] = Variable<String>(status);
    map['due_at'] = Variable<DateTime>(dueAt);
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt);
    }
    map['review_count'] = Variable<int>(reviewCount);
    map['lapse_count'] = Variable<int>(lapseCount);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  MemorySchedulesCompanion toCompanion(bool nullToAbsent) {
    return MemorySchedulesCompanion(
      id: Value(id),
      namespace: Value(namespace),
      subjectId: Value(subjectId),
      profileId: Value(profileId),
      profileVersion: Value(profileVersion),
      modelId: Value(modelId),
      modelStateVersion: Value(modelStateVersion),
      modelStateJson: Value(modelStateJson),
      phase: Value(phase),
      status: Value(status),
      dueAt: Value(dueAt),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
      reviewCount: Value(reviewCount),
      lapseCount: Value(lapseCount),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory MemorySchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemorySchedule(
      id: serializer.fromJson<String>(json['id']),
      namespace: serializer.fromJson<String>(json['namespace']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      profileVersion: serializer.fromJson<int>(json['profileVersion']),
      modelId: serializer.fromJson<String>(json['modelId']),
      modelStateVersion: serializer.fromJson<int>(json['modelStateVersion']),
      modelStateJson: serializer.fromJson<String>(json['modelStateJson']),
      phase: serializer.fromJson<String>(json['phase']),
      status: serializer.fromJson<String>(json['status']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      lastReviewedAt: serializer.fromJson<DateTime?>(json['lastReviewedAt']),
      reviewCount: serializer.fromJson<int>(json['reviewCount']),
      lapseCount: serializer.fromJson<int>(json['lapseCount']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'namespace': serializer.toJson<String>(namespace),
      'subjectId': serializer.toJson<String>(subjectId),
      'profileId': serializer.toJson<String>(profileId),
      'profileVersion': serializer.toJson<int>(profileVersion),
      'modelId': serializer.toJson<String>(modelId),
      'modelStateVersion': serializer.toJson<int>(modelStateVersion),
      'modelStateJson': serializer.toJson<String>(modelStateJson),
      'phase': serializer.toJson<String>(phase),
      'status': serializer.toJson<String>(status),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'lastReviewedAt': serializer.toJson<DateTime?>(lastReviewedAt),
      'reviewCount': serializer.toJson<int>(reviewCount),
      'lapseCount': serializer.toJson<int>(lapseCount),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  MemorySchedule copyWith({
    String? id,
    String? namespace,
    String? subjectId,
    String? profileId,
    int? profileVersion,
    String? modelId,
    int? modelStateVersion,
    String? modelStateJson,
    String? phase,
    String? status,
    DateTime? dueAt,
    Value<DateTime?> lastReviewedAt = const Value.absent(),
    int? reviewCount,
    int? lapseCount,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => MemorySchedule(
    id: id ?? this.id,
    namespace: namespace ?? this.namespace,
    subjectId: subjectId ?? this.subjectId,
    profileId: profileId ?? this.profileId,
    profileVersion: profileVersion ?? this.profileVersion,
    modelId: modelId ?? this.modelId,
    modelStateVersion: modelStateVersion ?? this.modelStateVersion,
    modelStateJson: modelStateJson ?? this.modelStateJson,
    phase: phase ?? this.phase,
    status: status ?? this.status,
    dueAt: dueAt ?? this.dueAt,
    lastReviewedAt: lastReviewedAt.present
        ? lastReviewedAt.value
        : this.lastReviewedAt,
    reviewCount: reviewCount ?? this.reviewCount,
    lapseCount: lapseCount ?? this.lapseCount,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  MemorySchedule copyWithCompanion(MemorySchedulesCompanion data) {
    return MemorySchedule(
      id: data.id.present ? data.id.value : this.id,
      namespace: data.namespace.present ? data.namespace.value : this.namespace,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      profileVersion: data.profileVersion.present
          ? data.profileVersion.value
          : this.profileVersion,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      modelStateVersion: data.modelStateVersion.present
          ? data.modelStateVersion.value
          : this.modelStateVersion,
      modelStateJson: data.modelStateJson.present
          ? data.modelStateJson.value
          : this.modelStateJson,
      phase: data.phase.present ? data.phase.value : this.phase,
      status: data.status.present ? data.status.value : this.status,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
      reviewCount: data.reviewCount.present
          ? data.reviewCount.value
          : this.reviewCount,
      lapseCount: data.lapseCount.present
          ? data.lapseCount.value
          : this.lapseCount,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemorySchedule(')
          ..write('id: $id, ')
          ..write('namespace: $namespace, ')
          ..write('subjectId: $subjectId, ')
          ..write('profileId: $profileId, ')
          ..write('profileVersion: $profileVersion, ')
          ..write('modelId: $modelId, ')
          ..write('modelStateVersion: $modelStateVersion, ')
          ..write('modelStateJson: $modelStateJson, ')
          ..write('phase: $phase, ')
          ..write('status: $status, ')
          ..write('dueAt: $dueAt, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    namespace,
    subjectId,
    profileId,
    profileVersion,
    modelId,
    modelStateVersion,
    modelStateJson,
    phase,
    status,
    dueAt,
    lastReviewedAt,
    reviewCount,
    lapseCount,
    revision,
    createdAt,
    updatedAt,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemorySchedule &&
          other.id == this.id &&
          other.namespace == this.namespace &&
          other.subjectId == this.subjectId &&
          other.profileId == this.profileId &&
          other.profileVersion == this.profileVersion &&
          other.modelId == this.modelId &&
          other.modelStateVersion == this.modelStateVersion &&
          other.modelStateJson == this.modelStateJson &&
          other.phase == this.phase &&
          other.status == this.status &&
          other.dueAt == this.dueAt &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.reviewCount == this.reviewCount &&
          other.lapseCount == this.lapseCount &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt);
}

class MemorySchedulesCompanion extends UpdateCompanion<MemorySchedule> {
  final Value<String> id;
  final Value<String> namespace;
  final Value<String> subjectId;
  final Value<String> profileId;
  final Value<int> profileVersion;
  final Value<String> modelId;
  final Value<int> modelStateVersion;
  final Value<String> modelStateJson;
  final Value<String> phase;
  final Value<String> status;
  final Value<DateTime> dueAt;
  final Value<DateTime?> lastReviewedAt;
  final Value<int> reviewCount;
  final Value<int> lapseCount;
  final Value<int> revision;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const MemorySchedulesCompanion({
    this.id = const Value.absent(),
    this.namespace = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.profileVersion = const Value.absent(),
    this.modelId = const Value.absent(),
    this.modelStateVersion = const Value.absent(),
    this.modelStateJson = const Value.absent(),
    this.phase = const Value.absent(),
    this.status = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemorySchedulesCompanion.insert({
    required String id,
    required String namespace,
    required String subjectId,
    required String profileId,
    required int profileVersion,
    required String modelId,
    required int modelStateVersion,
    this.modelStateJson = const Value.absent(),
    required String phase,
    required String status,
    required DateTime dueAt,
    this.lastReviewedAt = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.revision = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       namespace = Value(namespace),
       subjectId = Value(subjectId),
       profileId = Value(profileId),
       profileVersion = Value(profileVersion),
       modelId = Value(modelId),
       modelStateVersion = Value(modelStateVersion),
       phase = Value(phase),
       status = Value(status),
       dueAt = Value(dueAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MemorySchedule> custom({
    Expression<String>? id,
    Expression<String>? namespace,
    Expression<String>? subjectId,
    Expression<String>? profileId,
    Expression<int>? profileVersion,
    Expression<String>? modelId,
    Expression<int>? modelStateVersion,
    Expression<String>? modelStateJson,
    Expression<String>? phase,
    Expression<String>? status,
    Expression<DateTime>? dueAt,
    Expression<DateTime>? lastReviewedAt,
    Expression<int>? reviewCount,
    Expression<int>? lapseCount,
    Expression<int>? revision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (namespace != null) 'namespace': namespace,
      if (subjectId != null) 'subject_id': subjectId,
      if (profileId != null) 'profile_id': profileId,
      if (profileVersion != null) 'profile_version': profileVersion,
      if (modelId != null) 'model_id': modelId,
      if (modelStateVersion != null) 'model_state_version': modelStateVersion,
      if (modelStateJson != null) 'model_state_json': modelStateJson,
      if (phase != null) 'phase': phase,
      if (status != null) 'status': status,
      if (dueAt != null) 'due_at': dueAt,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (reviewCount != null) 'review_count': reviewCount,
      if (lapseCount != null) 'lapse_count': lapseCount,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemorySchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? namespace,
    Value<String>? subjectId,
    Value<String>? profileId,
    Value<int>? profileVersion,
    Value<String>? modelId,
    Value<int>? modelStateVersion,
    Value<String>? modelStateJson,
    Value<String>? phase,
    Value<String>? status,
    Value<DateTime>? dueAt,
    Value<DateTime?>? lastReviewedAt,
    Value<int>? reviewCount,
    Value<int>? lapseCount,
    Value<int>? revision,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return MemorySchedulesCompanion(
      id: id ?? this.id,
      namespace: namespace ?? this.namespace,
      subjectId: subjectId ?? this.subjectId,
      profileId: profileId ?? this.profileId,
      profileVersion: profileVersion ?? this.profileVersion,
      modelId: modelId ?? this.modelId,
      modelStateVersion: modelStateVersion ?? this.modelStateVersion,
      modelStateJson: modelStateJson ?? this.modelStateJson,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      lapseCount: lapseCount ?? this.lapseCount,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (namespace.present) {
      map['namespace'] = Variable<String>(namespace.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (profileVersion.present) {
      map['profile_version'] = Variable<int>(profileVersion.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (modelStateVersion.present) {
      map['model_state_version'] = Variable<int>(modelStateVersion.value);
    }
    if (modelStateJson.present) {
      map['model_state_json'] = Variable<String>(modelStateJson.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt.value);
    }
    if (reviewCount.present) {
      map['review_count'] = Variable<int>(reviewCount.value);
    }
    if (lapseCount.present) {
      map['lapse_count'] = Variable<int>(lapseCount.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemorySchedulesCompanion(')
          ..write('id: $id, ')
          ..write('namespace: $namespace, ')
          ..write('subjectId: $subjectId, ')
          ..write('profileId: $profileId, ')
          ..write('profileVersion: $profileVersion, ')
          ..write('modelId: $modelId, ')
          ..write('modelStateVersion: $modelStateVersion, ')
          ..write('modelStateJson: $modelStateJson, ')
          ..write('phase: $phase, ')
          ..write('status: $status, ')
          ..write('dueAt: $dueAt, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryReviewEventsTable extends MemoryReviewEvents
    with TableInfo<$MemoryReviewEventsTable, MemoryReviewEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryReviewEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memory_schedules (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isLapseMeta = const VerificationMeta(
    'isLapse',
  );
  @override
  late final GeneratedColumn<bool> isLapse = GeneratedColumn<bool>(
    'is_lapse',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_lapse" IN (0, 1))',
    ),
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseTimeMsMeta = const VerificationMeta(
    'responseTimeMs',
  );
  @override
  late final GeneratedColumn<int> responseTimeMs = GeneratedColumn<int>(
    'response_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileVersionMeta = const VerificationMeta(
    'profileVersion',
  );
  @override
  late final GeneratedColumn<int> profileVersion = GeneratedColumn<int>(
    'profile_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelStateVersionMeta = const VerificationMeta(
    'modelStateVersion',
  );
  @override
  late final GeneratedColumn<int> modelStateVersion = GeneratedColumn<int>(
    'model_state_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueBeforeMeta = const VerificationMeta(
    'dueBefore',
  );
  @override
  late final GeneratedColumn<DateTime> dueBefore = GeneratedColumn<DateTime>(
    'due_before',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAfterMeta = const VerificationMeta(
    'dueAfter',
  );
  @override
  late final GeneratedColumn<DateTime> dueAfter = GeneratedColumn<DateTime>(
    'due_after',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleRevisionAfterMeta =
      const VerificationMeta('scheduleRevisionAfter');
  @override
  late final GeneratedColumn<int> scheduleRevisionAfter = GeneratedColumn<int>(
    'schedule_revision_after',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scheduleId,
    sequence,
    operationId,
    rating,
    isLapse,
    reviewedAt,
    responseTimeMs,
    profileId,
    profileVersion,
    modelId,
    modelStateVersion,
    dueBefore,
    dueAfter,
    scheduleRevisionAfter,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_review_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryReviewEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('is_lapse')) {
      context.handle(
        _isLapseMeta,
        isLapse.isAcceptableOrUnknown(data['is_lapse']!, _isLapseMeta),
      );
    } else if (isInserting) {
      context.missing(_isLapseMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('response_time_ms')) {
      context.handle(
        _responseTimeMsMeta,
        responseTimeMs.isAcceptableOrUnknown(
          data['response_time_ms']!,
          _responseTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('profile_version')) {
      context.handle(
        _profileVersionMeta,
        profileVersion.isAcceptableOrUnknown(
          data['profile_version']!,
          _profileVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profileVersionMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('model_state_version')) {
      context.handle(
        _modelStateVersionMeta,
        modelStateVersion.isAcceptableOrUnknown(
          data['model_state_version']!,
          _modelStateVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelStateVersionMeta);
    }
    if (data.containsKey('due_before')) {
      context.handle(
        _dueBeforeMeta,
        dueBefore.isAcceptableOrUnknown(data['due_before']!, _dueBeforeMeta),
      );
    } else if (isInserting) {
      context.missing(_dueBeforeMeta);
    }
    if (data.containsKey('due_after')) {
      context.handle(
        _dueAfterMeta,
        dueAfter.isAcceptableOrUnknown(data['due_after']!, _dueAfterMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAfterMeta);
    }
    if (data.containsKey('schedule_revision_after')) {
      context.handle(
        _scheduleRevisionAfterMeta,
        scheduleRevisionAfter.isAcceptableOrUnknown(
          data['schedule_revision_after']!,
          _scheduleRevisionAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleRevisionAfterMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scheduleId, sequence},
    {scheduleId, operationId},
  ];
  @override
  MemoryReviewEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryReviewEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      )!,
      isLapse: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_lapse'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at'],
      )!,
      responseTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}response_time_ms'],
      ),
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      profileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_version'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      modelStateVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}model_state_version'],
      )!,
      dueBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_before'],
      )!,
      dueAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_after'],
      )!,
      scheduleRevisionAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_revision_after'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MemoryReviewEventsTable createAlias(String alias) {
    return $MemoryReviewEventsTable(attachedDatabase, alias);
  }
}

class MemoryReviewEvent extends DataClass
    implements Insertable<MemoryReviewEvent> {
  final String id;
  final String scheduleId;
  final int sequence;
  final String operationId;
  final String rating;
  final bool isLapse;
  final DateTime reviewedAt;
  final int? responseTimeMs;
  final String profileId;
  final int profileVersion;
  final String modelId;
  final int modelStateVersion;
  final DateTime dueBefore;
  final DateTime dueAfter;
  final int scheduleRevisionAfter;
  final DateTime createdAt;
  const MemoryReviewEvent({
    required this.id,
    required this.scheduleId,
    required this.sequence,
    required this.operationId,
    required this.rating,
    required this.isLapse,
    required this.reviewedAt,
    this.responseTimeMs,
    required this.profileId,
    required this.profileVersion,
    required this.modelId,
    required this.modelStateVersion,
    required this.dueBefore,
    required this.dueAfter,
    required this.scheduleRevisionAfter,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['schedule_id'] = Variable<String>(scheduleId);
    map['sequence'] = Variable<int>(sequence);
    map['operation_id'] = Variable<String>(operationId);
    map['rating'] = Variable<String>(rating);
    map['is_lapse'] = Variable<bool>(isLapse);
    map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    if (!nullToAbsent || responseTimeMs != null) {
      map['response_time_ms'] = Variable<int>(responseTimeMs);
    }
    map['profile_id'] = Variable<String>(profileId);
    map['profile_version'] = Variable<int>(profileVersion);
    map['model_id'] = Variable<String>(modelId);
    map['model_state_version'] = Variable<int>(modelStateVersion);
    map['due_before'] = Variable<DateTime>(dueBefore);
    map['due_after'] = Variable<DateTime>(dueAfter);
    map['schedule_revision_after'] = Variable<int>(scheduleRevisionAfter);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MemoryReviewEventsCompanion toCompanion(bool nullToAbsent) {
    return MemoryReviewEventsCompanion(
      id: Value(id),
      scheduleId: Value(scheduleId),
      sequence: Value(sequence),
      operationId: Value(operationId),
      rating: Value(rating),
      isLapse: Value(isLapse),
      reviewedAt: Value(reviewedAt),
      responseTimeMs: responseTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(responseTimeMs),
      profileId: Value(profileId),
      profileVersion: Value(profileVersion),
      modelId: Value(modelId),
      modelStateVersion: Value(modelStateVersion),
      dueBefore: Value(dueBefore),
      dueAfter: Value(dueAfter),
      scheduleRevisionAfter: Value(scheduleRevisionAfter),
      createdAt: Value(createdAt),
    );
  }

  factory MemoryReviewEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryReviewEvent(
      id: serializer.fromJson<String>(json['id']),
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      operationId: serializer.fromJson<String>(json['operationId']),
      rating: serializer.fromJson<String>(json['rating']),
      isLapse: serializer.fromJson<bool>(json['isLapse']),
      reviewedAt: serializer.fromJson<DateTime>(json['reviewedAt']),
      responseTimeMs: serializer.fromJson<int?>(json['responseTimeMs']),
      profileId: serializer.fromJson<String>(json['profileId']),
      profileVersion: serializer.fromJson<int>(json['profileVersion']),
      modelId: serializer.fromJson<String>(json['modelId']),
      modelStateVersion: serializer.fromJson<int>(json['modelStateVersion']),
      dueBefore: serializer.fromJson<DateTime>(json['dueBefore']),
      dueAfter: serializer.fromJson<DateTime>(json['dueAfter']),
      scheduleRevisionAfter: serializer.fromJson<int>(
        json['scheduleRevisionAfter'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scheduleId': serializer.toJson<String>(scheduleId),
      'sequence': serializer.toJson<int>(sequence),
      'operationId': serializer.toJson<String>(operationId),
      'rating': serializer.toJson<String>(rating),
      'isLapse': serializer.toJson<bool>(isLapse),
      'reviewedAt': serializer.toJson<DateTime>(reviewedAt),
      'responseTimeMs': serializer.toJson<int?>(responseTimeMs),
      'profileId': serializer.toJson<String>(profileId),
      'profileVersion': serializer.toJson<int>(profileVersion),
      'modelId': serializer.toJson<String>(modelId),
      'modelStateVersion': serializer.toJson<int>(modelStateVersion),
      'dueBefore': serializer.toJson<DateTime>(dueBefore),
      'dueAfter': serializer.toJson<DateTime>(dueAfter),
      'scheduleRevisionAfter': serializer.toJson<int>(scheduleRevisionAfter),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MemoryReviewEvent copyWith({
    String? id,
    String? scheduleId,
    int? sequence,
    String? operationId,
    String? rating,
    bool? isLapse,
    DateTime? reviewedAt,
    Value<int?> responseTimeMs = const Value.absent(),
    String? profileId,
    int? profileVersion,
    String? modelId,
    int? modelStateVersion,
    DateTime? dueBefore,
    DateTime? dueAfter,
    int? scheduleRevisionAfter,
    DateTime? createdAt,
  }) => MemoryReviewEvent(
    id: id ?? this.id,
    scheduleId: scheduleId ?? this.scheduleId,
    sequence: sequence ?? this.sequence,
    operationId: operationId ?? this.operationId,
    rating: rating ?? this.rating,
    isLapse: isLapse ?? this.isLapse,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    responseTimeMs: responseTimeMs.present
        ? responseTimeMs.value
        : this.responseTimeMs,
    profileId: profileId ?? this.profileId,
    profileVersion: profileVersion ?? this.profileVersion,
    modelId: modelId ?? this.modelId,
    modelStateVersion: modelStateVersion ?? this.modelStateVersion,
    dueBefore: dueBefore ?? this.dueBefore,
    dueAfter: dueAfter ?? this.dueAfter,
    scheduleRevisionAfter: scheduleRevisionAfter ?? this.scheduleRevisionAfter,
    createdAt: createdAt ?? this.createdAt,
  );
  MemoryReviewEvent copyWithCompanion(MemoryReviewEventsCompanion data) {
    return MemoryReviewEvent(
      id: data.id.present ? data.id.value : this.id,
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      rating: data.rating.present ? data.rating.value : this.rating,
      isLapse: data.isLapse.present ? data.isLapse.value : this.isLapse,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      responseTimeMs: data.responseTimeMs.present
          ? data.responseTimeMs.value
          : this.responseTimeMs,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      profileVersion: data.profileVersion.present
          ? data.profileVersion.value
          : this.profileVersion,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      modelStateVersion: data.modelStateVersion.present
          ? data.modelStateVersion.value
          : this.modelStateVersion,
      dueBefore: data.dueBefore.present ? data.dueBefore.value : this.dueBefore,
      dueAfter: data.dueAfter.present ? data.dueAfter.value : this.dueAfter,
      scheduleRevisionAfter: data.scheduleRevisionAfter.present
          ? data.scheduleRevisionAfter.value
          : this.scheduleRevisionAfter,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryReviewEvent(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('sequence: $sequence, ')
          ..write('operationId: $operationId, ')
          ..write('rating: $rating, ')
          ..write('isLapse: $isLapse, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('responseTimeMs: $responseTimeMs, ')
          ..write('profileId: $profileId, ')
          ..write('profileVersion: $profileVersion, ')
          ..write('modelId: $modelId, ')
          ..write('modelStateVersion: $modelStateVersion, ')
          ..write('dueBefore: $dueBefore, ')
          ..write('dueAfter: $dueAfter, ')
          ..write('scheduleRevisionAfter: $scheduleRevisionAfter, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scheduleId,
    sequence,
    operationId,
    rating,
    isLapse,
    reviewedAt,
    responseTimeMs,
    profileId,
    profileVersion,
    modelId,
    modelStateVersion,
    dueBefore,
    dueAfter,
    scheduleRevisionAfter,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryReviewEvent &&
          other.id == this.id &&
          other.scheduleId == this.scheduleId &&
          other.sequence == this.sequence &&
          other.operationId == this.operationId &&
          other.rating == this.rating &&
          other.isLapse == this.isLapse &&
          other.reviewedAt == this.reviewedAt &&
          other.responseTimeMs == this.responseTimeMs &&
          other.profileId == this.profileId &&
          other.profileVersion == this.profileVersion &&
          other.modelId == this.modelId &&
          other.modelStateVersion == this.modelStateVersion &&
          other.dueBefore == this.dueBefore &&
          other.dueAfter == this.dueAfter &&
          other.scheduleRevisionAfter == this.scheduleRevisionAfter &&
          other.createdAt == this.createdAt);
}

class MemoryReviewEventsCompanion extends UpdateCompanion<MemoryReviewEvent> {
  final Value<String> id;
  final Value<String> scheduleId;
  final Value<int> sequence;
  final Value<String> operationId;
  final Value<String> rating;
  final Value<bool> isLapse;
  final Value<DateTime> reviewedAt;
  final Value<int?> responseTimeMs;
  final Value<String> profileId;
  final Value<int> profileVersion;
  final Value<String> modelId;
  final Value<int> modelStateVersion;
  final Value<DateTime> dueBefore;
  final Value<DateTime> dueAfter;
  final Value<int> scheduleRevisionAfter;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MemoryReviewEventsCompanion({
    this.id = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.operationId = const Value.absent(),
    this.rating = const Value.absent(),
    this.isLapse = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.responseTimeMs = const Value.absent(),
    this.profileId = const Value.absent(),
    this.profileVersion = const Value.absent(),
    this.modelId = const Value.absent(),
    this.modelStateVersion = const Value.absent(),
    this.dueBefore = const Value.absent(),
    this.dueAfter = const Value.absent(),
    this.scheduleRevisionAfter = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryReviewEventsCompanion.insert({
    required String id,
    required String scheduleId,
    required int sequence,
    required String operationId,
    required String rating,
    required bool isLapse,
    required DateTime reviewedAt,
    this.responseTimeMs = const Value.absent(),
    required String profileId,
    required int profileVersion,
    required String modelId,
    required int modelStateVersion,
    required DateTime dueBefore,
    required DateTime dueAfter,
    required int scheduleRevisionAfter,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scheduleId = Value(scheduleId),
       sequence = Value(sequence),
       operationId = Value(operationId),
       rating = Value(rating),
       isLapse = Value(isLapse),
       reviewedAt = Value(reviewedAt),
       profileId = Value(profileId),
       profileVersion = Value(profileVersion),
       modelId = Value(modelId),
       modelStateVersion = Value(modelStateVersion),
       dueBefore = Value(dueBefore),
       dueAfter = Value(dueAfter),
       scheduleRevisionAfter = Value(scheduleRevisionAfter),
       createdAt = Value(createdAt);
  static Insertable<MemoryReviewEvent> custom({
    Expression<String>? id,
    Expression<String>? scheduleId,
    Expression<int>? sequence,
    Expression<String>? operationId,
    Expression<String>? rating,
    Expression<bool>? isLapse,
    Expression<DateTime>? reviewedAt,
    Expression<int>? responseTimeMs,
    Expression<String>? profileId,
    Expression<int>? profileVersion,
    Expression<String>? modelId,
    Expression<int>? modelStateVersion,
    Expression<DateTime>? dueBefore,
    Expression<DateTime>? dueAfter,
    Expression<int>? scheduleRevisionAfter,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (sequence != null) 'sequence': sequence,
      if (operationId != null) 'operation_id': operationId,
      if (rating != null) 'rating': rating,
      if (isLapse != null) 'is_lapse': isLapse,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (responseTimeMs != null) 'response_time_ms': responseTimeMs,
      if (profileId != null) 'profile_id': profileId,
      if (profileVersion != null) 'profile_version': profileVersion,
      if (modelId != null) 'model_id': modelId,
      if (modelStateVersion != null) 'model_state_version': modelStateVersion,
      if (dueBefore != null) 'due_before': dueBefore,
      if (dueAfter != null) 'due_after': dueAfter,
      if (scheduleRevisionAfter != null)
        'schedule_revision_after': scheduleRevisionAfter,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryReviewEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? scheduleId,
    Value<int>? sequence,
    Value<String>? operationId,
    Value<String>? rating,
    Value<bool>? isLapse,
    Value<DateTime>? reviewedAt,
    Value<int?>? responseTimeMs,
    Value<String>? profileId,
    Value<int>? profileVersion,
    Value<String>? modelId,
    Value<int>? modelStateVersion,
    Value<DateTime>? dueBefore,
    Value<DateTime>? dueAfter,
    Value<int>? scheduleRevisionAfter,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MemoryReviewEventsCompanion(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      sequence: sequence ?? this.sequence,
      operationId: operationId ?? this.operationId,
      rating: rating ?? this.rating,
      isLapse: isLapse ?? this.isLapse,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      profileId: profileId ?? this.profileId,
      profileVersion: profileVersion ?? this.profileVersion,
      modelId: modelId ?? this.modelId,
      modelStateVersion: modelStateVersion ?? this.modelStateVersion,
      dueBefore: dueBefore ?? this.dueBefore,
      dueAfter: dueAfter ?? this.dueAfter,
      scheduleRevisionAfter:
          scheduleRevisionAfter ?? this.scheduleRevisionAfter,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (isLapse.present) {
      map['is_lapse'] = Variable<bool>(isLapse.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (responseTimeMs.present) {
      map['response_time_ms'] = Variable<int>(responseTimeMs.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (profileVersion.present) {
      map['profile_version'] = Variable<int>(profileVersion.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (modelStateVersion.present) {
      map['model_state_version'] = Variable<int>(modelStateVersion.value);
    }
    if (dueBefore.present) {
      map['due_before'] = Variable<DateTime>(dueBefore.value);
    }
    if (dueAfter.present) {
      map['due_after'] = Variable<DateTime>(dueAfter.value);
    }
    if (scheduleRevisionAfter.present) {
      map['schedule_revision_after'] = Variable<int>(
        scheduleRevisionAfter.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryReviewEventsCompanion(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('sequence: $sequence, ')
          ..write('operationId: $operationId, ')
          ..write('rating: $rating, ')
          ..write('isLapse: $isLapse, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('responseTimeMs: $responseTimeMs, ')
          ..write('profileId: $profileId, ')
          ..write('profileVersion: $profileVersion, ')
          ..write('modelId: $modelId, ')
          ..write('modelStateVersion: $modelStateVersion, ')
          ..write('dueBefore: $dueBefore, ')
          ..write('dueAfter: $dueAfter, ')
          ..write('scheduleRevisionAfter: $scheduleRevisionAfter, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryReviewQueueEntriesTable extends MemoryReviewQueueEntries
    with TableInfo<$MemoryReviewQueueEntriesTable, MemoryReviewQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryReviewQueueEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _namespaceMeta = const VerificationMeta(
    'namespace',
  );
  @override
  late final GeneratedColumn<String> namespace = GeneratedColumn<String>(
    'namespace',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enqueuedAtMeta = const VerificationMeta(
    'enqueuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> enqueuedAt = GeneratedColumn<DateTime>(
    'enqueued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    namespace,
    subjectId,
    localDate,
    enqueuedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_review_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryReviewQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('namespace')) {
      context.handle(
        _namespaceMeta,
        namespace.isAcceptableOrUnknown(data['namespace']!, _namespaceMeta),
      );
    } else if (isInserting) {
      context.missing(_namespaceMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('enqueued_at')) {
      context.handle(
        _enqueuedAtMeta,
        enqueuedAt.isAcceptableOrUnknown(data['enqueued_at']!, _enqueuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enqueuedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {namespace, subjectId, localDate},
  ];
  @override
  MemoryReviewQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryReviewQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      namespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}namespace'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      enqueuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}enqueued_at'],
      )!,
    );
  }

  @override
  $MemoryReviewQueueEntriesTable createAlias(String alias) {
    return $MemoryReviewQueueEntriesTable(attachedDatabase, alias);
  }
}

class MemoryReviewQueueEntry extends DataClass
    implements Insertable<MemoryReviewQueueEntry> {
  final int id;
  final String namespace;
  final String subjectId;
  final String localDate;
  final DateTime enqueuedAt;
  const MemoryReviewQueueEntry({
    required this.id,
    required this.namespace,
    required this.subjectId,
    required this.localDate,
    required this.enqueuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['namespace'] = Variable<String>(namespace);
    map['subject_id'] = Variable<String>(subjectId);
    map['local_date'] = Variable<String>(localDate);
    map['enqueued_at'] = Variable<DateTime>(enqueuedAt);
    return map;
  }

  MemoryReviewQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return MemoryReviewQueueEntriesCompanion(
      id: Value(id),
      namespace: Value(namespace),
      subjectId: Value(subjectId),
      localDate: Value(localDate),
      enqueuedAt: Value(enqueuedAt),
    );
  }

  factory MemoryReviewQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryReviewQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      namespace: serializer.fromJson<String>(json['namespace']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      localDate: serializer.fromJson<String>(json['localDate']),
      enqueuedAt: serializer.fromJson<DateTime>(json['enqueuedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'namespace': serializer.toJson<String>(namespace),
      'subjectId': serializer.toJson<String>(subjectId),
      'localDate': serializer.toJson<String>(localDate),
      'enqueuedAt': serializer.toJson<DateTime>(enqueuedAt),
    };
  }

  MemoryReviewQueueEntry copyWith({
    int? id,
    String? namespace,
    String? subjectId,
    String? localDate,
    DateTime? enqueuedAt,
  }) => MemoryReviewQueueEntry(
    id: id ?? this.id,
    namespace: namespace ?? this.namespace,
    subjectId: subjectId ?? this.subjectId,
    localDate: localDate ?? this.localDate,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
  );
  MemoryReviewQueueEntry copyWithCompanion(
    MemoryReviewQueueEntriesCompanion data,
  ) {
    return MemoryReviewQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      namespace: data.namespace.present ? data.namespace.value : this.namespace,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      enqueuedAt: data.enqueuedAt.present
          ? data.enqueuedAt.value
          : this.enqueuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryReviewQueueEntry(')
          ..write('id: $id, ')
          ..write('namespace: $namespace, ')
          ..write('subjectId: $subjectId, ')
          ..write('localDate: $localDate, ')
          ..write('enqueuedAt: $enqueuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, namespace, subjectId, localDate, enqueuedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryReviewQueueEntry &&
          other.id == this.id &&
          other.namespace == this.namespace &&
          other.subjectId == this.subjectId &&
          other.localDate == this.localDate &&
          other.enqueuedAt == this.enqueuedAt);
}

class MemoryReviewQueueEntriesCompanion
    extends UpdateCompanion<MemoryReviewQueueEntry> {
  final Value<int> id;
  final Value<String> namespace;
  final Value<String> subjectId;
  final Value<String> localDate;
  final Value<DateTime> enqueuedAt;
  const MemoryReviewQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.namespace = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.localDate = const Value.absent(),
    this.enqueuedAt = const Value.absent(),
  });
  MemoryReviewQueueEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String namespace,
    required String subjectId,
    required String localDate,
    required DateTime enqueuedAt,
  }) : namespace = Value(namespace),
       subjectId = Value(subjectId),
       localDate = Value(localDate),
       enqueuedAt = Value(enqueuedAt);
  static Insertable<MemoryReviewQueueEntry> custom({
    Expression<int>? id,
    Expression<String>? namespace,
    Expression<String>? subjectId,
    Expression<String>? localDate,
    Expression<DateTime>? enqueuedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (namespace != null) 'namespace': namespace,
      if (subjectId != null) 'subject_id': subjectId,
      if (localDate != null) 'local_date': localDate,
      if (enqueuedAt != null) 'enqueued_at': enqueuedAt,
    });
  }

  MemoryReviewQueueEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? namespace,
    Value<String>? subjectId,
    Value<String>? localDate,
    Value<DateTime>? enqueuedAt,
  }) {
    return MemoryReviewQueueEntriesCompanion(
      id: id ?? this.id,
      namespace: namespace ?? this.namespace,
      subjectId: subjectId ?? this.subjectId,
      localDate: localDate ?? this.localDate,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (namespace.present) {
      map['namespace'] = Variable<String>(namespace.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (enqueuedAt.present) {
      map['enqueued_at'] = Variable<DateTime>(enqueuedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryReviewQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('namespace: $namespace, ')
          ..write('subjectId: $subjectId, ')
          ..write('localDate: $localDate, ')
          ..write('enqueuedAt: $enqueuedAt')
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
  late final $TtsCacheTable ttsCache = $TtsCacheTable(this);
  late final $MemorySchedulesTable memorySchedules = $MemorySchedulesTable(
    this,
  );
  late final $MemoryReviewEventsTable memoryReviewEvents =
      $MemoryReviewEventsTable(this);
  late final $MemoryReviewQueueEntriesTable memoryReviewQueueEntries =
      $MemoryReviewQueueEntriesTable(this);
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
  late final StudyStatisticsDao studyStatisticsDao = StudyStatisticsDao(
    this as AppDatabase,
  );
  late final TtsCacheDao ttsCacheDao = TtsCacheDao(this as AppDatabase);
  late final MemoryScheduleDao memoryScheduleDao = MemoryScheduleDao(
    this as AppDatabase,
  );
  late final FavoriteReviewDao favoriteReviewDao = FavoriteReviewDao(
    this as AppDatabase,
  );
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
    ttsCache,
    memorySchedules,
    memoryReviewEvents,
    memoryReviewQueueEntries,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'memory_schedules',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('memory_review_events', kind: UpdateKind.delete)],
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
      Value<String?> originalAudioSha256,
      Value<String?> transcriptLanguage,
      Value<int?> audioContentStatus,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<String?> wordTimestampsJson,
      Value<String?> transcriptSrt,
      Value<int> syncStatus,
      Value<String?> remoteAudioId,
      Value<DateTime?> originalDate,
      Value<DateTime?> communityUnavailableAt,
      Value<String?> communityDifficulty,
      Value<String?> importSourceType,
      Value<String?> importSourceUrl,
      Value<String?> podcastEpisodeGuid,
      Value<String?> podcastEnclosureUrl,
      Value<String?> podcastEnclosureType,
      Value<String?> podcastDescription,
      Value<String?> podcastImageUrl,
      Value<String?> podcastLink,
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
      Value<String?> originalAudioSha256,
      Value<String?> transcriptLanguage,
      Value<int?> audioContentStatus,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String?> wordTimestampsJson,
      Value<String?> transcriptSrt,
      Value<int> syncStatus,
      Value<String?> remoteAudioId,
      Value<DateTime?> originalDate,
      Value<DateTime?> communityUnavailableAt,
      Value<String?> communityDifficulty,
      Value<String?> importSourceType,
      Value<String?> importSourceUrl,
      Value<String?> podcastEpisodeGuid,
      Value<String?> podcastEnclosureUrl,
      Value<String?> podcastEnclosureType,
      Value<String?> podcastDescription,
      Value<String?> podcastImageUrl,
      Value<String?> podcastLink,
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

  ColumnFilters<String> get originalAudioSha256 => $composableBuilder(
    column: $table.originalAudioSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioContentStatus => $composableBuilder(
    column: $table.audioContentStatus,
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

  ColumnFilters<String> get transcriptSrt => $composableBuilder(
    column: $table.transcriptSrt,
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

  ColumnFilters<DateTime> get communityUnavailableAt => $composableBuilder(
    column: $table.communityUnavailableAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get communityDifficulty => $composableBuilder(
    column: $table.communityDifficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importSourceType => $composableBuilder(
    column: $table.importSourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importSourceUrl => $composableBuilder(
    column: $table.importSourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastEpisodeGuid => $composableBuilder(
    column: $table.podcastEpisodeGuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastEnclosureUrl => $composableBuilder(
    column: $table.podcastEnclosureUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastEnclosureType => $composableBuilder(
    column: $table.podcastEnclosureType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastDescription => $composableBuilder(
    column: $table.podcastDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastImageUrl => $composableBuilder(
    column: $table.podcastImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastLink => $composableBuilder(
    column: $table.podcastLink,
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

  ColumnOrderings<String> get originalAudioSha256 => $composableBuilder(
    column: $table.originalAudioSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioContentStatus => $composableBuilder(
    column: $table.audioContentStatus,
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

  ColumnOrderings<String> get transcriptSrt => $composableBuilder(
    column: $table.transcriptSrt,
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

  ColumnOrderings<DateTime> get communityUnavailableAt => $composableBuilder(
    column: $table.communityUnavailableAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get communityDifficulty => $composableBuilder(
    column: $table.communityDifficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importSourceType => $composableBuilder(
    column: $table.importSourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importSourceUrl => $composableBuilder(
    column: $table.importSourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastEpisodeGuid => $composableBuilder(
    column: $table.podcastEpisodeGuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastEnclosureUrl => $composableBuilder(
    column: $table.podcastEnclosureUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastEnclosureType => $composableBuilder(
    column: $table.podcastEnclosureType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastDescription => $composableBuilder(
    column: $table.podcastDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastImageUrl => $composableBuilder(
    column: $table.podcastImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastLink => $composableBuilder(
    column: $table.podcastLink,
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

  GeneratedColumn<String> get originalAudioSha256 => $composableBuilder(
    column: $table.originalAudioSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioContentStatus => $composableBuilder(
    column: $table.audioContentStatus,
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

  GeneratedColumn<String> get transcriptSrt => $composableBuilder(
    column: $table.transcriptSrt,
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

  GeneratedColumn<DateTime> get communityUnavailableAt => $composableBuilder(
    column: $table.communityUnavailableAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get communityDifficulty => $composableBuilder(
    column: $table.communityDifficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importSourceType => $composableBuilder(
    column: $table.importSourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importSourceUrl => $composableBuilder(
    column: $table.importSourceUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastEpisodeGuid => $composableBuilder(
    column: $table.podcastEpisodeGuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastEnclosureUrl => $composableBuilder(
    column: $table.podcastEnclosureUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastEnclosureType => $composableBuilder(
    column: $table.podcastEnclosureType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastDescription => $composableBuilder(
    column: $table.podcastDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastImageUrl => $composableBuilder(
    column: $table.podcastImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastLink => $composableBuilder(
    column: $table.podcastLink,
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
                Value<String?> originalAudioSha256 = const Value.absent(),
                Value<String?> transcriptLanguage = const Value.absent(),
                Value<int?> audioContentStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> wordTimestampsJson = const Value.absent(),
                Value<String?> transcriptSrt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> remoteAudioId = const Value.absent(),
                Value<DateTime?> originalDate = const Value.absent(),
                Value<DateTime?> communityUnavailableAt = const Value.absent(),
                Value<String?> communityDifficulty = const Value.absent(),
                Value<String?> importSourceType = const Value.absent(),
                Value<String?> importSourceUrl = const Value.absent(),
                Value<String?> podcastEpisodeGuid = const Value.absent(),
                Value<String?> podcastEnclosureUrl = const Value.absent(),
                Value<String?> podcastEnclosureType = const Value.absent(),
                Value<String?> podcastDescription = const Value.absent(),
                Value<String?> podcastImageUrl = const Value.absent(),
                Value<String?> podcastLink = const Value.absent(),
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
                originalAudioSha256: originalAudioSha256,
                transcriptLanguage: transcriptLanguage,
                audioContentStatus: audioContentStatus,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                wordTimestampsJson: wordTimestampsJson,
                transcriptSrt: transcriptSrt,
                syncStatus: syncStatus,
                remoteAudioId: remoteAudioId,
                originalDate: originalDate,
                communityUnavailableAt: communityUnavailableAt,
                communityDifficulty: communityDifficulty,
                importSourceType: importSourceType,
                importSourceUrl: importSourceUrl,
                podcastEpisodeGuid: podcastEpisodeGuid,
                podcastEnclosureUrl: podcastEnclosureUrl,
                podcastEnclosureType: podcastEnclosureType,
                podcastDescription: podcastDescription,
                podcastImageUrl: podcastImageUrl,
                podcastLink: podcastLink,
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
                Value<String?> originalAudioSha256 = const Value.absent(),
                Value<String?> transcriptLanguage = const Value.absent(),
                Value<int?> audioContentStatus = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> wordTimestampsJson = const Value.absent(),
                Value<String?> transcriptSrt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> remoteAudioId = const Value.absent(),
                Value<DateTime?> originalDate = const Value.absent(),
                Value<DateTime?> communityUnavailableAt = const Value.absent(),
                Value<String?> communityDifficulty = const Value.absent(),
                Value<String?> importSourceType = const Value.absent(),
                Value<String?> importSourceUrl = const Value.absent(),
                Value<String?> podcastEpisodeGuid = const Value.absent(),
                Value<String?> podcastEnclosureUrl = const Value.absent(),
                Value<String?> podcastEnclosureType = const Value.absent(),
                Value<String?> podcastDescription = const Value.absent(),
                Value<String?> podcastImageUrl = const Value.absent(),
                Value<String?> podcastLink = const Value.absent(),
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
                originalAudioSha256: originalAudioSha256,
                transcriptLanguage: transcriptLanguage,
                audioContentStatus: audioContentStatus,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                wordTimestampsJson: wordTimestampsJson,
                transcriptSrt: transcriptSrt,
                syncStatus: syncStatus,
                remoteAudioId: remoteAudioId,
                originalDate: originalDate,
                communityUnavailableAt: communityUnavailableAt,
                communityDifficulty: communityDifficulty,
                importSourceType: importSourceType,
                importSourceUrl: importSourceUrl,
                podcastEpisodeGuid: podcastEpisodeGuid,
                podcastEnclosureUrl: podcastEnclosureUrl,
                podcastEnclosureType: podcastEnclosureType,
                podcastDescription: podcastDescription,
                podcastImageUrl: podcastImageUrl,
                podcastLink: podcastLink,
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
      Value<String?> coverUrlChina,
      Value<String?> description,
      Value<String?> authorNickname,
      Value<DateTime?> publishedAt,
      Value<DateTime?> deprecatedAt,
      Value<String?> podcastInputUrl,
      Value<String?> podcastFeedUrl,
      Value<String?> podcastMetaJson,
      Value<DateTime?> podcastLastRefreshedAt,
      Value<String?> podcastLastRefreshError,
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
      Value<String?> coverUrlChina,
      Value<String?> description,
      Value<String?> authorNickname,
      Value<DateTime?> publishedAt,
      Value<DateTime?> deprecatedAt,
      Value<String?> podcastInputUrl,
      Value<String?> podcastFeedUrl,
      Value<String?> podcastMetaJson,
      Value<DateTime?> podcastLastRefreshedAt,
      Value<String?> podcastLastRefreshError,
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

  ColumnFilters<String> get coverUrlChina => $composableBuilder(
    column: $table.coverUrlChina,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorNickname => $composableBuilder(
    column: $table.authorNickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deprecatedAt => $composableBuilder(
    column: $table.deprecatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastInputUrl => $composableBuilder(
    column: $table.podcastInputUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastFeedUrl => $composableBuilder(
    column: $table.podcastFeedUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastMetaJson => $composableBuilder(
    column: $table.podcastMetaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get podcastLastRefreshedAt => $composableBuilder(
    column: $table.podcastLastRefreshedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get podcastLastRefreshError => $composableBuilder(
    column: $table.podcastLastRefreshError,
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

  ColumnOrderings<String> get coverUrlChina => $composableBuilder(
    column: $table.coverUrlChina,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorNickname => $composableBuilder(
    column: $table.authorNickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deprecatedAt => $composableBuilder(
    column: $table.deprecatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastInputUrl => $composableBuilder(
    column: $table.podcastInputUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastFeedUrl => $composableBuilder(
    column: $table.podcastFeedUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastMetaJson => $composableBuilder(
    column: $table.podcastMetaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get podcastLastRefreshedAt => $composableBuilder(
    column: $table.podcastLastRefreshedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get podcastLastRefreshError => $composableBuilder(
    column: $table.podcastLastRefreshError,
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

  GeneratedColumn<String> get coverUrlChina => $composableBuilder(
    column: $table.coverUrlChina,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorNickname => $composableBuilder(
    column: $table.authorNickname,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deprecatedAt => $composableBuilder(
    column: $table.deprecatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastInputUrl => $composableBuilder(
    column: $table.podcastInputUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastFeedUrl => $composableBuilder(
    column: $table.podcastFeedUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastMetaJson => $composableBuilder(
    column: $table.podcastMetaJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get podcastLastRefreshedAt => $composableBuilder(
    column: $table.podcastLastRefreshedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get podcastLastRefreshError => $composableBuilder(
    column: $table.podcastLastRefreshError,
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
                Value<String?> coverUrlChina = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> authorNickname = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<DateTime?> deprecatedAt = const Value.absent(),
                Value<String?> podcastInputUrl = const Value.absent(),
                Value<String?> podcastFeedUrl = const Value.absent(),
                Value<String?> podcastMetaJson = const Value.absent(),
                Value<DateTime?> podcastLastRefreshedAt = const Value.absent(),
                Value<String?> podcastLastRefreshError = const Value.absent(),
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
                coverUrlChina: coverUrlChina,
                description: description,
                authorNickname: authorNickname,
                publishedAt: publishedAt,
                deprecatedAt: deprecatedAt,
                podcastInputUrl: podcastInputUrl,
                podcastFeedUrl: podcastFeedUrl,
                podcastMetaJson: podcastMetaJson,
                podcastLastRefreshedAt: podcastLastRefreshedAt,
                podcastLastRefreshError: podcastLastRefreshError,
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
                Value<String?> coverUrlChina = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> authorNickname = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<DateTime?> deprecatedAt = const Value.absent(),
                Value<String?> podcastInputUrl = const Value.absent(),
                Value<String?> podcastFeedUrl = const Value.absent(),
                Value<String?> podcastMetaJson = const Value.absent(),
                Value<DateTime?> podcastLastRefreshedAt = const Value.absent(),
                Value<String?> podcastLastRefreshError = const Value.absent(),
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
                coverUrlChina: coverUrlChina,
                description: description,
                authorNickname: authorNickname,
                publishedAt: publishedAt,
                deprecatedAt: deprecatedAt,
                podcastInputUrl: podcastInputUrl,
                podcastFeedUrl: podcastFeedUrl,
                podcastMetaJson: podcastMetaJson,
                podcastLastRefreshedAt: podcastLastRefreshedAt,
                podcastLastRefreshError: podcastLastRefreshError,
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
      Value<String?> memorySubjectId,
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
      Value<String?> memorySubjectId,
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

  ColumnFilters<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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

  ColumnOrderings<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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

  GeneratedColumn<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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
                Value<String?> memorySubjectId = const Value.absent(),
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
                memorySubjectId: memorySubjectId,
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
                Value<String?> memorySubjectId = const Value.absent(),
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
                memorySubjectId: memorySubjectId,
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
      Value<int?> retellSentenceIndex,
      Value<int?> retellPassCount,
      Value<int?> blindListenSentenceIndex,
      Value<int?> freePlayBlindListenSentenceIndex,
      Value<int?> freePlayIntensiveListenSentenceIndex,
      Value<int?> freePlayShadowingSentenceIndex,
      Value<int?> freePlayDifficultPracticeSentenceIndex,
      Value<int?> freePlayRetellSentenceIndex,
      Value<DateTime?> newLearningBreakpointSavedAt,
      Value<DateTime?> freePlayBreakpointSavedAt,
      required DateTime updatedAt,
      Value<String> skippedSubStages,
      Value<bool> isPaused,
      Value<DateTime?> manualUnlockAt,
      Value<String> planVersionsJson,
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
      Value<int?> retellSentenceIndex,
      Value<int?> retellPassCount,
      Value<int?> blindListenSentenceIndex,
      Value<int?> freePlayBlindListenSentenceIndex,
      Value<int?> freePlayIntensiveListenSentenceIndex,
      Value<int?> freePlayShadowingSentenceIndex,
      Value<int?> freePlayDifficultPracticeSentenceIndex,
      Value<int?> freePlayRetellSentenceIndex,
      Value<DateTime?> newLearningBreakpointSavedAt,
      Value<DateTime?> freePlayBreakpointSavedAt,
      Value<DateTime> updatedAt,
      Value<String> skippedSubStages,
      Value<bool> isPaused,
      Value<DateTime?> manualUnlockAt,
      Value<String> planVersionsJson,
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

  ColumnFilters<int> get retellSentenceIndex => $composableBuilder(
    column: $table.retellSentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retellPassCount => $composableBuilder(
    column: $table.retellPassCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blindListenSentenceIndex => $composableBuilder(
    column: $table.blindListenSentenceIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freePlayBlindListenSentenceIndex => $composableBuilder(
    column: $table.freePlayBlindListenSentenceIndex,
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

  ColumnFilters<int> get freePlayRetellSentenceIndex => $composableBuilder(
    column: $table.freePlayRetellSentenceIndex,
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

  ColumnFilters<bool> get isPaused => $composableBuilder(
    column: $table.isPaused,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get manualUnlockAt => $composableBuilder(
    column: $table.manualUnlockAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planVersionsJson => $composableBuilder(
    column: $table.planVersionsJson,
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

  ColumnOrderings<int> get retellSentenceIndex => $composableBuilder(
    column: $table.retellSentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retellPassCount => $composableBuilder(
    column: $table.retellPassCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blindListenSentenceIndex => $composableBuilder(
    column: $table.blindListenSentenceIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freePlayBlindListenSentenceIndex =>
      $composableBuilder(
        column: $table.freePlayBlindListenSentenceIndex,
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

  ColumnOrderings<int> get freePlayRetellSentenceIndex => $composableBuilder(
    column: $table.freePlayRetellSentenceIndex,
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

  ColumnOrderings<bool> get isPaused => $composableBuilder(
    column: $table.isPaused,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get manualUnlockAt => $composableBuilder(
    column: $table.manualUnlockAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planVersionsJson => $composableBuilder(
    column: $table.planVersionsJson,
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

  GeneratedColumn<int> get retellSentenceIndex => $composableBuilder(
    column: $table.retellSentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retellPassCount => $composableBuilder(
    column: $table.retellPassCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blindListenSentenceIndex => $composableBuilder(
    column: $table.blindListenSentenceIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get freePlayBlindListenSentenceIndex =>
      $composableBuilder(
        column: $table.freePlayBlindListenSentenceIndex,
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

  GeneratedColumn<int> get freePlayRetellSentenceIndex => $composableBuilder(
    column: $table.freePlayRetellSentenceIndex,
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

  GeneratedColumn<bool> get isPaused =>
      $composableBuilder(column: $table.isPaused, builder: (column) => column);

  GeneratedColumn<DateTime> get manualUnlockAt => $composableBuilder(
    column: $table.manualUnlockAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get planVersionsJson => $composableBuilder(
    column: $table.planVersionsJson,
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
                Value<int?> retellSentenceIndex = const Value.absent(),
                Value<int?> retellPassCount = const Value.absent(),
                Value<int?> blindListenSentenceIndex = const Value.absent(),
                Value<int?> freePlayBlindListenSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayIntensiveListenSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayShadowingSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayDifficultPracticeSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayRetellSentenceIndex = const Value.absent(),
                Value<DateTime?> newLearningBreakpointSavedAt =
                    const Value.absent(),
                Value<DateTime?> freePlayBreakpointSavedAt =
                    const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> skippedSubStages = const Value.absent(),
                Value<bool> isPaused = const Value.absent(),
                Value<DateTime?> manualUnlockAt = const Value.absent(),
                Value<String> planVersionsJson = const Value.absent(),
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
                retellSentenceIndex: retellSentenceIndex,
                retellPassCount: retellPassCount,
                blindListenSentenceIndex: blindListenSentenceIndex,
                freePlayBlindListenSentenceIndex:
                    freePlayBlindListenSentenceIndex,
                freePlayIntensiveListenSentenceIndex:
                    freePlayIntensiveListenSentenceIndex,
                freePlayShadowingSentenceIndex: freePlayShadowingSentenceIndex,
                freePlayDifficultPracticeSentenceIndex:
                    freePlayDifficultPracticeSentenceIndex,
                freePlayRetellSentenceIndex: freePlayRetellSentenceIndex,
                newLearningBreakpointSavedAt: newLearningBreakpointSavedAt,
                freePlayBreakpointSavedAt: freePlayBreakpointSavedAt,
                updatedAt: updatedAt,
                skippedSubStages: skippedSubStages,
                isPaused: isPaused,
                manualUnlockAt: manualUnlockAt,
                planVersionsJson: planVersionsJson,
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
                Value<int?> retellSentenceIndex = const Value.absent(),
                Value<int?> retellPassCount = const Value.absent(),
                Value<int?> blindListenSentenceIndex = const Value.absent(),
                Value<int?> freePlayBlindListenSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayIntensiveListenSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayShadowingSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayDifficultPracticeSentenceIndex =
                    const Value.absent(),
                Value<int?> freePlayRetellSentenceIndex = const Value.absent(),
                Value<DateTime?> newLearningBreakpointSavedAt =
                    const Value.absent(),
                Value<DateTime?> freePlayBreakpointSavedAt =
                    const Value.absent(),
                required DateTime updatedAt,
                Value<String> skippedSubStages = const Value.absent(),
                Value<bool> isPaused = const Value.absent(),
                Value<DateTime?> manualUnlockAt = const Value.absent(),
                Value<String> planVersionsJson = const Value.absent(),
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
                retellSentenceIndex: retellSentenceIndex,
                retellPassCount: retellPassCount,
                blindListenSentenceIndex: blindListenSentenceIndex,
                freePlayBlindListenSentenceIndex:
                    freePlayBlindListenSentenceIndex,
                freePlayIntensiveListenSentenceIndex:
                    freePlayIntensiveListenSentenceIndex,
                freePlayShadowingSentenceIndex: freePlayShadowingSentenceIndex,
                freePlayDifficultPracticeSentenceIndex:
                    freePlayDifficultPracticeSentenceIndex,
                freePlayRetellSentenceIndex: freePlayRetellSentenceIndex,
                newLearningBreakpointSavedAt: newLearningBreakpointSavedAt,
                freePlayBreakpointSavedAt: freePlayBreakpointSavedAt,
                updatedAt: updatedAt,
                skippedSubStages: skippedSubStages,
                isPaused: isPaused,
                manualUnlockAt: manualUnlockAt,
                planVersionsJson: planVersionsJson,
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
      Value<String?> memorySubjectId,
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
      Value<String?> memorySubjectId,
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

  ColumnFilters<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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

  ColumnOrderings<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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

  GeneratedColumn<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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
                Value<String?> memorySubjectId = const Value.absent(),
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
                memorySubjectId: memorySubjectId,
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
                Value<String?> memorySubjectId = const Value.absent(),
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
                memorySubjectId: memorySubjectId,
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
      Value<String?> memorySubjectId,
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
      Value<String?> memorySubjectId,
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

  ColumnFilters<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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

  ColumnOrderings<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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

  GeneratedColumn<String> get memorySubjectId => $composableBuilder(
    column: $table.memorySubjectId,
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
                Value<String?> memorySubjectId = const Value.absent(),
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
                memorySubjectId: memorySubjectId,
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
                Value<String?> memorySubjectId = const Value.absent(),
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
                memorySubjectId: memorySubjectId,
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
      Value<int> studyTimeMilliseconds,
      Value<int> inputWords,
      Value<int> outputWords,
      Value<int> inputTimeSeconds,
      Value<int> inputTimeMilliseconds,
      Value<int> outputTimeSeconds,
      Value<int> outputTimeMilliseconds,
    });
typedef $$DailyStudyRecordsTableUpdateCompanionBuilder =
    DailyStudyRecordsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<int> studyTimeSeconds,
      Value<int> studyTimeMilliseconds,
      Value<int> inputWords,
      Value<int> outputWords,
      Value<int> inputTimeSeconds,
      Value<int> inputTimeMilliseconds,
      Value<int> outputTimeSeconds,
      Value<int> outputTimeMilliseconds,
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

  ColumnFilters<int> get studyTimeMilliseconds => $composableBuilder(
    column: $table.studyTimeMilliseconds,
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

  ColumnFilters<int> get inputTimeMilliseconds => $composableBuilder(
    column: $table.inputTimeMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTimeMilliseconds => $composableBuilder(
    column: $table.outputTimeMilliseconds,
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

  ColumnOrderings<int> get studyTimeMilliseconds => $composableBuilder(
    column: $table.studyTimeMilliseconds,
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

  ColumnOrderings<int> get inputTimeMilliseconds => $composableBuilder(
    column: $table.inputTimeMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTimeMilliseconds => $composableBuilder(
    column: $table.outputTimeMilliseconds,
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

  GeneratedColumn<int> get studyTimeMilliseconds => $composableBuilder(
    column: $table.studyTimeMilliseconds,
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

  GeneratedColumn<int> get inputTimeMilliseconds => $composableBuilder(
    column: $table.inputTimeMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTimeMilliseconds => $composableBuilder(
    column: $table.outputTimeMilliseconds,
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
                Value<int> studyTimeMilliseconds = const Value.absent(),
                Value<int> inputWords = const Value.absent(),
                Value<int> outputWords = const Value.absent(),
                Value<int> inputTimeSeconds = const Value.absent(),
                Value<int> inputTimeMilliseconds = const Value.absent(),
                Value<int> outputTimeSeconds = const Value.absent(),
                Value<int> outputTimeMilliseconds = const Value.absent(),
              }) => DailyStudyRecordsCompanion(
                id: id,
                date: date,
                studyTimeSeconds: studyTimeSeconds,
                studyTimeMilliseconds: studyTimeMilliseconds,
                inputWords: inputWords,
                outputWords: outputWords,
                inputTimeSeconds: inputTimeSeconds,
                inputTimeMilliseconds: inputTimeMilliseconds,
                outputTimeSeconds: outputTimeSeconds,
                outputTimeMilliseconds: outputTimeMilliseconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                Value<int> studyTimeSeconds = const Value.absent(),
                Value<int> studyTimeMilliseconds = const Value.absent(),
                Value<int> inputWords = const Value.absent(),
                Value<int> outputWords = const Value.absent(),
                Value<int> inputTimeSeconds = const Value.absent(),
                Value<int> inputTimeMilliseconds = const Value.absent(),
                Value<int> outputTimeSeconds = const Value.absent(),
                Value<int> outputTimeMilliseconds = const Value.absent(),
              }) => DailyStudyRecordsCompanion.insert(
                id: id,
                date: date,
                studyTimeSeconds: studyTimeSeconds,
                studyTimeMilliseconds: studyTimeMilliseconds,
                inputWords: inputWords,
                outputWords: outputWords,
                inputTimeSeconds: inputTimeSeconds,
                inputTimeMilliseconds: inputTimeMilliseconds,
                outputTimeSeconds: outputTimeSeconds,
                outputTimeMilliseconds: outputTimeMilliseconds,
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
      Value<int> studyTimeMilliseconds,
      Value<int> inputTimeSeconds,
      Value<int> inputTimeMilliseconds,
      Value<int> outputTimeSeconds,
      Value<int> outputTimeMilliseconds,
    });
typedef $$DailyStageStudyRecordsTableUpdateCompanionBuilder =
    DailyStageStudyRecordsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<StudyStage> stage,
      Value<int> studyTimeSeconds,
      Value<int> studyTimeMilliseconds,
      Value<int> inputTimeSeconds,
      Value<int> inputTimeMilliseconds,
      Value<int> outputTimeSeconds,
      Value<int> outputTimeMilliseconds,
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

  ColumnFilters<int> get studyTimeMilliseconds => $composableBuilder(
    column: $table.studyTimeMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTimeMilliseconds => $composableBuilder(
    column: $table.inputTimeMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTimeMilliseconds => $composableBuilder(
    column: $table.outputTimeMilliseconds,
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

  ColumnOrderings<int> get studyTimeMilliseconds => $composableBuilder(
    column: $table.studyTimeMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTimeMilliseconds => $composableBuilder(
    column: $table.inputTimeMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTimeMilliseconds => $composableBuilder(
    column: $table.outputTimeMilliseconds,
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

  GeneratedColumn<int> get studyTimeMilliseconds => $composableBuilder(
    column: $table.studyTimeMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputTimeSeconds => $composableBuilder(
    column: $table.inputTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputTimeMilliseconds => $composableBuilder(
    column: $table.inputTimeMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTimeSeconds => $composableBuilder(
    column: $table.outputTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTimeMilliseconds => $composableBuilder(
    column: $table.outputTimeMilliseconds,
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
                Value<int> studyTimeMilliseconds = const Value.absent(),
                Value<int> inputTimeSeconds = const Value.absent(),
                Value<int> inputTimeMilliseconds = const Value.absent(),
                Value<int> outputTimeSeconds = const Value.absent(),
                Value<int> outputTimeMilliseconds = const Value.absent(),
              }) => DailyStageStudyRecordsCompanion(
                id: id,
                date: date,
                stage: stage,
                studyTimeSeconds: studyTimeSeconds,
                studyTimeMilliseconds: studyTimeMilliseconds,
                inputTimeSeconds: inputTimeSeconds,
                inputTimeMilliseconds: inputTimeMilliseconds,
                outputTimeSeconds: outputTimeSeconds,
                outputTimeMilliseconds: outputTimeMilliseconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required StudyStage stage,
                Value<int> studyTimeSeconds = const Value.absent(),
                Value<int> studyTimeMilliseconds = const Value.absent(),
                Value<int> inputTimeSeconds = const Value.absent(),
                Value<int> inputTimeMilliseconds = const Value.absent(),
                Value<int> outputTimeSeconds = const Value.absent(),
                Value<int> outputTimeMilliseconds = const Value.absent(),
              }) => DailyStageStudyRecordsCompanion.insert(
                id: id,
                date: date,
                stage: stage,
                studyTimeSeconds: studyTimeSeconds,
                studyTimeMilliseconds: studyTimeMilliseconds,
                inputTimeSeconds: inputTimeSeconds,
                inputTimeMilliseconds: inputTimeMilliseconds,
                outputTimeSeconds: outputTimeSeconds,
                outputTimeMilliseconds: outputTimeMilliseconds,
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
typedef $$TtsCacheTableCreateCompanionBuilder =
    TtsCacheCompanion Function({
      Value<int> id,
      required String cacheKey,
      required String textHash,
      required String sourceText,
      required String engine,
      required String voice,
      required String languageCode,
      required double speed,
      required String format,
      required String filePath,
      required int fileSize,
      required DateTime createdAt,
      required DateTime lastAccessedAt,
      Value<DateTime?> expiresAt,
      Value<bool> isPinned,
    });
typedef $$TtsCacheTableUpdateCompanionBuilder =
    TtsCacheCompanion Function({
      Value<int> id,
      Value<String> cacheKey,
      Value<String> textHash,
      Value<String> sourceText,
      Value<String> engine,
      Value<String> voice,
      Value<String> languageCode,
      Value<double> speed,
      Value<String> format,
      Value<String> filePath,
      Value<int> fileSize,
      Value<DateTime> createdAt,
      Value<DateTime> lastAccessedAt,
      Value<DateTime?> expiresAt,
      Value<bool> isPinned,
    });

class $$TtsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TtsCacheTable> {
  $$TtsCacheTableFilterComposer({
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

  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voice => $composableBuilder(
    column: $table.voice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
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

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TtsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TtsCacheTable> {
  $$TtsCacheTableOrderingComposer({
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

  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voice => $composableBuilder(
    column: $table.voice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
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

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TtsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TtsCacheTable> {
  $$TtsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get textHash =>
      $composableBuilder(column: $table.textHash, builder: (column) => column);

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<String> get voice =>
      $composableBuilder(column: $table.voice, builder: (column) => column);

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => column,
  );

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);
}

class $$TtsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TtsCacheTable,
          TtsCacheData,
          $$TtsCacheTableFilterComposer,
          $$TtsCacheTableOrderingComposer,
          $$TtsCacheTableAnnotationComposer,
          $$TtsCacheTableCreateCompanionBuilder,
          $$TtsCacheTableUpdateCompanionBuilder,
          (
            TtsCacheData,
            BaseReferences<_$AppDatabase, $TtsCacheTable, TtsCacheData>,
          ),
          TtsCacheData,
          PrefetchHooks Function()
        > {
  $$TtsCacheTableTableManager(_$AppDatabase db, $TtsCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TtsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TtsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TtsCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cacheKey = const Value.absent(),
                Value<String> textHash = const Value.absent(),
                Value<String> sourceText = const Value.absent(),
                Value<String> engine = const Value.absent(),
                Value<String> voice = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
              }) => TtsCacheCompanion(
                id: id,
                cacheKey: cacheKey,
                textHash: textHash,
                sourceText: sourceText,
                engine: engine,
                voice: voice,
                languageCode: languageCode,
                speed: speed,
                format: format,
                filePath: filePath,
                fileSize: fileSize,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
                expiresAt: expiresAt,
                isPinned: isPinned,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String cacheKey,
                required String textHash,
                required String sourceText,
                required String engine,
                required String voice,
                required String languageCode,
                required double speed,
                required String format,
                required String filePath,
                required int fileSize,
                required DateTime createdAt,
                required DateTime lastAccessedAt,
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
              }) => TtsCacheCompanion.insert(
                id: id,
                cacheKey: cacheKey,
                textHash: textHash,
                sourceText: sourceText,
                engine: engine,
                voice: voice,
                languageCode: languageCode,
                speed: speed,
                format: format,
                filePath: filePath,
                fileSize: fileSize,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
                expiresAt: expiresAt,
                isPinned: isPinned,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TtsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TtsCacheTable,
      TtsCacheData,
      $$TtsCacheTableFilterComposer,
      $$TtsCacheTableOrderingComposer,
      $$TtsCacheTableAnnotationComposer,
      $$TtsCacheTableCreateCompanionBuilder,
      $$TtsCacheTableUpdateCompanionBuilder,
      (
        TtsCacheData,
        BaseReferences<_$AppDatabase, $TtsCacheTable, TtsCacheData>,
      ),
      TtsCacheData,
      PrefetchHooks Function()
    >;
typedef $$MemorySchedulesTableCreateCompanionBuilder =
    MemorySchedulesCompanion Function({
      required String id,
      required String namespace,
      required String subjectId,
      required String profileId,
      required int profileVersion,
      required String modelId,
      required int modelStateVersion,
      Value<String> modelStateJson,
      required String phase,
      required String status,
      required DateTime dueAt,
      Value<DateTime?> lastReviewedAt,
      Value<int> reviewCount,
      Value<int> lapseCount,
      Value<int> revision,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$MemorySchedulesTableUpdateCompanionBuilder =
    MemorySchedulesCompanion Function({
      Value<String> id,
      Value<String> namespace,
      Value<String> subjectId,
      Value<String> profileId,
      Value<int> profileVersion,
      Value<String> modelId,
      Value<int> modelStateVersion,
      Value<String> modelStateJson,
      Value<String> phase,
      Value<String> status,
      Value<DateTime> dueAt,
      Value<DateTime?> lastReviewedAt,
      Value<int> reviewCount,
      Value<int> lapseCount,
      Value<int> revision,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

final class $$MemorySchedulesTableReferences
    extends
        BaseReferences<_$AppDatabase, $MemorySchedulesTable, MemorySchedule> {
  $$MemorySchedulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MemoryReviewEventsTable, List<MemoryReviewEvent>>
  _memoryReviewEventsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.memoryReviewEvents,
        aliasName: $_aliasNameGenerator(
          db.memorySchedules.id,
          db.memoryReviewEvents.scheduleId,
        ),
      );

  $$MemoryReviewEventsTableProcessedTableManager get memoryReviewEventsRefs {
    final manager = $$MemoryReviewEventsTableTableManager(
      $_db,
      $_db.memoryReviewEvents,
    ).filter((f) => f.scheduleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _memoryReviewEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MemorySchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $MemorySchedulesTable> {
  $$MemorySchedulesTableFilterComposer({
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

  ColumnFilters<String> get namespace => $composableBuilder(
    column: $table.namespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modelStateVersion => $composableBuilder(
    column: $table.modelStateVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelStateJson => $composableBuilder(
    column: $table.modelStateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
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

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memoryReviewEventsRefs(
    Expression<bool> Function($$MemoryReviewEventsTableFilterComposer f) f,
  ) {
    final $$MemoryReviewEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryReviewEvents,
      getReferencedColumn: (t) => t.scheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryReviewEventsTableFilterComposer(
            $db: $db,
            $table: $db.memoryReviewEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemorySchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemorySchedulesTable> {
  $$MemorySchedulesTableOrderingComposer({
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

  ColumnOrderings<String> get namespace => $composableBuilder(
    column: $table.namespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modelStateVersion => $composableBuilder(
    column: $table.modelStateVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelStateJson => $composableBuilder(
    column: $table.modelStateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
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

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemorySchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemorySchedulesTable> {
  $$MemorySchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get namespace =>
      $composableBuilder(column: $table.namespace, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get modelStateVersion => $composableBuilder(
    column: $table.modelStateVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelStateJson => $composableBuilder(
    column: $table.modelStateJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  Expression<T> memoryReviewEventsRefs<T extends Object>(
    Expression<T> Function($$MemoryReviewEventsTableAnnotationComposer a) f,
  ) {
    final $$MemoryReviewEventsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.memoryReviewEvents,
          getReferencedColumn: (t) => t.scheduleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MemoryReviewEventsTableAnnotationComposer(
                $db: $db,
                $table: $db.memoryReviewEvents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MemorySchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemorySchedulesTable,
          MemorySchedule,
          $$MemorySchedulesTableFilterComposer,
          $$MemorySchedulesTableOrderingComposer,
          $$MemorySchedulesTableAnnotationComposer,
          $$MemorySchedulesTableCreateCompanionBuilder,
          $$MemorySchedulesTableUpdateCompanionBuilder,
          (MemorySchedule, $$MemorySchedulesTableReferences),
          MemorySchedule,
          PrefetchHooks Function({bool memoryReviewEventsRefs})
        > {
  $$MemorySchedulesTableTableManager(
    _$AppDatabase db,
    $MemorySchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemorySchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemorySchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemorySchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> namespace = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> profileVersion = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> modelStateVersion = const Value.absent(),
                Value<String> modelStateJson = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemorySchedulesCompanion(
                id: id,
                namespace: namespace,
                subjectId: subjectId,
                profileId: profileId,
                profileVersion: profileVersion,
                modelId: modelId,
                modelStateVersion: modelStateVersion,
                modelStateJson: modelStateJson,
                phase: phase,
                status: status,
                dueAt: dueAt,
                lastReviewedAt: lastReviewedAt,
                reviewCount: reviewCount,
                lapseCount: lapseCount,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String namespace,
                required String subjectId,
                required String profileId,
                required int profileVersion,
                required String modelId,
                required int modelStateVersion,
                Value<String> modelStateJson = const Value.absent(),
                required String phase,
                required String status,
                required DateTime dueAt,
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemorySchedulesCompanion.insert(
                id: id,
                namespace: namespace,
                subjectId: subjectId,
                profileId: profileId,
                profileVersion: profileVersion,
                modelId: modelId,
                modelStateVersion: modelStateVersion,
                modelStateJson: modelStateJson,
                phase: phase,
                status: status,
                dueAt: dueAt,
                lastReviewedAt: lastReviewedAt,
                reviewCount: reviewCount,
                lapseCount: lapseCount,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemorySchedulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memoryReviewEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (memoryReviewEventsRefs) db.memoryReviewEvents,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (memoryReviewEventsRefs)
                    await $_getPrefetchedData<
                      MemorySchedule,
                      $MemorySchedulesTable,
                      MemoryReviewEvent
                    >(
                      currentTable: table,
                      referencedTable: $$MemorySchedulesTableReferences
                          ._memoryReviewEventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MemorySchedulesTableReferences(
                            db,
                            table,
                            p0,
                          ).memoryReviewEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.scheduleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MemorySchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemorySchedulesTable,
      MemorySchedule,
      $$MemorySchedulesTableFilterComposer,
      $$MemorySchedulesTableOrderingComposer,
      $$MemorySchedulesTableAnnotationComposer,
      $$MemorySchedulesTableCreateCompanionBuilder,
      $$MemorySchedulesTableUpdateCompanionBuilder,
      (MemorySchedule, $$MemorySchedulesTableReferences),
      MemorySchedule,
      PrefetchHooks Function({bool memoryReviewEventsRefs})
    >;
typedef $$MemoryReviewEventsTableCreateCompanionBuilder =
    MemoryReviewEventsCompanion Function({
      required String id,
      required String scheduleId,
      required int sequence,
      required String operationId,
      required String rating,
      required bool isLapse,
      required DateTime reviewedAt,
      Value<int?> responseTimeMs,
      required String profileId,
      required int profileVersion,
      required String modelId,
      required int modelStateVersion,
      required DateTime dueBefore,
      required DateTime dueAfter,
      required int scheduleRevisionAfter,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$MemoryReviewEventsTableUpdateCompanionBuilder =
    MemoryReviewEventsCompanion Function({
      Value<String> id,
      Value<String> scheduleId,
      Value<int> sequence,
      Value<String> operationId,
      Value<String> rating,
      Value<bool> isLapse,
      Value<DateTime> reviewedAt,
      Value<int?> responseTimeMs,
      Value<String> profileId,
      Value<int> profileVersion,
      Value<String> modelId,
      Value<int> modelStateVersion,
      Value<DateTime> dueBefore,
      Value<DateTime> dueAfter,
      Value<int> scheduleRevisionAfter,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$MemoryReviewEventsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MemoryReviewEventsTable,
          MemoryReviewEvent
        > {
  $$MemoryReviewEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MemorySchedulesTable _scheduleIdTable(_$AppDatabase db) =>
      db.memorySchedules.createAlias(
        $_aliasNameGenerator(
          db.memoryReviewEvents.scheduleId,
          db.memorySchedules.id,
        ),
      );

  $$MemorySchedulesTableProcessedTableManager get scheduleId {
    final $_column = $_itemColumn<String>('schedule_id')!;

    final manager = $$MemorySchedulesTableTableManager(
      $_db,
      $_db.memorySchedules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scheduleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoryReviewEventsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryReviewEventsTable> {
  $$MemoryReviewEventsTableFilterComposer({
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

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLapse => $composableBuilder(
    column: $table.isLapse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get responseTimeMs => $composableBuilder(
    column: $table.responseTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modelStateVersion => $composableBuilder(
    column: $table.modelStateVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueBefore => $composableBuilder(
    column: $table.dueBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAfter => $composableBuilder(
    column: $table.dueAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduleRevisionAfter => $composableBuilder(
    column: $table.scheduleRevisionAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MemorySchedulesTableFilterComposer get scheduleId {
    final $$MemorySchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scheduleId,
      referencedTable: $db.memorySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemorySchedulesTableFilterComposer(
            $db: $db,
            $table: $db.memorySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryReviewEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryReviewEventsTable> {
  $$MemoryReviewEventsTableOrderingComposer({
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

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLapse => $composableBuilder(
    column: $table.isLapse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get responseTimeMs => $composableBuilder(
    column: $table.responseTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modelStateVersion => $composableBuilder(
    column: $table.modelStateVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueBefore => $composableBuilder(
    column: $table.dueBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAfter => $composableBuilder(
    column: $table.dueAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduleRevisionAfter => $composableBuilder(
    column: $table.scheduleRevisionAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemorySchedulesTableOrderingComposer get scheduleId {
    final $$MemorySchedulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scheduleId,
      referencedTable: $db.memorySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemorySchedulesTableOrderingComposer(
            $db: $db,
            $table: $db.memorySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryReviewEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryReviewEventsTable> {
  $$MemoryReviewEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<bool> get isLapse =>
      $composableBuilder(column: $table.isLapse, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get responseTimeMs => $composableBuilder(
    column: $table.responseTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get modelStateVersion => $composableBuilder(
    column: $table.modelStateVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueBefore =>
      $composableBuilder(column: $table.dueBefore, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAfter =>
      $composableBuilder(column: $table.dueAfter, builder: (column) => column);

  GeneratedColumn<int> get scheduleRevisionAfter => $composableBuilder(
    column: $table.scheduleRevisionAfter,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MemorySchedulesTableAnnotationComposer get scheduleId {
    final $$MemorySchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scheduleId,
      referencedTable: $db.memorySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemorySchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.memorySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryReviewEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryReviewEventsTable,
          MemoryReviewEvent,
          $$MemoryReviewEventsTableFilterComposer,
          $$MemoryReviewEventsTableOrderingComposer,
          $$MemoryReviewEventsTableAnnotationComposer,
          $$MemoryReviewEventsTableCreateCompanionBuilder,
          $$MemoryReviewEventsTableUpdateCompanionBuilder,
          (MemoryReviewEvent, $$MemoryReviewEventsTableReferences),
          MemoryReviewEvent,
          PrefetchHooks Function({bool scheduleId})
        > {
  $$MemoryReviewEventsTableTableManager(
    _$AppDatabase db,
    $MemoryReviewEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryReviewEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryReviewEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryReviewEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scheduleId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> rating = const Value.absent(),
                Value<bool> isLapse = const Value.absent(),
                Value<DateTime> reviewedAt = const Value.absent(),
                Value<int?> responseTimeMs = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> profileVersion = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> modelStateVersion = const Value.absent(),
                Value<DateTime> dueBefore = const Value.absent(),
                Value<DateTime> dueAfter = const Value.absent(),
                Value<int> scheduleRevisionAfter = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryReviewEventsCompanion(
                id: id,
                scheduleId: scheduleId,
                sequence: sequence,
                operationId: operationId,
                rating: rating,
                isLapse: isLapse,
                reviewedAt: reviewedAt,
                responseTimeMs: responseTimeMs,
                profileId: profileId,
                profileVersion: profileVersion,
                modelId: modelId,
                modelStateVersion: modelStateVersion,
                dueBefore: dueBefore,
                dueAfter: dueAfter,
                scheduleRevisionAfter: scheduleRevisionAfter,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scheduleId,
                required int sequence,
                required String operationId,
                required String rating,
                required bool isLapse,
                required DateTime reviewedAt,
                Value<int?> responseTimeMs = const Value.absent(),
                required String profileId,
                required int profileVersion,
                required String modelId,
                required int modelStateVersion,
                required DateTime dueBefore,
                required DateTime dueAfter,
                required int scheduleRevisionAfter,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryReviewEventsCompanion.insert(
                id: id,
                scheduleId: scheduleId,
                sequence: sequence,
                operationId: operationId,
                rating: rating,
                isLapse: isLapse,
                reviewedAt: reviewedAt,
                responseTimeMs: responseTimeMs,
                profileId: profileId,
                profileVersion: profileVersion,
                modelId: modelId,
                modelStateVersion: modelStateVersion,
                dueBefore: dueBefore,
                dueAfter: dueAfter,
                scheduleRevisionAfter: scheduleRevisionAfter,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryReviewEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scheduleId = false}) {
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
                    if (scheduleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scheduleId,
                                referencedTable:
                                    $$MemoryReviewEventsTableReferences
                                        ._scheduleIdTable(db),
                                referencedColumn:
                                    $$MemoryReviewEventsTableReferences
                                        ._scheduleIdTable(db)
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

typedef $$MemoryReviewEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryReviewEventsTable,
      MemoryReviewEvent,
      $$MemoryReviewEventsTableFilterComposer,
      $$MemoryReviewEventsTableOrderingComposer,
      $$MemoryReviewEventsTableAnnotationComposer,
      $$MemoryReviewEventsTableCreateCompanionBuilder,
      $$MemoryReviewEventsTableUpdateCompanionBuilder,
      (MemoryReviewEvent, $$MemoryReviewEventsTableReferences),
      MemoryReviewEvent,
      PrefetchHooks Function({bool scheduleId})
    >;
typedef $$MemoryReviewQueueEntriesTableCreateCompanionBuilder =
    MemoryReviewQueueEntriesCompanion Function({
      Value<int> id,
      required String namespace,
      required String subjectId,
      required String localDate,
      required DateTime enqueuedAt,
    });
typedef $$MemoryReviewQueueEntriesTableUpdateCompanionBuilder =
    MemoryReviewQueueEntriesCompanion Function({
      Value<int> id,
      Value<String> namespace,
      Value<String> subjectId,
      Value<String> localDate,
      Value<DateTime> enqueuedAt,
    });

class $$MemoryReviewQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryReviewQueueEntriesTable> {
  $$MemoryReviewQueueEntriesTableFilterComposer({
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

  ColumnFilters<String> get namespace => $composableBuilder(
    column: $table.namespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryReviewQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryReviewQueueEntriesTable> {
  $$MemoryReviewQueueEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get namespace => $composableBuilder(
    column: $table.namespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryReviewQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryReviewQueueEntriesTable> {
  $$MemoryReviewQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get namespace =>
      $composableBuilder(column: $table.namespace, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => column,
  );
}

class $$MemoryReviewQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryReviewQueueEntriesTable,
          MemoryReviewQueueEntry,
          $$MemoryReviewQueueEntriesTableFilterComposer,
          $$MemoryReviewQueueEntriesTableOrderingComposer,
          $$MemoryReviewQueueEntriesTableAnnotationComposer,
          $$MemoryReviewQueueEntriesTableCreateCompanionBuilder,
          $$MemoryReviewQueueEntriesTableUpdateCompanionBuilder,
          (
            MemoryReviewQueueEntry,
            BaseReferences<
              _$AppDatabase,
              $MemoryReviewQueueEntriesTable,
              MemoryReviewQueueEntry
            >,
          ),
          MemoryReviewQueueEntry,
          PrefetchHooks Function()
        > {
  $$MemoryReviewQueueEntriesTableTableManager(
    _$AppDatabase db,
    $MemoryReviewQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryReviewQueueEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MemoryReviewQueueEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MemoryReviewQueueEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> namespace = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<DateTime> enqueuedAt = const Value.absent(),
              }) => MemoryReviewQueueEntriesCompanion(
                id: id,
                namespace: namespace,
                subjectId: subjectId,
                localDate: localDate,
                enqueuedAt: enqueuedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String namespace,
                required String subjectId,
                required String localDate,
                required DateTime enqueuedAt,
              }) => MemoryReviewQueueEntriesCompanion.insert(
                id: id,
                namespace: namespace,
                subjectId: subjectId,
                localDate: localDate,
                enqueuedAt: enqueuedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryReviewQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryReviewQueueEntriesTable,
      MemoryReviewQueueEntry,
      $$MemoryReviewQueueEntriesTableFilterComposer,
      $$MemoryReviewQueueEntriesTableOrderingComposer,
      $$MemoryReviewQueueEntriesTableAnnotationComposer,
      $$MemoryReviewQueueEntriesTableCreateCompanionBuilder,
      $$MemoryReviewQueueEntriesTableUpdateCompanionBuilder,
      (
        MemoryReviewQueueEntry,
        BaseReferences<
          _$AppDatabase,
          $MemoryReviewQueueEntriesTable,
          MemoryReviewQueueEntry
        >,
      ),
      MemoryReviewQueueEntry,
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
  $$TtsCacheTableTableManager get ttsCache =>
      $$TtsCacheTableTableManager(_db, _db.ttsCache);
  $$MemorySchedulesTableTableManager get memorySchedules =>
      $$MemorySchedulesTableTableManager(_db, _db.memorySchedules);
  $$MemoryReviewEventsTableTableManager get memoryReviewEvents =>
      $$MemoryReviewEventsTableTableManager(_db, _db.memoryReviewEvents);
  $$MemoryReviewQueueEntriesTableTableManager get memoryReviewQueueEntries =>
      $$MemoryReviewQueueEntriesTableTableManager(
        _db,
        _db.memoryReviewQueueEntries,
      );
}
