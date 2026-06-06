import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import '../utils/app_data_dir.dart';
import 'package:path/path.dart' as p;

import '../data/demo_content.dart';
import '../database/app_database.dart';
import '../database/enums.dart';
import '../models/learning_plan.dart' show kLatestPlanVersions;
import '../models/study_stage.dart';

/// 演示数据种子服务
///
/// 负责在 `echo_loop_demo.db` 中写入精心设计的演示数据，
/// 以及在 documents/demo/ 目录下生成 SRT 字幕文件。
class DemoDataSeeder {
  final AppDatabase db;

  DemoDataSeeder(this.db);

  /// 仅当演示数据库为空时执行 seed。
  Future<void> seedIfEmpty() async {
    final count = await (db.select(db.audioItems)..limit(1)).get();
    if (count.isNotEmpty) return;
    await seed();
  }

  /// 将所有演示数据写入数据库（事务保证原子性）。
  Future<void> seed() async {
    final now = DateTime.now();

    // 媒体文件创建在事务外（文件系统操作）
    await _createMediaFiles();

    await db.transaction(() async {
      // 1. 插入合集
      await db
          .into(db.collections)
          .insert(
            CollectionsCompanion.insert(
              id: demoCollectionId,
              name: 'Demo Content',
              createdDate: now.subtract(const Duration(days: 14)),
              updatedAt: now,
            ),
          );

      // 2. 插入 5 个 AudioItem + CollectionAudioItem + LearningProgress
      for (var i = 0; i < demoAudios.length; i++) {
        final audio = demoAudios[i];
        final addedDate = now.subtract(Duration(days: 14 - i * 2));

        await db
            .into(db.audioItems)
            .insert(
              AudioItemsCompanion.insert(
                id: audio.id,
                name: audio.title,
                audioPath: Value('demo/audio_${i + 1}.wav'),
                // 字幕内容入 DB 列，transcriptPath 留空
                transcriptSrt: Value(audio.toSrt()),
                addedDate: addedDate,
                totalDuration: Value(audio.durationSeconds),
                sentenceCount: Value(audio.sentenceCount),
                wordCount: Value(audio.wordCount),
                transcriptSource: const Value(0), // local
                updatedAt: now,
              ),
            );

        // 合集关联
        await db
            .into(db.collectionAudioItems)
            .insert(
              CollectionAudioItemsCompanion.insert(
                collectionId: demoCollectionId,
                audioItemId: audio.id,
                sortOrder: Value(i),
                addedAt: addedDate,
              ),
            );

        // 学习进度
        final firstLearnCompleted = audio.firstLearnCompletedDaysAgo != null
            ? now.subtract(Duration(days: audio.firstLearnCompletedDaysAgo!))
            : null;
        final lastStageCompleted = audio.lastStageCompletedDaysAgo != null
            ? now.subtract(Duration(days: audio.lastStageCompletedDaysAgo!))
            : null;

        // 已练习过各 review 阶段的 demo 音频走 v1 plan：
        // - review0 已完成 → demo 当前在 review1+
        // - review1+ 已练习 → 对应 stage 在 v1
        // baseline = kLatestPlanVersions，按 demo 的 currentStage 推算哪些 stage
        // 应当锁定 v1（已完成）。stage_completions 里的历史与 v1 plan 对齐。
        const reviewStages = [
          LearningStage.review0,
          LearningStage.review1,
          LearningStage.review2,
          LearningStage.review4,
          LearningStage.review7,
          LearningStage.review14,
          LearningStage.review28,
        ];
        final currentStageEnum = LearningStage.fromKey(audio.currentStage);
        final planVersions = <LearningStage, int>{
          for (final e in kLatestPlanVersions.entries) e.key: e.value,
        };
        for (final s in reviewStages) {
          // demo 当前 stage 严格大于 s → s 已完成 → 锁 v1
          if (currentStageEnum.index > s.index) {
            planVersions[s] = 1;
          }
        }
        final planVersionsJson = jsonEncode({
          for (final e in planVersions.entries) e.key.key: e.value,
        });

        await db
            .into(db.learningProgresses)
            .insert(
              LearningProgressesCompanion.insert(
                audioItemId: audio.id,
                currentStage: Value(audio.currentStage),
                currentSubStage: Value(audio.currentSubStage),
                difficulty: Value(audio.difficulty),
                firstLearnCompletedAt: Value(firstLearnCompleted),
                lastStageCompletedAt: Value(lastStageCompleted),
                currentStageStartedAt: Value(lastStageCompleted ?? addedDate),
                blindListenPassCount: Value(
                  audio.currentStage == 'firstLearn' ? 1 : 3,
                ),
                shadowingSentenceIndex: Value(audio.shadowingSentenceIndex),
                updatedAt: now,
                planVersionsJson: Value(planVersionsJson),
              ),
            );
      }

      // 3. 插入阶段完成历史
      await _seedStageCompletions(now);

      // 4. 插入书签
      await _seedBookmarks(now);

      // 5. 插入收藏单词
      await _seedSavedWords(now);

      // 6. 插入已学习词形
      await _seedLearnedWordForms(now);

      // 7. 插入每日学习记录
      await _seedDailyStudyRecords(now);

      // 8. 插入收藏意群
      await _seedSavedSenseGroups(now);

      // 9. 插入每日分阶段学习记录
      await _seedDailyStageStudyRecords(now);
    });
  }

  /// 创建 SRT 字幕文件和静音 WAV 音频文件
  Future<void> _createMediaFiles() async {
    final docsDir = await getAppDataDirectory();
    final demoDir = Directory(p.join(docsDir.path, 'demo'));
    if (!demoDir.existsSync()) {
      await demoDir.create(recursive: true);
    }

    for (var i = 0; i < demoAudios.length; i++) {
      // 字幕内容存 DB transcript_srt 列，不再写 SRT 文件；仅需音频文件。
      final wavPath = p.join(demoDir.path, 'audio_${i + 1}.wav');
      await File(
        wavPath,
      ).writeAsBytes(_buildSilentWav(demoAudios[i].durationSeconds));
    }
  }

  /// 生成指定时长的静音 WAV 文件字节。
  ///
  /// 格式：16-bit PCM, mono, 8000 Hz（极小体积）。
  static Uint8List _buildSilentWav(int durationSeconds) {
    const sampleRate = 8000;
    const bitsPerSample = 16;
    const numChannels = 1;
    const byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = byteRate * durationSeconds;
    final fileSize = 36 + dataSize; // 总文件大小 - 8

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    void writeString(String s) {
      for (var i = 0; i < s.length; i++) {
        buffer.setUint8(offset++, s.codeUnitAt(i));
      }
    }

    void writeUint32(int v) {
      buffer.setUint32(offset, v, Endian.little);
      offset += 4;
    }

    void writeUint16(int v) {
      buffer.setUint16(offset, v, Endian.little);
      offset += 2;
    }

    writeString('RIFF');
    writeUint32(fileSize);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16); // subchunk1 size
    writeUint16(1); // PCM format
    writeUint16(numChannels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeString('data');
    writeUint32(dataSize);
    // PCM data 全部为 0（静音），ByteData 默认初始化为 0

    return buffer.buffer.asUint8List();
  }

  /// 插入阶段完成历史记录
  Future<void> _seedStageCompletions(DateTime now) async {
    for (var i = 0; i < demoAudios.length; i++) {
      final completions = generateStageCompletions(i);
      for (final (stage, subStage, daysAgo) in completions) {
        final completedAt = now.subtract(Duration(days: daysAgo));
        await db
            .into(db.stageCompletions)
            .insert(
              StageCompletionsCompanion.insert(
                audioItemId: demoAudios[i].id,
                stage: stage,
                subStage: subStage,
                completedAt: completedAt,
                durationMs: Value(_estimateDurationMs(subStage)),
              ),
            );
      }
    }
  }

  /// 插入书签（收藏句子）
  Future<void> _seedBookmarks(DateTime now) async {
    for (var i = 0; i < demoAudios.length; i++) {
      final audio = demoAudios[i];
      for (final idx in audio.bookmarkIndices) {
        final sentence = audio.sentences[idx];
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                audioItemId: audio.id,
                sentenceIndex: idx,
                sentenceText: sentence.text,
                startTime: sentence.startTime,
                endTime: sentence.endTime,
                createdAt: now.subtract(Duration(days: 10 - i)),
                updatedAt: now,
              ),
            );
      }
    }
  }

  /// 插入收藏单词
  Future<void> _seedSavedWords(DateTime now) async {
    for (var i = 0; i < demoSavedWords.length; i++) {
      final word = demoSavedWords[i];
      final audio = demoAudios[word.audioIndex];
      final sentence = audio.sentences[word.sentenceIndex];

      await db
          .into(db.savedWords)
          .insert(
            SavedWordsCompanion.insert(
              word: word.word,
              audioItemId: Value(audio.id),
              sentenceIndex: Value(word.sentenceIndex),
              sentenceText: Value(sentence.text),
              sentenceStartMs: Value((sentence.startTime * 1000).round()),
              sentenceEndMs: Value((sentence.endTime * 1000).round()),
              practiceCount: Value(i < 10 ? 3 : (i < 18 ? 1 : 0)),
              totalStudyMs: Value(i < 10 ? 24000 : (i < 18 ? 8000 : 0)),
              viewedBack: Value(i < 18),
              lastPracticedAt: Value(
                i < 18 ? now.subtract(Duration(days: i ~/ 3)) : null,
              ),
              createdAt: now.subtract(Duration(days: 12 - (i ~/ 2))),
              updatedAt: now,
            ),
          );
    }
  }

  /// 从转录文本中提取已学习词形并插入
  Future<void> _seedLearnedWordForms(DateTime now) async {
    final allWords = <String>{};

    // 从已学习的音频（1-4 全部句子，5 前 6 句）提取词汇
    for (var i = 0; i < demoAudios.length; i++) {
      final audio = demoAudios[i];
      final sentenceLimit = i == 4 ? 6 : audio.sentences.length;
      for (var j = 0; j < sentenceLimit; j++) {
        final words = audio.sentences[j].text
            .replaceAll(RegExp("[^\\w\\s'-]"), '')
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((w) => w.length > 1);
        allWords.addAll(words);
      }
    }

    // 按字母排序后插入，分批避免性能问题
    final sortedWords = allWords.toList()..sort();
    for (var i = 0; i < sortedWords.length; i++) {
      final daysAgo = (i * 13 ~/ sortedWords.length); // 分散到 13 天
      await db
          .into(db.learnedWordForms)
          .insert(
            LearnedWordFormsCompanion.insert(
              wordForm: sortedWords[i],
              firstLearnedAt: now.subtract(Duration(days: daysAgo)),
            ),
          );
    }
  }

  /// 插入 14 天每日学习记录
  Future<void> _seedDailyStudyRecords(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);

    for (final (daysAgo, totalSec, inputSec, outputSec, inputW, outputW)
        in demoDailyRecords) {
      final date = today.subtract(Duration(days: daysAgo));
      await db
          .into(db.dailyStudyRecords)
          .insert(
            DailyStudyRecordsCompanion.insert(
              date: date,
              studyTimeSeconds: Value(totalSec),
              inputWords: Value(inputW),
              outputWords: Value(outputW),
              inputTimeSeconds: Value(inputSec),
              outputTimeSeconds: Value(outputSec),
            ),
          );
    }
  }

  /// 插入收藏意群
  Future<void> _seedSavedSenseGroups(DateTime now) async {
    for (var i = 0; i < demoSavedSenseGroups.length; i++) {
      final sg = demoSavedSenseGroups[i];
      final audio = demoAudios[sg.audioIndex];
      final sentence = audio.sentences[sg.sentenceIndex];
      final sentenceStartMs = (sentence.startTime * 1000).round();
      final sentenceEndMs = (sentence.endTime * 1000).round();

      await db
          .into(db.savedSenseGroups)
          .insert(
            SavedSenseGroupsCompanion.insert(
              phraseText: sg.displayText.toLowerCase().trim(),
              displayText: sg.displayText,
              audioItemId: Value(audio.id),
              sentenceIndex: Value(sg.sentenceIndex),
              sentenceText: Value(sentence.text),
              sentenceStartMs: Value(sentenceStartMs),
              sentenceEndMs: Value(sentenceEndMs),
              groupStartMs: Value(sentenceStartMs + sg.offsetStartMs),
              groupEndMs: Value(sentenceStartMs + sg.offsetEndMs),
              practiceCount: Value(i < 5 ? 3 : (i < 8 ? 1 : 0)),
              totalStudyMs: Value(i < 5 ? 18000 : (i < 8 ? 6000 : 0)),
              viewedBack: Value(i < 8),
              lastPracticedAt: Value(
                i < 8 ? now.subtract(Duration(days: i ~/ 2)) : null,
              ),
              createdAt: now.subtract(Duration(days: 10 - i)),
              updatedAt: now,
            ),
          );
    }
  }

  /// 插入每日分阶段学习记录
  Future<void> _seedDailyStageStudyRecords(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);

    for (final (daysAgo, stageIndex, studyTime, inputTime, outputTime)
        in demoDailyStageRecords) {
      final date = today.subtract(Duration(days: daysAgo));
      await db
          .into(db.dailyStageStudyRecords)
          .insert(
            DailyStageStudyRecordsCompanion.insert(
              date: date,
              stage: StudyStage.values[stageIndex],
              studyTimeSeconds: Value(studyTime),
              inputTimeSeconds: Value(inputTime),
              outputTimeSeconds: Value(outputTime),
            ),
          );
    }
  }

  /// 根据子步骤估算耗时（毫秒），用于 stage_completions 记录
  int _estimateDurationMs(String subStage) {
    return switch (subStage) {
      'blindListen' => 120000, // 2 min
      'intensiveListen' => 300000, // 5 min
      'listenAndRepeat' => 360000, // 6 min
      'retell' => 240000, // 4 min
      'reviewDifficultPractice' => 180000, // 3 min
      'reviewRetellParagraph' => 180000, // 3 min
      _ => 120000,
    };
  }

  // -------------------------------------------------------------------------
  // 清理演示数据
  // -------------------------------------------------------------------------

  /// 删除演示数据库文件和 SRT 文件。
  ///
  /// 调用前应先切换回生产数据库并关闭演示数据库连接。
  static Future<void> cleanupFiles() async {
    final docsDir = await getAppDataDirectory();

    // 删除 demo SRT 目录
    final demoDir = Directory(p.join(docsDir.path, 'demo'));
    if (await demoDir.exists()) {
      await demoDir.delete(recursive: true);
    }

    // 删除演示数据库文件
    final dbFile = File(p.join(docsDir.path, 'echo_loop_demo.db'));
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  }
}
