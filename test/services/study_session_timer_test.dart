import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:clock/clock.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/services/study_activity_gate.dart';
import 'package:echo_loop/services/study_session_timer.dart';
import 'package:echo_loop/services/study_time_service.dart';
import 'package:echo_loop/services/app_logger.dart';

class _RecordingStudyTimeService extends StudyTimeService {
  _RecordingStudyTimeService(AppDatabase db)
    : super(db.dailyStudyRecordDao, db.dailyStageStudyRecordDao);

  final List<Duration> recordedStudy = <Duration>[];
  final List<Duration> recordedInput = <Duration>[];
  bool failNextRecord = false;

  @override
  Future<void> recordSessionDurations({
    required Duration studyDuration,
    Duration inputDuration = Duration.zero,
    required StudyStage stage,
    DateTime? date,
  }) async {
    recordedStudy.add(studyDuration);
    recordedInput.add(inputDuration);
    if (failNextRecord) {
      failNextRecord = false;
      throw StateError('simulated statistics write failure');
    }
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late StudyActivityGate activityGate;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    activityGate = StudyActivityGate();
  });

  tearDown(() async {
    activityGate.dispose();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await db.close();
  });

  test('stop persists foreground duration under the requested stage', () async {
    final timer = StudySessionTimer(
      studyTimeService: StudyTimeService(
        db.dailyStudyRecordDao,
        db.dailyStageStudyRecordDao,
      ),
      stage: StudyStage.savedSentencesReview,
      activityGate: activityGate,
    );

    timer.start();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await timer.stop();

    final records = await db.dailyStageStudyRecordDao.getByDate(DateTime.now());
    final record = records.singleWhere(
      (item) => item.stage == StudyStage.savedSentencesReview,
    );
    expect(record.studyTimeMilliseconds, greaterThanOrEqualTo(1000));
    await timer.dispose();
  });

  test('播放时长单独计入输入时长', () async {
    final timer = StudySessionTimer(
      studyTimeService: StudyTimeService(
        db.dailyStudyRecordDao,
        db.dailyStageStudyRecordDao,
      ),
      stage: StudyStage.freePlayer,
      activityGate: activityGate,
    );

    timer.start();
    timer.setPlaybackActive(true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    timer.setPlaybackActive(false);
    await timer.stop();

    final record = await db.dailyStudyRecordDao.getByDate(DateTime.now());
    expect(record?.studyTimeMilliseconds, greaterThanOrEqualTo(1000));
    expect(record?.inputTimeMilliseconds, greaterThanOrEqualTo(1000));
    expect(
      record?.inputTimeMilliseconds,
      lessThanOrEqualTo(record?.studyTimeMilliseconds ?? 0),
    );
    await timer.dispose();
  });

  test('后台启动时不计时，回到前台后才开始计时', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

    final timer = StudySessionTimer(
      studyTimeService: StudyTimeService(
        db.dailyStudyRecordDao,
        db.dailyStageStudyRecordDao,
      ),
      stage: StudyStage.freePlayer,
      activityGate: activityGate,
    );

    timer.start();
    expect(timer.elapsed, Duration.zero);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await timer.stop();

    final record = await db.dailyStudyRecordDao.getByDate(DateTime.now());
    expect(record?.studyTimeMilliseconds, greaterThanOrEqualTo(1000));
    await timer.dispose();
  });

  test('切到后台暂停计时，回到前台后恢复计时', () async {
    final timer = StudySessionTimer(
      studyTimeService: StudyTimeService(
        db.dailyStudyRecordDao,
        db.dailyStageStudyRecordDao,
      ),
      stage: StudyStage.freePlayer,
      activityGate: activityGate,
    );

    timer.start();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    final elapsedInForeground = timer.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(timer.elapsed, elapsedInForeground);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(timer.elapsed, greaterThan(elapsedInForeground));

    await timer.stop();
    await timer.dispose();
  });

  test('允许后台播放的任务在后台继续累计学习和输入时长', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 9, 8)), () {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        final service = _RecordingStudyTimeService(db);
        final timer = StudySessionTimer(
          studyTimeService: service,
          stage: StudyStage.freePlayer,
          activityGate: activityGate,
          allowBackgroundPlayback: true,
        );

        timer.start();
        timer.setPlaybackActive(true);
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        final stop = timer.stop();
        async.flushMicrotasks();

        expect(timer.elapsed, const Duration(seconds: 3));
        expect(timer.inputElapsed, const Duration(seconds: 3));
        expect(
          service.recordedStudy.fold<int>(
            0,
            (sum, duration) => sum + duration.inMilliseconds,
          ),
          3000,
        );
        expect(
          service.recordedInput.fold<int>(
            0,
            (sum, duration) => sum + duration.inMilliseconds,
          ),
          3000,
        );
        async.flushMicrotasks();
        final dispose = timer.dispose();
        async.flushMicrotasks();
        var stopCompleted = false;
        var disposeCompleted = false;
        stop.then((_) => stopCompleted = true);
        dispose.then((_) => disposeCompleted = true);
        async.flushMicrotasks();
        expect(stopCompleted, isTrue);
        expect(disposeCompleted, isTrue);
      });
    });
  });

  test('允许后台播放但没有实际播放时，进入后台立即停止计时', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 9, 8)), () {
        final service = _RecordingStudyTimeService(db);
        final timer = StudySessionTimer(
          studyTimeService: service,
          stage: StudyStage.freePlayer,
          activityGate: activityGate,
          allowBackgroundPlayback: true,
          checkpointInterval: const Duration(seconds: 10),
          idleTimeout: const Duration(seconds: 2),
        );

        timer.start();
        async.elapse(const Duration(seconds: 1));
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        async.flushMicrotasks();

        final elapsedAtBackground = timer.elapsed;
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(timer.isRunning, isFalse);
        expect(timer.elapsed, elapsedAtBackground);
        expect(
          service.recordedStudy.fold<int>(
            0,
            (sum, duration) => sum + duration.inMilliseconds,
          ),
          elapsedAtBackground.inMilliseconds,
        );
        expect(
          service.recordedInput.fold<int>(
            0,
            (sum, duration) => sum + duration.inMilliseconds,
          ),
          0,
        );

        final dispose = timer.dispose();
        async.flushMicrotasks();
        var disposeCompleted = false;
        dispose.then((_) => disposeCompleted = true);
        async.flushMicrotasks();
        expect(disposeCompleted, isTrue);
      });
    });
  });

  test('后台无播放后回到前台不会自动恢复，新的活动才会恢复', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 9, 8)), () {
        final service = _RecordingStudyTimeService(db);
        final timer = StudySessionTimer(
          studyTimeService: service,
          stage: StudyStage.freePlayer,
          activityGate: activityGate,
          allowBackgroundPlayback: true,
          idleTimeout: const Duration(seconds: 2),
        );

        timer.start();
        async.elapse(const Duration(seconds: 1));
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        async.flushMicrotasks();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(timer.isRunning, isFalse);
        final elapsedBeforeActivity = timer.elapsed;
        timer.markActivity();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(timer.isRunning, isTrue);
        expect(timer.elapsed, greaterThan(elapsedBeforeActivity));

        final dispose = timer.dispose();
        async.flushMicrotasks();
        var disposeCompleted = false;
        dispose.then((_) => disposeCompleted = true);
        async.flushMicrotasks();
        expect(disposeCompleted, isTrue);
      });
    });
  });

  test('播放暂停后仍可统计用户思考时间，但不增加输入时长', () async {
    final timer = StudySessionTimer(
      studyTimeService: StudyTimeService(
        db.dailyStudyRecordDao,
        db.dailyStageStudyRecordDao,
      ),
      stage: StudyStage.freePlayer,
      activityGate: activityGate,
      idleTimeout: const Duration(seconds: 2),
    );

    timer.start();
    timer.setPlaybackActive(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    timer.setPlaybackActive(false);
    final elapsedAfterPlayback = timer.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(timer.elapsed, greaterThan(elapsedAfterPlayback));
    expect(timer.inputElapsed, lessThan(timer.elapsed));

    await timer.dispose();
  });

  test('显式暂停期间活动不会偷偷恢复计时，恢复后继续原会话', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 9, 8)), () {
        final service = _RecordingStudyTimeService(db);
        final timer = StudySessionTimer(
          studyTimeService: service,
          stage: StudyStage.listenAndRepeat,
          activityGate: activityGate,
          checkpointInterval: const Duration(seconds: 10),
        );

        timer.start();
        async.elapse(const Duration(seconds: 1));
        timer.pause();
        async.flushMicrotasks();
        final pausedAt = timer.elapsed;
        async.elapse(const Duration(seconds: 5));
        timer.markActivity();
        expect(timer.elapsed, pausedAt);

        timer.resume();
        async.elapse(const Duration(seconds: 1));
        expect(timer.elapsed, greaterThan(pausedAt));

        final dispose = timer.dispose();
        async.flushMicrotasks();
        dispose.then((_) {});
        async.flushMicrotasks();
      });
    });
  });

  test('超过 idle timeout 后暂停，新的用户活动恢复同一会话', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 9, 8)), () {
        AppLogger.instance.clear();
        final service = _RecordingStudyTimeService(db);
        final timer = StudySessionTimer(
          studyTimeService: service,
          stage: StudyStage.freePlayer,
          activityGate: activityGate,
          checkpointInterval: const Duration(seconds: 10),
          idleTimeout: const Duration(seconds: 2),
        );

        timer.start();
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(timer.isRunning, isFalse);

        timer.markActivity();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(timer.isRunning, isTrue);
        expect(
          AppLogger.instance.entries.any(
            (entry) =>
                entry.tag == 'StudySessionTimer' &&
                entry.message.contains('session.activity') &&
                entry.message.contains('resumedFromIdle=true'),
          ),
          isTrue,
        );

        final stop = timer.stop();
        async.flushMicrotasks();
        var stopCompleted = false;
        stop.then((_) => stopCompleted = true);
        async.flushMicrotasks();
        expect(stopCompleted, isTrue);
        expect(
          service.recordedStudy.fold<int>(
            0,
            (sum, duration) => sum + duration.inMilliseconds,
          ),
          3000,
        );
        final dispose = timer.dispose();
        async.flushMicrotasks();
        var disposeCompleted = false;
        dispose.then((_) => disposeCompleted = true);
        async.flushMicrotasks();
        expect(disposeCompleted, isTrue);
      });
    });
  });

  test('fake clock 下 checkpoint 与 stop 串行且不重复写入', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 9, 8)), () {
        final service = _RecordingStudyTimeService(db);
        final timer = StudySessionTimer(
          studyTimeService: service,
          stage: StudyStage.freePlayer,
          activityGate: activityGate,
          checkpointInterval: const Duration(seconds: 2),
        );
        timer.start();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        final stop = timer.stop();
        async.flushMicrotasks();
        expect(
          service.recordedStudy.fold<int>(
            0,
            (sum, duration) => sum + duration.inMilliseconds,
          ),
          5000,
        );
        expect(timer.elapsed, const Duration(seconds: 5));
        final dispose = timer.dispose();
        async.flushMicrotasks();
        expect(
          service.recordedStudy.fold<int>(
            0,
            (sum, duration) => sum + duration.inMilliseconds,
          ),
          5000,
        );
        var stopCompleted = false;
        var disposeCompleted = false;
        stop.then((_) => stopCompleted = true);
        dispose.then((_) => disposeCompleted = true);
        async.flushMicrotasks();
        expect(stopCompleted, isTrue);
        expect(disposeCompleted, isTrue);
      });
    });
  });

  test('最终 flush 失败时保留未持久化增量并记录日志', () async {
    AppLogger.instance.clear();
    final service = _RecordingStudyTimeService(db)..failNextRecord = true;
    final timer = StudySessionTimer(
      studyTimeService: service,
      stage: StudyStage.freePlayer,
      activityGate: activityGate,
    );

    timer.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await expectLater(timer.dispose(), throwsStateError);
    expect(
      AppLogger.instance.entries.any(
        (entry) =>
            entry.tag == 'StudySessionTimer' &&
            entry.message.contains('session.flush.failed'),
      ),
      isTrue,
    );

    await timer.dispose();
    expect(service.recordedStudy, hasLength(2));
    expect(service.recordedStudy[1], service.recordedStudy[0]);
  });
}
