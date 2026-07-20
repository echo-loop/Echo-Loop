/// 句子详情页面
///
/// 通用句子解析页面，展示单个句子的翻译/语法/意群工具栏和播放按钮。
/// 支持收藏切换（BookmarkToggleRow）。
/// 由复述页面的句子列表和收藏页面的句子列表共同使用。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/audio_event_params.dart';
import '../analytics/models/event_names.dart';
import '../features/usage/usage_event.dart';
import '../features/usage/usage_providers.dart';
import '../database/providers.dart';
import '../features/chatbot/chatbot_flags.dart';
import '../features/chatbot/chatbot_sheet.dart';
import '../features/chatbot/models/chatbot_config.dart';
import '../features/remote_config/remote_config.dart';
import '../features/remote_config/remote_config_providers.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart' as model;
import '../models/sentence.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../providers/notification_permission_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/tappable_wrapper.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/practice/annotation_content_view.dart';

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

  /// 句子起始时间（毫秒）
  final int startTimeMs;

  /// 句子结束时间（毫秒）
  final int endTimeMs;

  const SentenceDetailArgs({
    required this.audioItemId,
    required this.audioName,
    required this.sentenceText,
    required this.sentenceIndex,
    required this.startTimeMs,
    required this.endTimeMs,
  });
}

/// AI 聊天入口显示规则：编译期开关负责硬停，远程开关负责运行期全球隐藏。
@visibleForTesting
bool shouldShowAiChatAssistantEntry({
  required bool chatbotEnabled,
  required bool remoteEnabled,
}) {
  return chatbotEnabled && remoteEnabled;
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

  /// 缓存 engine 引用，dispose 时 ref 已不可用
  late final AudioEngine _engine;

  @override
  void initState() {
    super.initState();
    AppLogger.log(
      'Navigation',
      'sentence-detail init audio=${widget.args.audioItemId} '
          'sentence=${widget.args.sentenceIndex}',
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
    Future(() => _engine.pause());
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
      final dao = ref.read(bookmarkDaoProvider);
      final args = widget.args;
      if (_isBookmarked) {
        await BookmarkManager.removeBookmarksFromDb(args.audioItemId, {
          args.sentenceIndex,
        }, dao: dao);
      } else {
        final sentence = Sentence(
          index: args.sentenceIndex,
          text: args.sentenceText,
          startTime: Duration(milliseconds: args.startTimeMs),
          endTime: Duration(milliseconds: args.endTimeMs),
        );
        await BookmarkManager.addBookmarkToDb(
          args.audioItemId,
          sentence,
          dao: dao,
        );
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

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 播放该句子的原声片段
  Future<void> _playSentence() async {
    final engine = ref.read(audioEngineProvider.notifier);

    if (_isPlaying) {
      engine.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      final engineState = ref.read(audioEngineProvider);
      final args = widget.args;

      // 如果当前加载的不是同一音频，重新加载
      if (engineState.currentAudioId != args.audioItemId) {
        final dao = ref.read(audioItemDaoProvider);
        final row = await dao.getById(args.audioItemId);
        if (row == null || !mounted) {
          setState(() => _isPlaying = false);
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
      final start = Duration(milliseconds: args.startTimeMs);
      final end = Duration(milliseconds: args.endTimeMs);
      await engine.playRangeOnce(start, end, sessionId);
    } catch (_) {
      // 忽略播放错误（音频文件不存在等）
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final args = widget.args;
    final showAiChatAssistant = shouldShowAiChatAssistantEntry(
      chatbotEnabled: kChatbotEnabled,
      remoteEnabled: ref.watch(
        remoteFeatureEnabledProvider(RemoteFeature.aiChatAssistant),
      ),
    );

    final durationMs = args.endTimeMs - args.startTimeMs;
    final durationSec = durationMs / 1000;
    final durationText = l10n.sentenceDuration(durationSec.toStringAsFixed(1));
    final timeRangeText =
        '${_formatTime(args.startTimeMs)} - ${_formatTime(args.endTimeMs)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(args.audioName),
        centerTitle: true,
        // 发布开关：编译期开关保留硬停能力，remote config 支持全球动态隐藏入口。
        actions: [
          if (showAiChatAssistant)
            // 右侧留白：让 action 按钮不贴屏幕右缘，与左侧返回箭头边距对称。
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                // 渐变多色图标，保留原始配色不做 colorFilter 染色。
                // SVG 图案铺满 viewBox（无自带留白），渲染到 20px 使可见footprint
                // 与返回箭头等大，左右视觉边距对称。
                icon: SvgPicture.asset(
                  'assets/icon/chat/use-ai-chat.svg',
                  width: 24,
                  height: 24,
                ),
                tooltip: l10n.chatOpenTooltip,
                onPressed: () => showChatbotSheet(
                  context: context,
                  config: ChatbotConfig(
                    // 会话按句子内容归属：相同句子无论出现在哪都复用同一会话
                    // （context 只传 sentenceText，位置无关）。用完整 text 而非
                    // hashCode，避免 hash 碰撞导致不同句子串会话；sessionId 仅内存 key，长度无妨。
                    sessionId: 'sentence:${args.sentenceText}',
                    endpoint: '/api/v1/stream/chat/sentence',
                    context: {'sentence': args.sentenceText},
                    title: l10n.chatSentenceTitle,
                    inputPlaceholder: l10n.chatInputPlaceholder,
                    contextSummary: args.sentenceText,
                  ),
                ),
              ),
            ),
        ],
      ),
      // 词典面板宿主：面板内嵌 body、非 modal（显示期间正文可继续点词）。
      // 页面自身无 PopScope，由宿主代管返回键（面板开着时先关面板）。
      body: DictionaryPanelHost(
        handleBackButton: true,
        child: Column(
          children: [
            // 句子时间信息
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.l,
                right: AppSpacing.l,
                top: AppSpacing.m,
              ),
              child: Row(
                children: [
                  Text(
                    timeRangeText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    durationText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.m),

            // 收藏标记行
            if (_bookmarkLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: BookmarkToggleRow(
                  isDifficult: _isBookmarked,
                  onTap: _toggleBookmark,
                ),
              ),

            const SizedBox(height: AppSpacing.m),

            // 主体内容：解析/翻译/意群 + 句子文本
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: AnnotationContentView(
                  text: args.sentenceText,
                  aiNotifier: ref.read(sentenceAiNotifierProvider),
                  audioItemId: args.audioItemId,
                  sentenceIndex: args.sentenceIndex,
                  sentenceStartMs: args.startTimeMs,
                  sentenceEndMs: args.endTimeMs,
                  onStopMainPlayer: () {
                    if (_isPlaying) {
                      ref.read(audioEngineProvider.notifier).stop();
                      setState(() => _isPlaying = false);
                    }
                  },
                  autoLoadSentenceAi: true,
                ),
              ),
            ),

            // 底部播放按钮
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.m, bottom: 64),
              child: _PlayButton(isPlaying: _isPlaying, onTap: _playSentence),
            ),
          ],
        ),
      ),
    );
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
