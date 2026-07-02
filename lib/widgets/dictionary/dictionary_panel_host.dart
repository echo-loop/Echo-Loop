/// 页面级词典面板宿主（非 modal）
///
/// 包在宿主页 Scaffold body 内容外层。词典面板作为 Stack 内嵌的常驻底部
/// 面板渲染（非 modal 路由）：面板显示期间正文仍可交互（继续点词/选词组），
/// 点新词经 [DictionaryPanelHostState.show] 原地切换面板内容，不重开动画。
///
/// 设计取舍（ADR 参照 CLAUDE.md「结构性属性优于运行时开关」）：
/// - 用 Stack 内嵌而非 showBottomSheet（LocalHistoryEntry/返回键纠缠）或
///   OverlayEntry（命令式生命周期易泄漏）；
/// - 面板状态是页面局部 state（谁创建谁销毁）：页面 pop 即面板销毁，
///   查词 controller（autoDispose）随之释放，无跨页残留；
/// - 面板开着时正文上盖一层**带词区域豁免的透明屏障**：点句子里的词/
///   拖手柄照常放行（连续查词/扩选），点其它区域先关面板并吸收该次点击
///   （不触发下层操作）。豁免判定由可点词组件经
///   [DictionaryPanelHostState.registerTapThroughHitTest] 注册**精确命中
///   谓词**（文本 bounds + 手柄命中区），不做外扩矩形——句子紧邻的按钮/
///   点击切换字幕等下层交互不会被误放行。
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dictionary_panel.dart';

/// 一次查词请求：查询文本 + 来源信息（收藏单词时记录出处）
class DictionaryPanelQuery {
  /// 查询文本（单词或多词词组，未归一化的原始点选文本）
  final String word;

  /// 来源音频 ID（可选）
  final String? audioItemId;

  /// 来源句子索引（可选）
  final int? sentenceIndex;

  /// 来源句子文本（可选）
  final String? sentenceText;

  /// 来源句子起始时间（毫秒，可选）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒，可选）
  final int? sentenceEndMs;

  const DictionaryPanelQuery({
    required this.word,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  @override
  bool operator ==(Object other) =>
      other is DictionaryPanelQuery &&
      other.word == word &&
      other.audioItemId == audioItemId &&
      other.sentenceIndex == sentenceIndex &&
      other.sentenceText == sentenceText &&
      other.sentenceStartMs == sentenceStartMs &&
      other.sentenceEndMs == sentenceEndMs;

  @override
  int get hashCode => Object.hash(
    word,
    audioItemId,
    sentenceIndex,
    sentenceText,
    sentenceStartMs,
    sentenceEndMs,
  );
}

/// 词典面板宿主。用法：`Scaffold(body: DictionaryPanelHost(child: 原body))`。
///
/// [handleBackButton] 为 true 时自带 PopScope（面板开着时返回键先关面板）；
/// 仅供页面自身没有 PopScope 的宿主使用。已有 PopScope 的页面必须保持
/// 单一 PopScope，在其回调首行调 [DictionaryPanelHostState.closeIfOpen]
/// 做 guard——同路由多个 PopScope 的触发顺序无保证。
class DictionaryPanelHost extends StatefulWidget {
  /// 页面正文
  final Widget child;

  /// 是否由宿主自带 PopScope 处理返回键（仅无 PopScope 的页面开启）
  final bool handleBackButton;

  const DictionaryPanelHost({
    super.key,
    required this.child,
    this.handleBackButton = false,
  });

  @override
  State<DictionaryPanelHost> createState() => DictionaryPanelHostState();

  /// 取最近的宿主 state（触发查词用，不建立依赖）
  static DictionaryPanelHostState of(BuildContext context) {
    final state = maybeOf(context);
    assert(
      state != null,
      'DictionaryPanelHost.of() 未找到宿主：请确认页面 body 已包 DictionaryPanelHost',
    );
    return state!;
  }

  /// 取最近的宿主 state；无宿主时返回 null
  static DictionaryPanelHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<DictionaryPanelHostState>();

  /// 当前活跃查词发起者（建立依赖）。
  ///
  /// 可点词组件据此清理选区：返回值不是自己（别处点了词）或为 null
  /// （面板已关闭）时清掉本地选区高亮。
  static Object? activeOwnerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_DictionaryPanelScope>()
      ?.owner;
}

/// 宿主 state：持有当前查询与出入场动画
class DictionaryPanelHostState extends State<DictionaryPanelHost>
    with SingleTickerProviderStateMixin {
  /// 当前查询；null = 面板关闭（不在树中）
  DictionaryPanelQuery? _query;

  /// 当前查词发起者（可点词组件的 identity token，选区清理用）
  Object? _owner;

  /// 是否正在滑出（滑出期间面板仍在树中播放退场动画）
  bool _closing = false;

  /// 面板滑入/滑出动画
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  /// 屏障豁免命中谓词集合（入参为全局坐标）。任一谓词命中的点击穿透
  /// 屏障直达下层（点词切换查询、拖手柄扩选）；均未命中则关面板并吸收点击。
  final Set<bool Function(Offset globalPosition)> _tapThroughHitTests = {};

  /// 注册屏障豁免命中谓词（可点词组件在挂载时调用，谓词在命中测试时求值）
  void registerTapThroughHitTest(bool Function(Offset globalPosition) hitTest) {
    _tapThroughHitTests.add(hitTest);
  }

  /// 注销屏障豁免命中谓词（组件卸载时调用，与注册的谓词同一 tear-off）
  void unregisterTapThroughHitTest(
    bool Function(Offset globalPosition) hitTest,
  ) {
    _tapThroughHitTests.remove(hitTest);
  }

  /// 全局坐标是否命中任一豁免谓词
  bool _hitsTapThroughRegion(Offset globalPosition) {
    for (final hitTest in _tapThroughHitTests) {
      if (hitTest(globalPosition)) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    // 滑出到底后再把面板移出树（期间保留子树以播放退场动画）
    _slide.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted && _closing) {
        setState(() {
          _query = null;
          _owner = null;
          _closing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  /// 面板是否打开（滑出中视为已关闭，避免 closeIfOpen 重复消费返回键）
  bool get isOpen => _query != null && !_closing;

  /// 显示/切换查词。面板已开时原地切换内容（不重播入场动画）。
  ///
  /// [owner] 为发起查词的组件 identity（可点词组件传 State 自身），
  /// 供 [DictionaryPanelHost.activeOwnerOf] 做选区清理判定。
  void show(DictionaryPanelQuery query, {Object? owner}) {
    setState(() {
      _query = query;
      _owner = owner;
      _closing = false;
    });
    _slide.forward();
  }

  /// 关闭面板（播放滑出动画后移出树）
  void close() {
    if (_query == null || _closing) return;
    setState(() => _closing = true);
    _slide.reverse();
  }

  /// 面板开着则关闭并返回 true；否则返回 false。
  ///
  /// 供宿主页 PopScope / 返回按钮回调首行做 guard：返回 true 时本次返回
  /// 只关面板，不退页面。
  bool closeIfOpen() {
    if (!isOpen) return false;
    close();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Stack(
      children: [
        widget.child,
        // 关面板屏障：盖在正文上、面板下。点词区域（豁免）放行，
        // 其余点击关面板并吸收（不触发下层操作）。滑出中即移除，页面立即可交互。
        if (isOpen)
          Positioned.fill(
            child: _DismissBarrier(
              shouldForward: _hitsTapThroughRegion,
              onDismiss: close,
            ),
          ),
        if (_query != null)
          // 非 Positioned 子节点拿 Stack 的宽松约束：面板最大高度天然
          // 不超过正文区域，宽度经内部拉满。
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
                  ),
              child: SizedBox(
                width: double.infinity,
                child: DictionaryPanel(
                  query: _query!,
                  onClose: close,
                  entryAnimation: _slide.view,
                ),
              ),
            ),
          ),
      ],
    );
    result = _DictionaryPanelScope(
      owner: isOpen ? _owner : null,
      child: result,
    );
    if (widget.handleBackButton) {
      result = PopScope(
        canPop: !isOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: result,
      );
    }
    return result;
  }
}

/// 向子树暴露当前查词发起者（选区清理依赖面）
class _DictionaryPanelScope extends InheritedWidget {
  final Object? owner;

  const _DictionaryPanelScope({required this.owner, required super.child});

  @override
  bool updateShouldNotify(_DictionaryPanelScope oldWidget) =>
      oldWidget.owner != owner;
}

/// 关面板屏障：豁免区域内的点击穿透（不命中自身），其余点击按下即关面板。
///
/// 用 [Listener.onPointerDown]（非手势竞技场）保证即时、无歧义地吸收该次
/// 点击——被吸收的手势后续事件仍归屏障，天然不会触发下层操作。
class _DismissBarrier extends StatelessWidget {
  /// 是否放行该全局坐标（命中词区域/手柄豁免区）
  final bool Function(Offset globalPosition) shouldForward;

  /// 关闭面板回调
  final VoidCallback onDismiss;

  const _DismissBarrier({required this.shouldForward, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return _TapThroughFilter(
      shouldForward: shouldForward,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onDismiss(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 命中测试过滤器：[shouldForward] 为 true 的位置视为未命中，
/// 事件穿透到 Stack 中位于屏障之下的正文。
class _TapThroughFilter extends SingleChildRenderObjectWidget {
  final bool Function(Offset globalPosition) shouldForward;

  const _TapThroughFilter({required this.shouldForward, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTapThroughFilter(shouldForward);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTapThroughFilter renderObject,
  ) {
    renderObject.shouldForward = shouldForward;
  }
}

/// [_TapThroughFilter] 的 render object
class _RenderTapThroughFilter extends RenderProxyBox {
  /// 是否放行该全局坐标
  bool Function(Offset globalPosition) shouldForward;

  _RenderTapThroughFilter(this.shouldForward);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (shouldForward(localToGlobal(position))) return false;
    return super.hitTest(result, position: position);
  }
}
