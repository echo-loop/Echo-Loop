import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/audio_item.dart';
import '../../providers/audio_library_provider.dart';
import '../../utils/app_data_dir.dart';
import '../audio_import/audio_import_provider.dart';
import '../community_collections/download/community_download_notifier.dart';
import 'media_readiness.dart';
import 'media_readiness_resolver.dart';

part 'media_readiness_provider.g.dart';

AudioItem? _findItem(List<AudioItem> items, String audioItemId) {
  for (final item in items) {
    if (item.id == audioItemId) return item;
  }
  return null;
}

/// 本地媒体文件是否真实存在（仅对已记录音频路径的条目检查，避免列表行做 IO）。
///
/// 只依赖 `audioPath` 字符串：库刷新会重建条目对象，但路径不变时不应重新检查，
/// 否则计划页会在就绪与校验中之间来回切换。
@riverpod
Future<bool> localMediaFileExists(Ref ref, String audioItemId) async {
  final audioPath = ref.watch(
    audioLibraryProvider.select(
      (state) => _findItem(state.audioItems, audioItemId)?.audioPath,
    ),
  );
  if (audioPath == null || audioPath.isEmpty) return false;
  final dataDir = await getAppDataDirectory();
  return File(p.join(dataDir.path, audioPath)).exists();
}

/// 计划页使用的媒体就绪状态。唯一的「就绪」判断来源。
@riverpod
MediaReadiness mediaReadiness(Ref ref, String audioItemId) {
  final item = ref.watch(
    audioLibraryProvider.select(
      (state) => _findItem(state.audioItems, audioItemId),
    ),
  );
  if (item == null) return const MediaItemMissing();

  final community = ref.watch(communityDownloadProvider);
  final podcast = ref.watch(podcastDownloadControllerProvider);

  bool? fileExists;
  if (item.isAudioReady) {
    // 依赖变化时 valueOrNull 保留上一次结果，避免闪回「校验中」。
    final check = ref.watch(localMediaFileExistsProvider(audioItemId));
    fileExists = check.hasError ? false : check.valueOrNull;
  }

  return resolveMediaReadiness(
    item: item,
    communityDownload: community,
    podcastDownload: podcast,
    fileExists: fileExists,
  );
}

/// 列表行的下载进度快照；未在下载时为 null。列表行与计划页共用同一来源。
@riverpod
MediaDownloadSnapshot? mediaDownloadSnapshot(Ref ref, String audioItemId) {
  final item = ref.watch(
    audioLibraryProvider.select(
      (state) => _findItem(state.audioItems, audioItemId),
    ),
  );
  if (item == null) return null;
  return downloadSnapshotFor(
    item: item,
    community: ref.watch(communityDownloadProvider),
    podcast: ref.watch(podcastDownloadControllerProvider),
  );
}
