// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_history_dao.dart';

// ignore_for_file: type=lint
mixin _$LookupHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $LookupHistoriesTable get lookupHistories => attachedDatabase.lookupHistories;
  LookupHistoryDaoManager get managers => LookupHistoryDaoManager(this);
}

class LookupHistoryDaoManager {
  final _$LookupHistoryDaoMixin _db;
  LookupHistoryDaoManager(this._db);
  $$LookupHistoriesTableTableManager get lookupHistories =>
      $$LookupHistoriesTableTableManager(
        _db.attachedDatabase,
        _db.lookupHistories,
      );
}
