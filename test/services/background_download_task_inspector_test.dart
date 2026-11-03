import 'package:background_downloader/background_downloader.dart';
import 'package:echo_loop/services/background_download_task_inspector.dart';
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFileDownloader extends Mock implements FileDownloader {}

class _MockDatabase extends Mock implements Database {}

void main() {
  late _MockFileDownloader downloader;
  late _MockDatabase database;
  late DownloadTaskInspector inspector;

  setUp(() {
    downloader = _MockFileDownloader();
    database = _MockDatabase();
    when(() => downloader.database).thenReturn(database);
    inspector = DownloadTaskInspector(downloader: downloader);
  });

  DownloadTask taskWithId(
    String taskId, {
    String fileName = 'a.mp3',
    String displayName = '',
    DateTime? creationTime,
  }) {
    return DownloadTask(
      taskId: taskId,
      url: 'https://example.com/$fileName?token=secret',
      filename: fileName,
      group: kUserFilesDownloadGroup,
      retries: 2,
      metaData: 'audio:$taskId',
      displayName: displayName,
      creationTime: creationTime,
    );
  }

  test('lists tasks newest first by creation time', () async {
    final base = DateTime(2026, 11, 1);
    when(() => database.allRecords(group: kUserFilesDownloadGroup)).thenAnswer(
      (_) async => [
        TaskRecord(
          taskWithId('oldest', creationTime: base),
          TaskStatus.complete,
          1,
          100,
        ),
        TaskRecord(
          taskWithId(
            'newest',
            creationTime: base.add(const Duration(hours: 2)),
          ),
          TaskStatus.running,
          0.5,
          100,
        ),
        TaskRecord(
          taskWithId(
            'middle',
            creationTime: base.add(const Duration(hours: 1)),
          ),
          TaskStatus.failed,
          -1,
          -1,
        ),
      ],
    );

    final infos = await inspector.list();

    expect(infos.map((info) => info.taskId), ['newest', 'middle', 'oldest']);
  });

  test('maps records to view models without leaking the full url', () async {
    final failedTask = taskWithId('failed', fileName: 'b.mp3');
    when(() => database.allRecords(group: kUserFilesDownloadGroup)).thenAnswer(
      (_) async => [
        TaskRecord(taskWithId('running'), TaskStatus.running, 0.5, 100),
        TaskRecord(
          failedTask,
          TaskStatus.failed,
          -1,
          -1,
          TaskFileSystemException(
            'ClientException https://example.com/b.mp3?token=secret',
          ),
        ),
      ],
    );

    final infos = await inspector.list();

    expect(infos[0].taskId, 'running');
    expect(infos[0].resourceKey, 'audio:running');
    expect(infos[0].displayName, 'a.mp3');
    expect(infos[0].host, 'example.com');
    expect(infos[0].progress, 0.5);
    expect(infos[0].receivedBytes, 50);
    expect(infos[0].expectedBytes, 100);
    expect(infos[0].retriesRemaining, 2);
    expect(infos[0].isFinished, isFalse);

    // 负数进度是插件哨兵，不能当作真实进度展示。
    expect(infos[1].progress, isNull);
    expect(infos[1].receivedBytes, isNull);
    expect(infos[1].isFinished, isTrue);
    expect(infos[1].errorDescription, isNot(contains('token=secret')));
    expect(infos[1].errorDescription, contains('<url>'));
  });

  test(
    'shows the human-readable display name instead of the stored file name',
    () async {
      when(() => database.allRecords(group: kUserFilesDownloadGroup))
          .thenAnswer(
            (_) async => [
              TaskRecord(
                taskWithId(
                  'named',
                  fileName: '77c44dfa-9652-426e.mp3',
                  displayName: 'Lesson 1',
                ),
                TaskStatus.complete,
                1,
                100,
              ),
            ],
          );

      final infos = await inspector.list();

      expect(infos.single.displayName, 'Lesson 1');
    },
  );

  test('remove cancels the task before deleting its record', () async {
    when(() => downloader.cancelTaskWithId('task-1'))
        .thenAnswer((_) async => true);
    when(() => database.deleteRecordWithId('task-1')).thenAnswer((_) async {});

    await inspector.remove('task-1');

    verifyInOrder([
      () => downloader.cancelTaskWithId('task-1'),
      () => database.deleteRecordWithId('task-1'),
    ]);
  });

  test('clearFinished deletes only records in a final state', () async {
    when(() => database.allRecords(group: kUserFilesDownloadGroup)).thenAnswer(
      (_) async => [
        TaskRecord(taskWithId('running'), TaskStatus.running, 0.2, 100),
        TaskRecord(taskWithId('done'), TaskStatus.complete, 1, 100),
        TaskRecord(taskWithId('failed'), TaskStatus.failed, -1, -1),
      ],
    );
    when(() => database.deleteRecordsWithIds(any())).thenAnswer((_) async {});

    await inspector.clearFinished();

    final deletedIds =
        verify(() => database.deleteRecordsWithIds(captureAny()))
                .captured
                .single
            as Iterable<String>;
    expect(deletedIds.toList(), ['done', 'failed']);
  });
}
