/// 收藏句 FSRS 复习设置状态管理。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark_review_settings.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../features/user_preferences/domain/user_preferences_sync_events.dart';

const _bookmarkReviewSettingsKey = 'bookmark_review_settings_v1';

final bookmarkReviewSettingsProvider =
    NotifierProvider<BookmarkReviewSettingsNotifier, BookmarkReviewSettings>(
      BookmarkReviewSettingsNotifier.new,
    );

class BookmarkReviewSettingsNotifier extends Notifier<BookmarkReviewSettings> {
  int _loadGeneration = 0;

  @override
  BookmarkReviewSettings build() {
    final generation = ++_loadGeneration;
    try {
      return _readFromPrefs(ref.read(sharedPreferencesProvider));
    } on UnimplementedError {
      _loadFromPreferences(generation);
      return const BookmarkReviewSettings();
    }
  }

  BookmarkReviewSettings _readFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(_bookmarkReviewSettingsKey);
    if (raw == null) return const BookmarkReviewSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return BookmarkReviewSettings.fromJson(decoded);
      }
    } catch (error) {
      debugPrint('BookmarkReviewSettings: load failed: $error');
    }
    return const BookmarkReviewSettings();
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

  Future<void> update(BookmarkReviewSettings settings) async {
    _loadGeneration++;
    state = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _bookmarkReviewSettingsKey,
        jsonEncode(settings.toJson()),
      );
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (error) {
      debugPrint('BookmarkReviewSettings: save failed: $error');
    }
  }
}
