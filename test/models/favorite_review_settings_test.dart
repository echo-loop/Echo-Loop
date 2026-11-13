import 'package:echo_loop/models/favorite_review_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('旧每日目标字段被忽略', () {
    final settings = FavoriteReviewSettings.fromJson({'dailyReviewGoal': 20});

    expect(settings.toJson().containsKey('dailyReviewGoal'), isFalse);
  });

  test('复习设置能序列化和恢复', () {
    const settings = FavoriteReviewSettings(order: FavoriteReviewOrder.dueAt);

    expect(
      FavoriteReviewSettings.fromJson(settings.toJson()).toJson(),
      settings.toJson(),
    );
  });

  test('正反面自动播放默认开启，兼容旧词汇背面偏好', () {
    final defaults = FavoriteReviewSettings.fromJson(const {});
    expect(defaults.autoPlayFront, isTrue);
    expect(defaults.autoPlayBack, isTrue);

    final migrated = FavoriteReviewSettings.fromJson(const {
      'autoPlayVocabularySourceSentence': false,
    });
    expect(migrated.autoPlayFront, isTrue);
    expect(migrated.autoPlayBack, isFalse);
    expect(defaults.autoShowAiLookup, isFalse);
  });

  test('两个自动播放设置都能序列化和恢复', () {
    const settings = FavoriteReviewSettings(
      autoPlayFront: false,
      autoPlayBack: false,
    );

    expect(
      FavoriteReviewSettings.fromJson(settings.toJson()).toJson(),
      settings.toJson(),
    );
  });

  test('自动显示 AI 查词设置能序列化和恢复', () {
    const settings = FavoriteReviewSettings(autoShowAiLookup: true);

    expect(
      FavoriteReviewSettings.fromJson(settings.toJson()).autoShowAiLookup,
      isTrue,
    );
  });

  test('正面显示词汇默认关闭且能序列化和恢复', () {
    expect(
      FavoriteReviewSettings.fromJson(const {}).showVocabularyOnFront,
      isFalse,
    );
    const settings = FavoriteReviewSettings(showVocabularyOnFront: true);

    expect(
      FavoriteReviewSettings.fromJson(settings.toJson()).showVocabularyOnFront,
      isTrue,
    );
  });

  test('正面显示单词释义默认关闭且能序列化和恢复', () {
    expect(
      FavoriteReviewSettings.fromJson(const {}).showWordDefinitionOnFront,
      isFalse,
    );
    expect(
      FavoriteReviewSettings.fromJson(const {
        'showWordDefinitionOnFront': 'yes',
      }).showWordDefinitionOnFront,
      isFalse,
    );
    const settings = FavoriteReviewSettings(showWordDefinitionOnFront: true);

    expect(
      FavoriteReviewSettings.fromJson(settings.toJson())
          .showWordDefinitionOnFront,
      isTrue,
    );
  });
}
