/// 「播客字幕可能不准确」提醒弹窗
///
/// 用户首次在字幕管理中选择「下载播客字幕」时弹出：播客自带字幕质量参差不齐，
/// 提示用户不准确时可改用云端转录。弹窗只有「知道了」按钮且不可点外部关闭，
/// 确保一次展示后必定由调用方记录「已提示」。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 展示提醒弹窗，用户点「知道了」后返回。
Future<void> showPodcastTranscriptReminderDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.podcastTranscriptReminderTitle),
      content: Text(l10n.podcastTranscriptReminderMessage),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.podcastTranscriptReminderConfirm),
        ),
      ],
    ),
  );
}
