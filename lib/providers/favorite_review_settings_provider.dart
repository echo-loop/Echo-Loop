/// 收藏复习共用调度设置的持久化状态。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../features/user_preferences/domain/user_preferences_sync_events.dart';
import '../models/favorite_review_settings.dart';

const _favoriteReviewSettingsKey = 'favorite_review_settings_v1';
const _bookmarkReviewSettingsKey = 'bookmark_review_settings_v1';
const _favoriteVocabularyReviewSettingsKey =
    'favorite_vocabulary_review_settings_v1';

final favoriteReviewSettingsProvider =
    NotifierProvider<FavoriteReviewSettingsNotifier, FavoriteReviewSettings>(
      FavoriteReviewSettingsNotifier.new,
    );

class FavoriteReviewSettingsNotifier extends Notifier<FavoriteReviewSettings> {
  int _loadGeneration = 0;

  @override
  FavoriteReviewSettings build() {
    final generation = ++_loadGeneration;
    try {
      return _readFromPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      _loadFromPreferences(generation);
      return const FavoriteReviewSettings();
    }
  }

  FavoriteReviewSettings _readFromPrefs(SharedPreferences prefs) {
    final raw =
        prefs.getString(_favoriteReviewSettingsKey) ??
        prefs.getString(_bookmarkReviewSettingsKey) ??
        prefs.getString(_favoriteVocabularyReviewSettingsKey);
    if (raw == null) return const FavoriteReviewSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final settings = FavoriteReviewSettings.fromJson(decoded);
        if (!prefs.containsKey(_favoriteReviewSettingsKey)) {
          unawaited(
            prefs
                .setString(_favoriteReviewSettingsKey, jsonEncode(settings))
                .then<void>(
                  (_) {},
                  onError: (Object error) {
                    debugPrint(
                      'FavoriteReviewSettings: legacy migration failed: $error',
                    );
                  },
                ),
          );
        }
        return settings;
      }
    } catch (error) {
      debugPrint('FavoriteReviewSettings: load failed: $error');
    }
    return const FavoriteReviewSettings();
  }

  void reloadFromPrefs() {
    final generation = ++_loadGeneration;
    try {
      state = _readFromPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      _loadFromPreferences(generation);
    }
  }

  Future<void> _loadFromPreferences(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (generation != _loadGeneration) return;
    state = _readFromPrefs(prefs);
  }

  Future<void> update(FavoriteReviewSettings settings) async {
    _loadGeneration++;
    state = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favoriteReviewSettingsKey, jsonEncode(settings));
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (error) {
      debugPrint('FavoriteReviewSettings: save failed: $error');
    }
  }
}
