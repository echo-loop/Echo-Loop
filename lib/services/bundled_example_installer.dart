import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../utils/app_data_dir.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// 内置示例内容安装器
///
/// 首次启动时将 assets/demo/ 中的示例音频复制到 Documents 目录，
/// 并在数据库中创建 "Examples" 合集和对应的音频条目（无字幕，引导用户生成）。
/// 通过 SharedPreferences 版本标记确保幂等，并支持替换旧内置示例。
class BundledExampleInstaller {
  static const _installedKey = 'bundled_example_installed';
  static const _installedVersionKey = 'bundled_example_installed_version';
  static const _currentVersion = 2;

  /// 旧版固定 ID（English in a Minute），用于 v1→v2 迁移清理。
  static const _legacyAudioId = 'bundled-example-audio-0001';
  static const _legacyAudioRelPath =
      'audios/English in a Minute - On the Ball.m4a';

  /// 固定合集 ID（保证幂等）
  static const collectionId = 'bundled-example-collection-0001';

  static const _examples = <_BundledExample>[
    _BundledExample(
      id: 'bundled-example-audio-a1',
      title: 'CEFR A1 - Book a table',
      assetPath: 'assets/demo/CEFR A1 - Book a table.m4a',
      audioRelPath: 'audios/CEFR A1 - Book a table.m4a',
    ),
    _BundledExample(
      id: 'bundled-example-audio-a2',
      title: 'CEFR A2 - Invitation to a party',
      assetPath: 'assets/demo/CEFR A2 - Invitation to a party.m4a',
      audioRelPath: 'audios/CEFR A2 - Invitation to a party.m4a',
    ),
    _BundledExample(
      id: 'bundled-example-audio-b1',
      title: 'CEFR B1 - Work-life balance',
      assetPath: 'assets/demo/CEFR B1 - Work-life balance.m4a',
      audioRelPath: 'audios/CEFR B1 - Work-life balance.m4a',
    ),
    _BundledExample(
      id: 'bundled-example-audio-b2',
      title: 'CEFR B2 - Incentives',
      assetPath: 'assets/demo/CEFR B2 - Incentives.m4a',
      audioRelPath: 'audios/CEFR B2 - Incentives.m4a',
    ),
    _BundledExample(
      id: 'bundled-example-audio-c1',
      title: 'CEFR C1 - Rent a house',
      assetPath: 'assets/demo/CEFR C1 - Rent a house.m4a',
      audioRelPath: 'audios/CEFR C1 - Rent a house.m4a',
    ),
    _BundledExample(
      id: 'bundled-example-audio-c2',
      title: 'CEFR C2 - Conducting yourself',
      assetPath: 'assets/demo/CEFR C2 - Conducting yourself.m4a',
      audioRelPath: 'audios/CEFR C2 - Conducting yourself.m4a',
    ),
  ];

  final AppDatabase db;
  final SharedPreferences prefs;
  final AssetBundle assetBundle;

  BundledExampleInstaller(this.db, this.prefs, {AssetBundle? assetBundle})
    : assetBundle = assetBundle ?? rootBundle;

  /// 首次启动或示例版本升级时安装示例内容，已是最新版本则跳过。
  Future<void> installOnFirstLaunch() async {
    if ((prefs.getInt(_installedVersionKey) ?? 0) >= _currentVersion) return;

    final legacyItem = await (db.select(
      db.audioItems,
    )..where((t) => t.id.equals(_legacyAudioId))).getSingleOrNull();

    final existing = await (db.select(db.audioItems)..limit(1)).get();
    final shouldInstall = existing.isEmpty || legacyItem != null;

    if (shouldInstall) {
      await _copyAssetFiles();
      await db.transaction(() async {
        if (legacyItem != null) {
          await _deleteLegacyDatabaseRecords();
        }
        await _insertDatabaseRecords();
      });

      if (legacyItem != null) {
        await _deleteLegacyAudioFile();
      }
    }

    await prefs.setInt(_installedVersionKey, _currentVersion);
    await prefs.setBool(_installedKey, true);
  }

  /// 将 asset 文件复制到应用数据目录
  Future<void> _copyAssetFiles() async {
    final docsDir = await getAppDataDirectory();
    final audiosDir = Directory(p.join(docsDir.path, 'audios'));
    if (!audiosDir.existsSync()) {
      await audiosDir.create(recursive: true);
    }

    // 仅复制音频文件，字幕由用户通过 AI 转录生成。
    for (final example in _examples) {
      final audioData = await assetBundle.load(example.assetPath);
      final audioFile = File(p.join(docsDir.path, example.audioRelPath));
      await audioFile.writeAsBytes(
        audioData.buffer.asUint8List(
          audioData.offsetInBytes,
          audioData.lengthInBytes,
        ),
        flush: true,
      );
    }
  }

  /// 在数据库中创建合集和音频条目
  Future<void> _insertDatabaseRecords() async {
    final now = DateTime.now();

    // 创建或恢复 "Examples" 合集
    await db
        .into(db.collections)
        .insertOnConflictUpdate(
          CollectionsCompanion.insert(
            id: collectionId,
            name: 'Examples',
            createdDate: now,
            updatedAt: now,
            deletedAt: const Value(null),
          ),
        );

    for (var i = 0; i < _examples.length; i++) {
      final example = _examples[i];
      // 创建音频条目（无字幕，引导用户通过 AI 转录生成）
      final existingAudio = await (db.select(
        db.audioItems,
      )..where((t) => t.id.equals(example.id))).getSingleOrNull();
      if (existingAudio == null) {
        await db
            .into(db.audioItems)
            .insert(
              AudioItemsCompanion.insert(
                id: example.id,
                name: example.title,
                audioPath: Value(example.audioRelPath),
                addedDate: now,
                updatedAt: now,
              ),
            );
      } else {
        // 版本标记丢失时可能重复进入安装流程；只恢复示例的基础元数据，
        // 不覆盖用户已通过 AI 转录生成的字幕和词级时间戳。
        await (db.update(
          db.audioItems,
        )..where((t) => t.id.equals(example.id))).write(
          AudioItemsCompanion(
            name: Value(example.title),
            audioPath: Value(example.audioRelPath),
            updatedAt: Value(now),
            deletedAt: const Value(null),
          ),
        );
      }

      // 关联音频到合集
      await db
          .into(db.collectionAudioItems)
          .insertOnConflictUpdate(
            CollectionAudioItemsCompanion.insert(
              collectionId: collectionId,
              audioItemId: example.id,
              sortOrder: Value(i),
              addedAt: now,
            ),
          );
    }
  }

  Future<void> _deleteLegacyDatabaseRecords() async {
    const ids = {_legacyAudioId};

    // 先清除 SET NULL 表里的冗余上下文，避免 hard delete 后只剩旧句子信息。
    await (db.update(
      db.savedWords,
    )..where((t) => t.audioItemId.isIn(ids))).write(
      const SavedWordsCompanion(
        audioItemId: Value(null),
        sentenceIndex: Value(null),
        sentenceText: Value(null),
        sentenceStartMs: Value(null),
        sentenceEndMs: Value(null),
      ),
    );
    await (db.update(
      db.savedSenseGroups,
    )..where((t) => t.audioItemId.isIn(ids))).write(
      const SavedSenseGroupsCompanion(
        audioItemId: Value(null),
        sentenceIndex: Value(null),
        sentenceText: Value(null),
        sentenceStartMs: Value(null),
        sentenceEndMs: Value(null),
        groupStartMs: Value(null),
        groupEndMs: Value(null),
      ),
    );

    // 显式清理所有旧 audio 外键引用；生产 DB 也开启 FK cascade，这里是双保险。
    await (db.delete(db.collectionAudioItems)..where(
          (t) =>
              t.collectionId.equals(collectionId) &
              t.audioItemId.equals(_legacyAudioId),
        ))
        .go();
    await (db.delete(
      db.bookmarks,
    )..where((t) => t.audioItemId.equals(_legacyAudioId))).go();
    await (db.delete(
      db.learningProgresses,
    )..where((t) => t.audioItemId.equals(_legacyAudioId))).go();
    await (db.delete(
      db.stageCompletions,
    )..where((t) => t.audioItemId.equals(_legacyAudioId))).go();
    await (db.delete(
      db.playbackStates,
    )..where((t) => t.audioItemId.equals(_legacyAudioId))).go();
    await (db.delete(
      db.audioItemTags,
    )..where((t) => t.audioItemId.equals(_legacyAudioId))).go();
    await (db.delete(
      db.audioItems,
    )..where((t) => t.id.equals(_legacyAudioId))).go();
  }

  Future<void> _deleteLegacyAudioFile() async {
    final docsDir = await getAppDataDirectory();
    final file = File(p.join(docsDir.path, _legacyAudioRelPath));
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}

class _BundledExample {
  final String id;
  final String title;
  final String assetPath;
  final String audioRelPath;

  const _BundledExample({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.audioRelPath,
  });
}
