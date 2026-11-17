/// 字幕内容变更后同步收藏与学习断点。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/providers.dart';
import '../models/sentence.dart';
import '../services/app_logger.dart';
import 'audio_sentences_provider.dart';
import 'learning_progress_provider.dart';

/// 字幕替换（编辑保存、社区字幕更新）后的统一同步入口。
final transcriptChangeSyncProvider = Provider<TranscriptChangeSync>(
  (ref) => TranscriptChangeSync(ref),
);

/// 字幕替换后让收藏与学习断点和新字幕保持一致：
/// - 收藏句、收藏词汇 / 意群的来源句改写为新字幕中对应那一句的文字与区间，
///   各页面（收藏列表、随心听、讲解页、复习、导出）读到的都是同一句；
/// - 学习进度断点按时间换算到新字幕；
/// - 让共享字幕投影重新解析。
///
/// 收藏的改写只依据收藏自身的区间，可安全重试。
class TranscriptChangeSync {
  TranscriptChangeSync(this._ref);

  final Ref _ref;

  Future<void> apply(
    String audioItemId, {
    required List<Sentence> oldSentences,
    required List<Sentence> newSentences,
  }) async {
    final bookmarks = await _ref
        .read(bookmarkDaoProvider)
        .relinkToSentences(audioItemId, newSentences);
    final words = await _ref
        .read(savedWordDaoProvider)
        .relinkSourceSentences(audioItemId, newSentences);
    final senseGroups = await _ref
        .read(savedSenseGroupDaoProvider)
        .relinkSourceSentences(audioItemId, newSentences);
    await _ref
        .read(learningProgressProvider.notifier)
        .remapSentenceBreakpoints(
          audioItemId,
          oldSentences: oldSentences,
          newSentences: newSentences,
        );
    _ref.invalidate(audioSentencesProvider(audioItemId));
    AppLogger.log(
      'TranscriptSync',
      'event=synced audioItemId=$audioItemId '
          'sentences=${oldSentences.length}->${newSentences.length} '
          'relinked=bookmarks:$bookmarks,words:$words,senseGroups:$senseGroups',
    );
  }
}
