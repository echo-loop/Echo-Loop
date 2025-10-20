import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/sentence.dart';
import '../services/subtitle_parser.dart';
import '../l10n/app_localizations.dart';

class SentenceListView extends StatefulWidget {
  final List<Sentence> sentences;
  final int? currentIndex;
  final Set<int> bookmarkedIndices;
  final Function(int) onSentenceTap;
  final Function(int) onBookmarkToggle;
  final bool showTranscript;
  final bool autoScrollEnabled;
  final VoidCallback? onUserScroll;

  const SentenceListView({
    super.key,
    required this.sentences,
    required this.currentIndex,
    required this.bookmarkedIndices,
    required this.onSentenceTap,
    required this.onBookmarkToggle,
    this.showTranscript = true,
    this.autoScrollEnabled = true,
    this.onUserScroll,
  });

  @override
  State<SentenceListView> createState() => _SentenceListViewState();
}

class _SentenceListViewState extends State<SentenceListView>
    with AutomaticKeepAliveClientMixin {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 监听滚动位置变化，检测用户手动滚动
    _itemPositionsListener.itemPositions.addListener(_onScrollPositionChanged);

    // 初次加载后滚动到当前句子
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSentence();
    });
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(
      _onScrollPositionChanged,
    );
    super.dispose();
  }

  void _onScrollPositionChanged() {
    // 当用户手动滚动时禁用自动滚动
    // 这里可以根据需要实现更复杂的逻辑
  }

  @override
  void didUpdateWidget(covariant SentenceListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentIndex != null && widget.autoScrollEnabled) {
      // 场景1：currentIndex 变化（播放中自动更新）→ 总是居中显示
      if (widget.currentIndex != oldWidget.currentIndex) {
        _scrollToCurrentSentence(checkVisibility: false);
      }
      // 场景3：autoScroll 从禁用变为启用 → 总是居中
      else if (!oldWidget.autoScrollEnabled && widget.autoScrollEnabled) {
        _scrollToCurrentSentence(checkVisibility: false);
      }
      // 场景2：sentences 列表变化（标签页切换）→ 智能滚动（可见则不动）
      else {
        _scrollToCurrentSentence(checkVisibility: true);
      }
    }
  }

  void _scrollToCurrentSentence({bool checkVisibility = false}) {
    if (widget.currentIndex == null || !widget.autoScrollEnabled) return;

    // 查找目标句子在当前列表中的位置
    final localPos = widget.sentences.indexWhere(
      (s) => s.index == widget.currentIndex,
    );
    if (localPos == -1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 如果需要检查可见性（标签页切换场景）
      if (checkVisibility) {
        final positions = _itemPositionsListener.itemPositions.value;

        // 如果能获取到可见位置信息，检查目标是否已经可见
        if (positions.isNotEmpty) {
          final isVisible = positions.any((pos) => pos.index == localPos);

          // 如果已经可见，不需要滚动
          if (isVisible) {
            return;
          }
        }
      }

      // 执行滚动（播放中总是滚动，标签页切换时只在不可见时滚动）
      _itemScrollController.scrollTo(
        index: localPos,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // 居中对齐
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以保持状态
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 检测用户手动滚动
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle) {
          widget.onUserScroll?.call();
        }
        return false;
      },
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          itemCount: widget.sentences.length,
          padding: const EdgeInsets.all(8),
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, idx) {
            final sentence = widget.sentences[idx];
            final isCurrent = widget.currentIndex == sentence.index;
            final isBookmarked = widget.bookmarkedIndices.contains(
              sentence.index,
            );

            return _SentenceTile(
              sentence: sentence,
              isCurrent: isCurrent,
              isBookmarked: isBookmarked,
              showTranscript: widget.showTranscript,
              onTap: () => widget.onSentenceTap(sentence.index),
              onBookmarkToggle: () => widget.onBookmarkToggle(sentence.index),
            );
          },
        ),
      ),
    );
  }
}

class _SentenceTile extends StatelessWidget {
  final Sentence sentence;
  final bool isCurrent;
  final bool isBookmarked;
  final bool showTranscript;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;

  const _SentenceTile({
    required this.sentence,
    required this.isCurrent,
    required this.isBookmarked,
    required this.showTranscript,
    required this.onTap,
    required this.onBookmarkToggle,
  });

  void _showContextMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context)!;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    final result = await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & (overlay?.size ?? const Size(0, 0)),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 20),
              const SizedBox(width: 12),
              Text(l10n.copy),
            ],
          ),
        ),
      ],
    );

    if (result == 'copy' && context.mounted) {
      await Clipboard.setData(ClipboardData(text: sentence.text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.copied),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 移动端优化：减小编号和按钮尺寸，增加文字区域宽度
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
    final numberBoxSize = isMobile ? 20.0 : 28.0;
    final numberFontSize = isMobile ? 10.0 : 11.0;
    final numberSpacing = isMobile ? 4.0 : 10.0;
    final iconSize = isMobile ? 16.0 : 22.0;
    final iconButtonSize = isMobile ? 24.0 : 36.0; // 进一步减小移动端按钮
    final iconButtonPadding = isMobile ? 4.0 : 8.0; // 减小移动端 padding
    final rightSpacing = isMobile ? 2.0 : 4.0;

    return Card(
      elevation: isCurrent ? 2 : 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isCurrent
          ? Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.26)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.35),
              )
            : const BorderSide(color: Colors.transparent),
      ),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        // Desktop端禁用长按，避免干扰正常使用
        onLongPressStart: isMobile
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            // 移动端右侧减小padding以补偿IconButton的内部空白，实现视觉对称
            padding: isMobile
                ? const EdgeInsets.only(left: 10, right: 0, top: 10, bottom: 10)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: numberBoxSize,
                  height: numberBoxSize,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${sentence.index + 1}',
                      style: TextStyle(
                        fontSize: numberFontSize,
                        fontWeight: FontWeight.bold,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: numberSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Text(
                            sentence.text,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                            textAlign: TextAlign.left,
                          ),
                          if (!showTranscript)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 5,
                                      sigmaY: 5,
                                    ),
                                    child: Container(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${SubtitleParser.formatDuration(sentence.startTime)} - ${SubtitleParser.formatDuration(sentence.endTime)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile) SizedBox(width: rightSpacing),
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? Colors.amber : Colors.grey,
                  ),
                  iconSize: iconSize,
                  padding: EdgeInsets.all(iconButtonPadding),
                  constraints: BoxConstraints(
                    minWidth: iconButtonSize,
                    minHeight: iconButtonSize,
                  ),
                  onPressed: onBookmarkToggle,
                  tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
