/// 收藏页面
///
/// 聚合两类核心资产：收藏句子（按音频分组）和收藏单词（按时间倒序）。
/// 通过 SegmentedButton 在句子/单词视图间切换。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/app_database.dart';
import '../database/daos/bookmark_dao.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart' as model;
import '../models/dict_entry.dart';
import '../models/sentence_ai_result.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/flashcard/flashcard_provider.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/saved_word_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../router/app_router.dart';
import '../services/dictionary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/ai_content_section.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';

/// 收藏页面视图模式
enum _FavoritesView { sentences, words }

/// 收藏页面
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  _FavoritesView _currentView = _FavoritesView.sentences;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 获取收藏数量
    final bookmarkDao = ref.watch(bookmarkDaoProvider);
    final savedWordsAsync = ref.watch(savedWordListProvider);
    final wordCount = savedWordsAsync.valueOrNull?.length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favorites), centerTitle: true),
      body: Column(
        children: [
          // SegmentedButton 切换
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.s,
            ),
            child: StreamBuilder<List<BookmarkWithAudio>>(
              stream: bookmarkDao.watchAllWithAudioName(),
              builder: (context, snapshot) {
                final sentenceCount = snapshot.data?.length;
                final sentenceLabel = sentenceCount != null && sentenceCount > 0
                    ? '${l10n.favoritesSentences} ($sentenceCount)'
                    : l10n.favoritesSentences;
                final wordLabel = wordCount != null && wordCount > 0
                    ? '${l10n.favoritesWords} ($wordCount)'
                    : l10n.favoritesWords;

                return SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_FavoritesView>(
                    segments: [
                      ButtonSegment(
                        value: _FavoritesView.sentences,
                        label: Text(sentenceLabel),
                        icon: const Icon(Icons.format_quote, size: 18),
                      ),
                      ButtonSegment(
                        value: _FavoritesView.words,
                        label: Text(wordLabel),
                        icon: const Icon(Icons.abc, size: 18),
                      ),
                    ],
                selected: {_currentView},
                onSelectionChanged: (selected) {
                  setState(() => _currentView = selected.first);
                },
                style: SegmentedButton.styleFrom(
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                  ),
                );
              },
            ),
          ),

          // 内容区域（Stack：列表 + 底部悬浮按钮）
          Expanded(
            child: Stack(
              children: [
                // 列表
                _currentView == _FavoritesView.sentences
                    ? const _SentencesView()
                    : const _WordsView(),

                // 底部悬浮复习按钮
                if (_currentView == _FavoritesView.sentences)
                  const _FloatingSentenceReviewButton()
                else
                  const _FloatingFlashcardButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 句子视图
// ============================================================

/// 句子视图 — 按音频分组展示收藏的书签句子
class _SentencesView extends ConsumerWidget {
  const _SentencesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkDao = ref.watch(bookmarkDaoProvider);

    return StreamBuilder<List<BookmarkWithAudio>>(
      stream: bookmarkDao.watchAllWithAudioName(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final allBookmarks = snapshot.data ?? [];
        if (allBookmarks.isEmpty) {
          return _buildEmptyState(context, isSentences: true);
        }

        // 按音频名称分组
        final grouped = <String, List<BookmarkWithAudio>>{};
        for (final item in allBookmarks) {
          (grouped[item.bookmark.audioItemId] ??= []).add(item);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
            80, // 底部留出悬浮按钮空间
          ),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final audioId = grouped.keys.elementAt(index);
            final items = grouped[audioId]!;
            final audioName = items.first.audioName;

            return _AudioBookmarkGroup(
              audioId: audioId,
              audioName: audioName,
              bookmarks: items,
            );
          },
        );
      },
    );
  }
}

/// 底部悬浮句子复习按钮
class _FloatingSentenceReviewButton extends ConsumerWidget {
  const _FloatingSentenceReviewButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkDao = ref.watch(bookmarkDaoProvider);

    return StreamBuilder<List<BookmarkWithAudio>>(
      stream: bookmarkDao.watchAllWithAudioName(),
      builder: (context, snapshot) {
        final allBookmarks = snapshot.data ?? [];
        if (allBookmarks.isEmpty) return const SizedBox.shrink();

        // 过滤掉无效书签（迁移遗留的无时长条目）
        final validBookmarks = allBookmarks.where((b) {
          final duration = b.bookmark.endTime - b.bookmark.startTime;
          return duration > 0 && b.bookmark.sentenceText.isNotEmpty;
        }).toList();
        if (validBookmarks.isEmpty) return const SizedBox.shrink();

        return _FloatingReviewButton(
          icon: Icons.headphones,
          label: AppLocalizations.of(
            context,
          )!.bookmarkReviewStartCount(validBookmarks.length),
          onPressed: () {
            final provider = ref.read(bookmarkReviewProvider.notifier);
            final audioItemDao = ref.read(audioItemDaoProvider);
            provider.initialize(
              allBookmarks,
              getAudioItemById: (id) => audioItemDao.getById(id),
            );
            context.push(AppRoutes.bookmarkReview);
          },
        );
      },
    );
  }
}

/// 底部悬浮 Flashcard 按钮
class _FloatingFlashcardButton extends ConsumerWidget {
  const _FloatingFlashcardButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedWordsAsync = ref.watch(savedWordListProvider);

    return savedWordsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (words) {
        if (words.isEmpty) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        return _FloatingReviewButton(
          icon: Icons.style_outlined,
          label: '${l10n.flashcardStartQuiz} (${words.length})',
          onPressed: () {
            ref.read(flashcardNotifierProvider.notifier).initialize(words);
            context.push(AppRoutes.flashcard);
          },
        );
      },
    );
  }
}

/// 底部悬浮复习按钮 — 渐变遮罩 + 全宽 FilledButton
class _FloatingReviewButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _FloatingReviewButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 渐变遮罩
          IgnorePointer(
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface.withValues(alpha: 0.0),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
          // 按钮区域
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个音频的书签分组卡片
class _AudioBookmarkGroup extends ConsumerWidget {
  final String audioId;
  final String audioName;
  final List<BookmarkWithAudio> bookmarks;

  const _AudioBookmarkGroup({
    required this.audioId,
    required this.audioName,
    required this.bookmarks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        title: Text(
          audioName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.favoritesBookmarkCount(bookmarks.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            // 练习该音频收藏句按钮
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.headphones, size: 18),
                color: theme.colorScheme.primary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: l10n.bookmarkReviewStartCount(bookmarks.length),
                onPressed: () {
                  final provider = ref.read(bookmarkReviewProvider.notifier);
                  final audioItemDao = ref.read(audioItemDaoProvider);
                  provider.initialize(
                    bookmarks,
                    getAudioItemById: (id) => audioItemDao.getById(id),
                  );
                  context.push(AppRoutes.bookmarkReview);
                },
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          for (final item in bookmarks)
            _BookmarkSentenceTile(bookmark: item.bookmark, audioId: audioId),
        ],
      ),
    );
  }
}

/// 单条书签句子列表项（可展开查看翻译/解析，支持播放和点词查词典）
class _BookmarkSentenceTile extends ConsumerStatefulWidget {
  final Bookmark bookmark;
  final String audioId;

  const _BookmarkSentenceTile({required this.bookmark, required this.audioId});

  @override
  ConsumerState<_BookmarkSentenceTile> createState() =>
      _BookmarkSentenceTileState();
}

class _BookmarkSentenceTileState extends ConsumerState<_BookmarkSentenceTile> {
  bool _isPlaying = false;
  bool _isExpanded = false;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 播放该句子的原声片段
  Future<void> _playSentence() async {
    if (_isPlaying) {
      ref.read(audioEngineProvider.notifier).stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      final engine = ref.read(audioEngineProvider.notifier);
      final engineState = ref.read(audioEngineProvider);

      // 如果当前加载的不是同一音频，重新加载
      if (engineState.currentAudioId != widget.audioId) {
        final dao = ref.read(audioItemDaoProvider);
        final row = await dao.getById(widget.audioId);
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
          isStarred: row.isStarred,
          transcriptSource: model.TranscriptSource.fromIndex(
            row.transcriptSource,
          ),
          audioSha256: row.audioSha256,
          transcriptLanguage: row.transcriptLanguage,
        );

        await engine.loadAudio(audioItem, 1.0);
      }

      if (!mounted) return;

      final sessionId = engine.newSession();
      final start = Duration(
        milliseconds: (widget.bookmark.startTime * 1000).round(),
      );
      final end = Duration(
        milliseconds: (widget.bookmark.endTime * 1000).round(),
      );
      await engine.playRangeOnce(start, end, sessionId);
    } catch (_) {
      // 忽略播放错误（音频文件不存在等）
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  /// 构建可点击单词的 InlineSpan 列表
  List<InlineSpan> _buildWordSpans(ThemeData theme) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final words = widget.bookmark.sentenceText.split(RegExp(r'(\s+)'));
    return words.map((word) {
      if (word.trim().isEmpty) {
        return TextSpan(text: word);
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          final cleanWord = word.replaceAll(RegExp(r'[.,!?;:\-—…、，。！？；：]'), '');
          if (cleanWord.isNotEmpty) {
            showWordDictionarySheet(
              context: context,
              word: cleanWord,
              audioItemId: widget.audioId,
              sentenceIndex: widget.bookmark.sentenceIndex,
              sentenceText: widget.bookmark.sentenceText,
            );
          }
        };
      _recognizers.add(recognizer);
      return TextSpan(text: '$word ', recognizer: recognizer);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bm = widget.bookmark;

    // 从 AI 缓存获取已有内容
    final ai = ref.read(sentenceAiNotifierProvider);
    final cachedTranslation = ai
        .getCachedTranslation(bm.sentenceText)
        ?.translation;
    final cachedAnalysis = ai.getCachedAnalysis(bm.sentenceText);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    return Dismissible(
      key: ValueKey('bookmark_${bm.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.l),
        color: theme.colorScheme.error,
        child: Icon(Icons.bookmark_remove, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) {
        ref
            .read(bookmarkDaoProvider)
            .removeBookmark(widget.audioId, bm.sentenceIndex);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.favoritesBookmarkRemoved),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Column(
        children: [
          // 主行：播放按钮 + 句子文本 + 展开箭头
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
            ),
            leading: IconButton(
              icon: Icon(
                _isPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                size: 28,
              ),
              color: _isPlaying
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              onPressed: _playSentence,
            ),
            title: _isExpanded
                ? RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurface,
                      ),
                      children: _buildWordSpans(theme),
                    ),
                  )
                : Text(
                    bm.sentenceText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
            subtitle: Text(
              '${_formatTime(bm.startTime)} - ${_formatTime(bm.endTime)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),

          // 展开内容：可点击单词 + AI 翻译 + AI 解析
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                0,
                AppSpacing.m,
                AppSpacing.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI 翻译
                  AiContentSection(
                    icon: Icons.translate,
                    title: l10n.aiTranslation,
                    cachedContent: cachedTranslation,
                    onRequest: () async {
                      final result = await ai.getTranslation(bm.sentenceText);
                      return result.translation;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s),

                  // AI 解析
                  AiContentSection(
                    icon: Icons.auto_awesome,
                    title: l10n.aiAnalysis,
                    cachedContent: cachedAnalysisText,
                    onRequest: () async {
                      final result = await ai.getAnalysis(bm.sentenceText);
                      return result.toDisplayString();
                    },
                    contentBuilder: (content) =>
                        _AnalysisContent(content: content),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 解析内容结构化展示（复用精听页面的 3 段式布局）
///
/// 使用 [SentenceAnalysis.parseDisplayString] 按字段分隔符拆分，
/// vocabulary 和 listening 字段内按 `\n` 拆分为多条并加 bullet。
class _AnalysisContent extends StatelessWidget {
  final String content;

  const _AnalysisContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final fields = SentenceAnalysis.parseDisplayString(content);
    final labels = [l10n.aiGrammar, l10n.aiVocabulary, l10n.aiListening];

    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length && i < labels.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s),
          Text(
            labels[i],
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          if (i == 0)
            Text(fields[i], style: bodyStyle)
          else
            ..._buildBulletItems(fields[i], bodyStyle),
        ],
      ],
    );
  }

  List<Widget> _buildBulletItems(String field, TextStyle? style) {
    final items = field.split('\n').where((s) => s.trim().isNotEmpty).toList();
    if (items.length <= 1) {
      return [Text(field, style: style)];
    }
    return [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('· $item', style: style),
        ),
    ];
  }
}

// ============================================================
// 单词视图
// ============================================================

/// 单词视图 — 按收藏时间倒序展示
class _WordsView extends ConsumerWidget {
  const _WordsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedWordsAsync = ref.watch(savedWordListProvider);

    return savedWordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (words) {
        if (words.isEmpty) {
          return _buildEmptyState(context, isSentences: false);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
            80, // 底部留出悬浮按钮空间
          ),
          itemCount: words.length,
          itemBuilder: (context, index) {
            final w = words[index];
            return _SavedWordTile(key: ValueKey(w.id), savedWord: w);
          },
        );
      },
    );
  }
}

/// 单条收藏单词列表项（可展开）
class _SavedWordTile extends ConsumerStatefulWidget {
  final SavedWord savedWord;

  const _SavedWordTile({super.key, required this.savedWord});

  @override
  ConsumerState<_SavedWordTile> createState() => _SavedWordTileState();
}

class _SavedWordTileState extends ConsumerState<_SavedWordTile> {
  DictEntry? _dictEntry;
  bool _dictLoaded = false;
  bool _isPlaying = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadDict();
  }

  @override
  void didUpdateWidget(covariant _SavedWordTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedWord.word != widget.savedWord.word) {
      _dictEntry = null;
      _dictLoaded = false;
      _loadDict();
    }
  }

  Future<void> _loadDict() async {
    final word = widget.savedWord.word;
    final entry = await DictionaryService.instance.lookup(word);
    if (!mounted) return;
    // 防止异步完成时 widget 已切换到另一个单词
    if (widget.savedWord.word != word) return;
    setState(() {
      _dictEntry = entry;
      _dictLoaded = true;
    });
  }

  /// 播放来源句子的原声片段
  ///
  /// 优先使用冗余存储的 sentenceStartMs/sentenceEndMs（不依赖字幕文件），
  /// 仅在无时间信息时回退到加载字幕。
  Future<void> _playSentence() async {
    final word = widget.savedWord;
    if (word.audioItemId == null) return;

    // 需要时间信息：优先冗余字段，其次字幕文件
    final hasStoredTiming =
        word.sentenceStartMs != null && word.sentenceEndMs != null;
    if (!hasStoredTiming && word.sentenceIndex == null) return;

    if (_isPlaying) {
      ref.read(audioEngineProvider.notifier).stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      final engine = ref.read(audioEngineProvider.notifier);
      final engineState = ref.read(audioEngineProvider);

      // 从数据库获取音频项
      final dao = ref.read(audioItemDaoProvider);
      final row = await dao.getById(word.audioItemId!);
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
        isStarred: row.isStarred,
        transcriptSource: model.TranscriptSource.fromIndex(
          row.transcriptSource,
        ),
        audioSha256: row.audioSha256,
        transcriptLanguage: row.transcriptLanguage,
      );

      // 如果当前加载的不是同一音频，重新加载
      if (engineState.currentAudioId != word.audioItemId) {
        await engine.loadAudio(audioItem, 1.0);
      }
      if (!mounted) return;

      Duration startTime;
      Duration endTime;

      if (hasStoredTiming) {
        // 使用冗余存储的时间（不依赖字幕文件）
        startTime = Duration(milliseconds: word.sentenceStartMs!);
        endTime = Duration(milliseconds: word.sentenceEndMs!);
      } else {
        // 回退：加载字幕获取句子时间信息
        if (row.transcriptPath == null) {
          setState(() => _isPlaying = false);
          return;
        }
        final sentences = await engine.loadTranscript(audioItem);
        if (!mounted || word.sentenceIndex! >= sentences.length) {
          setState(() => _isPlaying = false);
          return;
        }
        final sentence = sentences[word.sentenceIndex!];
        startTime = sentence.startTime;
        endTime = sentence.endTime;
      }

      final sessionId = engine.newSession();
      await engine.playRangeOnce(startTime, endTime, sessionId);
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
    final word = widget.savedWord;

    return Dismissible(
      key: ValueKey('word_${word.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.l),
        color: theme.colorScheme.error,
        child: Icon(Icons.bookmark_remove, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) {
        ref.read(savedWordListProvider.notifier).removeWord(word.word);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.favoritesWordRemoved),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          // 收起状态：单词 + 收藏图标 + 音标 + 简释
          title: Text(
            word.word,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: !_isExpanded && _dictLoaded && _dictEntry != null
              ? Text(
                  _buildSubtitle(_dictEntry!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          // 展开状态：完整释义（仅多行时）+ 柯林斯星级 + 考试标签 + 来源句子
          children: [
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  0,
                  AppSpacing.m,
                  AppSpacing.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 音标 + 完整释义
                    if (_dictEntry != null) ...[
                      if (_dictEntry!.phonetic.isNotEmpty)
                        Text(
                          '/${_dictEntry!.phonetic}/',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (_dictEntry!.translation != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _dictEntry!.translation!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.6,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ],

                    // 柯林斯星级 + 考试标签
                    if (_dictEntry != null &&
                        (_dictEntry!.collins > 0 ||
                            _dictEntry!.examTags.isNotEmpty)) ...[
                      const SizedBox(height: AppSpacing.s),
                      _buildMetaTags(theme, _dictEntry!),
                    ],

                    // 来源句子
                    if (word.sentenceText != null) ...[
                      const SizedBox(height: AppSpacing.s),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.s),
                      InkWell(
                        onTap:
                            word.audioItemId != null &&
                                word.sentenceIndex != null
                            ? _playSentence
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            if (word.audioItemId != null &&
                                word.sentenceIndex != null)
                              Icon(
                                _isPlaying
                                    ? Icons.stop_circle_outlined
                                    : Icons.play_circle_outline,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            if (word.audioItemId != null &&
                                word.sentenceIndex != null)
                              const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                word.sentenceText!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 简短副标题：音标 + 首行释义
  String _buildSubtitle(DictEntry entry) {
    final parts = <String>[];
    if (entry.phonetic.isNotEmpty) {
      parts.add('/${entry.phonetic}/');
    }
    if (entry.translation != null && entry.translation!.isNotEmpty) {
      final firstLine = entry.translation!.split('\n').first.trim();
      parts.add(firstLine);
    }
    return parts.join(' ');
  }

  /// 柯林斯星级 + 考试标签 Wrap
  Widget _buildMetaTags(ThemeData theme, DictEntry entry) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (entry.collins > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              return Icon(
                Icons.star_rounded,
                size: 12,
                color: i < entry.collins
                    ? Colors.amber.shade600
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              );
            }),
          ),
        for (final tag in entry.examTags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// 共用空状态
// ============================================================

Widget _buildEmptyState(BuildContext context, {required bool isSentences}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSentences ? Icons.format_quote : Icons.abc,
            size: 56,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            isSentences ? l10n.favoritesNoSentences : l10n.favoritesNoWords,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            isSentences
                ? l10n.favoritesNoSentencesHint
                : l10n.favoritesNoWordsHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    ),
  );
}
