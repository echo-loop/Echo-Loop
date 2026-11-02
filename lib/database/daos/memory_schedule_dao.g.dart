// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_schedule_dao.dart';

// ignore_for_file: type=lint
mixin _$MemoryScheduleDaoMixin on DatabaseAccessor<AppDatabase> {
  $MemorySchedulesTable get memorySchedules => attachedDatabase.memorySchedules;
  $MemoryReviewEventsTable get memoryReviewEvents =>
      attachedDatabase.memoryReviewEvents;
  MemoryScheduleDaoManager get managers => MemoryScheduleDaoManager(this);
}

class MemoryScheduleDaoManager {
  final _$MemoryScheduleDaoMixin _db;
  MemoryScheduleDaoManager(this._db);
  $$MemorySchedulesTableTableManager get memorySchedules =>
      $$MemorySchedulesTableTableManager(
        _db.attachedDatabase,
        _db.memorySchedules,
      );
  $$MemoryReviewEventsTableTableManager get memoryReviewEvents =>
      $$MemoryReviewEventsTableTableManager(
        _db.attachedDatabase,
        _db.memoryReviewEvents,
      );
}
