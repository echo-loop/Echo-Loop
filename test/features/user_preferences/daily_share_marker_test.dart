import 'dart:async';

import 'package:echo_loop/features/daily_goal_check_in/providers/daily_check_in_share_presentation_provider.dart';
import 'package:echo_loop/features/user_preferences/data/local_user_preferences_store.dart';
import 'package:echo_loop/features/user_preferences/domain/user_preferences_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const field = LocalUserPreferencesStore.dailyShareDateField;

  test('展示后立即落盘，首次同步的旧快照也不能覆盖本次展示', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gate = Completer<void>();
    final presentation = DailyShareDialogPresentation(
      preferences: prefs,
      currentUserId: () => 'a',
      synchronize: (_) => gate.future,
    );
    final key = LocalUserPreferencesStore.dailyShareDateKey;
    expect(key, 'daily_check_in_share_shown_date');
    presentation.didShow('a', '2026-11-09');
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(key), '2026-11-09');
    await prefs.remove(key);
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(key), '2026-11-09');
  });

  test('删除展示日期后，同一实例立即允许再次自动展示', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presentation = DailyShareDialogPresentation(
      preferences: prefs,
      currentUserId: () => 'a',
      synchronize: (_) async {},
    );
    presentation.didShow('a', '2026-11-09');
    await Future<void>.delayed(Duration.zero);
    expect(presentation.canAutoShow('a', '2026-11-09'), isFalse);
    await prefs.remove(LocalUserPreferencesStore.dailyShareDateKey);
    expect(presentation.canAutoShow('a', '2026-11-09'), isTrue);
  });

  test('自动判断只读取当前账号本地标记，不启动或等待同步', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var currentUserId = 'a';
    var syncCalls = 0;
    final presentation = DailyShareDialogPresentation(
      preferences: prefs,
      currentUserId: () => currentUserId,
      synchronize: (_) {
        syncCalls++;
        return Completer<void>().future;
      },
    );
    expect(presentation.canAutoShow('a', '2026-11-09'), isTrue);
    expect(syncCalls, 0);
    await prefs.setString(
      LocalUserPreferencesStore.dailyShareDateKey,
      '2026-11-09',
    );
    expect(presentation.canAutoShow('a', '2026-11-09'), isFalse);
    currentUserId = 'b';
    expect(presentation.canAutoShow('a', '2026-11-10'), isFalse);
    expect(presentation.canAutoShow('b', '2026-11-09'), isFalse);
    expect(syncCalls, 0);
  });

  test('日期合并单向前进，旧客户端缺失字段不清除云端日期', () {
    final base = UserPreferencesDocument({
      'learning': {field: '2026-11-06'},
    });
    final remote = UserPreferencesDocument({
      'learning': {field: '2026-11-08'},
    });
    final local = UserPreferencesDocument({
      'learning': {field: '2026-11-07'},
    });
    final result = UserPreferencesDocument.mergeLocalChanges(
      base: base,
      local: local,
      remote: remote,
    );
    expect(result.preferences['learning'], {field: '2026-11-08'});
    final oldClient = UserPreferencesDocument.mergeLocalChanges(
      base: base,
      local: UserPreferencesDocument.empty,
      remote: remote,
    );
    expect(oldClient.preferences['learning'], {field: '2026-11-08'});
    expect(isValidPreferenceDate('2026-02-30'), isFalse);
    expect(isValidPreferenceDate('2026-11-08'), isTrue);
  });

  test('分享日期无需额外账号标记即可捕获和恢复，缺失字段清除本地日期', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserPreferencesStore(prefs);
    await store.apply(
      UserPreferencesDocument({
        'learning': {field: '2026-11-08'},
      }),
    );
    expect(
      store.capture().preferences['learning'],
      containsPair(field, '2026-11-08'),
    );
    await store.apply(
      UserPreferencesDocument({
        'learning': {field: '2026-11-07'},
      }),
    );
    expect(
      prefs.getString(LocalUserPreferencesStore.dailyShareDateKey),
      '2026-11-07',
    );
    await store.apply(UserPreferencesDocument.empty);
    expect(store.capture().preferences['learning'], isNot(contains(field)));
  });
}
