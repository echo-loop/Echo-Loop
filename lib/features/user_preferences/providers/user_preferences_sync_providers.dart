import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../providers/audio_list_settings_provider.dart';
import '../../../providers/bookmark_review_settings_provider.dart';
import '../../../providers/blind_listen_prefs_provider.dart';
import '../../../providers/difficult_practice_prefs_provider.dart';
import '../../../providers/dictionary/dictionary_settings_provider.dart';
import '../../../providers/favorite_review_settings_provider.dart';
import '../../../providers/intensive_listen_prefs_provider.dart';
import '../../../providers/learning_settings_provider.dart';
import '../../../providers/reminder_settings_provider.dart';
import '../../../providers/retell_prefs_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/backend_dio.dart';
import '../../../services/runtime_endpoint_router.dart';
import '../data/local_user_preferences_store.dart';
import '../data/user_preferences_api.dart';
import '../data/user_preferences_sync_service.dart';
import '../domain/user_preferences_sync_events.dart';

final userPreferencesSyncServiceProvider = Provider<UserPreferencesSyncService>(
  (ref) {
    final preferences = ref.read(sharedPreferencesProvider);
    final local = LocalUserPreferencesStore(preferences);
    final dio = createAuthenticatedBackendDio(
      tokenCoordinator: ref.read(supabaseTokenCoordinatorProvider),
      endpointRouter: runtimeEndpointRouter,
      apiLogTag: 'USER_PREFERENCES',
    );
    final service = UserPreferencesSyncService(
      remote: UserPreferencesApi(dio),
      local: local,
      preferences: preferences,
      apply: (document) async {
        await local.apply(document);
        await Future.wait<void>([
          ref.read(appSettingsProvider.notifier).reloadFromPrefs(),
          Future<void>.sync(
            () => ref.read(learningSettingsProvider.notifier).reloadFromPrefs(),
          ),
          Future<void>.sync(
            () => ref
                .read(intensiveListenPrefsProvider.notifier)
                .reloadFromPrefs(),
          ),
          Future<void>.sync(
            () => ref.read(blindListenPrefsProvider.notifier).reloadFromPrefs(),
          ),
          Future<void>.sync(
            () => ref.read(retellPrefsProvider.notifier).reloadFromPrefs(),
          ),
          Future<void>.sync(
            () => ref
                .read(difficultPracticePrefsProvider.notifier)
                .reloadFromPrefs(),
          ),
          Future<void>.sync(
            () => ref
                .read(bookmarkReviewSettingsProvider.notifier)
                .reloadFromPrefs(),
          ),
          Future<void>.sync(
            () => ref
                .read(favoriteReviewSettingsProvider.notifier)
                .reloadFromPrefs(),
          ),
          Future<void>.sync(
            () => ref
                .read(dictionarySettingsNotifierProvider.notifier)
                .reloadFromPrefs(),
          ),
          Future<void>.sync(
            () => ref
                .read(reminderSettingsNotifierProvider.notifier)
                .reloadFromPrefs(),
          ),
          Future<void>.sync(
            () =>
                ref.read(audioListSettingsProvider.notifier).reloadFromPrefs(),
          ),
        ]);
      },
    );
    final changes = userPreferencesSyncEvents.changes.listen((_) {
      service.onLocalPreferenceChanged();
    });
    ref.onDispose(() {
      unawaited(changes.cancel());
      service.dispose();
      dio.close(force: true);
    });
    return service;
  },
);
