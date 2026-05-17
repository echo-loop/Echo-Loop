/// 标注模式内容卡片
///
/// 显示句子文本（单词可点击弹出词典弹窗）、
/// 难句标记切换、三按钮工具栏（拆意群/翻译/解析）。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_logger.dart';
import '../../models/sense_group_result.dart';
import '../../models/sentence_ai_result.dart';
import '../../models/speech_practice_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/sense_group_timing.dart';
import '../common/async_toggle_button.dart';
import '../common/shimmer_placeholder.dart';
import '../common/text_context_menu.dart';
import '../guide_flow.dart';
import '../intensive_listen/word_dictionary_sheet.dart';
import 'sense_group_text.dart';

/// 内容加载状态
enum ContentLoadState { idle, loading, loaded, error }

/// 意群显示模式
enum SenseGroupMode { off, medium, fine }

/// 标注模式句子卡片
///
/// 使用 StatefulWidget 管理 TapGestureRecognizer 生命周期，
/// 防止内存泄漏。内部管理翻译/解析的加载状态和意群显示开关。
///
/// 工具栏可以通过 [showToolbar] 控制是否在卡片内部渲染。
/// 当 [showToolbar] 为 false 时，外部可通过 [GlobalKey] 获取
/// [SentenceAnnotationCardState] 并调用 [SentenceAnnotationCardState.buildToolbar]
/// 在其他位置渲染工具栏。
class SentenceAnnotationCard extends StatefulWidget {
  /// 句子文本
  final String text;

  /// 请求翻译回调（返回翻译文本）
  final Future<String> Function()? onRequestTranslation;

  /// 请求解析回调（返回解析 JSON 文本）
  final Future<String> Function()? onRequestAnalysis;

  /// 已缓存的翻译文本
  final String? cachedTranslation;

  /// 已缓存的解析文本（grammar\nvocabulary\nusage 格式）
  final String? cachedAnalysis;

  /// 来源音频 ID（用于词典弹窗收藏单词时记录来源）
  final String? audioItemId;

  /// 来源句子索引
  final int? sentenceIndex;

  /// 来源句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// 句子正文下方的附加反馈区域。
  final Widget? inlineFeedback;

  /// 句子正文的高亮片段；为空时按原始句子构建。
  final List<SpeechTranscriptSegment>? highlightedSegments;

  /// AI 意群拆分结果（null 表示未请求或无数据，包含大意群和小意群）
  final SenseGroupResult? senseGroupResult;

  /// 各意群时间范围（对应当前显示的粒度）
  final List<SenseGroupTiming>? senseGroupTimings;

  /// 意群粒度切换时的回调（传入当前显示的意群列表，用于重新计算时间范围）
  final void Function(List<String> chunks)? onSenseGroupModeChanged;

  /// 正在播放的意群索引
  final int? playingSenseGroupIndex;

  /// 已播放过的意群索引集合
  final Set<int> playedSenseGroupIndices;

  /// 点击意群回调
  final void Function(int groupIndex)? onTapSenseGroup;

  /// 请求拆分意群回调
  final Future<void> Function()? onRequestSenseGroups;

  /// 是否有词级时间戳（决定拆意群按钮是否可用）
  final bool hasWordTimestamps;

  /// 已收藏的意群文本集合（归一化后，用于 badge 橙色高亮）
  final Set<String> savedGroupTexts;

  /// 点击意群回调（附带 badge 全局位置，用于显示工具条）
  final void Function(int groupIndex, Rect globalRect)? onTapGroupWithRect;

  /// 是否在卡片内部渲染工具栏
  ///
  /// 设为 false 时，工具栏不会在卡片内渲染。外部可通过
  /// [GlobalKey<SentenceAnnotationCardState>] 调用
  /// [SentenceAnnotationCardState.buildToolbar] 在其他位置渲染。
  final bool showToolbar;

  /// 工具栏状态变化回调
  ///
  /// 当 [showToolbar] 为 false 时，卡片内部状态（翻译/解析加载、意群切换）
  /// 变化后调用此回调，通知外部刷新工具栏。
  final VoidCallback? onToolbarStateChanged;

  /// 用户点击工具栏按钮（意群/翻译/解析）时触发，通知外部切换到手动模式
  final VoidCallback? onToolbarButtonTapped;

  /// 新手引导步骤：指向句子文本区域（点词查词典、长按复制）
  final GuideStep? sentenceGuideStep;

  /// 新手引导步骤：指向意群按钮
  final GuideStep? senseGroupGuideStep;

  /// 新手引导步骤：指向翻译按钮
  final GuideStep? translationGuideStep;

  /// 新手引导步骤：指向解析按钮
  final GuideStep? analysisGuideStep;

  const SentenceAnnotationCard({
    super.key,
    required this.text,
    this.onRequestTranslation,
    this.onRequestAnalysis,
    this.cachedTranslation,
    this.cachedAnalysis,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.inlineFeedback,
    this.highlightedSegments,
    this.senseGroupResult,
    this.senseGroupTimings,
    this.onSenseGroupModeChanged,
    this.playingSenseGroupIndex,
    this.playedSenseGroupIndices = const {},
    this.onTapSenseGroup,
    this.onRequestSenseGroups,
    this.hasWordTimestamps = false,
    this.showToolbar = true,
    this.onToolbarStateChanged,
    this.onToolbarButtonTapped,
    this.savedGroupTexts = const {},
    this.onTapGroupWithRect,
    this.sentenceGuideStep,
    this.senseGroupGuideStep,
    this.translationGuideStep,
    this.analysisGuideStep,
  });

  @override
  State<SentenceAnnotationCard> createState() => SentenceAnnotationCardState();
}

/// [SentenceAnnotationCard] 的公开 State，支持外部调用 [buildToolbar]。
class SentenceAnnotationCardState extends State<SentenceAnnotationCard> {
  final List<TapGestureRecognizer> _recognizers = [];
  static final RegExp _textPartPattern = RegExp(r'\s+|[^\s]+');

  /// 当前被按压高亮的词索引（-1 表示无）
  int _highlightedWordIndex = -1;

  /// 意群显示模式
  SenseGroupMode _senseGroupMode = SenseGroupMode.off;

  /// 翻译面板状态
  ContentLoadState _translationState = ContentLoadState.idle;
  String? _translationContent;
  bool _translationExpanded = false;
  bool _translationActivated = false;

  /// 解析面板状态
  ContentLoadState _analysisState = ContentLoadState.idle;
  String? _analysisContent;
  bool _analysisExpanded = false;
  bool _analysisActivated = false;

  @override
  void initState() {
    super.initState();
    // 有意群数据时自动显示大意群
    if (widget.senseGroupResult != null &&
        widget.senseGroupResult!.medium.isNotEmpty) {
      _senseGroupMode = SenseGroupMode.medium;
    }
    // 预存缓存内容（用户点击按钮时可立即显示，但不自动展开）
    if (widget.cachedTranslation != null) {
      _translationContent = widget.cachedTranslation;
    }
    if (widget.cachedAnalysis != null) {
      _analysisContent = widget.cachedAnalysis;
    }
    // 首帧构建后通知外部工具栏刷新（解决 GlobalKey 时序问题）
    if (widget.onToolbarStateChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
  }

  @override
  void didUpdateWidget(SentenceAnnotationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 意群数据从无到有时自动进入 medium 模式
    // 兜底逻辑：_onTapSenseGroup 的 await 返回时 widget 可能还没更新，
    // 此处在 parent rebuild 后再次检查并进入正确模式。
    if (widget.senseGroupResult != null &&
        widget.senseGroupResult!.medium.isNotEmpty &&
        oldWidget.senseGroupResult == null &&
        _senseGroupMode == SenseGroupMode.off) {
      setState(() => _senseGroupMode = SenseGroupMode.medium);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSenseGroupModeChanged?.call(widget.senseGroupResult!.medium);
          _notifyToolbar();
        }
      });
    }
    // 母语切换：缓存内容变化时重置已展示的翻译/解析
    if (widget.cachedTranslation != oldWidget.cachedTranslation) {
      _translationContent = widget.cachedTranslation;
      if (_translationContent == null && _translationExpanded) {
        _translationExpanded = false;
        _translationState = ContentLoadState.idle;
        _translationActivated = false;
      }
    }
    if (widget.cachedAnalysis != oldWidget.cachedAnalysis) {
      _analysisContent = widget.cachedAnalysis;
      if (_analysisContent == null && _analysisExpanded) {
        _analysisExpanded = false;
        _analysisState = ContentLoadState.idle;
      }
    }
    // 意群数据变化时通知工具栏刷新
    if (widget.senseGroupResult != oldWidget.senseGroupResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  // -- 按钮点击处理 --

  /// 通知外部工具栏状态已变化
  void _notifyToolbar() {
    widget.onToolbarStateChanged?.call();
  }

  /// 获取当前模式下应显示的意群列表（off 时返回 null）
  List<String>? get _activeSenseGroups {
    final result = widget.senseGroupResult;
    if (result == null) return null;
    return switch (_senseGroupMode) {
      SenseGroupMode.medium => result.medium,
      SenseGroupMode.fine => result.fine,
      SenseGroupMode.off => null,
    };
  }

  /// 拆意群按钮点击（返回 Future 供 AsyncToggleButton 管理 loading）
  ///
  /// 循环逻辑：
  /// - 两种结果相同：off → medium → off
  /// - 两种结果不同：off → medium（大意群）→ fine（小意群）→ off
  Future<void> _onTapSenseGroup() async {
    final result = widget.senseGroupResult;

    if (result != null && result.medium.isNotEmpty) {
      // 已有有效数据，切换显示模式
      // 仅从 off 进入 medium 时触发手动模式（首次激活）
      if (_senseGroupMode == SenseGroupMode.off) {
        widget.onToolbarButtonTapped?.call();
      }
      final bothEqual = result.areBothEqual;
      final prevMode = _senseGroupMode;
      setState(() {
        switch (_senseGroupMode) {
          case SenseGroupMode.off:
            _senseGroupMode = SenseGroupMode.medium;
          case SenseGroupMode.medium:
            _senseGroupMode = bothEqual
                ? SenseGroupMode.off
                : SenseGroupMode.fine;
          case SenseGroupMode.fine:
            _senseGroupMode = SenseGroupMode.off;
        }
      });
      AppLogger.log(
        'SenseGroup',
        '切换模式: $prevMode → $_senseGroupMode (bothEqual=$bothEqual)',
      );
      // 通知外部重新计算时间范围 + 停止播放（off 时传空列表）
      widget.onSenseGroupModeChanged?.call(_activeSenseGroups ?? []);
      _notifyToolbar();
    } else if (widget.onRequestSenseGroups != null) {
      // 无数据时 await 异步请求，按钮自动显示 loading
      // （空结果不会被父组件缓存，因此可重复点击重试）
      widget.onToolbarButtonTapped?.call();
      AppLogger.log('SenseGroup', '无数据，发起 API 请求...');
      await widget.onRequestSenseGroups!();
      // 请求完成后，父组件已通过 setState 将 senseGroupResult 传入。
      // 显式进入 medium 模式（不依赖 didUpdateWidget 的时序）。
      if (mounted &&
          widget.senseGroupResult != null &&
          widget.senseGroupResult!.medium.isNotEmpty) {
        setState(() => _senseGroupMode = SenseGroupMode.medium);
        AppLogger.log('SenseGroup', 'API 返回后进入 medium 模式');
        widget.onSenseGroupModeChanged?.call(widget.senseGroupResult!.medium);
        _notifyToolbar();
      }
    }
  }

  /// 翻译按钮点击（返回 Future 供 AsyncToggleButton 管理 loading）
  Future<void> _onTapTranslation() async {
    widget.onToolbarButtonTapped?.call();
    if (!_translationActivated) {
      _translationActivated = true;
    }
    if (_translationContent != null) {
      setState(() {
        _translationExpanded = !_translationExpanded;
        _translationState = ContentLoadState.loaded;
      });
      _notifyToolbar();
      return;
    }
    if (widget.onRequestTranslation == null) return;
    setState(() => _translationExpanded = true);
    try {
      final result = await widget.onRequestTranslation!();
      if (mounted) {
        setState(() {
          _translationContent = result;
          _translationState = ContentLoadState.loaded;
        });
        _notifyToolbar();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _translationExpanded = false;
          _translationState = ContentLoadState.idle;
        });
        _notifyToolbar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.aiTranslationFailed),
          ),
        );
      }
    }
  }

  /// 解析按钮点击（返回 Future 供 AsyncToggleButton 管理 loading）
  Future<void> _onTapAnalysis() async {
    widget.onToolbarButtonTapped?.call();
    if (!_analysisActivated) {
      _analysisActivated = true;
    }
    if (_analysisContent != null) {
      setState(() {
        _analysisExpanded = !_analysisExpanded;
        _analysisState = ContentLoadState.loaded;
      });
      _notifyToolbar();
      return;
    }
    if (widget.onRequestAnalysis == null) return;
    try {
      final result = await widget.onRequestAnalysis!();
      if (mounted) {
        setState(() {
          _analysisContent = result;
          _analysisExpanded = true;
          _analysisState = ContentLoadState.loaded;
        });
        _notifyToolbar();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _analysisExpanded = false;
          _analysisState = ContentLoadState.idle;
        });
        _notifyToolbar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.aiAnalysisFailed),
          ),
        );
      }
    }
  }

  // -- 词点击 --

  /// 短暂高亮被点击的词（150ms 后自动清除）
  void _flashWord(int index) {
    setState(() => _highlightedWordIndex = index);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _highlightedWordIndex = -1);
    });
  }

  /// 每次 build 前清理旧 recognizer，创建新的
  List<InlineSpan> _buildWordSpans(ThemeData theme) {
    // 清理旧 recognizer
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final parts = _textPartPattern
        .allMatches(widget.text)
        .map((match) => match.group(0) ?? '')
        .toList();
    final highlightColor = theme.colorScheme.primary.withValues(alpha: 0.1);
    final result = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final cleanWord = part.replaceAll(RegExp(r'[.,!?;:\-—…、，。！？；：]'), '');
      if (part.trim().isEmpty) {
        result.add(TextSpan(text: part));
        continue;
      }
      final wordIndex = i;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (cleanWord.isNotEmpty) {
            _flashWord(wordIndex);
            widget.onToolbarButtonTapped?.call();
            showWordDictionarySheet(
              context: context,
              word: cleanWord,
              audioItemId: widget.audioItemId,
              sentenceIndex: widget.sentenceIndex,
              sentenceText: widget.text,
              sentenceStartMs: widget.sentenceStartMs,
              sentenceEndMs: widget.sentenceEndMs,
            );
          }
        };
      _recognizers.add(recognizer);
      result.add(
        TextSpan(
          text: part,
          recognizer: recognizer,
          style: _highlightedWordIndex == wordIndex
              ? TextStyle(backgroundColor: highlightColor)
              : null,
        ),
      );
    }
    return result;
  }

  /// 基于高亮片段生成可点击的富文本 span。
  List<InlineSpan> _buildHighlightedWordSpans(ThemeData theme) {
    final segments = widget.highlightedSegments;
    if (segments == null || segments.isEmpty) {
      return _buildWordSpans(theme);
    }

    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final highlightColor = theme.colorScheme.primary.withValues(alpha: 0.1);
    final spans = <InlineSpan>[];
    int wordIndex = 0;
    for (final segment in segments) {
      final parts = _textPartPattern
          .allMatches(segment.text)
          .map((match) => match.group(0) ?? '')
          .toList();
      for (final part in parts) {
        if (part.isEmpty) {
          continue;
        }
        if (part.trim().isEmpty) {
          spans.add(TextSpan(text: part));
          continue;
        }
        final cleanWord = part.replaceAll(RegExp(r'[.,!?;:\-—…、，。！？；：]'), '');
        final currentIndex = wordIndex++;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (cleanWord.isNotEmpty) {
              _flashWord(currentIndex);
              widget.onToolbarButtonTapped?.call();
              showWordDictionarySheet(
                context: context,
                word: cleanWord,
                audioItemId: widget.audioItemId,
                sentenceIndex: widget.sentenceIndex,
                sentenceText: widget.text,
                sentenceStartMs: widget.sentenceStartMs,
                sentenceEndMs: widget.sentenceEndMs,
              );
            }
          };
        _recognizers.add(recognizer);
        final isHighlighted = _highlightedWordIndex == currentIndex;
        spans.add(
          TextSpan(
            text: part,
            recognizer: recognizer,
            style: TextStyle(
              color: segment.isMatched ? const Color(0xFF2E9B51) : null,
              backgroundColor: isHighlighted ? highlightColor : null,
            ),
          ),
        );
      }
    }
    return spans;
  }

  // -- 工具栏相关 --

  bool get _isSenseGroupEnabled => widget.onRequestSenseGroups != null;

  bool get _hasTranslation =>
      widget.onRequestTranslation != null || widget.cachedTranslation != null;

  bool get _hasAnalysis =>
      widget.onRequestAnalysis != null || widget.cachedAnalysis != null;

  /// 是否有任何可用的工具栏按钮
  bool get hasToolbarButtons =>
      _isSenseGroupEnabled || _hasTranslation || _hasAnalysis;

  /// 构建工具栏按钮行
  ///
  /// 当 [SentenceAnnotationCard.showToolbar] 为 false 时，外部可通过
  /// `GlobalKey<SentenceAnnotationCardState>` 获取 state 并调用此方法，
  /// 将工具栏渲染在卡片外部（如固定在滚动区域上方）。
  Widget buildToolbar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final showSenseGroupBlocks =
        _senseGroupMode != SenseGroupMode.off &&
        _activeSenseGroups != null &&
        _activeSenseGroups!.isNotEmpty;

    // 按钮文案根据当前模式变化
    final senseGroupLabel = switch (_senseGroupMode) {
      SenseGroupMode.medium => l10n.annotationBtnSenseGroupMedium,
      SenseGroupMode.fine => l10n.annotationBtnSenseGroupFine,
      SenseGroupMode.off => l10n.annotationBtnSenseGroup,
    };

    final analysisBtn = AsyncToggleButton(
      key: const ValueKey('analysis'),
      label: l10n.annotationBtnAnalysis,
      icon: Icons.auto_awesome,
      iconColor: Colors.purple.shade400,
      isActive: _analysisExpanded && _analysisState != ContentLoadState.idle,
      isDisabled: !_hasAnalysis,
      onPressed: _onTapAnalysis,
    );
    final translationBtn = AsyncToggleButton(
      key: const ValueKey('translation'),
      label: l10n.annotationBtnTranslation,
      icon: Icons.translate,
      iconColor: Colors.blue.shade600,
      isActive:
          _translationExpanded && _translationState != ContentLoadState.idle,
      isDisabled: !_hasTranslation,
      onPressed: _onTapTranslation,
    );
    final senseGroupBtn = AsyncToggleButton(
      key: const ValueKey('senseGroup'),
      label: senseGroupLabel,
      icon: Icons.auto_fix_high,
      iconColor: Colors.orange.shade700,
      isActive: showSenseGroupBlocks,
      isDisabled: !_isSenseGroupEnabled,
      onPressed: _onTapSenseGroup,
    );

    return Row(
      children: [
        Expanded(child: _wrapGuide(widget.analysisGuideStep, analysisBtn)),
        const SizedBox(width: AppSpacing.s),
        Expanded(child: _wrapGuide(widget.translationGuideStep, translationBtn)),
        const SizedBox(width: AppSpacing.s),
        Expanded(child: _wrapGuide(widget.senseGroupGuideStep, senseGroupBtn)),
      ],
    );
  }

  /// 可选地包一层 [GuideTarget]。step 为空时直接返回 child。
  Widget _wrapGuide(GuideStep? step, Widget child) {
    return step != null ? GuideTarget(step: step, child: child) : child;
  }

  // -- 构建 --

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 判断意群是否应显示色块
    final showSenseGroupBlocks =
        _senseGroupMode != SenseGroupMode.off &&
        _activeSenseGroups != null &&
        _activeSenseGroups!.isNotEmpty;

    final Widget sentenceBody = showSenseGroupBlocks
        ? SenseGroupText(
            chunks: _activeSenseGroups!,
            timings: widget.senseGroupTimings ?? const [],
            playingGroupIndex: widget.playingSenseGroupIndex,
            playedGroupIndices: widget.playedSenseGroupIndices,
            onTapGroup: widget.onTapSenseGroup ?? (_) {},
            savedGroupTexts: widget.savedGroupTexts,
            onTapGroupWithRect: widget.onTapGroupWithRect,
          )
        : GestureDetector(
            onLongPressStart: (details) => TextContextMenu.show(
              context,
              details.globalPosition,
              widget.text,
            ),
            onSecondaryTapDown: (details) => TextContextMenu.show(
              context,
              details.globalPosition,
              widget.text,
            ),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface,
                ),
                children: _buildHighlightedWordSpans(theme),
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 句子文本 — 意群色块模式或纯 RichText（带长按/右键复制整句）
        _wrapGuide(widget.sentenceGuideStep, sentenceBody),

        // 翻译文本（直接显示在句子下方，弱化字体）
        _buildInlineTranslation(theme, l10n),

        // 工具栏按钮行（showToolbar=true 时在卡片内渲染）
        if (widget.showToolbar && hasToolbarButtons) ...[
          const SizedBox(height: AppSpacing.m),
          buildToolbar(context),
        ],

        // 附加反馈区域
        if (widget.inlineFeedback case final inlineFeedback?) ...[
          const SizedBox(height: AppSpacing.l),
          Align(alignment: Alignment.centerRight, child: inlineFeedback),
        ],

        // 解析内容展示区
        _buildContentArea(theme, l10n),
      ],
    );
  }

  /// 构建翻译文本（直接显示在句子下方，弱化字体，无面板包裹）
  Widget _buildInlineTranslation(ThemeData theme, AppLocalizations l10n) {
    if (!_translationExpanded) return const SizedBox.shrink();

    final Widget content;
    switch (_translationState) {
      case ContentLoadState.loading:
        content = Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        );
      case ContentLoadState.loaded:
        content = Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            _translationContent ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        );
      case ContentLoadState.error:
        content = const SizedBox.shrink();
      case ContentLoadState.idle:
        content = const SizedBox.shrink();
    }

    return content;
  }

  /// 构建解析内容展示区
  Widget _buildContentArea(ThemeData theme, AppLocalizations l10n) {
    if (!_analysisExpanded) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s),
          _buildContentPanel(
            theme: theme,
            l10n: l10n,
            state: _analysisState,
            content: _analysisContent,
            contentBuilder: (content) => _AnalysisContent(content: content),
          ),
        ],
      ),
    );
  }

  /// 构建单个内容面板（shimmer / 内容）
  Widget _buildContentPanel({
    required ThemeData theme,
    required AppLocalizations l10n,
    required ContentLoadState state,
    required String? content,
    Widget Function(String)? contentBuilder,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: switch (state) {
        ContentLoadState.loading => const ShimmerPlaceholder(),
        ContentLoadState.loaded => _buildLoadedContent(
          theme,
          content ?? '',
          contentBuilder,
        ),
        ContentLoadState.error => const SizedBox.shrink(),
        ContentLoadState.idle => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildLoadedContent(
    ThemeData theme,
    String content,
    Widget Function(String)? contentBuilder,
  ) {
    if (contentBuilder != null) return contentBuilder(content);
    return Text(
      content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }

}

/// 解析内容结构化展示
///
/// 使用 [SentenceAnalysis.parseDisplayString] 将内容按字段分隔符拆分为
/// grammar / vocabulary / listening 三段。每段带 icon 标题与彩色 IconBox，
/// 段间以极浅分割线区隔。词汇段采用"词条加粗 + 释义"的字典式排版，
/// 听力段中的 IPA 音标（如 /tə/）以 monospace chip 形式高亮。
class _AnalysisContent extends StatelessWidget {
  final String content;

  const _AnalysisContent({required this.content});

  /// 匹配文本中的内联标记：反引号引用 `xxx` 或 IPA 音标 /tə/。
  ///
  /// - group(1)：反引号包裹的文本（不含反引号本身）。允许任意非反引号、非换行
  ///   字符，长度 ≤ 80；用来标注被强调的词、短语或例子。
  /// - group(2)：完整 IPA 音标片段（含两侧 `/`）。识别策略：
  ///   - 起始 `/` 紧跟非空白字符，结束 `/` 紧贴非空白字符——
  ///     用来与表示"或者"的斜杠（两侧通常有空格，如 `and / or`）区分。
  ///   - 中间至少出现一个 IPA 专属字符（U+0250–U+02FF，如 ɪ ə ʃ ɡ ˈ ˌ ː），
  ///     用来排除 `/path/to/file`、`1/2`、`a/an` 这类无 IPA 字符的斜杠。
  ///   - 中间允许任意非斜杠非换行字符，长度 ≤ 60，覆盖音节分界 `.`、合成词
  ///     连字符 `-`、组合附加符、希腊字母等常见 IPA 邻接字符。
  static final _inlineMarkerRegex = RegExp(
    r'`([^`\n]{1,80})`|(/(?=\S)(?=[^/\n]*[ɐ-˿])[^/\n]{1,60}(?<=\S)/)',
  );

  /// "key：value" 拆分
  ///
  /// key 中允许英文标点（+ / ( )）和空格，但不允许中文句号/逗号/分号/感叹/问号，
  /// 避免把长句子的内部冒号误判为 key/value 分隔；同时限制 key 长度 ≤ 80 字符。
  static final _keyValueRegex = RegExp(
    r'^\s*([^：:。，；！？]{1,80})[：:](.*)$',
    dotAll: true,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final fields = SentenceAnalysis.parseDisplayString(content);

    // 展示顺序：语法 → 听力提示 → 重点词汇
    // 字段索引固定为 [0=grammar, 1=vocabulary, 2=listening]，由 fieldIndex 关联
    final sections = <_Section>[
      _Section(0, l10n.aiGrammar, Icons.menu_book_outlined),
      _Section(2, l10n.aiListening, Icons.hearing_outlined),
      _Section(1, l10n.aiVocabulary, Icons.translate_outlined),
    ];

    // 仅渲染对应字段非空的段落
    final visible = [
      for (final s in sections)
        if (s.fieldIndex < fields.length && fields[s.fieldIndex].trim().isNotEmpty) s,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var idx = 0; idx < visible.length; idx++) ...[
          if (idx > 0) const SizedBox(height: 18),
          _buildSectionHeader(theme, visible[idx]),
          const SizedBox(height: 10),
          _buildSectionBody(theme, fields[visible[idx].fieldIndex]),
        ],
      ],
    );
  }

  /// 段落标题：IconBox + 中文标签
  Widget _buildSectionHeader(ThemeData theme, _Section s) {
    final cs = theme.colorScheme;
    return Semantics(
      header: true,
      label: s.label,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(s.icon, size: 14, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Text(
            s.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 段落正文：拆分为多条 bullet（"key：value"），单条无 key 时降级为段落
  Widget _buildSectionBody(ThemeData theme, String field) {
    final cs = theme.colorScheme;
    final body = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.55,
    );

    final items = field.split('\n').where((s) => s.trim().isNotEmpty).toList();
    // 单条且无 key 时直接展示为段落
    if (items.length == 1 && !_keyValueRegex.hasMatch(items.first)) {
      return _richWithIpa(theme, items.first, body);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildBulletItem(theme, items[i], body),
        ],
      ],
    );
  }

  /// 删除 key 中的反引号并规范化空格。
  ///
  /// 服务端已有相同清洗（[apps/app/app/api/v1/ai/analyze/cleanup.ts]），
  /// 客户端再做一遍是出于防御：
  /// - 老 API 版本或第三方接入未走清洗逻辑
  /// - 本地缓存的旧解析数据来自更早版本的服务端
  /// key 在 UI 中已通过加粗高亮，再加反引号既冗余、又不会被渲染成 chip。
  static String _cleanBulletKey(String key) {
    return key.replaceAll('`', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 统一 bullet 条目：▸ + 可选加粗 key + ": " + value（value 含 IPA chip）
  Widget _buildBulletItem(ThemeData theme, String raw, TextStyle? body) {
    final cs = theme.colorScheme;
    final m = _keyValueRegex.firstMatch(raw);
    final rawKey = m?.group(1)?.trim();
    final key = rawKey == null ? null : _cleanBulletKey(rawKey);
    final value = m?.group(2)?.trim();

    final bullet = Padding(
      padding: const EdgeInsets.only(top: 2, right: 8),
      child: Text(
        '▸',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: cs.primary,
          height: 1,
        ),
      ),
    );

    final Widget content;
    if (key == null || value == null || value.isEmpty) {
      // 无 key:value 结构，整行作为 value
      content = _richWithIpa(theme, raw, body);
    } else {
      final keyStyle = body?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      );
      content = Text.rich(
        TextSpan(
          style: body,
          children: [
            TextSpan(text: key, style: keyStyle),
            const TextSpan(text: '：'),
            ..._inlineSpans(theme, value, body),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bullet, Expanded(child: content)],
    );
  }

  /// 将文本中的 `xxx` 反引号引用和 /xxx/ IPA 音标拆分为普通 TextSpan + chip WidgetSpan
  List<InlineSpan> _inlineSpans(ThemeData theme, String text, TextStyle? body) {
    final cs = theme.colorScheme;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineMarkerRegex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final codeContent = m.group(1);
      if (codeContent != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              codeContent,
              style: TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Menlo', 'Courier'],
                fontSize: (body?.fontSize ?? 13) - 0.5,
                color: cs.onSurface,
                height: 1.2,
              ),
            ),
          ),
        ));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              m.group(2)!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Menlo', 'Courier'],
                fontSize: 11,
                color: cs.onPrimaryContainer,
                height: 1.2,
              ),
            ),
          ),
        ));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }

  /// 整段文本（含反引号 chip 和 IPA chip）渲染为 Text.rich
  Widget _richWithIpa(ThemeData theme, String text, TextStyle? body) {
    return Text.rich(
      TextSpan(style: body, children: _inlineSpans(theme, text, body)),
    );
  }
}

/// 解析卡片三段类型
/// 解析卡片段落定义
class _Section {
  /// 对应 [SentenceAnalysis.parseDisplayString] 返回数组的索引
  /// (0=grammar, 1=vocabulary, 2=listening)
  final int fieldIndex;

  /// 段落标题（如"语法"）
  final String label;

  /// 段落 icon
  final IconData icon;

  const _Section(this.fieldIndex, this.label, this.icon);
}
