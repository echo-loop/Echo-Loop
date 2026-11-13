/// 收藏复习共用的调度设置。
library;

import 'package:collection/collection.dart';

/// 所有收藏类型共用的复习排序规则。
enum FavoriteReviewOrder { smart, dueAt, random }

/// 仅包含调度语义的设置；句子 AI 展示偏好保持在句子专属设置中。
class FavoriteReviewSettings {
  const FavoriteReviewSettings({
    this.showNextReviewTime = false,
    this.autoPlayFront = true,
    this.autoPlayBack = true,
    this.autoShowAiLookup = false,
    this.showVocabularyOnFront = false,
    this.showWordDefinitionOnFront = false,
    this.order = FavoriteReviewOrder.smart,
  });

  final bool showNextReviewTime;

  /// 进入或切换到正面时是否自动播放当前卡片的音频。
  final bool autoPlayFront;

  /// 翻到背面时是否自动播放当前卡片对应的音频。
  final bool autoPlayBack;

  /// 收藏词汇翻面时是否自动展示 AI 查词结果。
  final bool autoShowAiLookup;

  /// 收藏词汇复习正面是否显示当前词汇。
  final bool showVocabularyOnFront;

  /// 收藏单词复习正面是否显示 AI 释义（仅单词生效，词组不受影响）。
  final bool showWordDefinitionOnFront;

  final FavoriteReviewOrder order;

  FavoriteReviewSettings copyWith({
    bool? showNextReviewTime,
    bool? autoPlayFront,
    bool? autoPlayBack,
    bool? autoShowAiLookup,
    bool? showVocabularyOnFront,
    bool? showWordDefinitionOnFront,
    FavoriteReviewOrder? order,
  }) => FavoriteReviewSettings(
    showNextReviewTime: showNextReviewTime ?? this.showNextReviewTime,
    autoPlayFront: autoPlayFront ?? this.autoPlayFront,
    autoPlayBack: autoPlayBack ?? this.autoPlayBack,
    autoShowAiLookup: autoShowAiLookup ?? this.autoShowAiLookup,
    showVocabularyOnFront: showVocabularyOnFront ?? this.showVocabularyOnFront,
    showWordDefinitionOnFront:
        showWordDefinitionOnFront ?? this.showWordDefinitionOnFront,
    order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'showNextReviewTime': showNextReviewTime,
    'autoPlayFront': autoPlayFront,
    'autoPlayBack': autoPlayBack,
    'autoShowAiLookup': autoShowAiLookup,
    'showVocabularyOnFront': showVocabularyOnFront,
    'showWordDefinitionOnFront': showWordDefinitionOnFront,
    'order': order.name,
  };

  factory FavoriteReviewSettings.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'];
    return FavoriteReviewSettings(
      showNextReviewTime: json['showNextReviewTime'] is bool
          ? json['showNextReviewTime'] == true
          : false,
      // 旧版正面固定自动播放；缺少新字段时保持这一默认体验。
      autoPlayFront: json['autoPlayFront'] is bool
          ? json['autoPlayFront'] == true
          : true,
      // 词汇旧字段只控制背面播放，迁移为所有收藏复习共用的背面偏好。
      autoPlayBack: json['autoPlayBack'] is bool
          ? json['autoPlayBack'] == true
          : json['autoPlayVocabularySourceSentence'] is bool
          ? json['autoPlayVocabularySourceSentence'] == true
          : true,
      autoShowAiLookup: json['autoShowAiLookup'] is bool
          ? json['autoShowAiLookup'] == true
          : false,
      showVocabularyOnFront: json['showVocabularyOnFront'] is bool
          ? json['showVocabularyOnFront'] == true
          : false,
      showWordDefinitionOnFront: json['showWordDefinitionOnFront'] is bool
          ? json['showWordDefinitionOnFront'] == true
          : false,
      order: rawOrder is String
          ? FavoriteReviewOrder.values.firstWhereOrNull(
                  (item) => item.name == rawOrder,
                ) ??
                FavoriteReviewOrder.smart
          : FavoriteReviewOrder.smart,
    );
  }
}
