import 'package:drift/drift.dart';

import 'memory_schedules.dart';

/// 只追加的记忆评分审计事件。
class MemoryReviewEvents extends Table {
  TextColumn get id => text()();
  TextColumn get scheduleId =>
      text().references(MemorySchedules, #id, onDelete: KeyAction.cascade)();
  IntColumn get sequence => integer()();
  TextColumn get operationId => text()();
  TextColumn get rating => text()();
  BoolColumn get isLapse => boolean()();
  DateTimeColumn get reviewedAt => dateTime()();
  IntColumn get responseTimeMs => integer().nullable()();
  TextColumn get profileId => text()();
  IntColumn get profileVersion => integer()();
  TextColumn get modelId => text()();
  IntColumn get modelStateVersion => integer()();
  DateTimeColumn get dueBefore => dateTime()();
  DateTimeColumn get dueAfter => dateTime()();
  IntColumn get scheduleRevisionAfter => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {scheduleId, sequence},
    {scheduleId, operationId},
  ];

  @override
  List<String> get customConstraints => const <String>[
    "CHECK (length(trim(id)) > 0)",
    'CHECK (sequence > 0)',
    "CHECK (rating IN ('again', 'hard', 'good', 'easy'))",
    'CHECK (is_lapse IN (0, 1))',
    'CHECK (profile_version > 0)',
    'CHECK (model_state_version > 0)',
    'CHECK (schedule_revision_after > 0)',
    'CHECK (response_time_ms IS NULL OR response_time_ms BETWEEN 0 AND 86400000)',
  ];
}
