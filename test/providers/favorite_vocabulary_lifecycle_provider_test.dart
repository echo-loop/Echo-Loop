import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_namespaces.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_schedule.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_subject_ref.dart';
import 'package:echo_loop/features/memory_scheduler/providers/memory_scheduler_providers.dart';
import 'package:echo_loop/providers/favorite_vocabulary_lifecycle_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('保存、重复收藏、删除和恢复会保留词汇与意群的调度状态', () async {
    AppLogger.instance.clear();
    final db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final lifecycle = container.read(favoriteVocabularyLifecycleProvider);
    final scheduler = container.read(memorySchedulerProvider);

    await lifecycle.saveWord(word: 'stadium');
    final word = await db.savedWordDao.getByWord('stadium');
    final wordSubject = MemorySubjectRef(
      namespace: kSavedWordOrPhraseNamespace,
      subjectId: word!.memorySubjectId!,
    );
    final wordSchedule = await scheduler.getSchedule(wordSubject);
    expect(wordSchedule?.status, MemoryScheduleStatus.active);

    await lifecycle.saveWord(word: 'stadium');
    final resavedWordSchedule = await scheduler.getSchedule(wordSubject);
    expect(resavedWordSchedule?.id, wordSchedule?.id);
    expect(resavedWordSchedule?.revision, wordSchedule?.revision);
    expect(resavedWordSchedule?.reviewCount, wordSchedule?.reviewCount);

    await lifecycle.removeWord('stadium');
    expect((await db.savedWordDao.getByWord('stadium'))!.deletedAt, isNotNull);
    expect(
      (await scheduler.getSchedule(wordSubject))!.status,
      MemoryScheduleStatus.archived,
    );

    await lifecycle.restoreWord('stadium');
    expect((await db.savedWordDao.getByWord('stadium'))!.deletedAt, isNull);
    expect(
      (await scheduler.getSchedule(wordSubject))!.status,
      MemoryScheduleStatus.active,
    );

    await lifecycle.saveSenseGroup(
      phraseText: 'take into account',
      displayText: 'take into account',
    );
    final group = await db.savedSenseGroupDao.getByPhraseText(
      'take into account',
    );
    final groupSubject = MemorySubjectRef(
      namespace: kSavedSenseGroupNamespace,
      subjectId: group!.memorySubjectId!,
    );
    final groupSchedule = await scheduler.getSchedule(groupSubject);
    expect(groupSchedule?.status, MemoryScheduleStatus.active);

    await lifecycle.saveSenseGroup(
      phraseText: 'take into account',
      displayText: 'take into account',
    );
    final resavedGroupSchedule = await scheduler.getSchedule(groupSubject);
    expect(resavedGroupSchedule?.id, groupSchedule?.id);
    expect(resavedGroupSchedule?.revision, groupSchedule?.revision);
    expect(resavedGroupSchedule?.reviewCount, groupSchedule?.reviewCount);

    await lifecycle.removeSenseGroup('take into account');
    expect(
      (await db.savedSenseGroupDao.getByPhraseText(
        'take into account',
      ))!.deletedAt,
      isNotNull,
    );
    expect(
      (await scheduler.getSchedule(groupSubject))!.status,
      MemoryScheduleStatus.archived,
    );

    await lifecycle.restoreSenseGroup('take into account');
    expect(
      (await db.savedSenseGroupDao.getByPhraseText(
        'take into account',
      ))!.deletedAt,
      isNull,
    );
    expect(
      (await scheduler.getSchedule(groupSubject))!.status,
      MemoryScheduleStatus.active,
    );

    final lifecycleLogs = AppLogger.instance.entries
        .map((entry) => entry.message)
        .toList();
    expect(
      lifecycleLogs.any(
        (message) => message.startsWith(
          'event=transaction_started operation=save entity=word',
        ),
      ),
      isTrue,
    );
    expect(
      lifecycleLogs.any(
        (message) => message.startsWith('event=schedule_ensured'),
      ),
      isTrue,
    );
    expect(
      lifecycleLogs.any(
        (message) => message.startsWith('event=schedule_archived'),
      ),
      isTrue,
    );
    expect(
      lifecycleLogs.any(
        (message) => message.startsWith('event=schedule_restored'),
      ),
      isTrue,
    );
    expect(
      lifecycleLogs.every((message) => !message.contains('stadium')),
      isTrue,
      reason: '生命周期日志不能记录用户收藏的原文',
    );
    expect(
      lifecycleLogs.every((message) => !message.contains('take into account')),
      isTrue,
      reason: '生命周期日志不能记录用户收藏的意群原文',
    );
  });

  test('建立单词调度失败时收藏写入会一起回滚', () async {
    AppLogger.instance.clear();
    final db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await db.customStatement('''
      CREATE TRIGGER fail_schedule_insert
      BEFORE INSERT ON memory_schedules
      BEGIN SELECT RAISE(ABORT, 'forced schedule insert failure'); END
    ''');

    final lifecycle = container.read(favoriteVocabularyLifecycleProvider);
    await expectLater(lifecycle.saveWord(word: 'stadium'), throwsA(anything));

    expect(await db.savedWordDao.getByWord('stadium'), isNull);
    final lifecycleLogs = AppLogger.instance.entries
        .map((entry) => entry.message)
        .toList();
    expect(
      lifecycleLogs.any(
        (message) => message.startsWith(
          'event=transaction_rolled_back operation=save entity=word',
        ),
      ),
      isTrue,
    );
    expect(
      lifecycleLogs.any(
        (message) =>
            message.contains('stage=schedule_restore_or_ensure') &&
            message.contains('errorType='),
      ),
      isTrue,
      reason: '回滚日志应包含失败阶段与异常类型',
    );
    expect(
      lifecycleLogs.every((message) => !message.contains('stadium')),
      isTrue,
      reason: '异常日志不能记录用户收藏的原文或数据库参数',
    );
  });

  test('建立意群调度失败时收藏写入会一起回滚', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await db.customStatement('''
      CREATE TRIGGER fail_schedule_insert
      BEFORE INSERT ON memory_schedules
      BEGIN SELECT RAISE(ABORT, 'forced schedule insert failure'); END
    ''');

    final lifecycle = container.read(favoriteVocabularyLifecycleProvider);
    await expectLater(
      lifecycle.saveSenseGroup(
        phraseText: 'take into account',
        displayText: 'take into account',
      ),
      throwsA(anything),
    );

    expect(
      await db.savedSenseGroupDao.getByPhraseText('take into account'),
      isNull,
    );
  });

  test('删除收藏失败时已归档的调度会随事务回滚', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final lifecycle = container.read(favoriteVocabularyLifecycleProvider);
    final scheduler = container.read(memorySchedulerProvider);
    await lifecycle.saveWord(word: 'stadium');
    final word = await db.savedWordDao.getByWord('stadium');
    final subject = MemorySubjectRef(
      namespace: kSavedWordOrPhraseNamespace,
      subjectId: word!.memorySubjectId!,
    );
    await db.customStatement('''
      CREATE TRIGGER fail_word_removal
      BEFORE UPDATE OF deleted_at ON saved_words
      WHEN NEW.deleted_at IS NOT NULL
      BEGIN SELECT RAISE(ABORT, 'forced content removal failure'); END
    ''');
    await db.customStatement('''
      CREATE TRIGGER fail_schedule_compensation
      BEFORE UPDATE ON memory_schedules
      WHEN NEW.status = 'active'
      BEGIN SELECT RAISE(ABORT, 'forced schedule compensation failure'); END
    ''');

    AppLogger.instance.clear();
    await expectLater(lifecycle.removeWord('stadium'), throwsA(anything));

    expect((await db.savedWordDao.getByWord('stadium'))!.deletedAt, isNull);
    expect(
      (await scheduler.getSchedule(subject))!.status,
      MemoryScheduleStatus.active,
    );
    final lifecycleLogs = AppLogger.instance.entries
        .map((entry) => entry.message)
        .toList();
    expect(
      lifecycleLogs.any(
        (message) =>
            message.startsWith(
              'event=transaction_rolled_back operation=remove entity=word',
            ) &&
            message.contains('stage=content_remove'),
      ),
      isTrue,
    );
    expect(
      lifecycleLogs.every((message) => !message.contains('stadium')),
      isTrue,
    );
  });

  test('恢复收藏失败时内容恢复会随事务回滚', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final lifecycle = container.read(favoriteVocabularyLifecycleProvider);
    final scheduler = container.read(memorySchedulerProvider);
    await lifecycle.saveWord(word: 'stadium');
    await lifecycle.removeWord('stadium');
    final word = await db.savedWordDao.getByWord('stadium');
    final subject = MemorySubjectRef(
      namespace: kSavedWordOrPhraseNamespace,
      subjectId: word!.memorySubjectId!,
    );
    await db.customStatement('''
      CREATE TRIGGER fail_schedule_restore
      BEFORE UPDATE ON memory_schedules
      WHEN NEW.status = 'active'
      BEGIN SELECT RAISE(ABORT, 'forced schedule restore failure'); END
    ''');
    await db.customStatement('''
      CREATE TRIGGER fail_word_restore_compensation
      BEFORE UPDATE OF deleted_at ON saved_words
      WHEN NEW.deleted_at IS NOT NULL
      BEGIN SELECT RAISE(ABORT, 'forced content compensation failure'); END
    ''');

    AppLogger.instance.clear();
    await expectLater(lifecycle.restoreWord('stadium'), throwsA(anything));

    expect((await db.savedWordDao.getByWord('stadium'))!.deletedAt, isNotNull);
    expect(
      (await scheduler.getSchedule(subject))!.status,
      MemoryScheduleStatus.archived,
    );
    final lifecycleLogs = AppLogger.instance.entries
        .map((entry) => entry.message)
        .toList();
    expect(
      lifecycleLogs.any(
        (message) =>
            message.startsWith(
              'event=transaction_rolled_back operation=restore entity=word',
            ) &&
            message.contains('stage=schedule_restore_or_ensure'),
      ),
      isTrue,
    );
    expect(
      lifecycleLogs.every((message) => !message.contains('stadium')),
      isTrue,
    );
  });
}
