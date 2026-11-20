import 'audio_item.dart';
import 'listening_practice_state.dart';
import 'playback_settings.dart';
import 'sentence.dart';
import 'sentence_focus_reason.dart';

/// media_kit 随心听页面的业务状态。
///
/// 音频和视频随心听共用此状态；只有视频媒体会使用画面轨相关字段。
class MediaPlaybackState {
  const MediaPlaybackState({
    this.audioItem,
    this.sentences = const [],
    this.currentFullIndex,
    this.currentBookmarkIndex,
    this.lastPlayedFullIndex,
    this.lastPlayedBookmarkIndex,
    this.sentenceFocusRevision = 0,
    this.sentenceFocusReason = SentenceFocusReason.immediate,
    this.fullSettings = const PlaybackSettings(),
    this.bookmarkSettings = kDefaultBookmarkPlaybackSettings,
    this.playlistMode = PlaylistMode.full,
    this.bookmarkedIndices = const {},
    this.isLoading = false,
    this.isTranscriptLoading = false,
    this.errorMessage,
    this.isPlaying = false,
    this.wholeLoopsDone = 0,
    this.sentenceRepeatsDone = 0,
    this.playbackInterval,
    this.position = Duration.zero,
    this.duration,
    this.visualTrackVisible = true,
    this.visualTrackExpanded = false,
    this.videoSubtitleVisible = false,
    this.isLandscapeVideo,
    this.videoAspectRatio,
  });

  final AudioItem? audioItem;
  final List<Sentence> sentences;
  final int? currentFullIndex;
  final int? currentBookmarkIndex;
  final int? lastPlayedFullIndex;
  final int? lastPlayedBookmarkIndex;

  /// 当前句聚焦请求版本，用于触发同一句上的显式重新定位。
  final int sentenceFocusRevision;

  /// 当前句变化来源，决定字幕列表是否播放跟随动画。
  final SentenceFocusReason sentenceFocusReason;
  final PlaybackSettings fullSettings;
  final PlaybackSettings bookmarkSettings;
  final PlaylistMode playlistMode;
  final Set<int> bookmarkedIndices;
  final bool isLoading;
  final bool isTranscriptLoading;
  final String? errorMessage;
  final bool isPlaying;
  final int wholeLoopsDone;
  final int sentenceRepeatsDone;

  /// 自动续播间隔的总时长（遍间 / 句间停顿）；不在间隔内时为 null。
  /// 主播放按钮据此显示环形倒计时，间隔期间仍视为播放中。
  final Duration? playbackInterval;
  final Duration position;
  final Duration? duration;
  final bool visualTrackVisible;
  final bool visualTrackExpanded;
  final bool videoSubtitleVisible;
  final bool? isLandscapeVideo;
  final double? videoAspectRatio;

  PlaybackSettings get settings =>
      playlistMode == PlaylistMode.bookmarks ? bookmarkSettings : fullSettings;

  List<Sentence> get bookmarkedSentences =>
      sentences.where((s) => bookmarkedIndices.contains(s.index)).toList();

  bool get hasMedia => audioItem != null;
  bool get hasSentences => sentences.isNotEmpty;

  /// 当前生效播放列表：全文模式=全部句子；收藏模式=收藏句子。
  List<Sentence> get playableSentences =>
      playlistMode == PlaylistMode.bookmarks ? bookmarkedSentences : sentences;

  /// 当前句在 [playableSentences] 中的序号（0-based）。列表为空返回 null。
  int? get currentPlayablePosition {
    final playable = playableSentences;
    if (playable.isEmpty) return null;
    if (playlistMode == PlaylistMode.bookmarks) {
      final ci = currentBookmarkIndex;
      if (ci == null) return 0;
      final p = playable.indexWhere((s) => s.index == ci);
      return p == -1 ? 0 : p;
    }
    final ci = currentFullIndex;
    if (ci == null || ci < 0 || ci >= playable.length) return 0;
    return ci;
  }

  /// 是否已在播放列表第一句（驱动"上一句"按钮禁用态）。
  bool get isFirstSentence => (currentPlayablePosition ?? 0) <= 0;

  /// 是否已在播放列表最后一句（驱动"下一句"按钮禁用态）。
  bool get isLastSentence {
    final playable = playableSentences;
    if (playable.isEmpty) return true;
    return (currentPlayablePosition ?? 0) >= playable.length - 1;
  }

  MediaPlaybackState copyWith({
    AudioItem? audioItem,
    bool clearAudioItem = false,
    List<Sentence>? sentences,
    int? currentFullIndex,
    bool clearCurrentFullIndex = false,
    int? currentBookmarkIndex,
    bool clearCurrentBookmarkIndex = false,
    int? lastPlayedFullIndex,
    bool clearLastPlayedFullIndex = false,
    int? lastPlayedBookmarkIndex,
    bool clearLastPlayedBookmarkIndex = false,
    bool requestSentenceFocus = false,
    SentenceFocusReason? sentenceFocusReason,
    PlaybackSettings? fullSettings,
    PlaybackSettings? bookmarkSettings,
    PlaybackSettings? settings,
    PlaylistMode? playlistMode,
    Set<int>? bookmarkedIndices,
    bool? isLoading,
    bool? isTranscriptLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isPlaying,
    int? wholeLoopsDone,
    int? sentenceRepeatsDone,
    Duration? playbackInterval,
    bool clearPlaybackInterval = false,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    bool? visualTrackVisible,
    bool? visualTrackExpanded,
    bool? videoSubtitleVisible,
    bool? isLandscapeVideo,
    bool clearIsLandscapeVideo = false,
    double? videoAspectRatio,
    bool clearVideoAspectRatio = false,
  }) {
    final nextPlaylistMode = playlistMode ?? this.playlistMode;
    var nextFullSettings = fullSettings ?? this.fullSettings;
    var nextBookmarkSettings = bookmarkSettings ?? this.bookmarkSettings;
    if (settings != null) {
      if (nextPlaylistMode == PlaylistMode.bookmarks) {
        nextBookmarkSettings = settings;
      } else {
        nextFullSettings = settings;
      }
    }

    return MediaPlaybackState(
      audioItem: clearAudioItem ? null : audioItem ?? this.audioItem,
      sentences: sentences ?? this.sentences,
      currentFullIndex: clearCurrentFullIndex
          ? null
          : currentFullIndex ?? this.currentFullIndex,
      currentBookmarkIndex: clearCurrentBookmarkIndex
          ? null
          : currentBookmarkIndex ?? this.currentBookmarkIndex,
      lastPlayedFullIndex: clearLastPlayedFullIndex
          ? null
          : lastPlayedFullIndex ?? this.lastPlayedFullIndex,
      lastPlayedBookmarkIndex: clearLastPlayedBookmarkIndex
          ? null
          : lastPlayedBookmarkIndex ?? this.lastPlayedBookmarkIndex,
      sentenceFocusRevision: requestSentenceFocus
          ? sentenceFocusRevision + 1
          : sentenceFocusRevision,
      sentenceFocusReason: sentenceFocusReason ?? this.sentenceFocusReason,
      fullSettings: nextFullSettings,
      bookmarkSettings: nextBookmarkSettings,
      playlistMode: nextPlaylistMode,
      bookmarkedIndices: bookmarkedIndices ?? this.bookmarkedIndices,
      isLoading: isLoading ?? this.isLoading,
      isTranscriptLoading: isTranscriptLoading ?? this.isTranscriptLoading,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      isPlaying: isPlaying ?? this.isPlaying,
      wholeLoopsDone: wholeLoopsDone ?? this.wholeLoopsDone,
      sentenceRepeatsDone: sentenceRepeatsDone ?? this.sentenceRepeatsDone,
      playbackInterval: clearPlaybackInterval
          ? null
          : playbackInterval ?? this.playbackInterval,
      position: position ?? this.position,
      duration: clearDuration ? null : duration ?? this.duration,
      visualTrackVisible: visualTrackVisible ?? this.visualTrackVisible,
      visualTrackExpanded: visualTrackExpanded ?? this.visualTrackExpanded,
      videoSubtitleVisible: videoSubtitleVisible ?? this.videoSubtitleVisible,
      isLandscapeVideo: clearIsLandscapeVideo
          ? null
          : isLandscapeVideo ?? this.isLandscapeVideo,
      videoAspectRatio: clearVideoAspectRatio
          ? null
          : videoAspectRatio ?? this.videoAspectRatio,
    );
  }
}
