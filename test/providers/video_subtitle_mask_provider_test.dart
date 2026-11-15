import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/video_subtitle_mask_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const videoId = 'video-1';
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    final now = DateTime.utc(2026, 11, 15);
    for (final id in [videoId, 'video-2']) {
      await database
          .into(database.audioItems)
          .insert(
            AudioItemsCompanion.insert(
              id: id,
              name: id,
              addedDate: now,
              updatedAt: now,
              audioPath: Value('videos/$id.mp4'),
            ),
          );
    }
  });

  tearDown(() => database.close());

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 保持监听并等待读出，模拟页面持有该视频的遮罩状态。
  Future<VideoSubtitleMask> load(
    ProviderContainer container,
    String audioItemId,
  ) {
    container.listen(videoSubtitleMaskProvider(audioItemId), (_, _) {});
    return container.read(videoSubtitleMaskProvider(audioItemId).future);
  }

  Future<List<VideoSubtitleMaskRecord>> records() =>
      database.select(database.videoSubtitleMasks).get();

  test('没有记录时为关闭 + 底部居中默认位置，且读取不会写入记录', () async {
    final container = createContainer();

    expect(await load(container, videoId), const VideoSubtitleMask());
    expect(await records(), isEmpty);
  });

  test('用户操作后才写入记录，重新进入时按视频恢复', () async {
    final container = createContainer();
    await load(container, videoId);
    final notifier = container.read(
      videoSubtitleMaskProvider(videoId).notifier,
    );

    await notifier.toggleEnabled();
    await notifier.setRect(const Rect.fromLTWH(0.2, 0.6, 0.5, 0.25));

    final reloaded = createContainer();
    expect(
      await load(reloaded, videoId),
      const VideoSubtitleMask(
        enabled: true,
        rect: Rect.fromLTWH(0.2, 0.6, 0.5, 0.25),
      ),
    );
    // 其他视频不受影响，仍是默认设置且没有记录。
    expect(await load(reloaded, 'video-2'), const VideoSubtitleMask());
    expect((await records()).map((r) => r.audioItemId), [videoId]);
  });

  test('删除视频时遮罩记录随之级联清除', () async {
    final container = createContainer();
    await load(container, videoId);
    await container
        .read(videoSubtitleMaskProvider(videoId).notifier)
        .toggleEnabled();
    expect(await records(), hasLength(1));

    await database.audioItemDao.hardDelete(videoId);

    expect(await records(), isEmpty);
  });

  test('写库失败时不向外抛出，并回退到修改前的状态', () async {
    // 视频不存在于素材表，外键约束会拒绝写入。
    const missingId = 'missing-video';
    final container = createContainer();
    await load(container, missingId);

    await expectLater(
      container
          .read(videoSubtitleMaskProvider(missingId).notifier)
          .toggleEnabled(),
      completes,
    );

    expect(
      container.read(videoSubtitleMaskProvider(missingId)).value,
      const VideoSubtitleMask(),
    );
    expect(await records(), isEmpty);
  });

  test('已存位置含非法数值时保留开关并回退到默认位置', () async {
    await database.videoSubtitleMaskDao.save(
      VideoSubtitleMasksCompanion.insert(
        audioItemId: videoId,
        enabled: true,
        rectLeft: double.infinity,
        rectTop: 0.5,
        rectWidth: double.infinity,
        rectHeight: 0.2,
        updatedAt: DateTime.utc(2026, 11, 15),
      ),
    );
    final container = createContainer();

    expect(
      await load(container, videoId),
      const VideoSubtitleMask(enabled: true),
    );
  });
}
