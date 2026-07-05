// LocalTranscriptionTaskManager 单元测试
//
// 通过 fake 引擎 / 转码服务 / fileOps + 内存 DB 验证完整流水线、
// 状态转换、专用引擎生命周期（用后 dispose）、空结果与失败处理。
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/audio_import/audio_transcode_service.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/local_transcription_task_provider.dart';
import 'package:echo_loop/providers/transcription_task_provider.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/providers/asr_engine_provider.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';

import '../helpers/mock_providers.dart';

// ─── Fakes ──────────────────────────────────────────────

class MockTranscriptionFileOps extends Mock implements TranscriptionFileOps {}

/// 假引擎：记录调用、返回预设分段并驱动进度回调。
class _FakeEngine implements OfflineAsrEngine {
  _FakeEngine(this.segments, {this.throwOnTranscribe = false});

  final List<AsrSegment> segments;
  final bool throwOnTranscribe;
  int initializeCalls = 0;
  int disposeCalls = 0;

  @override
  String get name => 'fake';
  @override
  bool get isReady => initializeCalls > 0 && disposeCalls == 0;
  @override
  AsrModelInfo? get currentModel => null;

  @override
  Future<void> initialize(AsrModelConfig config) async {
    initializeCalls++;
  }

  @override
  Future<AsrResult> transcribe(String wavPath) async =>
      const AsrResult(text: '', inferenceTime: Duration.zero);

  @override
  Future<List<AsrSegment>> transcribeSegments(
    String wavPath, {
    void Function(double progress)? onProgress,
  }) async {
    if (throwOnTranscribe) throw StateError('boom');
    for (var i = 0; i < segments.length; i++) {
      onProgress?.call((i + 1) / segments.length);
    }
    return segments;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

/// 假引擎：transcribeSegments 永不完成（模拟阻塞的 native 推理），
/// 用于验证取消能打断在途 await 并触发清理。
class _HangingEngine implements OfflineAsrEngine {
  final _never = Completer<List<AsrSegment>>();
  int initializeCalls = 0;
  int disposeCalls = 0;

  @override
  String get name => 'hang';
  @override
  bool get isReady => initializeCalls > 0 && disposeCalls == 0;
  @override
  AsrModelInfo? get currentModel => null;

  @override
  Future<void> initialize(AsrModelConfig config) async {
    initializeCalls++;
  }

  @override
  Future<AsrResult> transcribe(String wavPath) async =>
      const AsrResult(text: '', inferenceTime: Duration.zero);

  @override
  Future<List<AsrSegment>> transcribeSegments(
    String wavPath, {
    void Function(double progress)? onProgress,
  }) => _never.future; // 永不完成

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

/// 假转码：写一个占位文件并返回预设结果，记录调用。
class _FakeTranscode extends AudioTranscodeService {
  _FakeTranscode({this.ok = true});
  final bool ok;
  int calls = 0;

  @override
  Future<bool> transcodeToPcmWav16k({
    required File source,
    required File output,
  }) async {
    calls++;
    if (ok) {
      await output.parent.create(recursive: true);
      await output.writeAsBytes([0, 0, 0, 0]);
    }
    return ok;
  }
}

/// 假模型管理器：modelDir 返回临时目录，VAD 视为未下载（fake 引擎忽略 config）。
class _FakeModelManager extends AsrModelManager {
  _FakeModelManager(this._dir);
  final String _dir;
  @override
  Future<String> modelDir(String modelId) async => _dir;
  @override
  Future<bool> isModelDownloaded(String modelId) async => false;
}

AudioItem _testAudioItem({
  String id = 'a1',
  String audioPath = 'audios/x.m4a',
}) {
  return AudioItem(
    id: id,
    name: 'Test',
    audioPath: audioPath,
    addedDate: DateTime(2026),
    totalDuration: 60,
  );
}

Future<void> _seedRow(db.AppDatabase database, AudioItem item) async {
  await database
      .into(database.audioItems)
      .insert(
        db.AudioItemsCompanion.insert(
          id: item.id,
          name: item.name,
          audioPath: Value(item.audioPath),
          addedDate: item.addedDate,
          updatedAt: DateTime(2026),
        ),
      );
}

void main() {
  late db.AppDatabase database;
  late Directory dataDir;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    dataDir = await Directory.systemTemp.createTemp('local_tx_');
  });

  tearDown(() async {
    await database.close();
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  ProviderContainer buildContainer({
    required OfflineAsrEngine engine,
    required _FakeTranscode transcode,
    List<AudioItem>? items,
  }) {
    final fileOps = MockTranscriptionFileOps();
    when(() => fileOps.getDataDir()).thenAnswer((_) async => dataDir);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        audioLibraryProvider.overrideWith(TestAudioLibrary.new),
        transcriptionFileOpsProvider.overrideWithValue(fileOps),
        localTranscriptionEngineFactoryProvider.overrideWithValue(() => engine),
        localTranscriptionTranscodeServiceProvider.overrideWithValue(transcode),
        asrModelManagerProvider.overrideWithValue(
          _FakeModelManager(dataDir.path),
        ),
      ],
    );
    (container.read(audioLibraryProvider.notifier) as TestAudioLibrary)
        .setItems(items ?? [_testAudioItem()]);
    return container;
  }

  final model = availableModels.first;

  group('LocalTranscriptionTaskManager', () {
    test('初始状态为空 Map', () {
      final container = buildContainer(
        engine: _FakeEngine(const []),
        transcode: _FakeTranscode(),
      );
      addTearDown(container.dispose);
      expect(container.read(localTranscriptionTaskManagerProvider), isEmpty);
    });

    test('完整流水线：解码→转录→写库→完成，专用引擎用后 dispose', () async {
      final item = _testAudioItem();
      await _seedRow(database, item);
      final engine = _FakeEngine([
        const AsrSegment(
          text: 'Hello world',
          start: Duration(milliseconds: 200),
          end: Duration(milliseconds: 900),
        ),
        const AsrSegment(
          text: 'Second line',
          start: Duration(milliseconds: 1000),
          end: Duration(milliseconds: 1800),
        ),
      ]);
      final transcode = _FakeTranscode();
      final container = buildContainer(
        engine: engine,
        transcode: transcode,
        items: [item],
      );
      addTearDown(container.dispose);

      final states = <LocalTranscriptionState>[];
      container.listen(
        localTranscriptionTaskManagerProvider.select((m) => m[item.id]),
        (_, next) {
          if (next != null) states.add(next);
        },
      );

      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );
      // 关闭合并以验证原始分段流水线（两段各自成句）。
      await notifier.startLocalTranscription(
        item,
        model: model,
        autoMergeShortSentences: false,
      );

      // 状态经历 Decoding → Transcribing → Completed。
      expect(states.any((s) => s is LocalTranscriptionDecoding), isTrue);
      expect(states.any((s) => s is LocalTranscriptionTranscribing), isTrue);
      expect(states.last, isA<LocalTranscriptionCompleted>());

      // 转码与引擎生命周期。
      expect(transcode.calls, 1);
      expect(engine.initializeCalls, 1);
      expect(engine.disposeCalls, 1); // 用后释放

      // SRT 写库含两段文本。
      final srt = await database.audioItemDao.getTranscriptSrt(item.id);
      expect(srt, isNotNull);
      expect(srt!, contains('Hello world'));
      expect(srt, contains('Second line'));

      // AudioItem 更新为 device 来源 + 英文。
      final updated = container
          .read(audioLibraryProvider)
          .audioItems
          .singleWhere((i) => i.id == item.id);
      expect(updated.transcriptSource, TranscriptSource.device);
      expect(updated.transcriptLanguage, 'en');
      expect(updated.sentenceCount, 2);

      // 临时 WAV 已清理。
      final tmpDir = Directory('${dataDir.path}/tmp/asr_transcribe');
      final leftover = tmpDir.existsSync()
          ? tmpDir.listSync().whereType<File>().toList()
          : <File>[];
      expect(leftover, isEmpty);
    });

    test('空分段 → EmptyResult，不写库', () async {
      final item = _testAudioItem();
      await _seedRow(database, item);
      final engine = _FakeEngine(const []);
      final container = buildContainer(
        engine: engine,
        transcode: _FakeTranscode(),
        items: [item],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );

      await notifier.startLocalTranscription(item, model: model);

      expect(
        notifier.getTaskState(item.id),
        isA<LocalTranscriptionEmptyResult>(),
      );
      expect(await database.audioItemDao.getTranscriptSrt(item.id), isNull);
      expect(engine.disposeCalls, 1);
    });

    test('解码失败 → Failed(decode)，不初始化引擎', () async {
      final item = _testAudioItem();
      final engine = _FakeEngine(const []);
      final container = buildContainer(
        engine: engine,
        transcode: _FakeTranscode(ok: false),
        items: [item],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );

      await notifier.startLocalTranscription(item, model: model);

      final state = notifier.getTaskState(item.id);
      expect(state, isA<LocalTranscriptionFailed>());
      expect((state as LocalTranscriptionFailed).code, 'decode');
      expect(engine.initializeCalls, 0);
    });

    test('转录抛异常 → Failed(unknown)，引擎仍被 dispose', () async {
      final item = _testAudioItem();
      final engine = _FakeEngine(const [], throwOnTranscribe: true);
      final container = buildContainer(
        engine: engine,
        transcode: _FakeTranscode(),
        items: [item],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );

      await notifier.startLocalTranscription(item, model: model);

      expect(notifier.getTaskState(item.id), isA<LocalTranscriptionFailed>());
      expect(engine.disposeCalls, 1);
    });

    test('进行中防重入：Transcribing 态忽略新请求', () async {
      final transcode = _FakeTranscode();
      final container = buildContainer(
        engine: _FakeEngine(const []),
        transcode: transcode,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );
      notifier.state = {
        'a1': const LocalTranscriptionTranscribing(progress: 0.3),
      };

      await notifier.startLocalTranscription(_testAudioItem(), model: model);

      // 状态未被覆盖、未触发新一轮转码。
      expect(
        notifier.getTaskState('a1'),
        isA<LocalTranscriptionTranscribing>(),
      );
      expect(transcode.calls, 0);
    });

    test('取消在途转录：打断 await → 状态 Idle、dispose 引擎、清理临时 WAV', () async {
      final item = _testAudioItem();
      await _seedRow(database, item);
      final engine = _HangingEngine();
      final container = buildContainer(
        engine: engine,
        transcode: _FakeTranscode(),
        items: [item],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );

      // 不 await：transcribeSegments 会一直挂起。
      final future = notifier.startLocalTranscription(item, model: model);

      // 轮询等待进入「转录中」（此时正阻塞在 transcribeSegments 的 await）。
      for (
        var i = 0;
        i < 200 &&
            notifier.getTaskState(item.id) is! LocalTranscriptionTranscribing;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(
        notifier.getTaskState(item.id),
        isA<LocalTranscriptionTranscribing>(),
      );

      // 取消应立即打断 await，主流程走 finally 清理。
      notifier.cancelTranscription(item.id);
      await future;

      expect(notifier.getTaskState(item.id), isA<LocalTranscriptionIdle>());
      expect(engine.disposeCalls, 1);

      // 临时 WAV 已删除。
      final tmpDir = Directory('${dataDir.path}/tmp/asr_transcribe');
      final leftover = tmpDir.existsSync()
          ? tmpDir.listSync().whereType<File>().toList()
          : <File>[];
      expect(leftover, isEmpty);
    });

    test('cancelTranscription 将状态重置为 Idle', () {
      final container = buildContainer(
        engine: _FakeEngine(const []),
        transcode: _FakeTranscode(),
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );
      notifier.state = {'a1': const LocalTranscriptionDecoding()};
      notifier.cancelTranscription('a1');
      expect(notifier.getTaskState('a1'), isA<LocalTranscriptionIdle>());
    });

    test('clearState 从 Map 中移除条目', () {
      final container = buildContainer(
        engine: _FakeEngine(const []),
        transcode: _FakeTranscode(),
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );
      notifier.state = {'a1': const LocalTranscriptionCompleted()};
      notifier.clearState('a1');
      expect(container.read(localTranscriptionTaskManagerProvider), isEmpty);
    });

    test('autoMerge 开启：相邻短段合并为一句写库', () async {
      final item = _testAudioItem();
      await _seedRow(database, item);
      // 三段各 <4s，合并后应收敛为一句。
      final engine = _FakeEngine([
        const AsrSegment(
          text: 'Hello',
          start: Duration(milliseconds: 0),
          end: Duration(milliseconds: 800),
        ),
        const AsrSegment(
          text: 'world',
          start: Duration(milliseconds: 900),
          end: Duration(milliseconds: 1700),
        ),
        const AsrSegment(
          text: 'again',
          start: Duration(milliseconds: 1800),
          end: Duration(milliseconds: 2600),
        ),
      ]);
      final container = buildContainer(
        engine: engine,
        transcode: _FakeTranscode(),
        items: [item],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        localTranscriptionTaskManagerProvider.notifier,
      );

      await notifier.startLocalTranscription(
        item,
        model: model,
        autoMergeShortSentences: true,
      );

      final srt = await database.audioItemDao.getTranscriptSrt(item.id);
      expect(srt, contains('Hello world again'));
      final updated = container
          .read(audioLibraryProvider)
          .audioItems
          .singleWhere((i) => i.id == item.id);
      expect(updated.sentenceCount, 1);
    });
  });

  group('mergeShortAsrSegments', () {
    AsrSegment seg(String text, int startMs, int endMs) => AsrSegment(
      text: text,
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );

    test('空列表 / 单段原样返回', () {
      expect(mergeShortAsrSegments(const []), isEmpty);
      final one = [seg('solo', 0, 500)];
      expect(mergeShortAsrSegments(one), same(one));
    });

    test('相邻短段合并到 ≥4s，文本空格拼接、区间取并', () {
      final result = mergeShortAsrSegments([
        seg('a', 0, 1500),
        seg('b', 1500, 3000),
        seg('c', 3000, 4500),
      ]);
      expect(result, hasLength(1));
      expect(result.single.text, 'a b c');
      expect(result.single.start, Duration.zero);
      expect(result.single.end, const Duration(milliseconds: 4500));
    });

    test('已达下限的段独立成句，不再拼接后续', () {
      final result = mergeShortAsrSegments([
        seg('long', 0, 5000), // ≥4s，独立收尾
        seg('x', 5000, 5500),
        seg('y', 5500, 6000),
      ]);
      expect(result.map((s) => s.text).toList(), ['long', 'x y']);
    });

    test('末尾残余短段保留（不丢弃）', () {
      final result = mergeShortAsrSegments([
        seg('a', 0, 4200), // ≥4s 收尾
        seg('tail', 4200, 4700), // 残余短段独立保留
      ]);
      expect(result.map((s) => s.text).toList(), ['a', 'tail']);
    });
  });
}
