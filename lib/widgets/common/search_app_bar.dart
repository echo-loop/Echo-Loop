// 搜索模式 AppBar：圆角搜索框替代标题，「取消」退出搜索。
//
// 合集详情页与资源库首页共用，保证两处搜索的外观与交互一致。
// 绑定 Esc 退出搜索，保留桌面端的键盘操作习惯。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'svg_action_icon.dart';

const String _searchIconAsset = 'assets/icon/search.svg';

class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SearchAppBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.onCancel,
    this.onSubmitted,
    this.leading,
    this.actions,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;

  /// 当前原始输入，用于决定是否显示清除按钮。
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  /// 键盘搜索键的行为；默认只收起键盘，不退出搜索模式。
  final ValueChanged<String>? onSubmitted;

  /// 左侧入口（如返回键）；为空时不显示。
  final Widget? leading;

  /// 右侧操作；为空时使用「取消」按钮退出搜索。
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
      child: AppBar(
        automaticallyImplyLeading: false,
        leading: leading,
        // 输入框做成带底色的圆角搜索框，让用户一眼看出这里可以输入。
        title: Container(
          height: 40,
          padding: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                // 搜索图标作为 prefixIcon 与文字交给同一个 InputDecorator 排版，
                // 两者才能按同一基线垂直对齐。
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    prefixIcon: SvgActionIcon(
                      assetName: _searchIconAsset,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 0,
                    ),
                  ),
                  onChanged: onChanged,
                  // 默认键盘搜索键只收起键盘，不退出搜索模式。
                  onSubmitted: onSubmitted ?? (_) => focusNode.unfocus(),
                ),
              ),
              if (query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: l10n.collectionSearchClearTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                ),
            ],
          ),
        ),
        actions:
            actions ??
            [
              TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
              const SizedBox(width: 8),
            ],
      ),
    );
  }
}
