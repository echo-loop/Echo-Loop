/// 收藏区间在当前字幕中的句子编号（按需现算）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/source_sentence_anchor.dart';
import 'audio_sentences_provider.dart';

/// 一条收藏的来源：音频 + 收藏区间（毫秒）。
typedef SourceSentenceRef = ({String audioItemId, int? startMs, int? endMs});

/// 收藏区间当前对应字幕中的第几句；无字幕或来源句已删除时为 null。
///
/// 收藏不存句子编号。收藏复习、收藏列表等需要取前后句作 AI 上下文时，用它在
/// 当前字幕里现算；字幕变更后共享字幕投影被失效，这里随之重新计算。
final sourceSentenceIndexProvider = FutureProvider.autoDispose
    .family<int?, SourceSentenceRef>((ref, source) async {
      if (source.audioItemId.isEmpty) return null;
      final sentences = await ref.watch(
        audioSentencesProvider(source.audioItemId).future,
      );
      return resolveSourceSentenceIndex(
        SourceSentenceAnchor.fromMilliseconds(
          startMs: source.startMs,
          endMs: source.endMs,
        ),
        sentences,
      );
    });
