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
/// - 面板开着时正文上盖一层**带词区域豁免的透明屏障**：点句子里的词
///   照常放行（连续查词），点其它区域先关面板并吸收该次点击
///   （不触发下层操作）。豁免判定由可点词组件经
///   [DictionaryPanelHostState.registerTapThroughHitTest] 注册文本 bounds 的
///   **精确命中谓词**，不做外扩矩形——句子紧邻的按钮/
///   点击切换字幕等下层交互不会被误放行。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../selection/selection_toolbar_host.dart';
import '../selection/selection_toolbar_layer.dart';
import 'dictionary_panel.dart';

/// 面板查询切换日志；仅 debug 构建输出，与选区和 controller 日志共用前缀。
void _traceDictionaryPanel(String message) {
  if (!kDebugMode) return;
  final timestamp = DateTime.now().toIso8601String();
  debugPrint('[DictionaryTrace][$timestamp][panel] $message');
}

/// 词典面板收藏按钮对应的数据类型。
enum DictionaryBookmarkKind { word, senseGroup }

/// 一次查词请求：查询文本 + 来源信息（收藏单词时记录出处）
class DictionaryPanelQuery {
  /// 查询文本（单词或多词词组，未归一化的原始点选文本）
  final String word;

  /// 初始词典源 ID（可选）。
  ///
  /// 仅用于本次查询的初始选中源，不写入词典面板会话粘滞源。意群快捷 lookup
  /// 用它强制走 AI 源；普通点词/选词组不传，仍走默认源与词组优先 AI 规则。
  final String? preferredSourceId;

  /// 收藏按钮读写的数据类型；普通查词默认使用词汇收藏。
  final DictionaryBookmarkKind bookmarkKind;

  /// 来源音频 ID（可选）
  final String? audioItemId;

  /// 来源句子文本（可选）
  final String? sentenceText;

  /// 来源句子起始时间（毫秒，可选）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒，可选）
  final int? sentenceEndMs;

  const DictionaryPanelQuery({
    required this.word,
    this.preferredSourceId,
    this.bookmarkKind = DictionaryBookmarkKind.word,
    this.audioItemId,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  @override
  bool operator ==(Object other) =>
      other is DictionaryPanelQuery &&
      other.word == word &&
      other.preferredSourceId == preferredSourceId &&
      other.bookmarkKind == bookmarkKind &&
      other.audioItemId == audioItemId &&
      other.sentenceText == sentenceText &&
      other.sentenceStartMs == sentenceStartMs &&
      other.sentenceEndMs == sentenceEndMs;

  @override
  int get hashCode => Object.hash(
    word,
    preferredSourceId,
    bookmarkKind,
    audioItemId,
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

  /// 面板开关状态变化回调，供宿主页同步返回手势是否可用。
  final ValueChanged<bool>? onOpenStateChanged;

  const DictionaryPanelHost({
    super.key,
    required this.child,
    this.handleBackButton = false,
    this.onOpenStateChanged,
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

  /// 面板是否打开（建立依赖）。
  ///
  /// 供与面板互斥的交互按**结构性状态**决定自身行为，而不是靠命令式回调同步。
  /// 首个用途：面板开着时翻页器不接受滑动——屏障是按**区域**放行的（豁免正文
  /// 文本 bounds 以支持连续点词），而 `SelectableText` 在触屏上不消费水平拖拽，
  /// 于是文字区域上的横滑会穿到下层 PageView，导致切句成功而面板未关。
  /// 这不影响文本区域的 tap / 长按 / 手柄拖拽。
  static bool isPanelOpenOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DictionaryPanelScope>()
          ?.isOpen ??
      false;
}

/// 宿主 state：持有当前查询与出入场动画
class DictionaryPanelHostState extends State<DictionaryPanelHost>
    with SingleTickerProviderStateMixin
    implements SelectionToolbarMount {
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
  /// 屏障直达下层（点词切换查询）；均未命中则关面板并吸收点击。
  final Set<bool Function(Offset globalPosition)> _tapThroughHitTests = {};

  /// 面板开关状态监听器。
  ///
  /// 供页面内局部浮层（如意群快捷 lookup）在词典面板关闭时恢复交互。
  final Set<VoidCallback> _openStateListeners = {};

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

  /// 当前挂载的选区操作条请求（由可选文本组件推送）。
  SelectionToolbarRequest? _selectionToolbar;

  /// 挂载/更新选区操作条。
  ///
  /// 操作条必须由页面级宿主渲染：它会溢出正文的 render box，而祖先按各自 box
  /// 剪裁命中测试，挂在正文里溢出部分点不动；挂根 Overlay 则会盖在面板之上、
  /// 遮挡与滚动跟随都要手算。这里在 Stack 中位于「屏障之上、面板之下」，于是
  /// 点操作条不被屏障吸收、面板天然遮住操作条，全部由层序解决。
  @override
  void showSelectionToolbar(SelectionToolbarRequest request) {
    // 请求可能来自已卸载内容的延迟回调，宿主自身也可能正在销毁。
    if (!mounted || _selectionToolbar == request) return;
    setState(() => _selectionToolbar = request);
  }

  /// 收起选区操作条（仅当前 owner 可收起自己的）。
  @override
  void hideSelectionToolbar(Object owner) {
    if (!mounted || !identical(_selectionToolbar?.owner, owner)) return;
    setState(() => _selectionToolbar = null);
  }

  /// 全局锚点 → 宿主 Stack 局部锚点。
  TextSelectionToolbarAnchors _toLocalAnchors(
    TextSelectionToolbarAnchors global,
  ) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return global;
    final secondary = global.secondaryAnchor;
    return TextSelectionToolbarAnchors(
      primaryAnchor: box.globalToLocal(global.primaryAnchor),
      secondaryAnchor: secondary == null ? null : box.globalToLocal(secondary),
    );
  }

  /// 注册词典面板开关状态监听器。
  void addOpenStateListener(VoidCallback listener) {
    _openStateListeners.add(listener);
  }

  /// 注销词典面板开关状态监听器。
  void removeOpenStateListener(VoidCallback listener) {
    _openStateListeners.remove(listener);
  }

  void _notifyOpenStateListeners() {
    for (final listener in List<VoidCallback>.of(_openStateListeners)) {
      listener();
    }
    widget.onOpenStateChanged?.call(isOpen);
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
        _notifyOpenStateListeners();
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

  /// 当前打开的查词会话是否属于 [owner]。
  ///
  /// 异步恢复选区或操作条前需重新核对所有权，避免旧帧回调干扰已经切换的查询。
  bool isOwnedBy(Object owner) => isOpen && identical(_owner, owner);

  /// 显示/切换查词。面板已开时原地切换内容（不重播入场动画）。
  ///
  /// [owner] 为发起查词的组件 identity（可点词组件传 State 自身），
  /// 供 [DictionaryPanelHost.activeOwnerOf] 做选区清理判定。
  void show(DictionaryPanelQuery query, {Object? owner}) {
    _traceDictionaryPanel(
      'show owner=${owner == null ? null : identityHashCode(owner)} '
      'word="${query.word}" previous="${_query?.word}" '
      'wasOpen=$isOpen',
    );
    setState(() {
      _query = query;
      _owner = owner;
      _closing = false;
    });
    _slide.forward();
    _notifyOpenStateListeners();
  }

  /// 关闭面板（播放滑出动画后移出树）
  void close() {
    if (_query == null || _closing) return;
    setState(() => _closing = true);
    _slide.reverse();
    _notifyOpenStateListeners();
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

  /// 仅当当前面板由 [owner] 发起时关闭。
  ///
  /// 显式结束查词会话时用此入口同步收起面板，避免旧组件误关掉另一句
  /// 刚打开的新查询。
  bool closeIfOwnedBy(Object owner) {
    if (!isOwnedBy(owner)) return false;
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
        // 选区操作条：在屏障之上（点它不被吸收）、面板之下（被面板天然遮挡）。
        // 锚点在这里换算：宿主的 render box 上一帧已布局，而图层自身首次 build
        // 时 findRenderObject() 还是 null，无法就地换算。
        if (_selectionToolbar case final request?)
          Positioned.fill(
            child: SelectionToolbarLayer(
              anchors: _toLocalAnchors(request.globalAnchors),
              actions: request.actions,
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
              child: TextFieldTapRegion(
                child: SizedBox(
                  key: const Key('dict_panel_surface'),
                  width: double.infinity,
                  child: DictionaryPanel(
                    query: _query!,
                    onClose: close,
                    entryAnimation: _slide.view,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    result = _DictionaryPanelScope(
      owner: isOpen ? _owner : null,
      isOpen: isOpen,
      // 本宿主同时是选区操作条的挂载点（AI 回答等非查词内容也能挂进来）。
      child: SelectionToolbarScope(mount: this, child: result),
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

/// 向子树暴露当前查词发起者（选区清理依赖面）与面板开关状态
class _DictionaryPanelScope extends InheritedWidget {
  final Object? owner;

  /// 面板是否打开（滑出中视为已关闭，与 [DictionaryPanelHostState.isOpen] 一致）
  final bool isOpen;

  const _DictionaryPanelScope({
    required this.owner,
    required this.isOpen,
    required super.child,
  });

  @override
  bool updateShouldNotify(_DictionaryPanelScope oldWidget) =>
      oldWidget.owner != owner || oldWidget.isOpen != isOpen;
}

/// 关面板屏障：豁免区域内的点击穿透（不命中自身），其余点击按下即关面板。
///
/// 用 [Listener.onPointerDown]（非手势竞技场）保证即时、无歧义地吸收该次
/// 点击——被吸收的手势后续事件仍归屏障，天然不会触发下层操作。
class _DismissBarrier extends StatelessWidget {
  /// 是否放行该全局坐标（命中查词正文区域）
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
