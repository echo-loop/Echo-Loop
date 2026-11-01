/// 收藏词汇 FSRS 复习设置状态管理。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_vocabulary_review_settings.dart';

const _favoriteVocabularyReviewSettingsKey =
    'favorite_vocabulary_review_settings_v1';

final favoriteVocabularyReviewSettingsProvider =
    NotifierProvider<
      FavoriteVocabularyReviewSettingsNotifier,
      FavoriteVocabularyReviewSettings
    >(FavoriteVocabularyReviewSettingsNotifier.new);

class FavoriteVocabularyReviewSettingsNotifier
    extends Notifier<FavoriteVocabularyReviewSettings> {
  @override
  FavoriteVocabularyReviewSettings build() {
    _load();
    return const FavoriteVocabularyReviewSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_favoriteVocabularyReviewSettingsKey);
      if (raw != null) {
        state = FavoriteVocabularyReviewSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (error) {
      debugPrint('FavoriteVocabularyReviewSettings: load failed: $error');
    }
  }

  Future<void> update(FavoriteVocabularyReviewSettings settings) async {
    state = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _favoriteVocabularyReviewSettingsKey,
        jsonEncode(settings.toJson()),
      );
    } catch (error) {
      debugPrint('FavoriteVocabularyReviewSettings: save failed: $error');
    }
  }
}
