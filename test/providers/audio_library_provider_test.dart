import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/utils/app_data_dir.dart';

import '../database/dao_test.dart';
import '../helpers/mock_providers.dart';

void main() {
  group('AudioLibrary.togglePin', () {
    late ProviderContainer container;

    /// 创建带不同日期的音频项，方便验证排序
    AudioItem item(
      String id,
      String name,
      DateTime date, {
      bool pinned = false,
    }) {
      return createTestAudioItem(
        id: id,
        name: name,
        addedDate: date,
      ).copyWith(isPinned: pinned);
    }

    final jan1 = DateTime(2026, 1, 1);
    final jan5 = DateTime(2026, 1, 5);
    final jan10 = DateTime(2026, 1, 10);

    setUp(() {
      // 列表按日期倒序：jan10, jan5, jan1
      final initialItems = [
        item('a3', 'Audio 3', jan10),
        item('a2', 'Audio 2', jan5),
        item('a1', 'Audio 1', jan1),
      ];
      container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: initialItems)),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('togglePin 将未置顶音频切换为置顶', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.togglePin('a1');

      final items = container.read(audioLibraryProvider).audioItems;
      expect(items.firstWhere((i) => i.id == 'a1').isPinned, isTrue);
    });

    test('togglePin 将已置顶音频切换为未置顶', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.togglePin('a1');
      await notifier.togglePin('a1');

      final items = container.read(audioLibraryProvider).audioItems;
      expect(items.firstWhere((i) => i.id == 'a1').isPinned, isFalse);
    });

    test('togglePin 对不存在的 ID 无操作', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      final before = container.read(audioLibraryProvider).audioItems.length;

      await notifier.togglePin('non-existent');

      expect(container.read(audioLibraryProvider).audioItems.length, before);
    });

    test('togglePin 不改变列表顺序（排序由 UI 层 sortAudioItems 负责）', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      final idsBefore = container
          .read(audioLibraryProvider)
          .audioItems
          .map((i) => i.id)
          .toList();

      await notifier.togglePin('a1');

      final idsAfter = container
          .read(audioLibraryProvider)
          .audioItems
          .map((i) => i.id)
          .toList();
      // 顺序不变，只有 isPinned 字段变化
      expect(idsAfter, idsBefore);
    });
  });

  group('AudioLibrary.removeAudioItems', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_library_delete_');
      appDataDirectoryOverride = tempDir;
      final db = createTestDatabase();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          analyticsOverride(),
          usageOverride(),
          collectionListProvider.overrideWith(
            () => TestCollectionList(const CollectionState()),
          ),
          tagListProvider.overrideWith(() => TestTagList(const TagState())),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(const LearningProgressState()),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
    });

    tearDown(() async {
      appDataDirectoryOverride = null;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    AudioItem item(String id, String audioPath) {
      return createTestAudioItem(id: id, name: id, audioPath: audioPath);
    }

    test('保留仍被其他 AudioItem 引用的底层音频文件', () async {
      final file = File('${tempDir.path}/audios/imported/shared.m4a');
      await file.create(recursive: true);
      await file.writeAsString('audio');
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([
        item('remove', 'audios/imported/shared.m4a'),
        item('keep', 'audios/imported/shared.m4a'),
      ]);

      await notifier.removeAudioItems({'remove'});

      expect(await file.exists(), isTrue);
      expect(container.read(audioLibraryProvider).audioItems.map((e) => e.id), [
        'keep',
      ]);
    });

    test('待删集合覆盖共享路径所有引用时删除底层音频文件', () async {
      final file = File('${tempDir.path}/audios/imported/shared.m4a');
      await file.create(recursive: true);
      await file.writeAsString('audio');
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([
        item('remove-1', 'audios/imported/shared.m4a'),
        item('remove-2', 'audios/imported/shared.m4a'),
      ]);

      await notifier.removeAudioItems({'remove-1', 'remove-2'});

      expect(await file.exists(), isFalse);
      expect(container.read(audioLibraryProvider).audioItems, isEmpty);
    });

    test('删除音频时一并删除对应 waveform 文件', () async {
      final audioFile = File('${tempDir.path}/audios/imported/a.m4a');
      await audioFile.create(recursive: true);
      await audioFile.writeAsString('audio');
      final waveFile = File('${tempDir.path}/waveforms/wave-1.wave');
      await waveFile.create(recursive: true);
      await waveFile.writeAsString('wave');
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([item('wave-1', 'audios/imported/a.m4a')]);

      await notifier.removeAudioItems({'wave-1'});

      expect(await audioFile.exists(), isFalse);
      expect(await waveFile.exists(), isFalse);
    });
  });

  group('AudioLibrary.deleteDownloadedAudio', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_library_deldl_');
      appDataDirectoryOverride = tempDir;
      final db = createTestDatabase();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          analyticsOverride(),
          usageOverride(),
          collectionListProvider.overrideWith(
            () => TestCollectionList(const CollectionState()),
          ),
          tagListProvider.overrideWith(() => TestTagList(const TagState())),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(const LearningProgressState()),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
    });

    tearDown(() async {
      appDataDirectoryOverride = null;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('播客/导入：清空 audioPath 并删文件，item 保留，文件派生元数据一并清空', () async {
      final audioFile = File('${tempDir.path}/audios/imported/a.m4a');
      await audioFile.create(recursive: true);
      await audioFile.writeAsString('audio');
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([
        createTestAudioItem(
          id: 'dl-1',
          name: 'dl-1',
          audioPath: 'audios/imported/a.m4a',
        ).copyWith(
          podcastEpisodeGuid: 'guid-1',
          audioSha256: 'sha-x',
          originalAudioSha256: 'orig-x',
          contentStatus: AudioContentStatus.suspectEmpty,
        ),
      ]);

      await notifier.deleteDownloadedAudio('dl-1');

      // 文件已删、item 仍在、下载态与文件派生元数据全部清空
      expect(await audioFile.exists(), isFalse);
      final items = container.read(audioLibraryProvider).audioItems;
      expect(items.map((e) => e.id), ['dl-1']);
      final it = items.single;
      expect(it.audioPath, isNull);
      expect(it.isAudioReady, isFalse);
      expect(it.audioSha256, isNull);
      expect(it.originalAudioSha256, isNull);
      expect(it.contentStatus, isNull);
    });

    test('官方：保留 audioSha256（重下定位标识），清空其余文件派生元数据', () async {
      final audioFile = File('${tempDir.path}/audios/official/a.m4a');
      await audioFile.create(recursive: true);
      await audioFile.writeAsString('audio');
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([
        createTestAudioItem(
          id: 'dl-1',
          name: 'dl-1',
          audioPath: 'audios/official/a.m4a',
        ).copyWith(
          remoteAudioId: 'remote-1',
          audioSha256: 'sha-official',
          contentStatus: AudioContentStatus.ok,
        ),
      ]);

      await notifier.deleteDownloadedAudio('dl-1');

      expect(await audioFile.exists(), isFalse);
      final it = container.read(audioLibraryProvider).audioItems.single;
      expect(it.audioPath, isNull);
      // 官方 sha 保留，供重新下载定位 audios/official/<sha>.m4a
      expect(it.audioSha256, 'sha-official');
      expect(it.contentStatus, isNull);
    });

    test('保留字幕文件（字幕单独管理，不随删下载移除）', () async {
      final audioFile = File('${tempDir.path}/audios/official/a.m4a');
      await audioFile.create(recursive: true);
      await audioFile.writeAsString('audio');
      final transcriptFile = File('${tempDir.path}/transcripts/a.srt');
      await transcriptFile.create(recursive: true);
      await transcriptFile.writeAsString('srt');
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([
        createTestAudioItem(
          id: 'dl-1',
          name: 'dl-1',
          audioPath: 'audios/official/a.m4a',
          transcriptPath: 'transcripts/a.srt',
        ),
      ]);

      await notifier.deleteDownloadedAudio('dl-1');

      expect(await audioFile.exists(), isFalse);
      expect(await transcriptFile.exists(), isTrue);
    });

    test('一并删除对应 waveform 文件', () async {
      final audioFile = File('${tempDir.path}/audios/official/a.m4a');
      await audioFile.create(recursive: true);
      await audioFile.writeAsString('audio');
      final waveFile = File('${tempDir.path}/waveforms/dl-1.wave');
      await waveFile.create(recursive: true);
      await waveFile.writeAsString('wave');
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([
        createTestAudioItem(
          id: 'dl-1',
          name: 'dl-1',
          audioPath: 'audios/official/a.m4a',
        ),
      ]);

      await notifier.deleteDownloadedAudio('dl-1');

      expect(await waveFile.exists(), isFalse);
    });

    test('底层音频文件仍被其他条目引用时保留', () async {
      final file = File('${tempDir.path}/audios/official/shared.m4a');
      await file.create(recursive: true);
      await file.writeAsString('audio');
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([
        createTestAudioItem(
          id: 'dl-1',
          name: 'dl-1',
          audioPath: 'audios/official/shared.m4a',
        ),
        createTestAudioItem(
          id: 'keep',
          name: 'keep',
          audioPath: 'audios/official/shared.m4a',
        ),
      ]);

      await notifier.deleteDownloadedAudio('dl-1');

      // 文件被 keep 引用故保留；dl-1 仍在但 audioPath 置空
      expect(await file.exists(), isTrue);
      final items = container.read(audioLibraryProvider).audioItems;
      expect(items.firstWhere((e) => e.id == 'dl-1').audioPath, isNull);
      expect(
        items.firstWhere((e) => e.id == 'keep').audioPath,
        'audios/official/shared.m4a',
      );
    });

    test('未下载（audioPath 为空）时为 no-op', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.addAudioItems([
        createTestAudioItem(id: 'dl-1', name: 'dl-1', audioPath: ''),
      ]);

      await notifier.deleteDownloadedAudio('dl-1');

      expect(container.read(audioLibraryProvider).audioItems.length, 1);
    });
  });
}
