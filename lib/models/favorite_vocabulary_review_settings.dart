/// 收藏词汇 FSRS 复习设置。
library;

import 'package:collection/collection.dart';

enum FavoriteVocabularyReviewOrder { smart, dueAt, random }

class FavoriteVocabularyReviewSettings {
  const FavoriteVocabularyReviewSettings({
    this.dailyReviewGoal,
    this.order = FavoriteVocabularyReviewOrder.smart,
  });

  final int? dailyReviewGoal;
  final FavoriteVocabularyReviewOrder order;

  static const dailyReviewGoalOptions = <int?>[
    null,
    5,
    10,
    15,
    20,
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
  ];

  FavoriteVocabularyReviewSettings copyWith({
    int? dailyReviewGoal,
    bool clearDailyReviewGoal = false,
    FavoriteVocabularyReviewOrder? order,
  }) => FavoriteVocabularyReviewSettings(
    dailyReviewGoal: clearDailyReviewGoal
        ? null
        : dailyReviewGoal ?? this.dailyReviewGoal,
    order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'dailyReviewGoal': dailyReviewGoal,
    'order': order.name,
  };

  factory FavoriteVocabularyReviewSettings.fromJson(Map<String, dynamic> json) {
    final rawGoal = json['dailyReviewGoal'];
    final goal = rawGoal == null || rawGoal is! int
        ? null
        : dailyReviewGoalOptions.contains(rawGoal)
        ? rawGoal
        : null;
    final rawOrder = json['order'];
    final order = rawOrder is String
        ? FavoriteVocabularyReviewOrder.values
                  .where((item) => item.name == rawOrder)
                  .firstOrNull ??
              FavoriteVocabularyReviewOrder.smart
        : FavoriteVocabularyReviewOrder.smart;
    return FavoriteVocabularyReviewSettings(
      dailyReviewGoal: goal,
      order: order,
    );
  }
}
