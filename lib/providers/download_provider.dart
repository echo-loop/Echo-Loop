import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/background_file_download_service.dart';
import '../services/download/download_resource.dart';
import '../services/download/download_task_coordinator.dart';
import '../services/download/download_task_store.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'settings_provider.dart';

final downloadResourcesProvider = Provider<List<DownloadResource>>((ref) => const []);

/// 根据应用界面语言加载后台下载通知的状态文案。
Future<BackgroundFileDownloadNotificationLabels>
loadBackgroundFileDownloadNotificationLabels(Locale locale) async {
  final l10n = await AppLocalizations.delegate.load(locale);
  return BackgroundFileDownloadNotificationLabels(
    running: l10n.backgroundDownloadRunningTitle,
    complete: l10n.backgroundDownloadCompleteTitle,
    failed: l10n.backgroundDownloadFailedTitle,
  );
}

/// 用户文件后台下载服务；模型等专用资源继续使用各自的下载管理器。
final backgroundFileDownloadServiceProvider =
    Provider<BackgroundFileDownloadService>(
      (ref) => BackgroundFileDownloadService(
        resolveNotificationLabels: () async {
          final locale =
              ref.read(appSettingsProvider).locale ??
              PlatformDispatcher.instance.locale;
          return loadBackgroundFileDownloadNotificationLabels(locale);
        },
      ),
    );

/// 启动后可静默拉取的资源 ID；业务模块注册后由应用壳在首帧后触发。
final startupDownloadResourceIdsProvider = Provider<List<String>>((ref) => const []);

final downloadTaskCoordinatorProvider = Provider<DownloadTaskCoordinator>((ref) {
  final coordinator = DownloadTaskCoordinator(
    resources: ref.watch(downloadResourcesProvider),
    store: SharedPreferencesDownloadTaskStore(ref.watch(sharedPreferencesProvider)),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final downloadTaskStateProvider = StreamProvider.family<DownloadTaskState, String>((ref, id) {
  final coordinator = ref.watch(downloadTaskCoordinatorProvider);
  return coordinator.watch(id);
});

/// 触发所有启动静默下载。调用方须在首帧后 fire-and-forget 调用。
Future<void> startRegisteredDownloads(WidgetRef ref) async {
  final coordinator = ref.read(downloadTaskCoordinatorProvider);
  for (final id in ref.read(startupDownloadResourceIdsProvider)) {
    await coordinator.startSilently(id);
  }
}
