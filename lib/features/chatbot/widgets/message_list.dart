/// 消息列表：发送后把新消息滑动置顶 + 手动回底浮标。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/app_logger.dart';
import '../../../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../models/chat_role.dart';
import '../models/chatbot_config.dart';
import '../providers/chat_session_controller.dart';
import '../state/chat_session_state.dart';
import 'message_bubble.dart';

/// 距底阈值（px）：视口底部之外还有超过此距离的内容才显示回底浮标。
const double _stickThreshold = 80;

/// 消息列表：ScrollablePositionedList + 稳定 ValueKey(message.id)。
///
/// 置顶机制（业界标准，与 [ScrollablePositionedList] 惯例一致，参考
/// widgets/common/paragraph_sentence_list_card.dart）：发送一条新消息后，用
/// [ItemScrollController.scrollTo] 按 index 把「最新一条用户消息」平滑滑到视口顶部
/// （alignment=0），下方由末条消息的 minHeight 预留空间承接流式回答。按 index 定位
/// 不依赖像素测量，无论当前滚到第几条都可靠命中、落点一致。
///
/// 性能关键（ValueKey 只保 State 复用、**不跳过 build**）：
/// - 本组件只 watch 「id 列表」（结构变化才重建列表本身，delta 帧不触发）；
/// - 每行 [_MessageRow] 为独立 ConsumerWidget，各自 select 自己那条消息 →
///   历史消息实例不变、等值短路不 rebuild，流式期间只有正在生成那一行重建。
class ChatMessageList extends ConsumerStatefulWidget {
  const ChatMessageList({
    super.key,
    required this.config,
    this.onRetry,
    this.onUpgrade,
    this.onCopy,
    this.onEdit,
    this.onRegenerate,
    this.onFollowUp,
  });

  final ChatbotConfig config;
  final void Function(String messageId)? onRetry;
  final VoidCallback? onUpgrade;
  final void Function(String content)? onCopy;
  final void Function(String messageId)? onEdit;
  final void Function(String messageId)? onRegenerate;
  final void Function(String selectedText)? onFollowUp;

  @override
  ConsumerState<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends ConsumerState<ChatMessageList> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _showJumpButton = false;

  /// 当前 item 总数（含末尾哨兵）；供回底浮标几何计算，build 时更新。
  int _itemCount = 0;

  /// 当前视口高度（LayoutBuilder 提供）；把 px 阈值换算成 itemPositions 的比例。
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_syncJumpButtonVisibility);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(
      _syncJumpButtonVisibility,
    );
    super.dispose();
  }

  /// 按 itemPositions 同步回底浮标：末尾哨兵未进入视口、或其位置在视口底部之外超过
  /// 阈值 → 说明下方还有内容，显示浮标。这只依赖列表几何，不关心会话内容。
  void _syncJumpButtonVisibility() {
    if (!mounted || _itemCount == 0 || _viewportHeight <= 0) return;
    final positions = _itemPositionsListener.itemPositions.value;
    _setJumpButtonVisible(!_isAtBottom(positions));
  }

  /// 是否已到底：末尾哨兵可见且其上沿落在视口底部阈值之内。
  ///
  /// 哨兵是最后一个 item（0 高度，index == _itemCount-1）。它未出现在可见集合里 =
  /// 还在视口下方（下方内容多，未到底）；出现了则看它离视口底还有多远。
  bool _isAtBottom(Iterable<ItemPosition> positions) {
    if (positions.isEmpty) return true;
    final sentinelIndex = _itemCount - 1;
    final tolerance = _stickThreshold / _viewportHeight;
    for (final p in positions) {
      if (p.index == sentinelIndex) {
        // leadingEdge>1 表示哨兵在视口底部之下；差值即「底部之外的内容比例」。
        return (p.itemLeadingEdge - 1.0) <= tolerance;
      }
    }
    return false; // 哨兵尚未进入可见范围 → 下方还有内容。
  }

  /// 同步回底浮标可见性。
  void _setJumpButtonVisible(bool show) {
    if (show == _showJumpButton || !mounted) return;
    AppLogger.log('CHAT-SCROLL', '回底浮标 ${show ? "显示" : "隐藏"}');
    setState(() => _showJumpButton = show);
  }

  /// 动画滚到底部：把末尾哨兵对到视口底部，露出内容末端。
  void _animateToBottom() {
    if (!_itemScrollController.isAttached || _itemCount == 0) return;
    AppLogger.log('CHAT-SCROLL', '点击回底 → scrollTo 哨兵 index=${_itemCount - 1}');
    _itemScrollController.scrollTo(
      index: _itemCount - 1,
      alignment: 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// 新一轮开始（最新用户消息 id 变化）→ 把它瞬时定位到视口顶部（alignment=0）。
  ///
  /// 只在挂载后的真实新一轮触发（ref.listen 不回放初始值），因此打开已有会话不会
  /// 误滚动。流式增量只改 content、不改 id，故生成期不会重复置顶（提问保持置顶不动）。
  ///
  /// 用 [ItemScrollController.jumpTo]（瞬时）而非 `scrollTo`（动画）：`scrollTo` 一个
  /// 当前不可见的目标会落入 SPL 的「不可见分支」（anchor 置 0.5 → 居中 + 回弹），正是
  /// 新会话首条消息弹跳、落点偏移的根因；`jumpTo(alignment:0)` 按 index 精确置顶、无回
  /// 弹、无论当前滚到哪都稳定命中（与 paragraph_sentence_list_card 的既有惯例一致）。
  void _onNewUserTurn(String userId) {
    AppLogger.log('CHAT-SCROLL', '新一轮触发 userId=$userId → 下一帧置顶');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached) {
        AppLogger.log(
          'CHAT-SCROLL',
          '置顶跳过：mounted=$mounted attached=${_itemScrollController.isAttached}',
        );
        return;
      }
      final messages = ref
          .read(chatSessionControllerProvider(widget.config))
          .messages;
      final index = messages.indexWhere((m) => m.id == userId);
      if (index < 0) {
        AppLogger.log('CHAT-SCROLL', '置顶跳过：未找到 userId=$userId');
        return;
      }
      // 置顶留白与首条消息一致：首条消息无法滚过列表顶 padding，其上方天然保留
      // AppSpacing.s 空白；后续消息滚动置顶会滚过该 padding → 空白偏小。故对齐到
      // 「顶 padding」处（alignment = 顶 padding / 视口高），使两者观感一致。
      final topAlign = _viewportHeight > 0
          ? AppSpacing.s / _viewportHeight
          : 0.0;
      AppLogger.log(
        'CHAT-SCROLL',
        '置顶 jumpTo index=$index alignment=${topAlign.toStringAsFixed(3)} '
            'itemCount=$_itemCount viewport=${_viewportHeight.toStringAsFixed(1)}',
      );
      _itemScrollController.jumpTo(index: index, alignment: topAlign);
      // 下一帧回读锚点落位，确认是否贴顶（leadingEdge 应≈topAlign）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _logAnchorLanding(index);
      });
    });
  }

  /// 回读锚点消息在视口内的落位（leadingEdge/trailingEdge 为视口比例，0=顶 1=底）。
  void _logAnchorLanding(int index) {
    final positions = _itemPositionsListener.itemPositions.value;
    final anchor = positions.where((p) => p.index == index).firstOrNull;
    if (anchor == null) {
      AppLogger.log(
        'CHAT-SCROLL',
        '置顶落位：锚点 index=$index 不在可见集合（visible=${_visibleIndices(positions)}）',
      );
      return;
    }
    AppLogger.log(
      'CHAT-SCROLL',
      '置顶落位 index=$index '
          'leadingEdge=${anchor.itemLeadingEdge.toStringAsFixed(3)} '
          'trailingEdge=${anchor.itemTrailingEdge.toStringAsFixed(3)} '
          'topPx=${(anchor.itemLeadingEdge * _viewportHeight).toStringAsFixed(1)}',
    );
  }

  /// 当前可见 item 的 index 列表（升序），用于诊断日志。
  List<int> _visibleIndices(Iterable<ItemPosition> positions) =>
      (positions.map((p) => p.index).toList()..sort());

  @override
  Widget build(BuildContext context) {
    final provider = chatSessionControllerProvider(widget.config);

    // 结构变化（增/删消息）只重建列表，不改变滚动位置；用户可能仍在阅读上文。
    final idsCsv = ref.watch(
      provider.select((s) => s.messages.map((m) => m.id).join('|')),
    );
    final ids = idsCsv.isEmpty ? const <String>[] : idsCsv.split('|');
    // 流式增量到达后重算回底浮标（内容变高可能撑出底部）。
    ref.listen(
      provider.select((s) => s.messages.isEmpty ? '' : s.messages.last.content),
      (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncJumpButtonVisibility();
        });
      },
    );
    // 新一轮：最后一条 user 消息的 id 变化 → 把它滑到视口顶部。
    // 只监听「最后一条 user id」，流式增量（改 content）不触发。
    ref.listen(provider.select(_latestUserId), (_, next) {
      if (next.isNotEmpty) _onNewUserTurn(next);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        // 末条消息预留至少一屏高度：发送后用户消息顶到顶部、下方留白给流式回答；
        // 回答变长时该约束自动失效（内容撑开），不产生多余空白。减去列表纵向 padding
        // 使短内容时恰好不触发回底浮标。
        final reserve = (constraints.maxHeight - AppSpacing.s * 2).clamp(
          0.0,
          double.infinity,
        );
        // 末尾追加 0 高度哨兵，作为「回到底部 / 是否到底」的稳定锚点。
        _itemCount = ids.isEmpty ? 0 : ids.length + 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncJumpButtonVisibility();
        });

        return Stack(
          children: [
            ScrollablePositionedList.builder(
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              itemCount: _itemCount,
              itemBuilder: (context, index) {
                if (index >= ids.length) {
                  return const SizedBox.shrink(); // 末尾哨兵
                }
                return _buildRow(
                  ids[index],
                  isLast: index == ids.length - 1,
                  reserve: reserve,
                );
              },
            ),
            if (_showJumpButton)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.m,
                child: Center(
                  child: _JumpToBottomButton(onTap: _animateToBottom),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 最后一条 user 消息 id（无则空串）——新一轮置顶的触发信号。
  static String _latestUserId(ChatSessionState state) {
    for (final m in state.messages.reversed) {
      if (m.role == ChatRole.user) return m.id;
    }
    return '';
  }

  /// 构建单行：末条行预留 [reserve] 最小高度且内容顶对齐（避免被 minHeight 撑高后
  /// 垂直居中），为置顶后的流式回答让出空间。
  Widget _buildRow(String id, {required bool isLast, required double reserve}) {
    Widget row = _MessageRow(
      key: ValueKey(id),
      config: widget.config,
      messageId: id,
      onRetry: widget.onRetry,
      onUpgrade: widget.onUpgrade,
      onCopy: widget.onCopy,
      onEdit: widget.onEdit,
      onRegenerate: widget.onRegenerate,
      onFollowUp: widget.onFollowUp,
    );
    if (isLast) {
      row = ConstrainedBox(
        constraints: BoxConstraints(minHeight: reserve),
        child: Align(alignment: Alignment.topCenter, child: row),
      );
    }
    return row;
  }
}

/// 单行：独立 ConsumerWidget，select 自己那条消息 → 等值短路不随他行重建。
class _MessageRow extends ConsumerWidget {
  const _MessageRow({
    super.key,
    required this.config,
    required this.messageId,
    this.onRetry,
    this.onUpgrade,
    this.onCopy,
    this.onEdit,
    this.onRegenerate,
    this.onFollowUp,
  });

  final ChatbotConfig config;
  final String messageId;
  final void Function(String messageId)? onRetry;
  final VoidCallback? onUpgrade;
  final void Function(String content)? onCopy;
  final void Function(String messageId)? onEdit;
  final void Function(String messageId)? onRegenerate;
  final void Function(String selectedText)? onFollowUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(
      chatSessionControllerProvider(config).select(
        (s) => s.messages.firstWhere(
          (m) => m.id == messageId,
          orElse: () => _missing,
        ),
      ),
    );
    if (identical(message, _missing)) return const SizedBox.shrink();
    return ChatMessageBubble(
      message: message,
      onRetry: onRetry == null ? null : () => onRetry!(messageId),
      onUpgrade: onUpgrade,
      onCopy: onCopy,
      onEdit: onEdit == null ? null : () => onEdit!(messageId),
      onRegenerate: onRegenerate == null
          ? null
          : () => onRegenerate!(messageId),
      onFollowUp: onFollowUp,
    );
  }

  /// 消息已被移除时的哨兵（如首 token 前停止移除空占位）。
  static final ChatMessage _missing = ChatMessage(
    id: '__missing__',
    role: ChatRole.assistant,
    content: '',
    status: ChatMessageStatus.done,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// 回底浮标按钮：ChatGPT 风格 —— 居中、白色圆底、细边框 + 柔和阴影，向下箭头图标。
class _JumpToBottomButton extends StatelessWidget {
  const _JumpToBottomButton({required this.onTap});
  final VoidCallback onTap;

  /// 向下箭头图标（SVG）。
  static const String _iconArrowDown = 'assets/icon/chat/arrow-down.svg';

  /// 按钮直径与图标尺寸。
  static const double _size = 36;
  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.chatScrollToBottom,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 细边框：与背景轻微区分，观感干净。
          border: Border.all(color: scheme.outlineVariant),
          // 柔和阴影：轻微上浮，不喧宾夺主。
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          // 白色圆底（跟随主题 surface，浅色下为白）。
          color: scheme.surface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: _size,
              height: _size,
              child: Center(
                child: SvgPicture.asset(
                  _iconArrowDown,
                  width: _iconSize,
                  height: _iconSize,
                  colorFilter: ColorFilter.mode(
                    scheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
