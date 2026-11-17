/// 字幕内容变更后同步依赖句子编号的学习数据。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sentence.dart';
import '../services/app_logger.dart';
import 'audio_sentences_provider.dart';
import 'learning_progress_provider.dart';

/// 字幕替换（编辑保存、社区字幕更新）后的统一同步入口。
final transcriptChangeSyncProvider = Provider<TranscriptChangeSync>(
  (ref) => TranscriptChangeSync(ref),
);

/// 收藏句、收藏词汇 / 意群只存时间区间，字幕变化不需要改动它们；唯一仍按句子
/// 编号保存的是学习进度的断点，这里按时间换算到新字幕，并让共享字幕投影
/// 重新解析。
class TranscriptChangeSync {
  TranscriptChangeSync(this._ref);

  final Ref _ref;

  Future<void> apply(
    String audioItemId, {
    required List<Sentence> oldSentences,
    required List<Sentence> newSentences,
  }) async {
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
          'sentences=${oldSentences.length}->${newSentences.length}',
    );
  }
}
