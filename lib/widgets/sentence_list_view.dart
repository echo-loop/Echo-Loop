import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/sentence.dart';
import '../services/subtitle_parser.dart';

class SentenceListView extends StatefulWidget {
  final List<Sentence> sentences;
  final int? currentIndex;
  final Set<int> bookmarkedIndices;
  final Function(int) onSentenceTap;
  final Function(int) onPlayTap;
  final Function(int) onBookmarkToggle;
  final bool showTranscript;
  final String storageKey;
  final bool autoScrollEnabled;
  final VoidCallback? onUserScroll;

  const SentenceListView({
    super.key,
    required this.sentences,
    required this.currentIndex,
    required this.bookmarkedIndices,
    required this.onSentenceTap,
    required this.onPlayTap,
    required this.onBookmarkToggle,
    this.showTranscript = true,
    this.storageKey = 'sentence_list',
    this.autoScrollEnabled = true,
    this.onUserScroll,
  });

  @override
  State<SentenceListView> createState() => _SentenceListViewState();
}

class _SentenceListViewState extends State<SentenceListView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SentenceListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 currentIndex 变化或 autoScroll 从禁用变为启用时，滚动到当前句子
    if (widget.currentIndex != null && widget.autoScrollEnabled) {
      if (widget.currentIndex != oldWidget.currentIndex ||
          (!oldWidget.autoScrollEnabled && widget.autoScrollEnabled)) {
        _scrollToCurrentSentence();
      }
    }
  }

  void _scrollToCurrentSentence() {
    if (widget.currentIndex == null || !widget.autoScrollEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[widget.currentIndex];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
          curve: Curves.easeInOut,
        );
      } else {
        // 如果key不存在（item不在渲染范围内），先滚动到估算位置
        final estimatedOffset = widget.currentIndex! * 100.0; // 估算每个item约100像素
        _scrollController.jumpTo(
          estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
        // 等待渲染后再次尝试精确定位
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final key = _itemKeys[widget.currentIndex];
          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 300),
              alignment: 0.5,
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Only disable auto-scroll when user manually scrolls (not programmatic scroll)
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle) {
          widget.onUserScroll?.call();
        }
        return false;
      },
      child: ListView.builder(
      key: PageStorageKey<String>(widget.storageKey),
      controller: _scrollController,
      itemCount: widget.sentences.length,
      padding: const EdgeInsets.all(8),
      cacheExtent: 800,
      itemBuilder: (context, idx) {
        final sentence = widget.sentences[idx];
        final isCurrent = widget.currentIndex == sentence.index;
        final isBookmarked = widget.bookmarkedIndices.contains(sentence.index);

        if (isCurrent && !_itemKeys.containsKey(sentence.index)) {
          _itemKeys[sentence.index] = GlobalKey();
        }

        return _SentenceTile(
          key: isCurrent ? _itemKeys[sentence.index] : null,
          sentence: sentence,
          isCurrent: isCurrent,
          isBookmarked: isBookmarked,
          showTranscript: widget.showTranscript,
          onTap: () => widget.onSentenceTap(sentence.index),
          onPlay: () => widget.onPlayTap(sentence.index),
          onBookmarkToggle: () => widget.onBookmarkToggle(sentence.index),
        );
      },
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
  final VoidCallback onPlay;
  final VoidCallback onBookmarkToggle;

  const _SentenceTile({
    super.key,
    required this.sentence,
    required this.isCurrent,
    required this.isBookmarked,
    required this.showTranscript,
    required this.onTap,
    required this.onPlay,
    required this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${sentence.index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Text(
                          sentence.text,
                          style: const TextStyle(fontSize: 16, height: 1.5),
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
                    const SizedBox(height: 4),
                    Text(
                      '${SubtitleParser.formatDuration(sentence.startTime)} - ${SubtitleParser.formatDuration(sentence.endTime)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: onPlay,
                tooltip: 'Play sentence',
              ),
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? Colors.amber : Colors.grey,
                ),
                onPressed: onBookmarkToggle,
                tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
