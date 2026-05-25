/// 词典下载状态管理
///
/// 响应母语设置变化，自动下载/打开对应语言的词典。
/// 提供下载状态供 UI 展示进度或错误提示。
library;

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/app_logger.dart';
import '../services/dictionary_download_manager.dart';
import '../services/dictionary_service.dart';
import 'settings_provider.dart';

part 'dictionary_provider.g.dart';

/// 词典下载状态枚举
enum DictionaryStatus {
  /// 尚未下载
  notDownloaded,

  /// 正在下载
  downloading,

  /// 已下载并可用
  downloaded,

  /// 下载失败
  failed,
}

/// 词典状态
class DictionaryState {
  final DictionaryStatus status;

  /// 下载进度（0.0-1.0），仅在 [status] 为 [DictionaryStatus.downloading] 时有意义
  final double progress;

  /// 错误信息，仅在 [status] 为 [DictionaryStatus.failed] 时有值
  final String? error;

  /// 当前词典对应的母语
  final String nativeLanguage;

  const DictionaryState({
    required this.status,
    this.progress = 0,
    this.error,
    required this.nativeLanguage,
  });

  DictionaryState copyWith({
    DictionaryStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
    String? nativeLanguage,
  }) {
    return DictionaryState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
    );
  }
}

/// 词典状态管理 Provider
///
/// 监听母语设置变化，自动管理词典的下载和数据库连接。
@Riverpod(keepAlive: true)
class Dictionary extends _$Dictionary {
  CancelToken? _cancelToken;
  final DictionaryDownloadManager _manager = DictionaryDownloadManager();

  @override
  DictionaryState build() {
    final nativeLanguage = ref.watch(
      appSettingsProvider.select((s) => s.nativeLanguage),
    );

    ref.onDispose(() {
      _cancelToken?.cancel('provider disposed');
      _manager.dispose();
    });

    // 异步初始化：检查本地词典 → 打开或下载
    _initialize(nativeLanguage);

    return DictionaryState(
      status: DictionaryStatus.notDownloaded,
      nativeLanguage: nativeLanguage,
    );
  }

  /// 初始化：检查本地词典，有则打开，无则下载
  Future<void> _initialize(String nativeLanguage) async {
    // 取消之前的下载
    _cancelToken?.cancel('language changed');
    _cancelToken = null;

    // 关闭旧数据库
    DictionaryService.instance.close();

    final isDownloaded = await _manager.isDictionaryDownloaded(nativeLanguage);
    if (isDownloaded) {
      // 本地已有，直接打开
      final path = await _manager.dictionaryPath(nativeLanguage);
      DictionaryService.instance.openDatabase(path);
      AppLogger.log('Dict', 'opened local dictionary lang=$nativeLanguage');
      state = state.copyWith(
        status: DictionaryStatus.downloaded,
        nativeLanguage: nativeLanguage,
      );

      // 后台静默检查更新
      _checkForUpdate(nativeLanguage);
    } else {
      // 本地没有，开始下载
      AppLogger.log(
        'Dict',
        'no local dictionary for lang=$nativeLanguage, downloading...',
      );
      await _startDownload(nativeLanguage);
    }
  }

  /// 开始下载词典
  Future<void> _startDownload(String nativeLanguage) async {
    _cancelToken?.cancel('new download');
    _cancelToken = CancelToken();

    state = state.copyWith(
      status: DictionaryStatus.downloading,
      progress: 0,
      clearError: true,
      nativeLanguage: nativeLanguage,
    );

    try {
      final path = await _manager.download(
        nativeLanguage,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
        cancelToken: _cancelToken,
      );

      // 下载完成，打开数据库
      DictionaryService.instance.openDatabase(path);
      AppLogger.log('Dict', 'download complete lang=$nativeLanguage');
      state = state.copyWith(
        status: DictionaryStatus.downloaded,
        progress: 1.0,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return; // 取消不算失败
      AppLogger.log(
        'Dict',
        'download failed lang=$nativeLanguage '
            'type=${e.type} message=${e.message} '
            'url=${e.requestOptions.uri}',
      );
      state = state.copyWith(
        status: DictionaryStatus.failed,
        error: e.message ?? 'Download failed',
      );
    } catch (e) {
      AppLogger.log('Dict', 'download failed lang=$nativeLanguage error=$e');
      state = state.copyWith(
        status: DictionaryStatus.failed,
        error: e.toString(),
      );
    }
  }

  /// 后台检查词典更新
  Future<void> _checkForUpdate(String nativeLanguage) async {
    try {
      final needsUpdate = await _manager.needsUpdate(nativeLanguage);
      if (!needsUpdate) return;

      // 需要更新，静默下载
      AppLogger.log(
        'Dict',
        'update available for lang=$nativeLanguage, downloading...',
      );
      _cancelToken = CancelToken();
      final path = await _manager.download(
        nativeLanguage,
        cancelToken: _cancelToken,
      );

      // 重新打开数据库
      DictionaryService.instance.close();
      DictionaryService.instance.openDatabase(path);
      AppLogger.log('Dict', 'update complete lang=$nativeLanguage');
    } catch (e) {
      // 更新失败不影响当前已有词典的使用
      AppLogger.log(
        'Dict',
        'update check failed lang=$nativeLanguage error=$e',
      );
    }
  }

  /// 重试下载（下载失败后调用）
  Future<void> retryDownload() async {
    await _startDownload(state.nativeLanguage);
  }
}
