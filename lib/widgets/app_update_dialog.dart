/// App 版本更新对话框
///
/// 根据更新类型显示不同的对话框：
/// - Soft update: 可关闭，包含"稍后提醒"和"立即更新"按钮
/// - Force update: 不可关闭，无"稍后"按钮，提供"复制下载链接"逃生通道
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/app_update_info.dart';

/// 显示版本更新对话框
///
/// [isForceUpdate] 控制是否为强制更新（不可关闭）。
/// [onDismiss] 在 soft update 时用户点击"稍后"触发。
/// [downloadUrl] 当前平台的下载链接。
Future<void> showAppUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo info,
  required bool isForceUpdate,
  required String? downloadUrl,
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: !isForceUpdate,
    builder: (context) => PopScope(
      canPop: !isForceUpdate,
      child: _AppUpdateDialogContent(
        info: info,
        isForceUpdate: isForceUpdate,
        downloadUrl: downloadUrl,
        onDismiss: onDismiss,
      ),
    ),
  );
}

class _AppUpdateDialogContent extends StatelessWidget {
  final AppUpdateInfo info;
  final bool isForceUpdate;
  final String? downloadUrl;
  final VoidCallback? onDismiss;

  const _AppUpdateDialogContent({
    required this.info,
    required this.isForceUpdate,
    required this.downloadUrl,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    // 标题
    final title = isForceUpdate
        ? l10n.forceUpdateTitle
        : l10n.updateAvailable(info.latestVersion);

    // 正文
    final releaseNotes =
        info.releaseNotes[locale] ?? info.releaseNotes['en'] ?? '';
    final message = isForceUpdate ? l10n.forceUpdateMessage : releaseNotes;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isNotEmpty) _ReleaseNotesText(text: message),
          if (isForceUpdate && downloadUrl != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _copyLink(context, l10n),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l10n.copyDownloadLink),
              ),
            ),
          ],
        ],
      ),
      actions: [
        // soft update: 稍后提醒
        if (!isForceUpdate)
          TextButton(
            onPressed: () {
              onDismiss?.call();
              Navigator.of(context).pop();
            },
            child: Text(l10n.updateLater),
          ),
        // 立即更新
        FilledButton(
          onPressed: () => _launchUpdate(context),
          child: Text(l10n.updateNow),
        ),
      ],
    );
  }

  void _launchUpdate(BuildContext context) {
    if (downloadUrl != null) {
      launchUrl(Uri.parse(downloadUrl!), mode: LaunchMode.externalApplication);
    }
    // soft update 时关闭对话框
    if (!isForceUpdate) {
      Navigator.of(context).pop();
    }
  }

  void _copyLink(BuildContext context, AppLocalizations l10n) {
    if (downloadUrl == null) return;
    Clipboard.setData(ClipboardData(text: downloadUrl!));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
  }
}

/// 简易 release notes 渲染：按行拆分，`- ` / `* ` 开头的行渲染为带圆点的列表项
class _ReleaseNotesText extends StatelessWidget {
  final String text;

  const _ReleaseNotesText({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) _buildLine(lines[i], i, context),
      ],
    );
  }

  Widget _buildLine(String raw, int index, BuildContext context) {
    final line = raw.trimRight();
    final padTop = index == 0 ? 0.0 : 4.0;
    final trimmed = line.trimLeft();
    final isBullet = trimmed.startsWith('- ') || trimmed.startsWith('* ');

    if (isBullet) {
      final dotColor =
          DefaultTextStyle.of(context).style.color ??
          Theme.of(context).colorScheme.onSurface;
      return Padding(
        padding: EdgeInsets.only(top: padTop),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8, top: 7),
              child: SizedBox(
                width: 4,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Expanded(child: Text(trimmed.substring(2))),
          ],
        ),
      );
    }

    if (line.isEmpty) {
      return const SizedBox(height: 4);
    }

    return Padding(
      padding: EdgeInsets.only(top: padTop),
      child: Text(line),
    );
  }
}
