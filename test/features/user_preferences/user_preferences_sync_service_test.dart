import 'dart:async';

import 'package:echo_loop/features/user_preferences/data/local_user_preferences_store.dart';
import 'package:echo_loop/features/user_preferences/data/user_preferences_api.dart';
import 'package:echo_loop/features/user_preferences/data/user_preferences_sync_service.dart';
import 'package:echo_loop/features/user_preferences/domain/user_preferences_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryLocalStore extends LocalUserPreferencesStore {
  _MemoryLocalStore(super.preferences, this.document);

  UserPreferencesDocument document;

  @override
  UserPreferencesDocument capture() => document;

  @override
  Future<void> apply(UserPreferencesDocument value) async {
    document = value;
  }
}

class _FakeRemote implements UserPreferencesRemoteDataSource {
  final gets = <UserPreferencesApiResult>[];
  final getRevisions = <int?>[];
  int failedGets = 0;
  Completer<void>? getGate;
  final puts = <({UserPreferencesDocument document, int expectedRevision})>[];
  final putResults = <Object>[];

  @override
  Future<UserPreferencesApiResult> getCurrent({int? knownRevision}) async {
    getRevisions.add(knownRevision);
    if (getGate != null) await getGate!.future;
    if (failedGets > 0) {
      failedGets--;
      throw StateError('offline');
    }
    if (gets.isEmpty) throw StateError('No scripted GET response');
    return gets.removeAt(0);
  }

  @override
  Future<UserPreferencesApiResult> replace({
    required UserPreferencesDocument document,
    required int expectedRevision,
  }) async {
    puts.add((document: document, expectedRevision: expectedRevision));
    final result = putResults.isEmpty
        ? UserPreferencesApiResult(document: document, revision: 1)
        : putResults.removeAt(0);
    if (result is UserPreferencesConflict) throw result;
    if (result is UserPreferencesApiResult) return result;
    throw StateError('Unexpected fake PUT result: $result');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('同账号并发绑定等待同一轮云同步，不提前读取展示标记', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final document = UserPreferencesDocument({
      'learning': {'dailyCheckInShareShownDate': '2026-11-08'},
    });
    final local = _MemoryLocalStore(prefs, document);
    final gate = Completer<void>();
    final remote = _FakeRemote()
      ..getGate = gate
      ..gets.add(UserPreferencesApiResult(document: document, revision: 1));
    final service = UserPreferencesSyncService(
      remote: remote,
      local: local,
      preferences: prefs,
      apply: local.apply,
    );
    addTearDown(service.dispose);
    final first = service.onSessionChanged('user-1');
    var completed = false;
    final second = service.onSessionChanged('user-1').then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    gate.complete();
    await Future.wait([first, second]);
    expect(remote.getRevisions, hasLength(1));
  });

  test('并发 synchronize 调用等待在途同步和合并刷新完成', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final document = UserPreferencesDocument({
      'appearance': {'themeMode': 'dark'},
    });
    final local = _MemoryLocalStore(prefs, document);
    final remote = _FakeRemote()
      ..gets.addAll(
        List.filled(
          3,
          UserPreferencesApiResult(document: document, revision: 1),
        ),
      );
    final service = UserPreferencesSyncService(
      remote: remote,
      local: local,
      preferences: prefs,
      apply: local.apply,
    );
    addTearDown(service.dispose);
    await service.onSessionChanged('user-1');
    final gate = Completer<void>();
    remote.getGate = gate;
    final first = service.synchronize();
    var completed = false;
    final second = service.synchronize().then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    gate.complete();
    await Future.wait([first, second]);
    expect(remote.getRevisions, hasLength(3));
  });

  test('first sync seeds the server when it has no snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final localDocument = UserPreferencesDocument({
      'appearance': {'themeMode': 'dark'},
    });
    final local = _MemoryLocalStore(prefs, localDocument);
    final remote = _FakeRemote()
      ..gets.add(const UserPreferencesApiResult(document: null, revision: 0));
    final service = UserPreferencesSyncService(
      remote: remote,
      local: local,
      preferences: prefs,
      apply: local.apply,
    );
    addTearDown(service.dispose);

    await service.onSessionChanged('user-1');

    expect(remote.puts, hasLength(1));
    expect(remote.puts.single.document.toJson(), localDocument.toJson());
    expect(remote.puts.single.expectedRevision, 0);
  });

  test(
    'concurrent first sync adopts the snapshot created by the other device',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localInitial = UserPreferencesDocument({
        'appearance': {'themeMode': 'system', 'locale': 'en'},
      });
      final remoteSnapshot = UserPreferencesDocument({
        'appearance': {'themeMode': 'dark', 'locale': 'zh-CN'},
      });
      final local = _MemoryLocalStore(prefs, localInitial);
      final remote = _FakeRemote()
        ..gets.add(const UserPreferencesApiResult(document: null, revision: 0))
        ..putResults.add(
          UserPreferencesConflict(
            UserPreferencesApiResult(document: remoteSnapshot, revision: 1),
          ),
        );
      final service = UserPreferencesSyncService(
        remote: remote,
        local: local,
        preferences: prefs,
        apply: local.apply,
      );
      addTearDown(service.dispose);

      await service.onSessionChanged('user-1');

      expect(local.document.toJson(), remoteSnapshot.toJson());
      expect(remote.puts, hasLength(1));
    },
  );

  test('304 reuses the saved snapshot without sending a PUT', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final baseline = UserPreferencesDocument({
      'appearance': {'themeMode': 'dark'},
    });
    final local = _MemoryLocalStore(prefs, baseline);
    final remote = _FakeRemote()
      ..gets.add(UserPreferencesApiResult(document: baseline, revision: 4))
      ..gets.add(
        const UserPreferencesApiResult(
          document: null,
          revision: 4,
          notModified: true,
        ),
      );
    final service = UserPreferencesSyncService(
      remote: remote,
      local: local,
      preferences: prefs,
      apply: local.apply,
    );
    addTearDown(service.dispose);

    await service.onSessionChanged('user-1');
    await service.onAppResumed();

    expect(remote.getRevisions, [null, 4]);
    expect(remote.puts, isEmpty);
    expect(local.document.toJson(), baseline.toJson());
  });

  test('offline keeps local preferences and retries on foreground', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final localDocument = UserPreferencesDocument({
      'appearance': {'themeMode': 'dark'},
    });
    final local = _MemoryLocalStore(prefs, localDocument);
    final remote = _FakeRemote()
      ..failedGets = 1
      ..gets.add(const UserPreferencesApiResult(document: null, revision: 0));
    final service = UserPreferencesSyncService(
      remote: remote,
      local: local,
      preferences: prefs,
      apply: local.apply,
    );
    addTearDown(service.dispose);

    await service.onSessionChanged('user-1');
    expect(local.document.toJson(), localDocument.toJson());
    expect(remote.puts, isEmpty);

    await service.onAppResumed();

    expect(remote.puts, hasLength(1));
    expect(remote.puts.single.document.toJson(), localDocument.toJson());
  });

  test('initial sync adopts an existing cloud snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = _MemoryLocalStore(
      prefs,
      UserPreferencesDocument({
        'appearance': {'themeMode': 'light'},
      }),
    );
    final cloud = UserPreferencesDocument({
      'appearance': {'themeMode': 'dark', 'locale': 'zh-CN'},
    });
    final remote = _FakeRemote()
      ..gets.add(UserPreferencesApiResult(document: cloud, revision: 1));
    final service = UserPreferencesSyncService(
      remote: remote,
      local: local,
      preferences: prefs,
      apply: local.apply,
    );
    addTearDown(service.dispose);

    await service.onSessionChanged('user-1');

    expect(local.document.toJson(), cloud.toJson());
    expect(remote.puts, isEmpty);
  });

  test(
    '412 merges only local field changes over the latest cloud snapshot',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final baseline = UserPreferencesDocument({
        'learning': {'autoSkipRetell': false, 'autoShowAiAnalysis': true},
      });
      final local = _MemoryLocalStore(prefs, baseline);
      final remote = _FakeRemote()
        ..gets.add(UserPreferencesApiResult(document: baseline, revision: 1));
      final service = UserPreferencesSyncService(
        remote: remote,
        local: local,
        preferences: prefs,
        apply: local.apply,
        debounce: const Duration(hours: 1),
      );
      addTearDown(service.dispose);
      await service.onSessionChanged('user-1');

      local.document = UserPreferencesDocument({
        'learning': {'autoSkipRetell': true, 'autoShowAiAnalysis': true},
      });
      final getSnapshot = UserPreferencesDocument({
        'learning': {'autoSkipRetell': false, 'autoShowAiAnalysis': false},
      });
      final conflictSnapshot = UserPreferencesDocument({
        'learning': {'autoSkipRetell': false, 'autoShowAiAnalysis': false},
        'serverOnly': {'kept': true},
      });
      remote.gets.add(
        UserPreferencesApiResult(document: getSnapshot, revision: 2),
      );
      remote.putResults.add(
        UserPreferencesConflict(
          UserPreferencesApiResult(document: conflictSnapshot, revision: 3),
        ),
      );
      remote.putResults.add(
        UserPreferencesApiResult(
          document: UserPreferencesDocument({
            'learning': {'autoSkipRetell': true, 'autoShowAiAnalysis': false},
            'serverOnly': {'kept': true},
          }),
          revision: 4,
        ),
      );
      service.onLocalPreferenceChanged();

      await service.synchronize();

      expect(remote.puts, hasLength(2));
      expect(remote.puts.last.expectedRevision, 3);
      expect(remote.puts.last.document.preferences['learning'], {
        'autoSkipRetell': true,
        'autoShowAiAnalysis': false,
      });
      expect(remote.puts.last.document.preferences['serverOnly'], {
        'kept': true,
      });
    },
  );

  test('switching accounts restores each account local snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final userA = UserPreferencesDocument({
      'appearance': {'themeMode': 'dark'},
    });
    final userB = UserPreferencesDocument({
      'appearance': {'themeMode': 'light'},
    });
    final local = _MemoryLocalStore(prefs, userA);
    final remote = _FakeRemote()
      ..gets.add(UserPreferencesApiResult(document: userA, revision: 1))
      ..gets.add(UserPreferencesApiResult(document: userB, revision: 1))
      ..gets.add(UserPreferencesApiResult(document: userA, revision: 1));
    final service = UserPreferencesSyncService(
      remote: remote,
      local: local,
      preferences: prefs,
      apply: local.apply,
    );
    addTearDown(service.dispose);

    await service.onSessionChanged('user-a');
    await service.onSessionChanged('user-b');
    expect(local.document.toJson(), userB.toJson());
    await service.onSessionChanged('user-a');
    expect(local.document.toJson(), userA.toJson());
  });
}
