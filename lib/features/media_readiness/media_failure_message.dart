import '../../l10n/app_localizations.dart';
import '../audio_import/audio_import_models.dart';
import '../community_collections/download/community_download_notifier.dart';

/// 把下载错误映射为面向用户的补充说明；无法归类时返回 null（只显示通用失败文案）。
String? mediaFailureDetail(AppLocalizations l10n, Object error) {
  if (error is CommunityFileUnavailable) return l10n.communityFileUnavailable;
  if (error is! AudioImportException) return null;
  return switch (error.code) {
    AudioImportFailureCode.invalidUrl ||
    AudioImportFailureCode.unsupportedScheme ||
    AudioImportFailureCode.unsupportedFormat ||
    AudioImportFailureCode.notAudio => l10n.audioUrlUnsupported,
    AudioImportFailureCode.network => l10n.downloadErrorNetwork,
    AudioImportFailureCode.storage => l10n.downloadErrorStorage,
    AudioImportFailureCode.duplicate => error.message,
    AudioImportFailureCode.canceled => l10n.cancel,
    AudioImportFailureCode.unknown =>
      error.message.isEmpty ? null : error.message,
  };
}
