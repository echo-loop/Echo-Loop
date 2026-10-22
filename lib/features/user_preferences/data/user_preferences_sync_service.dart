import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_logger.dart';
import '../domain/user_preferences_document.dart';
import 'local_user_preferences_store.dart';
import 'user_preferences_api.dart';

typedef ApplyUserPreferences =
    Future<void> Function(UserPreferencesDocument document);

class UserPreferencesSyncService {
  UserPreferencesSyncService({
    required UserPreferencesRemoteDataSource remote,
    required LocalUserPreferencesStore local,
    required SharedPreferences preferences,
    required ApplyUserPreferences apply,
    Duration debounce = const Duration(milliseconds: 500),
  }) : _remote = remote,
       _local = local,
       _metadata = _UserPreferencesSyncMetadata(preferences),
       _apply = apply,
       _debounceDuration = debounce;

  final UserPreferencesRemoteDataSource _remote;
  final LocalUserPreferencesStore _local;
  final _UserPreferencesSyncMetadata _metadata;
  final ApplyUserPreferences _apply;
  final Duration _debounceDuration;

  Timer? _debounceTimer;
  String? _userId;
  int _identityGeneration = 0;
  int _localChangeGeneration = 0;
  bool _running = false;
  bool _syncAgain = false;
  bool _disposed = false;
  Future<void> _pendingWrites = Future<void>.value();
  Future<void> _applyQueue = Future<void>.value();

  /// 绑定已确认的 Supabase 用户身份；切换账号时隔离两边的本地快照。
  Future<void> onSessionChanged(String? userId) async {
    if (_disposed || userId == _userId) {
      if (userId != null && !_disposed) unawaited(synchronize());
      return;
    }

    final generation = ++_identityGeneration;
    final previousUserId = _userId;
    _userId = userId;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (previousUserId != null) {
      await _pendingWrites;
      await _capturePending(previousUserId);
      final previousRecord = _metadata.recordFor(previousUserId);
      await _metadata.saveRecord(
        previousUserId,
        previousRecord.copyWith(localSnapshot: _local.capture()),
      );
    }
    if (!_isCurrent(userId, generation) || userId == null) return;

    final lastUserId = _metadata.activeUserId;
    if (lastUserId != null && lastUserId != userId) {
      // SharedPreferences 是设备级存储。账号切换先清回默认值，避免把前一账号的
      // 本地偏好或未同步值当成新账号的初始快照。
      final accountRecord = _metadata.recordFor(userId);
      await _applyDocument(
        accountRecord.localSnapshot ?? UserPreferencesDocument.empty,
        userId: userId,
        generation: generation,
      );
      if (!_isCurrent(userId, generation)) return;
    }
    await _metadata.setActiveUser(userId);
    if (!_isCurrent(userId, generation)) return;
    await synchronize();
  }

  /// 用户主动修改本地偏好后调用；未登录时只保留设备本地行为。
  void onLocalPreferenceChanged() {
    if (_disposed) return;
    _localChangeGeneration++;
    final userId = _userId;
    if (userId == null) return;

    final generation = _identityGeneration;
    _pendingWrites = _pendingWrites
        .then((_) async {
          if (_isCurrent(userId, generation)) await _capturePending(userId);
        })
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.log(
            'UserPreferencesSync',
            '保存待同步偏好失败: $error\n$stackTrace',
          );
        });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () => unawaited(synchronize()));
  }

  /// 应用回到前台时拉取其它设备的最新偏好，并尝试发送待同步修改。
  Future<void> onAppResumed() => synchronize();

  Future<void> synchronize() async {
    final userId = _userId;
    if (_disposed || userId == null) return;
    if (_running) {
      _syncAgain = true;
      return;
    }

    _running = true;
    final generation = _identityGeneration;
    try {
      do {
        _syncAgain = false;
        await _synchronizeOnce(userId, generation);
      } while (_syncAgain && _isCurrent(userId, generation));
    } on Object catch (error, stackTrace) {
      AppLogger.log(
        'UserPreferencesSync',
        '同步偏好失败，保留本地状态并等待后续重试: $error\n$stackTrace',
      );
    } finally {
      _running = false;
      if (_syncAgain && !_disposed) {
        _syncAgain = false;
        unawaited(synchronize());
      }
    }
  }

  Future<void> _synchronizeOnce(String userId, int generation) async {
    await _pendingWrites;
    if (!_isCurrent(userId, generation)) return;

    var record = _metadata.recordFor(userId);
    final localBeforeGet = _local.capture();
    if (record.initialLocal == null && record.base == null) {
      record = record.copyWith(initialLocal: localBeforeGet);
      await _metadata.saveRecord(userId, record);
    }

    // 捕捉进程中断前尚未来得及写 pending 的偏好变化。
    final currentBeforeGet = _local.capture();
    final baseBeforeGet = record.base;
    if (baseBeforeGet != null && record.pending == null) {
      if (UserPreferencesDocument.hasLocalChanges(
        base: baseBeforeGet,
        local: currentBeforeGet,
      )) {
        record = record.copyWith(pending: currentBeforeGet);
        await _metadata.saveRecord(userId, record);
      }
    }

    final localChangeAtGet = _localChangeGeneration;
    UserPreferencesApiResult current;
    try {
      final knownRevision = record.base == null ? null : record.revision;
      current = await _remote.getCurrent(knownRevision: knownRevision);
      if (current.notModified) {
        final savedBase = record.base;
        if (savedBase == null || record.revision != current.revision) {
          AppLogger.log('UserPreferencesSync', '收到无法匹配本地基线的 304，改为完整 GET');
          current = await _remote.getCurrent();
          if (current.notModified) {
            throw StateError('Unconditional preference GET returned 304');
          }
        } else {
          current = UserPreferencesApiResult(
            document: savedBase,
            revision: current.revision,
          );
        }
      }
    } on Object catch (error, stackTrace) {
      AppLogger.log(
        'UserPreferencesSync',
        '拉取偏好失败，保留本地值并等待后续重试: $error\n$stackTrace',
      );
      return;
    }
    if (!_isCurrent(userId, generation)) return;

    await _pendingWrites;
    if (!_isCurrent(userId, generation)) return;
    record = _metadata.recordFor(userId);
    final localNow = _local.capture();
    final serverDocument = current.document ?? UserPreferencesDocument.empty;

    UserPreferencesDocument desired;
    UserPreferencesDocument conflictBase = serverDocument;
    final savedBase = record.base;
    if (savedBase == null) {
      final initialLocal = record.initialLocal ?? localBeforeGet;
      if (current.document == null) {
        // 没有云端快照时，当前设备偏好负责初始化该账号；若并发设备先创建，
        // 冲突合并只把本次 GET 后的本地改动视为本机意图。
        desired = localNow;
        conflictBase = initialLocal;
      } else {
        // 新设备的已有值服从云端；只保留 GET 发出后用户新做的修改。
        desired = UserPreferencesDocument.mergeLocalChanges(
          base: initialLocal,
          local: localNow,
          remote: serverDocument,
        );
        if (_localChangeGeneration == localChangeAtGet &&
            !UserPreferencesDocument.hasLocalChanges(
              base: initialLocal,
              local: localNow,
            )) {
          desired = serverDocument;
        }
      }
    } else {
      if (current.document == null) {
        // 云端记录被清除时，以本机最后保存的偏好重新初始化；若期间又有设备
        // 写入，只有相对旧基线改变过的本机字段才覆盖云端。
        desired = record.pending ?? localNow;
        conflictBase = savedBase;
      } else {
        final localToMerge = record.pending ?? localNow;
        desired = UserPreferencesDocument.mergeLocalChanges(
          base: savedBase,
          local: localToMerge,
          remote: serverDocument,
        );
      }
    }

    if (!_isCurrent(userId, generation)) return;
    if (_documentsEqual(desired, serverDocument) && current.document != null) {
      await _applyDocument(
        serverDocument,
        userId: userId,
        generation: generation,
      );
      if (!_isCurrent(userId, generation)) return;
      final baseline = _local.capture();
      await _metadata.saveRecord(
        userId,
        _UserPreferencesAccountRecord(
          base: baseline,
          revision: current.revision,
          localSnapshot: baseline,
        ),
      );
      return;
    }

    await _applyDocument(desired, userId: userId, generation: generation);
    if (!_isCurrent(userId, generation)) return;
    var pendingDocument = _local.capture();
    var revision = current.revision;
    UserPreferencesDocument? acceptedDocument;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _remote.replace(
          document: desired,
          expectedRevision: revision,
        );
        acceptedDocument = response.document ?? desired;
        revision = response.revision;
        break;
      } on UserPreferencesConflict catch (conflict) {
        if (!_isCurrent(userId, generation)) return;
        revision = conflict.current.revision;
        final conflictDocument =
            conflict.current.document ?? UserPreferencesDocument.empty;
        await _pendingWrites;
        final latestLocal = _local.capture();
        desired = UserPreferencesDocument.mergeLocalChanges(
          base: conflictBase,
          local: latestLocal,
          remote: conflictDocument,
        );
        conflictBase = conflictDocument;
        if (_documentsEqual(desired, conflictDocument)) {
          await _applyDocument(
            conflictDocument,
            userId: userId,
            generation: generation,
          );
          if (!_isCurrent(userId, generation)) return;
          acceptedDocument = conflictDocument;
          break;
        }
        if (attempt == 2) {
          pendingDocument = latestLocal;
          await _metadata.saveRecord(
            userId,
            _UserPreferencesAccountRecord(
              base: record.base,
              revision: record.revision,
              pending: pendingDocument,
              initialLocal: record.initialLocal,
              localSnapshot: pendingDocument,
            ),
          );
          AppLogger.log(
            'UserPreferencesSync',
            '偏好冲突重试达到上限，保留待同步快照 userId=$userId',
          );
          return;
        }
        await _applyDocument(desired, userId: userId, generation: generation);
        if (!_isCurrent(userId, generation)) return;
        pendingDocument = _local.capture();
      } on Object catch (error, stackTrace) {
        if (!_isCurrent(userId, generation)) return;
        pendingDocument = _local.capture();
        await _metadata.saveRecord(
          userId,
          _UserPreferencesAccountRecord(
            base: record.base,
            revision: record.revision,
            pending: pendingDocument,
            initialLocal: record.initialLocal,
            localSnapshot: pendingDocument,
          ),
        );
        AppLogger.log(
          'UserPreferencesSync',
          '推送偏好失败，已保留待同步快照: $error\n$stackTrace',
        );
        return;
      }
    }

    if (!_isCurrent(userId, generation)) return;
    final accepted = acceptedDocument;
    if (accepted == null) return;
    final latestLocal = _local.capture();
    final hasChangesAfterPut = UserPreferencesDocument.hasLocalChanges(
      base: accepted,
      local: latestLocal,
    );
    await _metadata.saveRecord(
      userId,
      _UserPreferencesAccountRecord(
        base: accepted,
        revision: revision,
        pending: hasChangesAfterPut ? latestLocal : null,
        localSnapshot: latestLocal,
      ),
    );
    if (hasChangesAfterPut) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounceDuration, () => unawaited(synchronize()));
    }
  }

  Future<void> _applyDocument(
    UserPreferencesDocument document, {
    required String userId,
    required int generation,
  }) async {
    final operation = _applyQueue.then((_) async {
      if (!_isCurrent(userId, generation)) return;
      await _apply(document);
    });
    _applyQueue = operation.catchError((Object error, StackTrace stackTrace) {
      AppLogger.log('UserPreferencesSync', '应用本地偏好失败: $error\n$stackTrace');
    });
    await operation;
  }

  Future<void> _capturePending(String userId) async {
    final record = _metadata.recordFor(userId);
    final local = _local.capture();
    final base = record.base;
    if (base != null) {
      final hasChanges = UserPreferencesDocument.hasLocalChanges(
        base: base,
        local: local,
      );
      await _metadata.saveRecord(
        userId,
        record.copyWith(pending: hasChanges ? local : null),
      );
    } else {
      final initial = record.initialLocal ?? local;
      final hasChanges = UserPreferencesDocument.hasLocalChanges(
        base: initial,
        local: local,
      );
      await _metadata.saveRecord(
        userId,
        record.copyWith(
          initialLocal: initial,
          pending: hasChanges ? local : null,
        ),
      );
    }
  }

  bool _isCurrent(String? userId, int generation) =>
      !_disposed && _identityGeneration == generation && _userId == userId;

  static bool _documentsEqual(
    UserPreferencesDocument first,
    UserPreferencesDocument second,
  ) => const DeepCollectionEquality().equals(first.toJson(), second.toJson());

  void dispose() {
    _disposed = true;
    _identityGeneration++;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}

class _UserPreferencesSyncMetadata {
  _UserPreferencesSyncMetadata(this._preferences) {
    final raw = _preferences.getString(
      LocalUserPreferencesStore.syncMetadataKey,
    );
    if (raw == null) return;
    try {
      final decoded = _stringMap(jsonDecode(raw));
      if (decoded == null) return;
      final activeUserId = decoded['activeUserId'];
      _activeUserId = activeUserId is String ? activeUserId : null;
      final rawAccounts = _stringMap(decoded['accounts']);
      if (rawAccounts == null) return;
      for (final entry in rawAccounts.entries) {
        try {
          final account = _stringMap(entry.value);
          if (account == null) continue;
          final record = _UserPreferencesAccountRecord.fromJson(account);
          _records[entry.key] = record;
        } on Object catch (error) {
          AppLogger.log(
            'UserPreferencesSync',
            '跳过损坏的偏好同步记录 userId=${entry.key}: $error',
          );
        }
      }
    } on Object catch (error) {
      AppLogger.log('UserPreferencesSync', '同步元数据损坏，重新初始化: $error');
    }
  }

  final SharedPreferences _preferences;
  final Map<String, _UserPreferencesAccountRecord> _records = {};
  String? _activeUserId;
  Future<void> _writeQueue = Future<void>.value();

  String? get activeUserId => _activeUserId;

  _UserPreferencesAccountRecord recordFor(String userId) =>
      _records[userId] ?? const _UserPreferencesAccountRecord();

  Future<void> setActiveUser(String userId) async {
    _activeUserId = userId;
    await _enqueueWrite();
  }

  Future<void> saveRecord(
    String userId,
    _UserPreferencesAccountRecord record,
  ) async {
    _records[userId] = record;
    await _enqueueWrite();
  }

  Future<void> _enqueueWrite() {
    final encoded = jsonEncode({
      'activeUserId': _activeUserId,
      'accounts': {
        for (final entry in _records.entries) entry.key: entry.value.toJson(),
      },
    });
    final operation = _writeQueue.then((_) async {
      final saved = await _preferences.setString(
        LocalUserPreferencesStore.syncMetadataKey,
        encoded,
      );
      if (!saved) throw StateError('Unable to persist preference sync state');
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }
}

class _UserPreferencesAccountRecord {
  const _UserPreferencesAccountRecord({
    this.base,
    this.revision,
    this.pending,
    this.initialLocal,
    this.localSnapshot,
  });

  final UserPreferencesDocument? base;
  final int? revision;
  final UserPreferencesDocument? pending;
  final UserPreferencesDocument? initialLocal;
  final UserPreferencesDocument? localSnapshot;

  _UserPreferencesAccountRecord copyWith({
    UserPreferencesDocument? base,
    int? revision,
    UserPreferencesDocument? pending,
    UserPreferencesDocument? initialLocal,
    UserPreferencesDocument? localSnapshot,
  }) => _UserPreferencesAccountRecord(
    base: base ?? this.base,
    revision: revision ?? this.revision,
    pending: pending,
    initialLocal: initialLocal,
    localSnapshot: localSnapshot ?? this.localSnapshot,
  );

  Map<String, Object?> toJson() {
    final base = this.base;
    final revision = this.revision;
    final pending = this.pending;
    final initialLocal = this.initialLocal;
    final localSnapshot = this.localSnapshot;
    return {
      if (base != null) 'base': base.toJson(),
      if (revision != null) 'revision': revision,
      if (pending != null) 'pending': pending.toJson(),
      if (initialLocal != null) 'initialLocal': initialLocal.toJson(),
      if (localSnapshot != null) 'localSnapshot': localSnapshot.toJson(),
    };
  }

  static _UserPreferencesAccountRecord fromJson(Map<String, Object?> raw) {
    UserPreferencesDocument? documentValue(Object? value) =>
        value == null ? null : UserPreferencesDocument.fromJson(value);

    final rawRevision = raw['revision'];
    final revision =
        rawRevision is int && rawRevision >= 0 && rawRevision <= 2147483647
        ? rawRevision
        : null;

    return _UserPreferencesAccountRecord(
      base: documentValue(raw['base']),
      revision: revision,
      pending: documentValue(raw['pending']),
      initialLocal: documentValue(raw['initialLocal']),
      localSnapshot: documentValue(raw['localSnapshot']),
    );
  }
}

Map<String, Object?>? _stringMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) return null;
    result[key] = entry.value;
  }
  return result;
}
