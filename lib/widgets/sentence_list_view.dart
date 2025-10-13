import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/sentence.dart';
import '../services/subtitle_parser.dart';
import '../l10n/app_localizations.dart';

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
  final int? itemPlaybackSentenceIndex;

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
    this.itemPlaybackSentenceIndex,
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
        final localPos = widget.sentences.indexWhere(
          (s) => s.index == widget.currentIndex,
        );
        if (localPos == -1) return;

        final estimatedOffset = localPos * 100.0; // 估算每个item约100像素
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(estimatedOffset.clamp(0.0, max));

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
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: ListView.builder(
          key: PageStorageKey<String>(widget.storageKey),
          controller: _scrollController,
          primary: false,
          itemCount: widget.sentences.length,
          padding: const EdgeInsets.all(8),
          cacheExtent: 800,
          itemBuilder: (context, idx) {
            final sentence = widget.sentences[idx];
            final isCurrent = widget.currentIndex == sentence.index;
            final isBookmarked = widget.bookmarkedIndices.contains(sentence.index);
            final isItemPlaying =
                widget.itemPlaybackSentenceIndex == sentence.index;

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
              isItemPlaying: isItemPlaying,
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
  final VoidCallback onPlay;
  final VoidCallback onBookmarkToggle;
  final bool isItemPlaying;

  const _SentenceTile({
    super.key,
    required this.sentence,
    required this.isCurrent,
    required this.isBookmarked,
    required this.showTranscript,
    required this.onTap,
    required this.onPlay,
    required this.onBookmarkToggle,
    required this.isItemPlaying,
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
        onLongPressStart: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Text(
                            sentence.text,
                            style: const TextStyle(fontSize: 15, height: 1.4),
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
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(isItemPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 22,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: onPlay,
                  tooltip: isItemPlaying ? 'Pause sentence' : 'Play sentence',
                ),
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? Colors.amber : Colors.grey,
                  ),
                  iconSize: 22,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
