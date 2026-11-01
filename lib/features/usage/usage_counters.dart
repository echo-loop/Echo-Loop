import 'usage_event.dart';

/// 用户本地累计使用统计。
///
/// 这些值用于产品体验节奏、功能使用状态和用户引导时机判断，只做历史累加，
/// 不因删除音频、取消收藏或清缓存而回退。
class UsageCounters {
  const UsageCounters({
    this.audioUploadCount = 0,
    this.subtitleUploadCount = 0,
    this.aiTranscriptionStartedCount = 0,
    this.aiTranscriptionCompletedCount = 0,
    this.subStageCompletedCount = 0,
    this.translationTapCount = 0,
    this.analysisTapCount = 0,
    this.senseGroupTapCount = 0,
    this.translationSuccessCount = 0,
    this.analysisSuccessCount = 0,
    this.senseGroupSuccessCount = 0,
    this.aiWordAnalysisSuccessCount = 0,
    this.bookmarkSentenceReviewCompleteCount = 0,
    this.flashcardReviewCompleteCount = 0,
    this.bookmarkSentenceSaveCount = 0,
    this.wordSaveCount = 0,
    this.recordingCompleteCount = 0,
    this.studyTaskTapCount = 0,
    this.firstLearnCompleteCount = 0,
    this.bookmarkReviewButtonTapCount = 0,
    this.flashcardButtonTapCount = 0,
  });

  final int audioUploadCount;
  final int subtitleUploadCount;
  final int aiTranscriptionStartedCount;
  final int aiTranscriptionCompletedCount;
  final int subStageCompletedCount;
  final int translationTapCount;
  final int analysisTapCount;
  final int senseGroupTapCount;

  /// AI 功能「成功次数」（区别于上面的点击次数）：仅在 API 成功返回可用结果时累加，
  /// 用于评价/付费提醒等 UX 触达判断。失败/额度不足不计。
  final int translationSuccessCount;
  final int analysisSuccessCount;
  final int senseGroupSuccessCount;
  final int aiWordAnalysisSuccessCount;
  final int bookmarkSentenceReviewCompleteCount;
  final int flashcardReviewCompleteCount;
  final int bookmarkSentenceSaveCount;
  final int wordSaveCount;
  final int recordingCompleteCount;
  final int studyTaskTapCount;
  final int firstLearnCompleteCount;
  final int bookmarkReviewButtonTapCount;
  final int flashcardButtonTapCount;

  UsageCounters increment(UsageEvent event) {
    return switch (event) {
      UsageEvent.audioUpload => copyWith(
        audioUploadCount: audioUploadCount + 1,
      ),
      UsageEvent.subtitleUploaded => copyWith(
        subtitleUploadCount: subtitleUploadCount + 1,
      ),
      UsageEvent.aiTranscriptionStarted => copyWith(
        aiTranscriptionStartedCount: aiTranscriptionStartedCount + 1,
      ),
      UsageEvent.aiTranscriptionCompleted => copyWith(
        aiTranscriptionCompletedCount: aiTranscriptionCompletedCount + 1,
      ),
      UsageEvent.subStageCompleted => copyWith(
        subStageCompletedCount: subStageCompletedCount + 1,
      ),
      UsageEvent.translationTapped => copyWith(
        translationTapCount: translationTapCount + 1,
      ),
      UsageEvent.analysisTapped => copyWith(
        analysisTapCount: analysisTapCount + 1,
      ),
      UsageEvent.senseGroupTapped => copyWith(
        senseGroupTapCount: senseGroupTapCount + 1,
      ),
      UsageEvent.translationSucceeded => copyWith(
        translationSuccessCount: translationSuccessCount + 1,
      ),
      UsageEvent.analysisSucceeded => copyWith(
        analysisSuccessCount: analysisSuccessCount + 1,
      ),
      UsageEvent.senseGroupSucceeded => copyWith(
        senseGroupSuccessCount: senseGroupSuccessCount + 1,
      ),
      UsageEvent.aiWordAnalysisSucceeded => copyWith(
        aiWordAnalysisSuccessCount: aiWordAnalysisSuccessCount + 1,
      ),
      UsageEvent.bookmarkSentenceReviewCompleted => copyWith(
        bookmarkSentenceReviewCompleteCount:
            bookmarkSentenceReviewCompleteCount + 1,
      ),
      UsageEvent.flashcardReviewCompleted => copyWith(
        flashcardReviewCompleteCount: flashcardReviewCompleteCount + 1,
      ),
      UsageEvent.bookmarkSentenceSaved => copyWith(
        bookmarkSentenceSaveCount: bookmarkSentenceSaveCount + 1,
      ),
      UsageEvent.wordSaved => copyWith(wordSaveCount: wordSaveCount + 1),
      UsageEvent.recordingCompleted => copyWith(
        recordingCompleteCount: recordingCompleteCount + 1,
      ),
      UsageEvent.studyTaskTapped => copyWith(
        studyTaskTapCount: studyTaskTapCount + 1,
      ),
      UsageEvent.firstLearnCompleted => copyWith(
        firstLearnCompleteCount: firstLearnCompleteCount + 1,
      ),
      UsageEvent.bookmarkReviewButtonTapped => copyWith(
        bookmarkReviewButtonTapCount: bookmarkReviewButtonTapCount + 1,
      ),
      UsageEvent.flashcardButtonTapped => copyWith(
        flashcardButtonTapCount: flashcardButtonTapCount + 1,
      ),
    };
  }

  UsageCounters copyWith({
    int? audioUploadCount,
    int? subtitleUploadCount,
    int? aiTranscriptionStartedCount,
    int? aiTranscriptionCompletedCount,
    int? subStageCompletedCount,
    int? translationTapCount,
    int? analysisTapCount,
    int? senseGroupTapCount,
    int? translationSuccessCount,
    int? analysisSuccessCount,
    int? senseGroupSuccessCount,
    int? aiWordAnalysisSuccessCount,
    int? bookmarkSentenceReviewCompleteCount,
    int? flashcardReviewCompleteCount,
    int? bookmarkSentenceSaveCount,
    int? wordSaveCount,
    int? recordingCompleteCount,
    int? studyTaskTapCount,
    int? firstLearnCompleteCount,
    int? bookmarkReviewButtonTapCount,
    int? flashcardButtonTapCount,
  }) {
    return UsageCounters(
      audioUploadCount: audioUploadCount ?? this.audioUploadCount,
      subtitleUploadCount: subtitleUploadCount ?? this.subtitleUploadCount,
      aiTranscriptionStartedCount:
          aiTranscriptionStartedCount ?? this.aiTranscriptionStartedCount,
      aiTranscriptionCompletedCount:
          aiTranscriptionCompletedCount ?? this.aiTranscriptionCompletedCount,
      subStageCompletedCount:
          subStageCompletedCount ?? this.subStageCompletedCount,
      translationTapCount: translationTapCount ?? this.translationTapCount,
      analysisTapCount: analysisTapCount ?? this.analysisTapCount,
      senseGroupTapCount: senseGroupTapCount ?? this.senseGroupTapCount,
      translationSuccessCount:
          translationSuccessCount ?? this.translationSuccessCount,
      analysisSuccessCount: analysisSuccessCount ?? this.analysisSuccessCount,
      senseGroupSuccessCount:
          senseGroupSuccessCount ?? this.senseGroupSuccessCount,
      aiWordAnalysisSuccessCount:
          aiWordAnalysisSuccessCount ?? this.aiWordAnalysisSuccessCount,
      bookmarkSentenceReviewCompleteCount:
          bookmarkSentenceReviewCompleteCount ??
          this.bookmarkSentenceReviewCompleteCount,
      flashcardReviewCompleteCount:
          flashcardReviewCompleteCount ?? this.flashcardReviewCompleteCount,
      bookmarkSentenceSaveCount:
          bookmarkSentenceSaveCount ?? this.bookmarkSentenceSaveCount,
      wordSaveCount: wordSaveCount ?? this.wordSaveCount,
      recordingCompleteCount:
          recordingCompleteCount ?? this.recordingCompleteCount,
      studyTaskTapCount: studyTaskTapCount ?? this.studyTaskTapCount,
      firstLearnCompleteCount:
          firstLearnCompleteCount ?? this.firstLearnCompleteCount,
      bookmarkReviewButtonTapCount:
          bookmarkReviewButtonTapCount ?? this.bookmarkReviewButtonTapCount,
      flashcardButtonTapCount:
          flashcardButtonTapCount ?? this.flashcardButtonTapCount,
    );
  }

  Map<String, Object> toJson() {
    return {
      'audioUploadCount': audioUploadCount,
      'subtitleUploadCount': subtitleUploadCount,
      'aiTranscriptionStartedCount': aiTranscriptionStartedCount,
      'aiTranscriptionCompletedCount': aiTranscriptionCompletedCount,
      'subStageCompletedCount': subStageCompletedCount,
      'translationTapCount': translationTapCount,
      'analysisTapCount': analysisTapCount,
      'senseGroupTapCount': senseGroupTapCount,
      'translationSuccessCount': translationSuccessCount,
      'analysisSuccessCount': analysisSuccessCount,
      'senseGroupSuccessCount': senseGroupSuccessCount,
      'aiWordAnalysisSuccessCount': aiWordAnalysisSuccessCount,
      'bookmarkSentenceReviewCompleteCount':
          bookmarkSentenceReviewCompleteCount,
      'flashcardReviewCompleteCount': flashcardReviewCompleteCount,
      'bookmarkSentenceSaveCount': bookmarkSentenceSaveCount,
      'wordSaveCount': wordSaveCount,
      'recordingCompleteCount': recordingCompleteCount,
      'studyTaskTapCount': studyTaskTapCount,
      'firstLearnCompleteCount': firstLearnCompleteCount,
      'bookmarkReviewButtonTapCount': bookmarkReviewButtonTapCount,
      'flashcardButtonTapCount': flashcardButtonTapCount,
    };
  }

  factory UsageCounters.fromJson(Map<String, Object?> json) {
    return UsageCounters(
      audioUploadCount: _readInt(json, 'audioUploadCount'),
      subtitleUploadCount: _readInt(json, 'subtitleUploadCount'),
      aiTranscriptionStartedCount: _readInt(
        json,
        'aiTranscriptionStartedCount',
      ),
      aiTranscriptionCompletedCount: _readInt(
        json,
        'aiTranscriptionCompletedCount',
      ),
      subStageCompletedCount: _readInt(json, 'subStageCompletedCount'),
      translationTapCount: _readInt(json, 'translationTapCount'),
      analysisTapCount: _readInt(json, 'analysisTapCount'),
      senseGroupTapCount: _readInt(json, 'senseGroupTapCount'),
      translationSuccessCount: _readInt(json, 'translationSuccessCount'),
      analysisSuccessCount: _readInt(json, 'analysisSuccessCount'),
      senseGroupSuccessCount: _readInt(json, 'senseGroupSuccessCount'),
      aiWordAnalysisSuccessCount: _readInt(json, 'aiWordAnalysisSuccessCount'),
      bookmarkSentenceReviewCompleteCount: _readInt(
        json,
        'bookmarkSentenceReviewCompleteCount',
      ),
      flashcardReviewCompleteCount: _readInt(
        json,
        'flashcardReviewCompleteCount',
      ),
      bookmarkSentenceSaveCount: _readInt(json, 'bookmarkSentenceSaveCount'),
      wordSaveCount: _readInt(json, 'wordSaveCount'),
      recordingCompleteCount: _readInt(json, 'recordingCompleteCount'),
      studyTaskTapCount: _readInt(json, 'studyTaskTapCount'),
      firstLearnCompleteCount: _readInt(json, 'firstLearnCompleteCount'),
      bookmarkReviewButtonTapCount: _readInt(
        json,
        'bookmarkReviewButtonTapCount',
      ),
      flashcardButtonTapCount: _readInt(json, 'flashcardButtonTapCount'),
    );
  }

  static int _readInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
