// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learned_word_form_dao.dart';

// ignore_for_file: type=lint
mixin _$LearnedWordFormDaoMixin on DatabaseAccessor<AppDatabase> {
  $LearnedWordFormsTable get learnedWordForms =>
      attachedDatabase.learnedWordForms;
  LearnedWordFormDaoManager get managers => LearnedWordFormDaoManager(this);
}

class LearnedWordFormDaoManager {
  final _$LearnedWordFormDaoMixin _db;
  LearnedWordFormDaoManager(this._db);
  $$LearnedWordFormsTableTableManager get learnedWordForms =>
      $$LearnedWordFormsTableTableManager(
        _db.attachedDatabase,
        _db.learnedWordForms,
      );
}
