import 'package:background_downloader/background_downloader.dart';
import 'package:echo_loop/features/baidu_netdisk/providers/baidu_netdisk_import_tasks_provider.dart';
import 'package:echo_loop/providers/download_provider.dart';
import 'package:echo_loop/screens/download_tasks_screen.dart';
import 'package:echo_loop/services/background_download_task_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInspector extends Mock implements DownloadTaskInspector {}

const _runningTask = DownloadTaskInfo(
  taskId: 'task-1',
  resourceKey: 'audio:42',
  displayName: 'episode.mp3',
  host: 'cdn.example.com',
  status: TaskStatus.running,
  progress: 0.5,
  receivedBytes: 1024,
  expectedBytes: 2048,
  retriesRemaining: 2,
  errorDescription: null,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<DownloadTaskInfo> tasks,
  required DownloadTaskInspector inspector,
  List<DownloadTaskInfo> waiting = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        downloadTaskInspectorProvider.overrideWithValue(inspector),
        downloadTaskInfosProvider.overrideWith((ref) => Stream.value(tasks)),
        baiduWaitingDownloadInfosProvider.overrideWithValue(waiting),
      ],
      child: const MaterialApp(home: DownloadTasksScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an empty state when there are no tasks', (tester) async {
    await _pumpScreen(tester, tasks: const [], inspector: _MockInspector());

    expect(find.text('暂无下载任务'), findsOneWidget);
  });

  testWidgets('lists task name, status, retries and progress', (tester) async {
    await _pumpScreen(
      tester,
      tasks: const [_runningTask],
      inspector: _MockInspector(),
    );

    expect(find.text('episode.mp3'), findsOneWidget);
    expect(
      find.textContaining('cdn.example.com · 下载中 · 剩余重试 2 次'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('deleting a task removes it through the inspector', (
    tester,
  ) async {
    final inspector = _MockInspector();
    when(() => inspector.remove(any())).thenAnswer((_) async {});

    await _pumpScreen(
      tester,
      tasks: const [_runningTask],
      inspector: inspector,
    );
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();

    verify(() => inspector.remove('task-1')).called(1);
  });

  testWidgets('排队中的导入任务排在前面显示，且没有删除按钮', (tester) async {
    const waitingTask = DownloadTaskInfo(
      taskId: 'waiting-7',
      resourceKey: 'baidu:7',
      displayName: 'waiting.mp3',
      host: '',
      status: TaskStatus.enqueued,
      progress: null,
      receivedBytes: null,
      expectedBytes: null,
      retriesRemaining: 2,
      errorDescription: null,
    );
    final inspector = _MockInspector();
    await _pumpScreen(
      tester,
      tasks: const [_runningTask],
      inspector: inspector,
      waiting: const [waitingTask],
    );

    expect(find.text('waiting.mp3'), findsOneWidget);
    expect(find.textContaining('排队中'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('waiting.mp3')).dy,
      lessThan(tester.getTopLeft(find.text('episode.mp3')).dy),
    );
  });
}
