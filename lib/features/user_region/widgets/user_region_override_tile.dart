/// 开发者选项中的「服务地区」切换入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_logger.dart';
import '../user_region_override.dart';
import '../user_region_providers.dart';

/// 展示当前生效地区与已保存的覆盖值，点击弹窗选择自动 / 中国区 / 全球区。
///
/// 地区在启动时固定，所以选择后提示重启生效。开发者调试用，文案不做国际化。
class UserRegionOverrideTile extends ConsumerWidget {
  const UserRegionOverrideTile({super.key, required this.leading});

  /// 与设置页其他行一致的前置图标。
  final Widget leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref.watch(userRegionOverrideProvider).valueOrNull ??
        UserRegionOverride.auto;
    final isChinaUser = ref.watch(isChinaUserProvider);
    final effectiveLabel = isChinaUser ? '中国区' : '全球区';
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: leading,
      title: const Text('服务地区'),
      subtitle: Text('本次启动：$effectiveLabel'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _labelOf(saved),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _pickOverride(context, ref, saved),
    );
  }

  Future<void> _pickOverride(
    BuildContext context,
    WidgetRef ref,
    UserRegionOverride current,
  ) async {
    final selected = await showDialog<UserRegionOverride>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('服务地区'),
        children: [
          for (final option in UserRegionOverride.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(option),
              child: Row(
                children: [
                  Expanded(child: Text(_labelOf(option))),
                  if (option == current) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    try {
      await ref.read(userRegionOverrideStoreProvider).save(selected);
    } catch (error) {
      AppLogger.log('UserRegion', 'developer override save failed: $error');
      if (!context.mounted) return;
      _showSnackBar(context, '保存失败：$error');
      return;
    }
    ref.invalidate(userRegionOverrideProvider);
    if (!context.mounted) return;
    _showSnackBar(context, '已切换为「${_labelOf(selected)}」，重启 App 后生效');
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _labelOf(UserRegionOverride value) => switch (value) {
    UserRegionOverride.auto => '自动',
    UserRegionOverride.china => '中国区',
    UserRegionOverride.global => '全球区',
  };
}
