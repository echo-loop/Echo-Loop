import 'audio_item.dart';
import 'sentence.dart';
import 'playback_settings.dart';

enum PlaylistMode { full, bookmarks }

class ListeningPracticeState {
  final AudioItem? currentAudioItem;
  final List<Sentence> sentences;
  final int? currentFullIndex;
  final int? currentBookmarkIndex;
  final int? lastPlayedFullIndex;
  final int? lastPlayedBookmarkIndex;
  final PlaybackSettings fullSettings;
  final PlaybackSettings bookmarkSettings;
  final PlaylistMode playlistMode;
  final Set<int> bookmarkedIndices;
  final bool isLoading;

  /// 逻辑播放态：controller 当前是否处于「播放意图」。
  ///
  /// 这是播放/暂停按钮图标的唯一真相源，由 controller 在起播/暂停/停止/自然播完
  /// 等明确入口显式维护，**不**读 just_audio 的 `AudioPlayer.playing`——后者在
  /// 自然播完（completed）后仍为 true，会让图标误显「暂停」。
  final bool isPlaying;

  const ListeningPracticeState({
    this.currentAudioItem,
    this.sentences = const [],
    this.currentFullIndex,
    this.currentBookmarkIndex,
    this.lastPlayedFullIndex,
    this.lastPlayedBookmarkIndex,
    PlaybackSettings? settings,
    PlaybackSettings fullSettings = const PlaybackSettings(),
    PlaybackSettings bookmarkSettings = kDefaultBookmarkPlaybackSettings,
    this.playlistMode = PlaylistMode.full,
    this.bookmarkedIndices = const {},
    this.isLoading = false,
    this.isPlaying = false,
  }) : fullSettings = settings ?? fullSettings,
       bookmarkSettings = settings ?? bookmarkSettings;

  /// 当前激活 Tab 生效的播放设置。
  PlaybackSettings get settings =>
      playlistMode == PlaylistMode.bookmarks ? bookmarkSettings : fullSettings;

  // 计算属性
  List<Sentence> get bookmarkedSentences =>
      sentences.where((s) => bookmarkedIndices.contains(s.index)).toList();

  Sentence? get currentSentence =>
      currentFullIndex != null && currentFullIndex! < sentences.length
      ? sentences[currentFullIndex!]
      : null;

  bool get hasAudio => currentAudioItem != null;
  bool get hasSentences => sentences.isNotEmpty;

  ListeningPracticeState copyWith({
    AudioItem? currentAudioItem,
    bool clearCurrentAudioItem = false,
    List<Sentence>? sentences,
    int? currentFullIndex,
    bool clearCurrentFullIndex = false,
    int? currentBookmarkIndex,
    bool clearCurrentBookmarkIndex = false,
    int? lastPlayedFullIndex,
    bool clearLastPlayedFullIndex = false,
    int? lastPlayedBookmarkIndex,
    bool clearLastPlayedBookmarkIndex = false,
    PlaybackSettings? fullSettings,
    PlaybackSettings? bookmarkSettings,
    PlaybackSettings? settings,
    PlaylistMode? playlistMode,
    Set<int>? bookmarkedIndices,
    bool? isLoading,
    bool? isPlaying,
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

    return ListeningPracticeState(
      currentAudioItem: clearCurrentAudioItem
          ? null
          : (currentAudioItem ?? this.currentAudioItem),
      sentences: sentences ?? this.sentences,
      currentFullIndex: clearCurrentFullIndex
          ? null
          : (currentFullIndex ?? this.currentFullIndex),
      currentBookmarkIndex: clearCurrentBookmarkIndex
          ? null
          : (currentBookmarkIndex ?? this.currentBookmarkIndex),
      lastPlayedFullIndex: clearLastPlayedFullIndex
          ? null
          : (lastPlayedFullIndex ?? this.lastPlayedFullIndex),
      lastPlayedBookmarkIndex: clearLastPlayedBookmarkIndex
          ? null
          : (lastPlayedBookmarkIndex ?? this.lastPlayedBookmarkIndex),
      fullSettings: nextFullSettings,
      bookmarkSettings: nextBookmarkSettings,
      playlistMode: nextPlaylistMode,
      bookmarkedIndices: bookmarkedIndices ?? this.bookmarkedIndices,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
