/// 句子详情页面
///
/// 通用句子解析页面，展示单个句子的翻译/语法/意群工具栏和播放按钮。
/// 支持收藏切换（BookmarkToggleRow）。
/// 由复述页面的句子列表和收藏页面的句子列表共同使用。
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
import '../models/audio_item.dart' as model;
import '../models/media_playback_state.dart';
import '../models/sense_group_range_playback.dart';
import '../models/sentence.dart';
import '../models/word_highlight_binding.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/media_engine/media_engine_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../providers/favorite_sentence_lifecycle_provider.dart';
import '../providers/notification_permission_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/media_visual_surface.dart';
import '../widgets/common/tappable_wrapper.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
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

  /// 句子索引
  final int sentenceIndex;

  /// 当前材料的句子总数。为空时仅显示当前句序号。
  final int? totalSentenceCount;

  /// 句子起始时间（毫秒）
  final int startTimeMs;

  /// 句子结束时间（毫秒）
  final int endTimeMs;

  /// 由调用方注入的句子与意群区间播放器，绑定到当前学习会话的播放引擎。
  ///
  /// 为空时，详情页使用自己的音频播放逻辑。
  final SenseGroupRangePlayback? rangePlayback;

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
    this.totalSentenceCount,
    required this.startTimeMs,
    required this.endTimeMs,
    this.rangePlayback,
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
  bool _isPlaying = false;
  bool _isBookmarked = false;
  bool _bookmarkLoaded = false;
  bool _isTogglingBookmark = false;
  bool _mediaExpanded = false;
  Duration? _resumePosition;
  int _playbackGeneration = 0;

  /// 缓存 engine 引用，dispose 时 ref 已不可用
  late final AudioEngine _engine;

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
    _loadBookmarkStatus();
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
    // 这里只暂停并失效讲解页 session，不 stop；否则晚到的 stop 会在播放器返回后
    // 重置 clip/position，造成句首短暂漏播和按钮状态误判。
    final rangePlayback = widget.args.rangePlayback;
    final mediaSession = widget.args.mediaSession;
    if (mediaSession != null && _mediaExpanded) {
      AppLogger.log(
        'SentenceDetailMedia',
        'exit fullscreen on dispose audio=${widget.args.audioItemId} '
            'sentence=${widget.args.sentenceIndex}',
      );
      unawaited(Future<void>(() => mediaSession.setFullscreen(false)));
    }
    if (rangePlayback != null) {
      unawaited(Future<void>(() => rangePlayback.cancel()));
    } else {
      Future(() => _engine.pause());
    }
    super.dispose();
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
        _isBookmarked = indices.contains(widget.args.sentenceIndex);
        _bookmarkLoaded = true;
      });
    }
  }

  /// 切换收藏状态（防重入）
  Future<void> _toggleBookmark() async {
    if (_isTogglingBookmark) return;
    _isTogglingBookmark = true;

    try {
      final args = widget.args;
      if (_isBookmarked) {
        await ref.read(favoriteSentenceLifecycleProvider).remove(
          args.audioItemId,
          {args.sentenceIndex},
        );
      } else {
        final sentence = Sentence(
          index: args.sentenceIndex,
          text: args.sentenceText,
          startTime: Duration(milliseconds: args.startTimeMs),
          endTime: Duration(milliseconds: args.endTimeMs),
        );
        await ref
            .read(favoriteSentenceLifecycleProvider)
            .save(args.audioItemId, sentence);
      }

      // 埋点：收藏/取消收藏句子
      final isAdding = !_isBookmarked;
      final analyticsParams = {
        ...ref.audioEventParams(args.audioItemId),
        EventParams.sentenceIndex: args.sentenceIndex,
        EventParams.action: _isBookmarked ? 'remove' : 'add',
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
        setState(() => _isBookmarked = !_isBookmarked);
      }
    } finally {
      _isTogglingBookmark = false;
    }
  }

  /// 播放该句子的原声片段
  Future<void> _playSentence() async {
    final rangePlayback = widget.args.rangePlayback;
    if (_isPlaying) {
      await _pauseSentencePlayback(rangePlayback);
      return;
    }

    final generation = ++_playbackGeneration;
    final args = widget.args;
    final sentenceStart = Duration(milliseconds: args.startTimeMs);
    final sentenceEnd = Duration(milliseconds: args.endTimeMs);
    final resumePosition = _takeResumePosition(sentenceStart, sentenceEnd);
    if (mounted) setState(() => _isPlaying = true);

    if (rangePlayback != null) {
      final resumablePlayback = switch (rangePlayback) {
        ResumableSentenceRangePlayback playback => playback,
        _ => null,
      };
      AppLogger.log(
        'SentenceDetailMedia',
        '▶ range start audio=${args.audioItemId} '
            'sentence=${args.sentenceIndex} '
            'startMs=${(resumePosition ?? sentenceStart).inMilliseconds} '
            'endMs=${sentenceEnd.inMilliseconds} '
            'resuming=${resumePosition != null}',
      );
      try {
        if (resumePosition != null && resumablePlayback != null) {
          await resumablePlayback.playFromPosition(
            args.audioItemId,
            sentenceStart,
            sentenceEnd,
            resumePosition,
          );
        } else {
          await rangePlayback.play(
            args.audioItemId,
            sentenceStart,
            sentenceEnd,
          );
        }
        AppLogger.log(
          'SentenceDetailMedia',
          '✓ range complete audio=${args.audioItemId} '
              'sentence=${args.sentenceIndex}',
        );
      } catch (error) {
        AppLogger.log(
          'SentenceDetailMedia',
          '✗ range failed audio=${args.audioItemId} '
              'sentence=${args.sentenceIndex}: $error',
        );
      } finally {
        _setPlaybackStoppedIfCurrent(generation);
      }
      return;
    }

    final engine = ref.read(audioEngineProvider.notifier);

    try {
      final engineState = ref.read(audioEngineProvider);

      // 如果当前加载的不是同一音频，重新加载
      if (engineState.currentAudioId != args.audioItemId) {
        final dao = ref.read(audioItemDaoProvider);
        final row = await dao.getById(args.audioItemId);
        if (row == null || !mounted) {
          return;
        }

        final audioItem = model.AudioItem(
          id: row.id,
          name: row.name,
          audioPath: row.audioPath,
          transcriptPath: row.transcriptPath,
          addedDate: row.addedDate,
          totalDuration: row.totalDuration,
          sentenceCount: row.sentenceCount,
          wordCount: row.wordCount,
          isPinned: row.isPinned,
          transcriptSource: model.TranscriptSource.fromIndex(
            row.transcriptSource,
          ),
          audioSha256: row.audioSha256,
          originalAudioSha256: row.originalAudioSha256,
          transcriptLanguage: row.transcriptLanguage,
        );

        await engine.loadAudio(audioItem, 1.0);
      }

      if (!mounted) return;

      final sessionId = engine.newSession();
      await engine.playRangeOnce(
        resumePosition ?? sentenceStart,
        sentenceEnd,
        sessionId,
      );
    } catch (_) {
      // 忽略播放错误（音频文件不存在等）
    } finally {
      _setPlaybackStoppedIfCurrent(generation);
    }
  }

  /// 暂停时快照句子内的绝对位置，再取消本次播放请求。
  Future<void> _pauseSentencePlayback(
    SenseGroupRangePlayback? rangePlayback,
  ) async {
    final args = widget.args;
    final start = Duration(milliseconds: args.startTimeMs);
    final end = Duration(milliseconds: args.endTimeMs);
    final position = switch (rangePlayback) {
      ResumableSentenceRangePlayback playback => playback.currentPosition,
      null => _engine.absoluteCurrentPosition,
      _ => null,
    };
    _resumePosition = position != null && position >= start && position < end
        ? position
        : null;
    _playbackGeneration++;
    if (mounted) setState(() => _isPlaying = false);

    if (rangePlayback != null) {
      await rangePlayback.cancel();
    } else {
      await _engine.pause();
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final args = widget.args;
    final durationMs = args.endTimeMs - args.startTimeMs;
    final durationSec = durationMs / 1000;
    final durationText = l10n.sentenceDuration(durationSec.toStringAsFixed(1));
    final sentenceProgressText = args.totalSentenceCount == null
        ? '第 ${args.sentenceIndex + 1} 句'
        : '第 ${args.sentenceIndex + 1}/${args.totalSentenceCount} 句';

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
                    text: args.sentenceText,
                    audioItemId: args.audioItemId,
                    sentenceIndex: args.sentenceIndex,
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
              child: Column(
                children: [
                  if (mediaSurface != null) mediaSurface,
                  // 句子进度与收藏操作保持单行，方便用户快速确认当前位置。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.m,
                      AppSpacing.m,
                      AppSpacing.m,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$sentenceProgressText · $durationText',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (_bookmarkLoaded)
                          SizedBox(
                            width: 104,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: BookmarkToggleRow(
                                isDifficult: _isBookmarked,
                                onTap: _toggleBookmark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    key: ValueKey('sentence-detail-explanation-gap'),
                    height: 6,
                  ),

                  // 主体内容：解析/翻译/意群 + 句子文本
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                      ),
                      child: SentenceExplanationView(
                        text: args.sentenceText,
                        aiNotifier: ref.read(sentenceAiNotifierProvider),
                        audioItemId: args.audioItemId,
                        wordHighlightSource: args.wordHighlightSource,
                        sentenceIndex: args.sentenceIndex,
                        sentenceStartMs: args.startTimeMs,
                        sentenceEndMs: args.endTimeMs,
                        onStopMainPlayer: () {
                          _playbackGeneration++;
                          _resumePosition = null;
                          final rangePlayback = args.rangePlayback;
                          if (rangePlayback != null) {
                            unawaited(rangePlayback.cancel());
                          } else if (_isPlaying) {
                            ref.read(audioEngineProvider.notifier).stop();
                          }
                          if (_isPlaying) setState(() => _isPlaying = false);
                        },
                        senseGroupRangePlayback: args.rangePlayback,
                      ),
                    ),
                  ),

                  // 底部播放按钮
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.m,
                      bottom: 64,
                    ),
                    child: _PlayButton(
                      isPlaying: _isPlaying,
                      onTap: _playSentence,
                    ),
                  ),
                ],
              ),
            ),
    );
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
        onPlayPause: () => unawaited(_playSentence()),
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

/// 单句播放按钮
class _PlayButton extends StatelessWidget {
  /// 是否正在播放
  final bool isPlaying;

  /// 点击回调
  final VoidCallback onTap;

  const _PlayButton({required this.isPlaying, required this.onTap});

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TappableWrapper(
      onTap: onTap,
      feedbackType: TapFeedback.scale,
      scaleDown: 0.92,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 28,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
