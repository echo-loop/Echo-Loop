/// 收藏词汇来源句进入句子讲解页的共享导航。
///
/// 收藏词汇复习、查词详情与收藏详情页共用：统一补全讲解页所需的材料定位与
/// 词级高亮来源，避免各页面各自维护一份跳转逻辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daos/audio_item_dao.dart';
import '../../database/providers.dart';
import '../../models/sentence.dart';
import '../../models/word_highlight_binding.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../router/app_router.dart';
import '../../screens/sentence_detail_screen.dart';
import '../../services/subtitle_parser.dart';

/// 解析收藏词汇来源句进入讲解页所需的位置。
///
/// 新数据直接使用持久化的句序和时间；旧数据缺少其中任一字段时，改从当前
/// 材料字幕按句序或文本恢复，避免把错误的时间范围传给讲解页。
Future<void> openFavoriteSourceSentenceDetail({
  required BuildContext context,
  required WidgetRef ref,
  required String audioItemId,
  required String sentenceText,
  required int? sentenceIndex,
  required int? sentenceStartMs,
  required int? sentenceEndMs,
}) async {
  final audioItemDao = ref.read(audioItemDaoProvider);
  final audio = await audioItemDao.getById(audioItemId);
  if (audio == null) return;

  final storedRangeIsValid =
      sentenceStartMs != null &&
      sentenceEndMs != null &&
      sentenceEndMs - sentenceStartMs >= 200;
  final storedIndexIsValid = sentenceIndex != null && sentenceIndex >= 0;
  final storedLocation = storedRangeIsValid && storedIndexIsValid
      ? (
          sentenceIndex: sentenceIndex,
          startTimeMs: sentenceStartMs,
          endTimeMs: sentenceEndMs,
        )
      : null;
  final location =
      storedLocation ??
      await _resolveSourceSentenceLocation(
        audioItemDao: audioItemDao,
        audioItemId: audioItemId,
        sentenceText: sentenceText,
        preferredSentenceIndex: sentenceIndex,
      );
  if (location == null || !context.mounted) return;

  AppRoutes.pushNested(
    context,
    AppRoutes.sentenceDetailSegment,
    extra: SentenceDetailArgs(
      audioItemId: audioItemId,
      audioName: audio.name,
      sentenceText: sentenceText,
      sentenceIndex: location.sentenceIndex,
      startTimeMs: location.startTimeMs,
      endTimeMs: location.endTimeMs,
      wordHighlightSource: audioEngineWordHighlightSource(ref, audioItemId),
    ),
  );
}

/// 收藏详情页的句子试听由全局音频引擎播放，因此显式绑定该引擎的时间轴。
WordHighlightSource audioEngineWordHighlightSource(
  WidgetRef ref,
  String audioItemId,
) {
  final engine = ref.read(audioEngineProvider.notifier);
  return WordHighlightSource(
    audioItemId: audioItemId,
    positionStream: engine.absolutePositionStream,
    currentPosition: engine.absoluteCurrentPosition,
    playbackStatus: engine.wordHighlightPlaybackStatus,
    playbackStatusStream: engine.wordHighlightPlaybackStatusStream,
  );
}

/// 从材料字幕恢复来源句的位置；优先信任仍与文本一致的原句序。
Future<({int sentenceIndex, int startTimeMs, int endTimeMs})?>
_resolveSourceSentenceLocation({
  required AudioItemDao audioItemDao,
  required String audioItemId,
  required String sentenceText,
  required int? preferredSentenceIndex,
}) async {
  final srt = await audioItemDao.getTranscriptSrt(audioItemId);
  if (srt == null || srt.isEmpty) return null;
  final sentences = await SubtitleParser.parseSubtitleString(srt);
  final normalizedText = sentenceText.trim();
  if (normalizedText.isEmpty) return null;

  final preferred =
      preferredSentenceIndex != null &&
          preferredSentenceIndex >= 0 &&
          preferredSentenceIndex < sentences.length
      ? sentences[preferredSentenceIndex]
      : null;
  final resolved = preferred?.text.trim() == normalizedText
      ? preferred
      : sentences.cast<Sentence?>().firstWhere(
          (candidate) => candidate?.text.trim() == normalizedText,
          orElse: () => null,
        );
  if (resolved == null) return null;
  return (
    sentenceIndex: resolved.index,
    startTimeMs: resolved.startTime.inMilliseconds,
    endTimeMs: resolved.endTime.inMilliseconds,
  );
}
