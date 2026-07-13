/// 标注模式内容卡片
///
/// 显示句子文本（单词可点击弹出词典弹窗）、
/// 难句标记切换、三按钮工具栏（拆意群/翻译/解析）。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/sentence_ai_provider.dart';
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
import 'selectable_sentence_text.dart';
import 'sense_group_text.dart';

/// 句子 AI 请求来源。
enum SentenceAiRequestSource { automatic, userTap }

/// 内容加载状态
enum ContentLoadState { idle, loading, loaded, error }

/// 意群显示模式
enum SenseGroupMode { off, medium, fine }

/// 标注模式句子卡片
///
/// 句子文本经 [SelectableSentenceText] 渲染（点词查词 + 词组选区手柄），
/// 内部管理翻译/解析的加载状态和意群显示开关。
///
/// 工具栏可以通过 [showToolbar] 控制是否在卡片内部渲染。
/// 当 [showToolbar] 为 false 时，外部可通过 [GlobalKey] 获取
/// [SentenceAnnotationCardState] 并调用 [SentenceAnnotationCardState.buildToolbar]
/// 在其他位置渲染工具栏。
class SentenceAnnotationCard extends StatefulWidget {
  /// 句子文本
  final String text;

  /// 请求翻译回调（返回译文的字段级增量流，逐帧渐显；与 [onRequestAnalysis] 同构）
  final Stream<String> Function(
    CancelToken cancelToken,
    SentenceAiRequestSource source,
  )?
  onRequestTranslation;

  /// 请求解析回调（返回结构化解析的字段级增量流，逐帧渐显）
  final Stream<SentenceAnalysis> Function(
    CancelToken cancelToken,
    SentenceAiRequestSource source,
  )?
  onRequestAnalysis;

  /// 已缓存的翻译文本
  final String? cachedTranslation;

  /// 已缓存的结构化解析（命中时自动展开）
  final SentenceAnalysis? cachedAnalysis;

  /// 是否在首帧后自动加载翻译。
  final bool autoLoadTranslation;

  /// 是否在首帧后自动加载解析。
  final bool autoLoadAnalysis;

  /// 用户手动点击翻译按钮时触发。
  final VoidCallback? onTranslationUserIntent;

  /// 用户手动点击解析按钮时触发。
  final VoidCallback? onAnalysisUserIntent;

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

  /// 等待 fine 意群就绪回调（流式场景：medium 先返回、fine 后返回）。
  ///
  /// medium→fine 切换时若 fine 尚未就绪，await 此 Future，`AsyncToggleButton` 期间自动显示加载；
  /// fine 已就绪（或缓存命中已含完整 fine）则立即返回。为空时不等待（向后兼容）。
  final Future<void> Function()? onAwaitSenseGroupFine;

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
    this.autoLoadTranslation = false,
    this.autoLoadAnalysis = false,
    this.onTranslationUserIntent,
    this.onAnalysisUserIntent,
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
    this.onAwaitSenseGroupFine,
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
  /// 意群显示模式
  SenseGroupMode _senseGroupMode = SenseGroupMode.off;

  /// 翻译面板状态
  ContentLoadState _translationState = ContentLoadState.idle;
  String? _translationContent;
  bool _translationExpanded = false;
  bool _translationActivated = false;

  /// 解析面板状态
  ContentLoadState _analysisState = ContentLoadState.idle;
  SentenceAnalysis? _analysisContent;
  bool _analysisExpanded = false;
  bool _analysisActivated = false;

  /// 进行中的解析流订阅（逐帧渐显）；dispose / 重新请求时取消。
  StreamSubscription<SentenceAnalysis>? _analysisSub;
  CancelToken? _analysisCancelToken;

  /// 进行中的翻译流订阅（逐帧渐显）；dispose / 重新请求时取消。
  StreamSubscription<String>? _translationSub;
  CancelToken? _translationCancelToken;

  @override
  void initState() {
    super.initState();
    // 有意群数据时自动显示大意群
    if (widget.senseGroupResult != null &&
        widget.senseGroupResult!.medium.isNotEmpty) {
      _senseGroupMode = SenseGroupMode.medium;
    }
    // 预存缓存内容（有缓存时自动展开，无需用户点击按钮）
    if (widget.cachedTranslation != null &&
        widget.cachedTranslation!.isNotEmpty) {
      _translationContent = widget.cachedTranslation;
      _translationState = ContentLoadState.loaded;
      _translationExpanded = true;
      _translationActivated = true;
    }
    if (widget.cachedAnalysis != null && widget.cachedAnalysis!.isNotEmpty) {
      _analysisContent = widget.cachedAnalysis;
      _analysisState = ContentLoadState.loaded;
      _analysisExpanded = true;
      _analysisActivated = true;
    }
    // 首帧构建后通知外部工具栏刷新（解决 GlobalKey 时序问题）
    if (widget.onToolbarStateChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerInitialAutoLoads();
    });
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
    // 缓存内容变化时自动展示或收折
    if (widget.cachedTranslation != oldWidget.cachedTranslation) {
      final hasContent =
          widget.cachedTranslation != null &&
          widget.cachedTranslation!.isNotEmpty;
      _translationContent = widget.cachedTranslation;
      if (hasContent) {
        _translationState = ContentLoadState.loaded;
        _translationExpanded = true;
        _translationActivated = true;
      } else if (_translationContent == null && _translationExpanded) {
        _translationExpanded = false;
        _translationState = ContentLoadState.idle;
        _translationActivated = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
    if (widget.cachedAnalysis != oldWidget.cachedAnalysis) {
      final hasContent =
          widget.cachedAnalysis != null && widget.cachedAnalysis!.isNotEmpty;
      _analysisContent = widget.cachedAnalysis;
      if (hasContent) {
        _analysisState = ContentLoadState.loaded;
        _analysisExpanded = true;
        _analysisActivated = true;
      } else if (_analysisContent == null && _analysisExpanded) {
        _analysisExpanded = false;
        _analysisState = ContentLoadState.idle;
        _analysisActivated = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
    // 意群数据变化时通知工具栏刷新
    if (widget.senseGroupResult != oldWidget.senseGroupResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
    if (widget.text != oldWidget.text ||
        widget.autoLoadTranslation != oldWidget.autoLoadTranslation ||
        widget.autoLoadAnalysis != oldWidget.autoLoadAnalysis) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _triggerInitialAutoLoads();
      });
    }
  }

  // -- 按钮点击处理 --

  /// 通知外部工具栏状态已变化
  void _notifyToolbar() {
    widget.onToolbarStateChanged?.call();
  }

  /// 首帧后自动加载翻译/解析。
  void _triggerInitialAutoLoads() {
    if (widget.autoLoadTranslation) {
      AppLogger.log(
        'SentenceAnnotation',
        '自动加载翻译: start text="${widget.text}"',
      );
      unawaited(
        _runAutoLoad('translation', () => _requestTranslation(automatic: true)),
      );
    }
    if (widget.autoLoadAnalysis) {
      AppLogger.log(
        'SentenceAnnotation',
        '自动加载解析: start text="${widget.text}"',
      );
      unawaited(
        _runAutoLoad('analysis', () => _requestAnalysis(automatic: true)),
      );
    }
  }

  Future<void> _runAutoLoad(String type, Future<void> Function() action) async {
    try {
      await action();
      AppLogger.log('SentenceAnnotation', '自动加载$type: done');
    } catch (error) {
      AppLogger.log('SentenceAnnotation', '自动加载$type: blocked/failed $error');
    }
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
      final prevMode = _senseGroupMode;

      // medium→fine：fine 可能尚未流完（后端 medium 先返回、fine 后返回）。
      // 先 await fine 就绪（流已结束则立即返回），await 期间 AsyncToggleButton 自动显示加载。
      if (prevMode == SenseGroupMode.medium && !result.areBothEqual) {
        if (widget.onAwaitSenseGroupFine != null) {
          await widget.onAwaitSenseGroupFine!.call();
        }
        if (!mounted) return;
        final ready = widget.senseGroupResult;
        // await 后 fine 仍空（出错/无 fine）→ 放弃切换，保持 medium
        if (ready == null || ready.fine.isEmpty) return;
        // fine 完整后再判定是否与 medium 等同：等同则回 off，否则进 fine
        final nextMode = ready.areBothEqual
            ? SenseGroupMode.off
            : SenseGroupMode.fine;
        setState(() => _senseGroupMode = nextMode);
        AppLogger.log('SenseGroup', '切换模式: $prevMode → $nextMode');
        widget.onSenseGroupModeChanged?.call(_activeSenseGroups ?? []);
        _notifyToolbar();
        return;
      }

      // off→medium / fine→off / medium→off(两粒度等同)：同步切换
      setState(() {
        switch (_senseGroupMode) {
          case SenseGroupMode.off:
            _senseGroupMode = SenseGroupMode.medium;
          case SenseGroupMode.medium:
            _senseGroupMode = SenseGroupMode.off;
          case SenseGroupMode.fine:
            _senseGroupMode = SenseGroupMode.off;
        }
      });
      AppLogger.log('SenseGroup', '切换模式: $prevMode → $_senseGroupMode');
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

  /// 翻译按钮点击（返回 Future 供 AsyncToggleButton 管理 loading）。
  ///
  /// 未命中缓存时订阅译文流：首帧前显示 shimmer，随后逐帧 setState 渐显（逐词显示，
  /// 与流式解析一致）。返回的 Future 在流结束（完成/出错）时 settle，供按钮收起
  /// loading。auth/quota 异常向上抛出交由 glue 弹登录/订阅。
  Future<void> _onTapTranslation() async {
    widget.onTranslationUserIntent?.call();
    await _requestTranslation(automatic: false);
  }

  /// 加载翻译。自动触发与用户点击共用该逻辑；自动触发不折叠已有内容。
  Future<void> _requestTranslation({required bool automatic}) async {
    final source = automatic ? 'auto' : 'user';
    if (_translationState == ContentLoadState.loading) {
      AppLogger.log(
        'SentenceAnnotation',
        '翻译请求跳过: source=$source reason=loading',
      );
      return;
    }
    if (automatic && _translationContent != null) {
      AppLogger.log('SentenceAnnotation', '翻译自动加载跳过: reason=hasContent');
      return;
    }
    if (!automatic) {
      widget.onToolbarButtonTapped?.call();
    }
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
    if (widget.onRequestTranslation == null) {
      AppLogger.log(
        'SentenceAnnotation',
        '翻译请求跳过: source=$source reason=noCallback',
      );
      return;
    }

    AppLogger.log('SentenceAnnotation', '翻译请求进入 loading: source=$source');
    setState(() {
      _translationExpanded = true;
      _translationState = ContentLoadState.loading;
    });
    _notifyToolbar();

    final completer = Completer<void>();
    await _translationSub?.cancel();
    _translationCancelToken?.cancel('translation stream replaced');
    final cancelToken = CancelToken();
    _translationCancelToken = cancelToken;
    _translationSub = widget
        .onRequestTranslation!(
          cancelToken,
          automatic
              ? SentenceAiRequestSource.automatic
              : SentenceAiRequestSource.userTap,
        )
        .listen(
          (translation) {
            if (!mounted) return;
            // 首帧起把 shimmer 换成内容，后续帧持续覆盖（渐显）。空快照仍留在 loading。
            if (translation.isEmpty) return;
            AppLogger.log(
              'SentenceAnnotation',
              '翻译请求收到内容: source=$source length=${translation.length}',
            );
            setState(() {
              _translationContent = translation;
              _translationState = ContentLoadState.loaded;
            });
            _notifyToolbar();
          },
          onError: (Object error) {
            _translationSub = null;
            _translationCancelToken = null;
            if (!completer.isCompleted) completer.completeError(error);
          },
          onDone: () {
            _translationSub = null;
            _translationCancelToken = null;
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    try {
      await completer.future;
      if (mounted &&
          _translationState == ContentLoadState.loading &&
          _translationContent == null) {
        _resetTranslationAfterEmptyRequest(source);
      }
    } catch (error) {
      if (error is AiFeatureAuthRequiredException ||
          error is AiFeatureQuotaExceededException) {
        _resetTranslationAfterBlockedRequest();
        AppLogger.log(
          'SentenceAnnotation',
          '翻译请求被阻断: source=$source error=$error',
        );
        if (!automatic) rethrow;
        return;
      }
      if (mounted) {
        setState(() {
          _translationExpanded = false;
          _translationState = ContentLoadState.idle;
          _translationContent = null;
        });
        _notifyToolbar();
        AppLogger.log(
          'SentenceAnnotation',
          '翻译请求失败: source=$source error=$error',
        );
        if (!automatic) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.aiTranslationFailed),
            ),
          );
        }
      }
    }
  }

  /// 流正常结束但没有任何可展示译文时，退出 loading 并允许后续重试。
  void _resetTranslationAfterEmptyRequest(String source) {
    setState(() {
      _translationExpanded = false;
      _translationState = ContentLoadState.idle;
      _translationContent = null;
      _translationActivated = false;
    });
    _notifyToolbar();
    AppLogger.log('SentenceAnnotation', '翻译请求无内容结束: source=$source');
  }

  /// 登录或额度门槛阻断请求时，恢复翻译区域到可重新点击的初始状态。
  void _resetTranslationAfterBlockedRequest() {
    if (!mounted) return;
    setState(() {
      _translationExpanded = false;
      _translationState = ContentLoadState.idle;
      _translationContent = null;
      _translationActivated = false;
    });
    _notifyToolbar();
  }

  /// 解析按钮点击（返回 Future 供 AsyncToggleButton 管理 loading）。
  ///
  /// 未命中缓存时订阅结构化解析流：首帧前显示 shimmer，随后逐帧 setState 自上而下
  /// 渐显（与流式查词一致）。返回的 Future 在流结束（完成/出错）时 settle，供按钮
  /// 收起 loading。auth/quota 异常向上抛出交由 glue 弹登录/订阅。
  Future<void> _onTapAnalysis() async {
    widget.onAnalysisUserIntent?.call();
    await _requestAnalysis(automatic: false);
  }

  /// 加载解析。自动触发与用户点击共用该逻辑；自动触发不折叠已有内容。
  Future<void> _requestAnalysis({required bool automatic}) async {
    final source = automatic ? 'auto' : 'user';
    if (_analysisState == ContentLoadState.loading) {
      AppLogger.log(
        'SentenceAnnotation',
        '解析请求跳过: source=$source reason=loading',
      );
      return;
    }
    if (automatic && _analysisContent != null) {
      AppLogger.log('SentenceAnnotation', '解析自动加载跳过: reason=hasContent');
      return;
    }
    if (!automatic) {
      widget.onToolbarButtonTapped?.call();
    }
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
    if (widget.onRequestAnalysis == null) {
      AppLogger.log(
        'SentenceAnnotation',
        '解析请求跳过: source=$source reason=noCallback',
      );
      return;
    }

    AppLogger.log('SentenceAnnotation', '解析请求进入 loading: source=$source');
    setState(() {
      _analysisExpanded = true;
      _analysisState = ContentLoadState.loading;
    });
    _notifyToolbar();

    final completer = Completer<void>();
    await _analysisSub?.cancel();
    _analysisCancelToken?.cancel('analysis stream replaced');
    final cancelToken = CancelToken();
    _analysisCancelToken = cancelToken;
    _analysisSub = widget
        .onRequestAnalysis!(
          cancelToken,
          automatic
              ? SentenceAiRequestSource.automatic
              : SentenceAiRequestSource.userTap,
        )
        .listen(
          (analysis) {
            if (!mounted) return;
            // 首帧起把 shimmer 换成内容，后续帧持续覆盖（渐显）。空快照仍留在 loading。
            if (analysis.isEmpty) return;
            AppLogger.log('SentenceAnnotation', '解析请求收到内容: source=$source');
            setState(() {
              _analysisContent = analysis;
              _analysisState = ContentLoadState.loaded;
            });
            _notifyToolbar();
          },
          onError: (Object error) {
            _analysisSub = null;
            _analysisCancelToken = null;
            if (!completer.isCompleted) completer.completeError(error);
          },
          onDone: () {
            _analysisSub = null;
            _analysisCancelToken = null;
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    try {
      await completer.future;
      if (mounted &&
          _analysisState == ContentLoadState.loading &&
          _analysisContent == null) {
        _resetAnalysisAfterEmptyRequest(source);
      }
    } catch (error) {
      if (error is AiFeatureAuthRequiredException ||
          error is AiFeatureQuotaExceededException) {
        _resetAnalysisAfterBlockedRequest();
        AppLogger.log(
          'SentenceAnnotation',
          '解析请求被阻断: source=$source error=$error',
        );
        if (!automatic) rethrow;
        return;
      }
      if (mounted) {
        setState(() {
          _analysisExpanded = false;
          _analysisState = ContentLoadState.idle;
          _analysisContent = null;
        });
        _notifyToolbar();
        AppLogger.log(
          'SentenceAnnotation',
          '解析请求失败: source=$source error=$error',
        );
        if (!automatic) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.aiAnalysisFailed),
            ),
          );
        }
      }
    }
  }

  /// 流正常结束但没有任何可展示解析时，退出 loading 并允许后续重试。
  void _resetAnalysisAfterEmptyRequest(String source) {
    setState(() {
      _analysisExpanded = false;
      _analysisState = ContentLoadState.idle;
      _analysisContent = null;
      _analysisActivated = false;
    });
    _notifyToolbar();
    AppLogger.log('SentenceAnnotation', '解析请求无内容结束: source=$source');
  }

  /// 登录或额度门槛阻断请求时，恢复解析区域到可重新点击的初始状态。
  void _resetAnalysisAfterBlockedRequest() {
    if (!mounted) return;
    setState(() {
      _analysisExpanded = false;
      _analysisState = ContentLoadState.idle;
      _analysisContent = null;
      _analysisActivated = false;
    });
    _notifyToolbar();
  }

  @override
  void dispose() {
    _analysisSub?.cancel();
    _analysisCancelToken?.cancel('analysis card disposed');
    _translationSub?.cancel();
    _translationCancelToken?.cancel('translation card disposed');
    super.dispose();
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
      isLoading: _analysisState == ContentLoadState.loading,
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
      isLoading: _translationState == ContentLoadState.loading,
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
        Expanded(
          child: _wrapGuide(widget.translationGuideStep, translationBtn),
        ),
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
            highlightedSegments: widget.highlightedSegments,
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
            child: SelectableSentenceText(
              text: widget.text,
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface,
              ),
              highlightedSegments: widget.highlightedSegments,
              origin: DictionaryLookupOrigin(
                audioItemId: widget.audioItemId,
                sentenceIndex: widget.sentenceIndex,
                sentenceText: widget.text,
                sentenceStartMs: widget.sentenceStartMs,
                sentenceEndMs: widget.sentenceEndMs,
              ),
              onBeforeLookup: () => widget.onToolbarButtonTapped?.call(),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 句子文本 — 意群色块模式或纯 RichText（带长按/右键复制整句）。
        // 上下留白给选区手柄圆点（悬在首行上方/末行下方各约 12dp）让位，
        // 避免遮挡；上方留白由外部工具栏缩小间距补偿（annotation_content_view）。
        _wrapGuide(
          widget.sentenceGuideStep,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.m - 4),
            child: sentenceBody,
          ),
        ),

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
          padding: const EdgeInsets.only(top: AppSpacing.s),
          child: _buildLoadingPanel(theme),
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

  /// 构建 AI 内容加载骨架，翻译和解析使用同一套 shimmer 反馈机制。
  Widget _buildLoadingPanel(ThemeData theme) {
    return _buildContentPanelContainer(
      theme,
      const ShimmerPlaceholder(singleLine: true),
    );
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
          ),
        ],
      ),
    );
  }

  /// 构建解析内容面板（shimmer / 结构化内容）
  Widget _buildContentPanel({
    required ThemeData theme,
    required AppLocalizations l10n,
    required ContentLoadState state,
    required SentenceAnalysis? content,
  }) {
    final child = switch (state) {
      ContentLoadState.loading => const ShimmerPlaceholder(),
      ContentLoadState.loaded when content != null => _AnalysisContent(
        analysis: content,
      ),
      ContentLoadState.loaded => const SizedBox.shrink(),
      ContentLoadState.error => const SizedBox.shrink(),
      ContentLoadState.idle => const SizedBox.shrink(),
    };
    return _buildContentPanelContainer(theme, child);
  }

  /// 构建 AI 内容面板容器；纯黑深色主题下使用不透明实底 + 细描边。
  Widget _buildContentPanelContainer(ThemeData theme, Widget child) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: isDark
            ? Border.all(color: theme.colorScheme.outlineVariant, width: 1)
            : null,
      ),
      child: child,
    );
  }
}

/// 解析内容结构化展示
///
/// 直接读取结构化 [SentenceAnalysis]（grammar / vocabulary / listening 三组要点
/// 对象），无 `label: value` 文本解析。每段带 icon 标题与彩色 IconBox，段间以极浅
/// 分割线区隔；每条要点为「标签加粗 + 详解」，详解中的反引号引用高亮、IPA 音标
/// （如 /tə/）以 monospace chip 形式高亮。支持流式渐显：字段随帧到达逐条出现。
class _AnalysisContent extends StatelessWidget {
  final SentenceAnalysis analysis;

  const _AnalysisContent({required this.analysis});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 展示顺序：重点词汇 → 听力提示 → 语法
    final sections = <_Section>[
      _Section(l10n.aiVocabulary, Icons.translate_outlined, [
        for (final v in analysis.vocabulary) (v.term, v.note),
      ]),
      _Section(l10n.aiListening, Icons.hearing_outlined, [
        for (final p in analysis.listening) (p.phrase, p.note),
      ]),
      _Section(l10n.aiGrammar, Icons.menu_book_outlined, [
        for (final g in analysis.grammar) (g.point, g.note),
      ]),
    ];

    // 仅渲染有非空要点的段落（流式渐显：空段先不出现）
    final visible = [
      for (final s in sections)
        if (s.visibleItems.isNotEmpty) s,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var idx = 0; idx < visible.length; idx++) ...[
          if (idx > 0) const SizedBox(height: 12),
          _buildSectionHeader(theme, visible[idx]),
          const SizedBox(height: 6),
          _buildSectionBody(theme, visible[idx].visibleItems),
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
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(s.icon, size: 12, color: cs.primary),
          ),
          const SizedBox(width: 6),
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

  /// 段落正文：把结构化要点逐条渲染为 bullet（标签加粗 + 详解）。
  Widget _buildSectionBody(ThemeData theme, List<(String, String)> items) {
    final cs = theme.colorScheme;
    final body = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          _buildBulletItem(theme, items[i].$1, items[i].$2, body),
        ],
      ],
    );
  }

  /// 删除标签中的反引号并规范化空格。
  ///
  /// 后端已约束标签为纯文本；客户端再清洗一次是防御旧缓存/异常数据。
  /// 标签在 UI 中已通过加粗高亮，再加反引号既冗余、又不会被渲染成 chip。
  static String _cleanBulletKey(String key) {
    return key.replaceAll('`', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 统一 bullet 条目：▸ + 可选加粗标签 + "：" + 详解（详解含反引号高亮/IPA chip）。
  /// 流式渐显时详解可能暂为空，此时只显示标签。
  Widget _buildBulletItem(
    ThemeData theme,
    String rawKey,
    String rawValue,
    TextStyle? body,
  ) {
    final cs = theme.colorScheme;
    final trimmedKey = rawKey.trim();
    final key = trimmedKey.isEmpty ? null : _cleanBulletKey(trimmedKey);
    final value = rawValue.trim();

    final bullet = Padding(
      padding: const EdgeInsets.only(top: 1, right: 6),
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
    if (key == null) {
      // 无标签，整条作为详解
      content = _richWithIpa(theme, value, body);
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
            // 详解暂未到达（流式中）时不加冒号，只显示标签
            if (value.isNotEmpty) ...[
              const TextSpan(text: '：'),
              ..._inlineSpans(theme, value, body),
            ],
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bullet,
        Expanded(child: content),
      ],
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
        // 反引号引用：用 primaryContainer 作为字形背后的扁平高亮色，沿文本流
        // 自然换行；不使用 WidgetSpan 盒子，避免长短语撑出强制断行。
        spans.add(
          TextSpan(
            text: codeContent,
            style: TextStyle(
              background: Paint()..color = cs.primaryContainer,
              color: cs.onPrimaryContainer,
            ),
          ),
        );
      } else {
        // IPA 音标：保留 chip 盒子（monospace），但用中性灰色背景，不喧宾夺主
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                m.group(2)!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Menlo', 'Courier'],
                  fontSize: (body?.fontSize ?? 13) - 1,
                  color: cs.onSurface,
                  height: 1.2,
                ),
              ),
            ),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }

  /// 整段文本（含反引号高亮 badge 和 IPA 斜体）渲染为 Text.rich
  Widget _richWithIpa(ThemeData theme, String text, TextStyle? body) {
    return Text.rich(
      TextSpan(style: body, children: _inlineSpans(theme, text, body)),
    );
  }
}

/// 解析卡片段落定义：标题 + icon + 要点列表（(标签, 详解) 对）。
class _Section {
  /// 段落标题（如"语法"）
  final String label;

  /// 段落 icon
  final IconData icon;

  /// 该段全部要点（(标签, 详解)）；渐显时可能含尚未到齐的空条目。
  final List<(String, String)> items;

  const _Section(this.label, this.icon, this.items);

  /// 至少有标签或详解非空的要点（过滤掉流式中尚全空的占位条目）。
  List<(String, String)> get visibleItems => [
    for (final it in items)
      if (it.$1.trim().isNotEmpty || it.$2.trim().isNotEmpty) it,
  ];
}
