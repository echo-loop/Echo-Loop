import 'dart:io' show Platform;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/background_download_task_inspector.dart';
import '../services/background_file_download_service.dart';
import '../services/download_completion_notifier.dart';
import '../services/resource_download_registry.dart';
import '../services/system_proxy.dart';
import '../services/download/download_resource.dart';
import '../services/download/download_task_coordinator.dart';
import '../services/download/download_task_store.dart';
import '../services/resource_download_registry.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'developer_options_provider.dart';
import 'review_reminder_provider.dart';
import 'settings_provider.dart';

final downloadResourcesProvider = Provider<List<DownloadResource>>(
  (ref) => const [],
);

/// 按界面语言加载后台下载通知的状态文案。
///
/// 传入的 [locale] 先经 [matchUiLocale] 归一为 en / zh_CN，
/// 因此任意系统语言都不会触发 `AppLocalizations` 的未支持异常。
Future<BackgroundFileDownloadNotificationLabels>
loadBackgroundFileDownloadNotificationLabels(Locale locale) async {
  final l10n = await AppLocalizations.delegate.load(matchUiLocale(locale));
  return BackgroundFileDownloadNotificationLabels(
    running: l10n.backgroundDownloadRunningTitle,
    complete: l10n.backgroundDownloadCompleteTitle,
    failed: l10n.backgroundDownloadFailedTitle,
  );
}

/// 解析后台下载通知文案：用户显式设置优先，跟随系统时按系统语言匹配。
Future<BackgroundFileDownloadNotificationLabels>
resolveBackgroundDownloadLabels({
  required Locale? settingLocale,
  required Locale systemLocale,
}) => loadBackgroundFileDownloadNotificationLabels(
  resolveUiLocale(settingLocale, systemLocale),
);

/// 资源登记表：界面读取排队与下载状态，下载服务写入。与服务共用同一实例。
final resourceDownloadRegistryProvider = Provider<ResourceDownloadRegistry>(
  (ref) => sharedResourceDownloadRegistry,
);

/// 桌面端终态通知：background_downloader 在 macOS 上不发通知，由应用补发。
/// 移动端由插件原生发送，这里返回 null。
DownloadCompletionNotifier? _desktopDownloadCompletionNotifier(Ref ref) {
  if (!Platform.isMacOS) return null;
  final reminderService = ref.read(reviewReminderServiceProvider);
  return MacOSDownloadCompletionNotifier(
    plugin: FlutterLocalNotificationsPlugin(),
    ensureInitialized: reminderService.initPlugin,
    isAppInForeground: () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
  );
}

/// 用户文件后台下载服务；模型等专用资源继续使用各自的下载管理器。
final backgroundFileDownloadServiceProvider =
    Provider<BackgroundFileDownloadService>(
      (ref) => BackgroundFileDownloadService(
        registry: ref.read(resourceDownloadRegistryProvider),
        resolveNotificationLabels: () => resolveBackgroundDownloadLabels(
          settingLocale: ref.read(appSettingsProvider).locale,
          systemLocale: PlatformDispatcher.instance.locale,
        ),
        resolveDownloadProxy: () async {
          if (!await readUseSystemProxyForDownloads()) return null;
          return readSystemProxy();
        },
        completionNotifier: _desktopDownloadCompletionNotifier(ref),
      ),
    );

/// 启动后可静默拉取的资源 ID；业务模块注册后由应用壳在首帧后触发。
final startupDownloadResourceIdsProvider = Provider<List<String>>(
  (ref) => const [],
);

final downloadTaskCoordinatorProvider = Provider<DownloadTaskCoordinator>((
  ref,
) {
  final coordinator = DownloadTaskCoordinator(
    resources: ref.watch(downloadResourcesProvider),
    store: SharedPreferencesDownloadTaskStore(
      ref.watch(sharedPreferencesProvider),
    ),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final downloadTaskStateProvider =
    StreamProvider.family<DownloadTaskState, String>((ref, id) {
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

/// 用户文件下载队列的调试查看器；仅供开发者选项页使用。
final downloadTaskInspectorProvider = Provider<DownloadTaskInspector>(
  (ref) => DownloadTaskInspector(downloader: FileDownloader()),
);

/// 下载任务列表，每 2 秒从插件持久化记录刷新一次；页面销毁后自动停止轮询。
final downloadTaskInfosProvider =
    StreamProvider.autoDispose<List<DownloadTaskInfo>>((ref) async* {
      final inspector = ref.watch(downloadTaskInspectorProvider);
      while (true) {
        yield await inspector.list();
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    });

/// 资源级下载状态的只读镜像。唯一状态来源是服务层的登记表，这里不持有第二份状态。
class ResourceDownloadsNotifier
    extends Notifier<Map<String, ResourceDownloadState>> {
  @override
  Map<String, ResourceDownloadState> build() {
    final reader = ref.watch(resourceDownloadRegistryProvider);
    // 先取快照再订阅，两者之间没有异步间隙，不会丢失变化。
    final snapshot = Map<String, ResourceDownloadState>.of(reader.snapshot);
    final subscription = reader.changes.listen((change) {
      state = {...state, change.key: change};
    });
    ref.onDispose(subscription.cancel);
    return snapshot;
  }
}

final resourceDownloadsProvider =
    NotifierProvider<
      ResourceDownloadsNotifier,
      Map<String, ResourceDownloadState>
    >(ResourceDownloadsNotifier.new);

/// 单个资源的下载状态；只有该资源的状态变化才会重建监听它的 UI。
final resourceDownloadProvider =
    Provider.family<ResourceDownloadState?, String>(
      (ref, resourceKey) => ref.watch(
        resourceDownloadsProvider.select((states) => states[resourceKey]),
      ),
    );
