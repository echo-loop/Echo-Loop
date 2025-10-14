import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../l10n/app_localizations.dart';
import '../providers/player_provider.dart';
import '../services/subtitle_parser.dart';
import '../widgets/playback_controls.dart';
import '../widgets/sentence_list_view.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/player_hotkey_scope.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PlayerProvider? _cachedPlayerProvider; // 缓存 Provider 引用

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final player = Provider.of<PlayerProvider>(context, listen: false);
      await player.setPlaylistMode(PlaylistMode.full);
    });
    // Switch mode and pause playback when switching tabs (tap or swipe)
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          (_tabController.animation?.value !=
              _tabController.index.toDouble())) {
        final player = Provider.of<PlayerProvider>(context, listen: false);
        // setPlaylistMode will handle pause automatically
        player.setPlaylistMode(
          _tabController.index == 0
              ? PlaylistMode.full
              : PlaylistMode.bookmarks,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 缓存 Provider 引用，以便在 dispose 中安全使用
    _cachedPlayerProvider = Provider.of<PlayerProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // 使用缓存的 Provider 引用，避免在 dispose 中访问 context
    if (_cachedPlayerProvider != null) {
      _cachedPlayerProvider!.pause();
      _cachedPlayerProvider!.saveCurrentPlaybackState();
    }
    
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return PlayerHotkeyScope(
          player: player,
          child: Scaffold(
            appBar: AppBar(
              title: Text(player.currentAudioItem?.name ?? 'Player'),
              actions: [
                IconButton(
                  icon: Icon(
                    player.autoScrollEnabled
                        ? Icons.center_focus_strong
                        : Icons.center_focus_weak,
                  ),
                  onPressed: () =>
                      player.setAutoScroll(!player.autoScrollEnabled),
                  tooltip: player.autoScrollEnabled
                      ? 'Disable auto-scroll'
                      : 'Enable auto-scroll',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showSettingsDialog(context, player),
                  tooltip: 'Settings',
                ),
              ],
            ),
            body: !player.hasAudio
                ? const Center(child: Text('No audio loaded'))
                : _buildLayout(context, player),
          ),
        );
      },
    );
  }

  Widget _buildLayout(BuildContext context, PlayerProvider player) {
    return Column(
      children: [
        Expanded(child: _buildTranscriptView(player)),
        _buildControlPanel(context, player),
      ],
    );
  }

  // 字幕视图：使用标签页（全文/收藏）
  Widget _buildTranscriptView(PlayerProvider player) {
    final l10n = AppLocalizations.of(context)!;

    if (!player.hasSentences) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subtitles_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noSubtitle,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 标签栏
        TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.article, size: 18),
                  const SizedBox(width: 8),
                  Text('${l10n.fullText} (${player.sentences.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.bookmarked} (${player.bookmarkedSentences.length})',
                  ),
                ],
              ),
            ),
          ],
        ),
        // 标签页内容
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 第一个标签页：全文
              _buildFullTextTab(player),
              // 第二个标签页：收藏列表
              _buildBookmarkedTab(player),
            ],
          ),
        ),
      ],
    );
  }

  // 全文标签页
  Widget _buildFullTextTab(PlayerProvider player) {
    final l10n = AppLocalizations.of(context)!;

    // 单句模式：只展示当前播放的句子
    if (player.settings.singleSentenceMode) {
      if (player.currentFullIndex == null && player.sentences.isNotEmpty) {
        // 自动选择第一个句子（不自动播放）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          player.selectFullSentence(0, autoPlay: false);
        });
        return const Center(child: CircularProgressIndicator());
      }
      if (player.currentFullIndex != null) {
        return _buildSingleSentenceView(player, player.currentFullIndex!);
      }
      return Center(
        child: Text(
          l10n.noSentenceSelected,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    // 非单句模式：展示所有句子列表
    if (player.currentFullIndex == null && player.sentences.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        player.selectFullSentence(0, autoPlay: false);
      });
    }
    return SentenceListView(
      sentences: player.sentences,
      currentIndex: player.currentFullIndex,
      bookmarkedIndices: player.bookmarkedIndices,
      showTranscript: player.settings.showTranscript,
      autoScrollEnabled: player.autoScrollEnabled,
      onSentenceTap: (index) => player.selectFullSentence(index),
      onBookmarkToggle: (index) => player.toggleBookmark(index),
      onUserScroll: () => player.setAutoScroll(false),
      storageKey: 'full_text_list',
    );
  }

  // 收藏标签页
  Widget _buildBookmarkedTab(PlayerProvider player) {
    final l10n = AppLocalizations.of(context)!;
    final bookmarkedSentences = player.bookmarkedSentences;

    if (bookmarkedSentences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noBookmarkedSentences,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tapBookmarkIcon,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 单句模式：只展示当前播放的句子（如果是收藏的）
    if (player.settings.singleSentenceMode) {
      if (player.currentBookmarkIndex == null ||
          !player.bookmarkedIndices.contains(player.currentBookmarkIndex)) {
        // 自动选择第一个收藏的句子
        if (bookmarkedSentences.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            player.selectBookmarkedSentence(
              bookmarkedSentences.first.index,
              autoPlay: false,
            );
          });
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Text(
            l10n.noSentenceSelected,
            style: const TextStyle(color: Colors.grey),
          ),
        );
      }
      return _buildSingleSentenceView(player, player.currentBookmarkIndex!);
    }

    // 非单句模式：展示所有收藏的句子列表
    if ((player.currentBookmarkIndex == null ||
            !player.bookmarkedIndices.contains(player.currentBookmarkIndex)) &&
        bookmarkedSentences.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        player.selectBookmarkedSentence(
          bookmarkedSentences.first.index,
          autoPlay: false,
        );
      });
    }
    return SentenceListView(
      sentences: bookmarkedSentences,
      currentIndex: player.currentBookmarkIndex,
      bookmarkedIndices: player.bookmarkedIndices,
      showTranscript: player.settings.showTranscript,
      autoScrollEnabled: player.autoScrollEnabled,
      onSentenceTap: (index) => player.selectBookmarkedSentence(index),
      onBookmarkToggle: (index) => player.toggleBookmark(index),
      onUserScroll: () => player.setAutoScroll(false),
      storageKey: 'bookmarked_list',
    );
  }

  // 单句视图
  Widget _buildSingleSentenceView(PlayerProvider player, int index) {
    final l10n = AppLocalizations.of(context)!;
    final currentSentence = player.sentences[index];
    final isBookmarked = player.bookmarkedIndices.contains(
      currentSentence.index,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Text(
                      currentSentence.text,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.normal),
                      textAlign: TextAlign.left,
                    ),
                    if (!player.settings.showTranscript)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      SubtitleParser.formatDuration(currentSentence.startTime),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: isBookmarked ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () =>
                          player.toggleBookmark(currentSentence.index),
                      tooltip: isBookmarked
                          ? l10n.removeBookmarkTip
                          : l10n.addBookmarkTip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 显示设置对话框
  void _showSettingsDialog(BuildContext context, PlayerProvider player) {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(player: player),
    );
  }

  Widget _buildControlPanel(BuildContext context, PlayerProvider player) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressBar(player, isMobile),
                PlaybackControls(player: player),
                // 移动端不显示底部信息栏
                if (!isMobile) _buildInfoBar(player),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(PlayerProvider player, bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isMobile ? 16 : 12,
        16,
        isMobile ? 4 : 8,
      ),
      child: StreamBuilder<Duration>(
        stream: player.absolutePositionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final total = player.totalDuration ?? Duration.zero;
          // print('position: $position, total: $total');

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressBar(
                progress: position,
                total: total,
                onSeek: (duration) => player.seekAbsolute(duration),
                barHeight: 3,
                thumbRadius: 5,
                timeLabelTextStyle: const TextStyle(fontSize: 11),
                timeLabelLocation: TimeLabelLocation.none,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    SubtitleParser.formatDuration(position),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(() {
                    final clampedPos = position > total ? total : position;
                    final remaining = total - clampedPos;
                    return '-${SubtitleParser.formatDuration(remaining)}';
                  }(), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // 底部信息栏
  Widget _buildInfoBar(PlayerProvider player) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 左侧：播放状态信息
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 显示当前模式
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    player.settings.singleSentenceMode
                        ? Icons.format_quote
                        : Icons.article,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 3),
                  Text(
                    player.settings.singleSentenceMode
                        ? l10n.singleSentenceMode
                        : l10n.listMode,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              // 显示句子循环状态
              if (player.settings.loopEnabled) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_one, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Text(
                      'x${player.settings.loopCount}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              // 显示音频循环状态
              if (player.settings.loopAudioEnabled) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Text(
                      player.settings.loopAudio == 0
                          ? '∞'
                          : 'x${player.settings.loopAudio}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              // 显示播放速度
              const SizedBox(width: 12),
              Text(
                '${player.settings.playbackSpeed}x',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          // 2 用 Spacer 把右侧整体推到最右
          const Spacer(),
          // 右侧：macOS 快捷键提示轮播
          if (Platform.isMacOS)
            SizedBox(
              // 使用 Align 将子组件贴到 Row 的最右侧
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: _HotkeyTipsCarousel(l10n: l10n),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 快捷键提示轮播 Widget
class _HotkeyTipsCarousel extends StatefulWidget {
  final AppLocalizations l10n;

  const _HotkeyTipsCarousel({required this.l10n});

  @override
  State<_HotkeyTipsCarousel> createState() => _HotkeyTipsCarouselState();
}

class _HotkeyTipsCarouselState extends State<_HotkeyTipsCarousel> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCarousel();
  }

  void _startCarousel() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getCurrentTip() {
    switch (_currentIndex) {
      case 0:
        return widget.l10n.hotkeyReplay;
      case 1:
        return widget.l10n.hotkeyPlayPause;
      case 2:
        return widget.l10n.hotkeyToggleTranscript;
      case 3:
        return widget.l10n.hotkeyNavigation;
      default:
        return widget.l10n.hotkeyReplay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _getCurrentTip(),
        key: ValueKey<int>(_currentIndex),
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        textAlign: TextAlign.right,
      ),
    );
  }
}
