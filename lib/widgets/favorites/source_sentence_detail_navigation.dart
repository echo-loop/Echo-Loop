/// 收藏词汇来源句进入句子讲解页的共享导航。
///
/// 收藏词汇复习、查词详情与收藏详情页共用：统一补全讲解页所需的材料定位与
/// 词级高亮来源，避免各页面各自维护一份跳转逻辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/word_highlight_binding.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../router/app_router.dart';
import '../../screens/sentence_detail_screen.dart';
import '../../services/pronunciation/local_audio_range_player.dart';
import '../app_toast.dart';
import 'favorite_sentence_video_session.dart';

/// 打开收藏入口对应的来源句讲解页。
///
/// 收藏列表、收藏词汇复习、查词详情与来源句卡片共用本函数。视频材料由
/// [FavoriteSentenceVideoSession] 把画面加载进媒体引擎后再进入讲解页，音频材料
/// 保持原有的音频讲解路径。
Future<void> openFavoriteSentenceDetail({
  required BuildContext context,
  required WidgetRef ref,
  required String audioItemId,
  required String sentenceText,
  required int? sentenceStartMs,
  required int? sentenceEndMs,
}) async {
  final audioItemDao = ref.read(audioItemDaoProvider);
  final audioRow = await audioItemDao.getById(audioItemId);
  if (audioRow == null) return;
  final audio = audioItemFromDatabaseRow(audioRow);

  // 讲解页按收藏区间自行定位到当前字幕；没有有效区间的收藏无法打开讲解页。
  if (sentenceStartMs == null ||
      sentenceEndMs == null ||
      sentenceEndMs - sentenceStartMs < _minStoredRangeMs) {
    return;
  }
  final location = (startTimeMs: sentenceStartMs, endTimeMs: sentenceEndMs);
  if (!context.mounted) return;

  if (!audio.isVideo) {
    AppRoutes.pushNested(
      context,
      AppRoutes.sentenceDetailSegment,
      extra: SentenceDetailArgs(
        audioItemId: audioItemId,
        audioName: audio.name,
        sentenceText: sentenceText,
        startTimeMs: location.startTimeMs,
        endTimeMs: location.endTimeMs,
        wordHighlightSource: audioEngineWordHighlightSource(ref, audioItemId),
      ),
    );
    return;
  }

  await _openVideoSentenceDetail(
    context: context,
    ref: ref,
    audio: audio,
    sentenceText: sentenceText,
    location: location,
  );
}

/// 视频来源句：先加载画面并定位到句首，再进入讲解页；离开讲解页时释放会话。
Future<void> _openVideoSentenceDetail({
  required BuildContext context,
  required WidgetRef ref,
  required AudioItem audio,
  required String sentenceText,
  required ({int startTimeMs, int endTimeMs}) location,
}) async {
  final session = FavoriteSentenceVideoSession(
    engine: ref.read(mediaEngineProvider.notifier),
    audioEngine: ref.read(audioEngineProvider.notifier),
    audioItemDao: ref.read(audioItemDaoProvider),
  );
  try {
    final result = await session.open(
      item: audio,
      sentenceStart: Duration(milliseconds: location.startTimeMs),
    );
    if (!context.mounted) return;
    switch (result) {
      case FavoriteVideoOpenResult.cancelled:
        return;
      case FavoriteVideoOpenResult.failed:
        showAppToast(
          overlayState: Overlay.of(context),
          message: AppLocalizations.of(context)!.playbackFailedTitle,
        );
        return;
      case FavoriteVideoOpenResult.opened:
        await AppRoutes.pushNested(
          context,
          AppRoutes.sentenceDetailSegment,
          extra: SentenceDetailArgs(
            audioItemId: audio.id,
            audioName: audio.name,
            sentenceText: sentenceText,
            startTimeMs: location.startTimeMs,
            endTimeMs: location.endTimeMs,
            rangePlaybackBuilder: session.rangePlaybackBuilder,
            wordHighlightSource: session.wordHighlightSource(audio.id),
            mediaSession: session.mediaSession,
          ),
        );
    }
  } finally {
    await session.close();
  }
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

/// 收藏区间短于该值视为无效（早期数据），无法打开讲解页。
const int _minStoredRangeMs = 200;
