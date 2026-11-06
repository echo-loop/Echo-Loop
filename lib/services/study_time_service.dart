import 'dart:async';

import '../database/daos/daily_study_record_dao.dart';
import '../database/daos/daily_stage_study_record_dao.dart';
import '../database/daos/study_statistics_dao.dart';
import '../models/study_stage.dart';
import '../utils/word_counter.dart';
import 'app_logger.dart';

/// 学习统计事件服务。
///
/// 所有写入都先在调用点快照日期和阶段，再进入同一个 FIFO 队列。
/// 查询会等待提交前的队列尾部，因此读操作具备 read-after-write 一致性；
/// 具体数据库事务由 [StudyStatisticsDao] 负责。是否支持后台由具体学习任务
/// 决定，统计写入本身不根据 App 生命周期丢弃事件。
class StudyTimeService {
  final DailyStudyRecordDao _dao;
  final DailyStageStudyRecordDao _stageDao;
  late final StudyStatisticsDao _statisticsDao;

  Future<void> _queueTail = Future<void>.value();
  Future<void>? _flushInFlight;
  int _nextEventId = 0;
  final List<_StudyWriteFailure> _failures = <_StudyWriteFailure>[];
  final StreamController<DateTime> _sessionRecordedController =
      StreamController<DateTime>.broadcast();

  StudyTimeService(
    this._dao,
    this._stageDao, {
    StudyStatisticsDao? statisticsDao,
  }) {
    _statisticsDao = statisticsDao ?? StudyStatisticsDao(_dao.attachedDatabase);
  }

  /// 有学习时长写入成功后发出该事件日期，供打卡判定订阅。
  ///
  /// 只在时长真正落库后发出，因此订阅方查询到的今日时长已包含本次写入。
  Stream<DateTime> get studySessionRecorded =>
      _sessionRecordedController.stream;

  /// 释放事件流；随 Provider 销毁或数据库切换时调用。
  Future<void> dispose() => _sessionRecordedController.close();

  /// 记录一次学习会话的总学习时长和输入时长。
  ///
  /// 两类时长属于同一个统计事件，使用一次 FIFO 入队和一次数据库事务，
  /// 但数值彼此独立：用户暂停播放后继续思考时，只增加学习时长，不增加输入时长。
  Future<void> recordSessionDurations({
    required Duration studyDuration,
    Duration inputDuration = Duration.zero,
    required StudyStage stage,
    DateTime? date,
  }) {
    final eventDate = date ?? DateTime.now();
    return _enqueue(
      StudyStatisticsDelta(
        date: eventDate,
        stage: stage,
        studyTimeMilliseconds: studyDuration.inMilliseconds,
        inputTimeMilliseconds: inputDuration.inMilliseconds,
      ),
    ).then((_) {
      AppLogger.log(
        'StudyStatistics',
        'event=session_duration_persisted stage=${stage.name} '
            'studyDurationMs=${studyDuration.inMilliseconds} '
            'inputDurationMs=${inputDuration.inMilliseconds}',
      );
      if (studyDuration > Duration.zero &&
          !_sessionRecordedController.isClosed) {
        _sessionRecordedController.add(eventDate);
      }
    });
  }

  /// 尝试为 [date] 当天记录每日学习目标打卡，返回本次是否刚刚打卡成功。
  ///
  /// 先等待已入队的写入，确保判定读到最新时长；日期由调用方传入，
  /// 与触发它的时长写入保持同一天。
  Future<bool> tryCheckInDailyGoal({
    required int goalMinutes,
    required DateTime date,
  }) async {
    await _queueTail;
    return _statisticsDao.markDailyGoalCheckIn(
      date: date,
      goalMinutes: goalMinutes,
    );
  }

  /// 记录有效学习时长；是否允许后台计时由具体学习任务和计时器决定。
  Future<void> recordActiveDuration(
    Duration duration, {
    required StudyStage stage,
    bool recordInputDuration = false,
    DateTime? date,
  }) {
    final eventDate = date ?? DateTime.now();
    return recordSessionDurations(
      studyDuration: duration,
      inputDuration: recordInputDuration ? duration : Duration.zero,
      stage: stage,
      date: eventDate,
    );
  }

  /// 记录按句播放；词数和词形由服务统一从文本提取。
  Future<void> recordSentencePlayback({
    required Duration duration,
    required String text,
    required StudyStage stage,
    bool recordInputDuration = true,
    DateTime? date,
  }) {
    final eventDate = date ?? DateTime.now();
    final milliseconds = duration.inMilliseconds;
    final inputWords = countWords(text);
    final wordForms = _extractWordForms(text, eventDate);
    return _enqueue(
      StudyStatisticsDelta(
        date: eventDate,
        stage: stage,
        inputTimeMilliseconds: recordInputDuration ? milliseconds : 0,
        inputWords: inputWords,
        wordForms: wordForms,
      ),
    ).then((_) {
      AppLogger.log(
        'StudyStatistics',
        'event=input_persisted stage=${stage.name} '
            'durationMs=$milliseconds inputWords=$inputWords',
      );
    });
  }

  /// 记录一次语音识别输出。
  Future<void> recordSpeechRecognition({
    required Duration duration,
    int producedWordCount = 0,
    required StudyStage stage,
    DateTime? date,
  }) {
    final eventDate = date ?? DateTime.now();
    return _enqueue(
      StudyStatisticsDelta(
        date: eventDate,
        stage: stage,
        outputTimeMilliseconds: duration.inMilliseconds,
        outputWords: producedWordCount,
      ),
    ).then((_) {
      AppLogger.log(
        'StudyStatistics',
        'event=output_persisted stage=${stage.name} '
            'durationMs=${duration.inMilliseconds} '
            'outputWords=$producedWordCount',
      );
    });
  }

  /// 记录输出词数事件。
  Future<void> recordOutputWords(
    int count, {
    required StudyStage stage,
    DateTime? date,
  }) {
    final eventDate = date ?? DateTime.now();
    return _enqueue(
      StudyStatisticsDelta(date: eventDate, stage: stage, outputWords: count),
    );
  }

  /// 非阻塞提交按句播放事件；异常由队列保留到下一次 [flush] 报告。
  void submitSentencePlayback({
    required Duration duration,
    required String text,
    required StudyStage stage,
    bool recordInputDuration = true,
    DateTime? date,
  }) {
    unawaited(
      recordSentencePlayback(
        duration: duration,
        text: text,
        stage: stage,
        recordInputDuration: recordInputDuration,
        date: date,
      ).catchError((Object error, StackTrace stackTrace) {
        AppLogger.log(
          'StudyStatistics',
          'submit.failed error=$error\n$stackTrace',
        );
      }),
    );
  }

  /// 非阻塞提交语音识别事件。
  void submitSpeechRecognition({
    required Duration duration,
    int producedWordCount = 0,
    required StudyStage stage,
    DateTime? date,
  }) {
    unawaited(
      recordSpeechRecognition(
        duration: duration,
        producedWordCount: producedWordCount,
        stage: stage,
        date: date,
      ).catchError((Object error, StackTrace stackTrace) {
        AppLogger.log(
          'StudyStatistics',
          'submit.failed error=$error\n$stackTrace',
        );
      }),
    );
  }

  /// 非阻塞提交输出词数事件。
  void submitOutputWords(
    int count, {
    required StudyStage stage,
    DateTime? date,
  }) {
    unawaited(
      recordOutputWords(count, stage: stage, date: date).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLogger.log(
          'StudyStatistics',
          'submit.failed error=$error\n$stackTrace',
        );
      }),
    );
  }

  /// 等待调用前已提交的事件；失败时抛出该批次最早的原始异常。
  ///
  /// 同一时刻的并发调用共享一个 flush future。flush 开始后提交的新事件
  /// 属于下一批，不会被当前调用隐式等待。
  Future<void> flush() {
    final active = _flushInFlight;
    if (active != null) return active;
    final boundary = _nextEventId;
    final queue = _queueTail;
    final operation = _finishFlush(queue, boundary);
    final scheduled = operation.whenComplete(() => _flushInFlight = null);
    _flushInFlight = scheduled;
    return scheduled;
  }

  Future<void> _finishFlush(Future<void> queue, int boundary) async {
    await queue;
    final failures = _failures
        .where((failure) => failure.id <= boundary)
        .toList();
    _failures.removeWhere((failure) => failure.id <= boundary);
    if (failures.isNotEmpty) {
      final failure = failures.first;
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  Future<void> _enqueue(StudyStatisticsDelta delta) {
    final eventId = ++_nextEventId;
    final result = Completer<void>();
    final event = _queueTail.then((_) async {
      try {
        await _statisticsDao.applyDelta(delta);
        result.complete();
      } catch (error, stackTrace) {
        _failures.add(_StudyWriteFailure(eventId, error, stackTrace));
        AppLogger.log(
          'StudyStatistics',
          'write.failed event=$eventId error=$error\n$stackTrace',
        );
        result.completeError(error, stackTrace);
      }
    });
    _queueTail = event.catchError((Object _) {});
    return result.future;
  }

  Future<T> _afterWrites<T>(Future<T> Function() query) async {
    await _queueTail;
    return query();
  }

  Map<String, DateTime> _extractWordForms(String text, DateTime learnedAt) {
    final forms = <String, DateTime>{};
    for (final match in _wordPattern.allMatches(text)) {
      final wordForm = match.group(0)?.toLowerCase();
      if (wordForm != null) forms[wordForm] = learnedAt;
    }
    return forms;
  }

  static final RegExp _wordPattern = RegExp(r"[A-Za-z]+(?:['’-][A-Za-z]+)*");

  /// 获取指定日期的学习时长（秒），由毫秒真值转换。
  Future<int> getStudyTime(DateTime date) async {
    final record = await _afterWrites(() => _dao.getByDate(date));
    if (record == null) return 0;
    return _durationSeconds(record.studyTimeMilliseconds);
  }

  /// 获取今日学习时长（秒）
  Future<int> getTodayStudyTime() => getStudyTime(DateTime.now());

  /// 指定日期是否已完成每日学习目标打卡
  Future<bool> isDailyGoalCheckedIn(DateTime date) async {
    final record = await _afterWrites(() => _dao.getByDate(date));
    return record?.checkedInGoalMinutes != null;
  }

  /// 获取连续学习天数（streak）
  ///
  /// 从昨天往回数连续有学习记录的天数，今天有学习则 +1。
  Future<int> getStudyStreak({DateTime? now}) {
    return _afterWrites(() => _dao.getStreak(now: now));
  }

  /// 获取过去 7 天每天的学习时长（秒）
  ///
  /// 返回长度为 7 的列表，索引 0 = 6 天前，索引 6 = 今天。
  Future<List<int>> getWeeklyStudyTimes({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final records = await _afterWrites(() => _dao.getBetween(start, today));

    // 按日期建立查找表
    final Map<int, int> dayMap = {};
    for (final r in records) {
      final key = _dayKey(r.date);
      dayMap[key] = _durationSeconds(r.studyTimeMilliseconds);
    }

    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(dayMap[_dayKey(date)] ?? 0);
    }
    return result;
  }

  /// 获取本周一至今的累计学习时长（秒）
  Future<int> getWeekTotalStudyTime({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final daysSinceMonday = today.weekday - 1;
    final monday = today.subtract(Duration(days: daysSinceMonday));
    final records = await _afterWrites(() => _dao.getBetween(monday, today));

    int total = 0;
    for (final r in records) {
      total += _durationSeconds(r.studyTimeMilliseconds);
    }
    return total;
  }

  // ========== 输入词数 ==========

  /// 获取指定日期的输入词数
  Future<int> getInputWords(DateTime date) async {
    final record = await _afterWrites(() => _dao.getByDate(date));
    return record?.inputWords ?? 0;
  }

  /// 获取今日输入词数
  Future<int> getTodayInputWords() => getInputWords(DateTime.now());

  // ========== 输出词数 ==========

  /// 获取指定日期的输出词数
  Future<int> getOutputWords(DateTime date) async {
    final record = await _afterWrites(() => _dao.getByDate(date));
    return record?.outputWords ?? 0;
  }

  /// 获取今日输出词数
  Future<int> getTodayOutputWords() => getOutputWords(DateTime.now());

  // ========== 输入时间（秒） ==========

  /// 获取指定日期的输入时间（秒）
  Future<int> getInputTime(DateTime date) async {
    final record = await _afterWrites(() => _dao.getByDate(date));
    if (record == null) return 0;
    return _durationSeconds(record.inputTimeMilliseconds);
  }

  /// 获取今日输入时间（秒）
  Future<int> getTodayInputTime() => getInputTime(DateTime.now());

  /// 获取过去 7 天每天的输入时间（秒）
  ///
  /// 返回长度为 7 的列表，索引 0 = 6 天前，索引 6 = 今天。
  Future<List<int>> getWeeklyInputTimes({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final records = await _afterWrites(() => _dao.getBetween(start, today));

    final Map<int, int> dayMap = {};
    for (final r in records) {
      dayMap[_dayKey(r.date)] = _durationSeconds(r.inputTimeMilliseconds);
    }

    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(dayMap[_dayKey(date)] ?? 0);
    }
    return result;
  }

  // ========== 输出时间（秒） ==========

  /// 获取指定日期的输出时间（秒）
  Future<int> getOutputTime(DateTime date) async {
    final record = await _afterWrites(() => _dao.getByDate(date));
    if (record == null) return 0;
    return _durationSeconds(record.outputTimeMilliseconds);
  }

  /// 获取今日输出时间（秒）
  Future<int> getTodayOutputTime() => getOutputTime(DateTime.now());

  /// 获取过去 7 天每天的输出时间（秒）
  ///
  /// 返回长度为 7 的列表，索引 0 = 6 天前，索引 6 = 今天。
  Future<List<int>> getWeeklyOutputTimes({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final records = await _afterWrites(() => _dao.getBetween(start, today));

    final Map<int, int> dayMap = {};
    for (final r in records) {
      dayMap[_dayKey(r.date)] = _durationSeconds(r.outputTimeMilliseconds);
    }

    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(dayMap[_dayKey(date)] ?? 0);
    }
    return result;
  }

  // ========== 阶段明细查询 ==========

  /// 按阶段累加日期范围（含首尾）的原始秒数，按枚举顺序输出。
  /// 格式化和显示裁剪留给弹窗，避免逐日取整造成累计误差。
  Future<List<DailyStageStudyRecordData>> getStageBreakdownInRange(
    DateTime start,
    DateTime end,
  ) async {
    final records = await _afterWrites(
      () => _stageDao.getInDateRange(start, end),
    );
    final totals = <StudyStage, DailyStageStudyRecordData>{};
    for (final record in records) {
      final previous = totals[record.stage];
      totals[record.stage] = DailyStageStudyRecordData(
        stage: record.stage,
        studyTimeSeconds:
            (previous?.studyTimeSeconds ?? 0) +
            _durationSeconds(record.studyTimeMilliseconds),
        inputTimeSeconds:
            (previous?.inputTimeSeconds ?? 0) +
            _durationSeconds(record.inputTimeMilliseconds),
        outputTimeSeconds:
            (previous?.outputTimeSeconds ?? 0) +
            _durationSeconds(record.outputTimeMilliseconds),
      );
    }
    return [
      for (final stage in StudyStage.values)
        if (totals[stage] case final record?) record,
    ];
  }

  /// 获取指定日期的阶段明细列表
  ///
  /// 返回该日期所有有记录的阶段，按阶段序号排序。
  /// 时长优先使用累计毫秒字段，兼容没有毫秒数据的旧记录。
  /// 无记录时返回空列表。
  Future<List<DailyStageStudyRecordData>> getStageBreakdown(
    DateTime date,
  ) async {
    final records = await _afterWrites(() => _stageDao.getByDate(date));
    return records
        .map(
          (r) => DailyStageStudyRecordData(
            stage: r.stage,
            studyTimeSeconds: _durationSeconds(r.studyTimeMilliseconds),
            inputTimeSeconds: _durationSeconds(r.inputTimeMilliseconds),
            outputTimeSeconds: _durationSeconds(r.outputTimeMilliseconds),
          ),
        )
        .toList();
  }

  /// 获取指定日期的总量记录（用于弹窗回退显示）
  Future<DailyTotalData?> getDayTotal(DateTime date) async {
    final record = await _afterWrites(() => _dao.getByDate(date));
    if (record == null) return null;
    return DailyTotalData(
      studyTimeSeconds: _durationSeconds(record.studyTimeMilliseconds),
      inputTimeSeconds: _durationSeconds(record.inputTimeMilliseconds),
      outputTimeSeconds: _durationSeconds(record.outputTimeMilliseconds),
    );
  }

  /// 截断时间部分，只保留日期
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  int _durationSeconds(int milliseconds) => milliseconds ~/ 1000;

  /// 将日期转换为用于 Map key 的整数（yyyymmdd）
  int _dayKey(DateTime dt) => dt.year * 10000 + dt.month * 100 + dt.day;
}

/// 阶段明细数据（从 DAO 记录映射的简单值对象）
class DailyStageStudyRecordData {
  final StudyStage stage;
  final int studyTimeSeconds;
  final int inputTimeSeconds;
  final int outputTimeSeconds;

  const DailyStageStudyRecordData({
    required this.stage,
    required this.studyTimeSeconds,
    required this.inputTimeSeconds,
    required this.outputTimeSeconds,
  });
}

/// 每日总量数据（用于弹窗回退显示旧数据）
class DailyTotalData {
  final int studyTimeSeconds;
  final int inputTimeSeconds;
  final int outputTimeSeconds;

  const DailyTotalData({
    required this.studyTimeSeconds,
    required this.inputTimeSeconds,
    required this.outputTimeSeconds,
  });
}

final class _StudyWriteFailure {
  const _StudyWriteFailure(this.id, this.error, this.stackTrace);

  final int id;
  final Object error;
  final StackTrace stackTrace;
}
