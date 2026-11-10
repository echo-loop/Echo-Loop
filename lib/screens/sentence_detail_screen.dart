/// 句子讲解页面
///
/// 与逐句精听共用同一套控制区：顶部全篇进度条、句子信息行，中间可横滑切句的
/// 讲解内容，底部上一句 / 播放暂停 / 下一句 / 速度。入口句所在的整篇字幕即切句范围。
/// 支持收藏切换（BookmarkToggleRow）。
/// 由盲听、复述、随心听的句子列表和收藏页面共同使用。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/audio_event_params.dart';
import '../analytics/models/event_names.dart';
import '../features/usage/usage_event.dart';
import '../features/usage/usage_providers.dart';
import '../database/providers.dart';
import '../features/chatbot/widgets/sentence_chat_button.dart';
import '../features/chatbot/sentence_passage.dart';
import '../l10n/app_localizations.dart';
import '../models/media_playback_state.dart';
import '../models/sense_group_range_playback.dart';
import '../models/sentence.dart';
import '../models/word_highlight_binding.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/audio_engine/audio_engine_sense_group_range_playback.dart';
import '../providers/audio_sentences_provider.dart';
import '../providers/media_engine/media_engine_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../providers/favorite_sentence_lifecycle_provider.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/notification_permission_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/practice_playback_footer.dart';
import '../widgets/common/media_visual_surface.dart';
import '../widgets/common/playback_controls.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../widgets/practice/practice_sentence_pager.dart';
import '../widgets/practice/sentence_explanation_view.dart';

/// 句子讲解页借用的视频会话。
///
/// 会话由父任务创建并持有 [MediaEngine] 的生命周期；本页只通过这份契约
/// 渲染画面及发出控制意图，因而不会依赖某个具体任务的 Provider。
class SentenceDetailMediaSession {
  const SentenceDetailMediaSession({
    required this.readState,
    required this.setVisible,
    required this.setSubtitleVisible,
    required this.setFullscreen,
    required this.buildVideoView,
  });

  /// 父任务提供的媒体视觉单一状态源。
  final MediaPlaybackState Function() readState;
  final Future<void> Function(bool visible) setVisible;
  final Future<void> Function(bool visible) setSubtitleVisible;
  final Future<void> Function(bool expanded) setFullscreen;
  final Widget Function(Size viewportSize) buildVideoView;
}

/// 句子详情页面参数
class SentenceDetailArgs {
  /// 音频 ID
  final String audioItemId;

  /// 音频名称（用于 AppBar 显示）
  final String audioName;

  /// 句子文本
  final String sentenceText;

  /// 入口句的句子索引；讲解页打开后切句以整篇字幕为准。
  final int sentenceIndex;

  /// 句子起始时间（毫秒）
  final int startTimeMs;

  /// 句子结束时间（毫秒）
  final int endTimeMs;

  /// 由调用方提供的区间播放器工厂，绑定到调用方所在学习会话的播放引擎。
  ///
  /// 讲解页用自己的速度（每次进入为 1.0x）调用工厂，因此速度不会沿用来源任务。
  /// 为空时使用全局音频引擎播放。
  final SenseGroupRangePlayback Function(double Function() playbackSpeed)?
  rangePlaybackBuilder;

  /// 视频随心听注入的画面呈现能力。
  ///
  /// 仅作为当前父级媒体会话的视图与全屏协调入口，不拥有、不加载也不释放
  /// `MediaEngine`。为空时讲解页保持原有纯音频布局。
  final SentenceDetailMediaSession? mediaSession;

  /// 调用方当前实际使用的原音播放时间轴。
  final WordHighlightSource wordHighlightSource;

  const SentenceDetailArgs({
    required this.audioItemId,
    required this.audioName,
    required this.sentenceText,
    required this.sentenceIndex,
    required this.startTimeMs,
    required this.endTimeMs,
    this.rangePlaybackBuilder,
    this.mediaSession,
    required this.wordHighlightSource,
  });
}

/// 句子详情页面
class SentenceDetailScreen extends ConsumerStatefulWidget {
  /// 页面参数
  final SentenceDetailArgs args;

  const SentenceDetailScreen({super.key, required this.args});

  @override
  ConsumerState<SentenceDetailScreen> createState() =>
      _SentenceDetailScreenState();
}

class _SentenceDetailScreenState extends ConsumerState<SentenceDetailScreen> {
  /// 切句范围：入口句所在的整篇字幕。为 null 表示仍在加载。
  List<Sentence>? _sentences;

  /// 当前句在 [_sentences] 中的位置，即分页与进度条的唯一真相源。
  int _position = 0;

  /// 字幕读取失败时的错误；非空时展示可重试的错误态，而不是静默降级。
  Object? _loadError;

  /// 已收藏的句子索引（整篇范围），切句时直接查询，无需再读库。
  Set<int> _bookmarkedIndices = const {};
  bool _bookmarkLoaded = false;
  bool _isTogglingBookmark = false;

  bool _isPlaying = false;
  bool _mediaExpanded = false;
  Duration? _resumePosition;
  int _playbackGeneration = 0;

  /// 讲解页本地速度。每次进入固定为 1.0x，不持久化，也不影响来源页。
  double _playbackSpeed = 1.0;

  final PracticeSentencePagerController _sentencePager =
      PracticeSentencePagerController();

  /// 缓存 engine 引用，dispose 时 ref 已不可用
  late final AudioEngine _engine;

  /// 句子与意群共用的区间播放器，播放速度读取本页的 [_playbackSpeed]。
  late final SenseGroupRangePlayback _rangePlayback;

  /// 讲解页入口句，字幕加载失败或字幕已改动时作为唯一可用句子。
  Sentence get _entrySentence => Sentence(
    index: widget.args.sentenceIndex,
    text: widget.args.sentenceText,
    startTime: Duration(milliseconds: widget.args.startTimeMs),
    endTime: Duration(milliseconds: widget.args.endTimeMs),
  );

  /// 当前显示的句子；加载完成前退化为入口句，供 AppBar 与埋点取值。
  Sentence get _currentSentence {
    final sentences = _sentences;
    return sentences == null ? _entrySentence : sentences[_position];
  }

  @override
  void initState() {
    super.initState();
    AppLogger.log(
      'Navigation',
      'sentence-detail init audio=${widget.args.audioItemId} '
          'sentence=${widget.args.sentenceIndex} '
          'media=${widget.args.mediaSession != null}',
    );
    _engine = ref.read(audioEngineProvider.notifier);
    final rangePlaybackBuilder = widget.args.rangePlaybackBuilder;
    _rangePlayback =
        rangePlaybackBuilder?.call(() => _playbackSpeed) ??
        AudioEngineSenseGroupRangePlayback(
          engine: _engine,
          playbackSpeed: () => _playbackSpeed,
        );
    _loadBookmarkStatus();
    unawaited(_loadSentences());
  }

  @override
  void dispose() {
    AppLogger.log(
      'Navigation',
      'sentence-detail dispose audio=${widget.args.audioItemId} '
          'sentence=${widget.args.sentenceIndex}',
    );
    // 延迟到帧结束后再暂停音频：返回上一页时，监听 audioEngineProvider 的
    // 页面（如全能播放器的进度条）正在重建，若在 dispose 同步阶段改 provider
    // 会触发 "Tried to modify a provider while the widget tree was building"。
    // 这里只取消讲解页 session，不 stop；否则晚到的 stop 会在播放器返回后
    // 重置 clip/position，造成句首短暂漏播和按钮状态误判。
    final mediaSession = widget.args.mediaSession;
    if (mediaSession != null && _mediaExpanded) {
      AppLogger.log(
        'SentenceDetailMedia',
        'exit fullscreen on dispose audio=${widget.args.audioItemId} '
            'sentence=${widget.args.sentenceIndex}',
      );
      unawaited(Future<void>(() => mediaSession.setFullscreen(false)));
    }
    unawaited(Future<void>(() => _rangePlayback.cancel()));
    super.dispose();
  }

  /// 读取整篇字幕作为切句范围。
  ///
  /// 读取失败（数据库或字幕解析异常）进入可重试的错误态；字幕缺失、或入口句已不在字幕
  /// 中（如字幕被编辑过）则属于正常情况，此时才退化为单句讲解。
  Future<void> _loadSentences() async {
    final List<Sentence> transcript;
    try {
      transcript = await ref.read(
        audioSentencesProvider(widget.args.audioItemId).future,
      );
    } catch (error, stackTrace) {
      // 页面数据读取的边界：异常在此记录并转为错误态，不向上逃逸。
      AppLogger.log(
        'SentenceDetail',
        'load transcript failed audio=${widget.args.audioItemId}: '
            '$error\n$stackTrace',
      );
      if (mounted) setState(() => _loadError = error);
      return;
    }
    if (!mounted) return;
    _applyTranscript(transcript);
  }

  void _applyTranscript(List<Sentence> transcript) {
    final entryPosition = _findEntryPosition(transcript);
    if (entryPosition == null) {
      AppLogger.log(
        'SentenceDetail',
        'entry sentence not in transcript, fallback to single sentence '
            'audio=${widget.args.audioItemId} sentence=${widget.args.sentenceIndex} '
            'transcriptCount=${transcript.length}',
      );
    }
    setState(() {
      _loadError = null;
      _sentences = entryPosition == null ? [_entrySentence] : transcript;
      _position = entryPosition ?? 0;
    });
  }

  void _retryLoadSentences() {
    setState(() => _loadError = null);
    unawaited(_loadSentences());
  }

  /// 定位入口句：优先信任仍与文本一致的原句序，否则按文本查找。
  int? _findEntryPosition(List<Sentence> transcript) {
    final entryText = widget.args.sentenceText.trim();
    if (entryText.isEmpty) return null;
    final preferred = widget.args.sentenceIndex;
    if (preferred >= 0 &&
        preferred < transcript.length &&
        transcript[preferred].text.trim() == entryText) {
      return preferred;
    }
    final position = transcript.indexWhere(
      (sentence) => sentence.text.trim() == entryText,
    );
    return position < 0 ? null : position;
  }

  /// 从数据库加载收藏状态
  Future<void> _loadBookmarkStatus() async {
    final dao = ref.read(bookmarkDaoProvider);
    final indices = await BookmarkManager.loadBookmarks(
      widget.args.audioItemId,
      dao: dao,
    );
    if (mounted) {
      setState(() {
        _bookmarkedIndices = indices;
        _bookmarkLoaded = true;
      });
    }
  }

  /// 切换当前句的收藏状态（防重入）
  Future<void> _toggleBookmark() async {
    if (_isTogglingBookmark) return;
    _isTogglingBookmark = true;

    try {
      final args = widget.args;
      final sentence = _currentSentence;
      final isBookmarked = _bookmarkedIndices.contains(sentence.index);
      if (isBookmarked) {
        await ref.read(favoriteSentenceLifecycleProvider).remove(
          args.audioItemId,
          {sentence.index},
        );
      } else {
        await ref
            .read(favoriteSentenceLifecycleProvider)
            .save(args.audioItemId, sentence);
      }

      // 埋点：收藏/取消收藏句子
      final isAdding = !isBookmarked;
      final analyticsParams = {
        ...ref.audioEventParams(args.audioItemId),
        EventParams.sentenceIndex: sentence.index,
        EventParams.action: isBookmarked ? 'remove' : 'add',
      };
      if (isAdding) {
        await ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.bookmarkSentenceSaved,
              analyticsParams: analyticsParams,
            );
      } else {
        ref
            .read(analyticsServiceProvider)
            .track(Events.bookmarkToggle, analyticsParams);
      }

      // 价值锚点：只在「添加收藏」时尝试触发通知权限 pre-prompt
      if (isAdding) {
        unawaited(
          ref.read(notificationPermissionServiceProvider).maybeTriggerPrompt(),
        );
      }

      if (mounted) {
        setState(() {
          final nextIndices = {..._bookmarkedIndices};
          if (isBookmarked) {
            nextIndices.remove(sentence.index);
          } else {
            nextIndices.add(sentence.index);
          }
          _bookmarkedIndices = nextIndices;
        });
      }
    } finally {
      _isTogglingBookmark = false;
    }
  }

  /// 切换播放：播放当前句的原声片段；播放中则暂停并记住位置，便于续播。
  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _pauseSentencePlayback();
      return;
    }

    final generation = ++_playbackGeneration;
    final sentence = _currentSentence;
    final sentenceStart = sentence.startTime;
    final sentenceEnd = sentence.endTime;
    final resumePosition = _takeResumePosition(sentenceStart, sentenceEnd);
    if (mounted) setState(() => _isPlaying = true);

    final rangePlayback = _rangePlayback;
    final resumablePlayback = switch (rangePlayback) {
      ResumableSentenceRangePlayback playback => playback,
      _ => null,
    };
    final audioItemId = widget.args.audioItemId;
    AppLogger.log(
      'SentenceDetailMedia',
      '▶ range start audio=$audioItemId sentence=${sentence.index} '
          'startMs=${(resumePosition ?? sentenceStart).inMilliseconds} '
          'endMs=${sentenceEnd.inMilliseconds} '
          'speed=$_playbackSpeed resuming=${resumePosition != null}',
    );
    try {
      if (resumePosition != null && resumablePlayback != null) {
        await resumablePlayback.playFromPosition(
          audioItemId,
          sentenceStart,
          sentenceEnd,
          resumePosition,
        );
      } else {
        await rangePlayback.play(audioItemId, sentenceStart, sentenceEnd);
      }
      AppLogger.log(
        'SentenceDetailMedia',
        '✓ range complete audio=$audioItemId sentence=${sentence.index}',
      );
    } catch (error) {
      AppLogger.log(
        'SentenceDetailMedia',
        '✗ range failed audio=$audioItemId sentence=${sentence.index}: $error',
      );
    } finally {
      _setPlaybackStoppedIfCurrent(generation);
    }
  }

  /// 暂停时快照句子内的绝对位置，再取消本次播放请求。
  Future<void> _pauseSentencePlayback() async {
    final sentence = _currentSentence;
    final start = sentence.startTime;
    final end = sentence.endTime;
    final position = switch (_rangePlayback) {
      ResumableSentenceRangePlayback playback => playback.currentPosition,
      _ => null,
    };
    final resumeFromSentenceStart = ref
        .read(appSettingsProvider)
        .resumeFromSentenceStartEnabled;
    _resumePosition = position != null && position >= start && position < end
        ? (resumeFromSentenceStart ? start : position)
        : null;
    _playbackGeneration++;
    if (mounted) setState(() => _isPlaying = false);
    await _rangePlayback.cancel();
  }

  /// 停止播放并使迟到的完成回调失效；切句、讲解区播放意群前调用。
  Future<void> _stopPlayback() async {
    _playbackGeneration++;
    _resumePosition = null;
    if (mounted && _isPlaying) setState(() => _isPlaying = false);
    await _rangePlayback.cancel();
  }

  /// 切到整篇范围中的第 [position] 句。进度条、横滑、上下句按钮与快捷键都汇入这里。
  Future<void> _goToPosition(int position) async {
    final sentences = _sentences;
    if (sentences == null ||
        position == _position ||
        position < 0 ||
        position >= sentences.length) {
      return;
    }
    AppLogger.log(
      'SentenceDetail',
      'switch sentence audio=${widget.args.audioItemId} '
          'from=${_currentSentence.index} to=${sentences[position].index}',
    );
    await _stopPlayback();
    if (!mounted) return;
    setState(() => _position = position);
  }

  /// 上一句：先完成分页动画，再提交切句。
  void _handlePrevious() {
    final target = _position - 1;
    if (target < 0) return;
    unawaited(
      _sentencePager.animateAndCommit(
        target,
        commit: () => _goToPosition(target),
      ),
    );
  }

  /// 下一句：先完成分页动画，再提交切句。
  void _handleNext() {
    final sentences = _sentences;
    if (sentences == null) return;
    final target = _position + 1;
    if (target >= sentences.length) return;
    unawaited(
      _sentencePager.animateAndCommit(
        target,
        commit: () => _goToPosition(target),
      ),
    );
  }

  /// 设置本页播放速度。正在播放时立即作用于当前句，未播放时从下一次播放生效。
  void _setPlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (!_isPlaying) return;
    switch (_rangePlayback) {
      case LiveSpeedRangePlayback playback:
        unawaited(playback.setPlaybackSpeed(speed));
      default:
        AppLogger.log(
          'SentenceDetailMedia',
          'speed not applied to playing range: player lacks live speed '
              'speed=$speed',
        );
    }
  }

  Duration? _takeResumePosition(Duration start, Duration end) {
    final position = _resumePosition;
    _resumePosition = null;
    return position != null && position >= start && position < end
        ? position
        : null;
  }

  void _setPlaybackStoppedIfCurrent(int generation) {
    if (mounted && generation == _playbackGeneration) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final args = widget.args;
    final sentences = _sentences;
    final current = _currentSentence;
    final showPlaybackSpeedButton = ref.watch(
      learningSettingsProvider.select((s) => s.showPlaybackSpeedButton),
    );

    final mediaSession = args.mediaSession;
    final hasMedia = mediaSession != null;
    final mediaState = hasMedia
        ? mediaSession.readState()
        : const MediaPlaybackState();
    final expanded = hasMedia && mediaState.visualTrackExpanded;
    _mediaExpanded = expanded;
    final mediaSurface = hasMedia
        ? _buildMediaSurface(mediaState, mediaSession)
        : null;
    return Scaffold(
      backgroundColor: expanded ? Colors.black : null,
      appBar: expanded
          ? null
          : AppBar(
              actionsPadding: const EdgeInsets.only(right: AppSpacing.s),
              title: Text(args.audioName),
              centerTitle: true,
              actions: [
                SentenceChatButton(
                  target: SentenceChatTarget(
                    text: current.text,
                    audioItemId: args.audioItemId,
                    sentenceIndex: current.index,
                  ),
                ),
              ],
            ),
      // 词典面板宿主：面板内嵌 body、非 modal（显示期间正文可继续点词）。
      // 页面自身无 PopScope，由宿主代管返回键（面板开着时先关面板）。
      body: expanded
          ? mediaSurface
          : DictionaryPanelHost(
              handleBackButton: true,
              child: LearningHotkeyScope(
                onPlayPause: _handleCenter,
                onPrevious: _handlePrevious,
                onNext: _handleNext,
                child: Column(
                  children: [
                    if (mediaSurface != null) mediaSurface,
                    if (sentences == null)
                      Expanded(
                        child: Center(
                          child: _loadError == null
                              ? const CircularProgressIndicator()
                              : _buildLoadError(l10n),
                        ),
                      )
                    else ...[
                      PracticeProgressBar(
                        current: _position + 1,
                        total: sentences.length,
                        elapsed: current.startTime,
                        remaining: sentences.last.endTime - current.startTime,
                        onSeek: (position) =>
                            unawaited(_goToPosition(position)),
                      ),
                      PracticeSentenceInfoRow(
                        progressText:
                            '第 ${_position + 1}/${sentences.length} 句',
                        durationText: l10n.sentenceDuration(
                          (current.duration.inMilliseconds / 1000)
                              .toStringAsFixed(1),
                        ),
                        trailing: _bookmarkLoaded
                            ? SizedBox(
                                width: 104,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: BookmarkToggleRow(
                                    isDifficult: _bookmarkedIndices.contains(
                                      current.index,
                                    ),
                                    onTap: _toggleBookmark,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      // 主体内容：解析/翻译/意群 + 句子文本，可横滑切到相邻句。
                      Expanded(
                        child: PracticeSentencePager(
                          controller: _sentencePager,
                          pageViewKey: const ValueKey(
                            'sentence-detail-page-view',
                          ),
                          currentIndex: _position,
                          itemCount: sentences.length,
                          horizontalPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.m,
                          ),
                          onSentenceSettled: _goToPosition,
                          itemBuilder: (context, position) => _buildExplanation(
                            sentences[position],
                            isActive: position == _position,
                          ),
                        ),
                      ),
                      _buildPlaybackControls(
                        position: _position,
                        total: sentences.length,
                        showSpeedControl: showPlaybackSpeedButton,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  /// 单句讲解内容。只有当前页绑定原声高亮与新手引导，相邻页保活时不抢占它们。
  Widget _buildExplanation(Sentence sentence, {required bool isActive}) {
    final args = widget.args;
    return SentenceExplanationView(
      key: ValueKey(sentence.index),
      text: sentence.text,
      aiNotifier: ref.read(sentenceAiNotifierProvider),
      audioItemId: args.audioItemId,
      wordHighlightSource: isActive ? args.wordHighlightSource : null,
      sentenceIndex: sentence.index,
      sentenceStartMs: sentence.startTime.inMilliseconds,
      sentenceEndMs: sentence.endTime.inMilliseconds,
      onStopMainPlayer: () => unawaited(_stopPlayback()),
      senseGroupRangePlayback: _rangePlayback,
      enableGuide: isActive,
      isActiveSentence: isActive,
    );
  }

  /// 字幕读取失败时的错误态：提示并允许重新读取。
  Widget _buildLoadError(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.sentenceDetailLoadFailed),
        const SizedBox(height: AppSpacing.s),
        TextButton(
          onPressed: _retryLoadSentences,
          child: Text(l10n.sentenceDetailRetry),
        ),
      ],
    );
  }

  /// 底部控制区与逐句精听共用 [PracticePlaybackFooter]，保证按钮位置与底部留白一致。
  Widget _buildPlaybackControls({
    required int position,
    required int total,
    required bool showSpeedControl,
  }) {
    return Padding(
      // 与精听底栏一致：控制区上方留出 m 间距，与讲解内容分开。
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: PracticePlaybackFooter(
        canGoPrev: position > 0,
        canGoNext: position < total - 1,
        isLast: false,
        centerIcon: _isPlaying
            ? PlaybackToggleIcon.pause
            : PlaybackToggleIcon.play,
        onPrevious: _handlePrevious,
        onNext: _handleNext,
        onCenter: _handleCenter,
        // 句子讲解没有遍数概念，playCountText 为空，底栏只保留等高的空行。
        isManualMode: false,
        playbackSpeed: showSpeedControl ? _playbackSpeed : null,
        onPlaybackSpeedChanged: showSpeedControl ? _setPlaybackSpeed : null,
        l10n: AppLocalizations.of(context)!,
        theme: Theme.of(context),
      ),
    );
  }

  /// 播放 / 暂停入口，底栏与快捷键共用；字幕加载完成前不响应。
  void _handleCenter() {
    if (_sentences == null) return;
    unawaited(_togglePlayback());
  }

  /// 使用随心听的单一状态源组装共享 media_kit 视频外壳。
  Widget _buildMediaSurface(
    MediaPlaybackState state,
    SentenceDetailMediaSession session,
  ) {
    return MediaVisualSurface(
      state: MediaVisualSurfaceState(
        visible: state.visualTrackVisible,
        expanded: state.visualTrackExpanded,
        isPlaying: _isPlaying,
        subtitleVisible: state.videoSubtitleVisible,
      ),
      actions: MediaVisualSurfaceActions(
        onShow: () => unawaited(_setMediaVisible(session, true)),
        onHide: () => unawaited(_setMediaVisible(session, false)),
        onPlayPause: _handleCenter,
        onSubtitleToggle: () => unawaited(
          _setMediaSubtitleVisible(session, !state.videoSubtitleVisible),
        ),
        onFullscreenToggle: () =>
            unawaited(_setMediaFullscreen(session, !state.visualTrackExpanded)),
      ),
      fillAvailableHeight: state.visualTrackExpanded,
      buildVideoView: session.buildVideoView,
    );
  }

  Future<void> _setMediaVisible(
    SentenceDetailMediaSession session,
    bool visible,
  ) async {
    await session.setVisible(visible);
    if (mounted) setState(() {});
  }

  Future<void> _setMediaSubtitleVisible(
    SentenceDetailMediaSession session,
    bool visible,
  ) async {
    await session.setSubtitleVisible(visible);
    if (mounted) setState(() {});
  }

  Future<void> _setMediaFullscreen(
    SentenceDetailMediaSession session,
    bool expanded,
  ) async {
    await session.setFullscreen(expanded);
    if (mounted) setState(() {});
  }
}
