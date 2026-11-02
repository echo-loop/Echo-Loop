import 'dart:ui' show Locale;

import '../l10n/app_localizations.dart';

/// 复习提醒通知的展示文案，按 App 界面语言解析。
///
/// 由 [ReviewReminderService] 在每次同步时读取，保证切换语言后下一次调度即生效。
class ReviewReminderTexts {
  const ReviewReminderTexts({
    required this.savedBodies,
    required this.perAudioBody,
    required this.localeTag,
  });

  /// 从生成的 [AppLocalizations] 构造文案。
  ///
  /// [localeTag] 用于快照去重：语言变化时即使提醒列表不变也会重新调度。
  factory ReviewReminderTexts.fromL10n(
    AppLocalizations l10n, {
    required String localeTag,
  }) {
    return ReviewReminderTexts(
      savedBodies: [
        l10n.reviewReminderSavedBody1,
        l10n.reviewReminderSavedBody2,
        l10n.reviewReminderSavedBody3,
        l10n.reviewReminderSavedBody4,
        l10n.reviewReminderSavedBody5,
        l10n.reviewReminderSavedBody6,
        l10n.reviewReminderSavedBody7,
        l10n.reviewReminderSavedBody8,
        l10n.reviewReminderSavedBody9,
        l10n.reviewReminderSavedBody10,
      ],
      perAudioBody: l10n.reviewReminderBody,
      localeTag: localeTag,
    );
  }

  /// 英文文案，作为文案解析失败时的兜底。
  factory ReviewReminderTexts.english() {
    return ReviewReminderTexts.fromL10n(
      lookupAppLocalizations(const Locale('en')),
      localeTag: 'en',
    );
  }

  /// 收藏复习提醒的正文池，按天轮换。
  final List<String> savedBodies;

  /// 单条音频复习提醒的正文，参数为音频名与复习轮次。
  final String Function(String audioName, int round) perAudioBody;

  /// 当前文案的语言标识，如 `en` / `zh-CN`。
  final String localeTag;
}
