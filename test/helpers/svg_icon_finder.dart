import 'package:echo_loop/widgets/common/svg_action_icon.dart';
import 'package:flutter_test/flutter_test.dart';

/// 按 `assets/icon` 资源名查找 [SvgActionIcon]。
///
/// 图标统一为 SVG 资源后，测试应按资源名断言，而不是 Material IconData。
Finder svgIcon(String assetName) => find.byWidgetPredicate(
  (widget) => widget is SvgActionIcon && widget.assetName == assetName,
);
