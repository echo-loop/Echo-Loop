import 'package:echo_loop/models/favorite_review_settings.dart';
import 'package:echo_loop/providers/favorite_review_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('更新正面显示词汇设置后持久化', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(favoriteReviewSettingsProvider.notifier)
        .update(const FavoriteReviewSettings(showVocabularyOnFront: true));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorite_review_settings_v1');
    if (raw == null) {
      fail('favorite review settings were not persisted');
    }
    expect(raw, contains('"showVocabularyOnFront":true'));
  });

  test('正面显示单词释义会持久化到收藏复习设置', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(favoriteReviewSettingsProvider.notifier)
        .update(const FavoriteReviewSettings(showWordDefinitionOnFront: true));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorite_review_settings_v1');
    if (raw == null) {
      fail('favorite review settings were not persisted');
    }
    expect(raw, contains('"showWordDefinitionOnFront":true'));
  });
}
