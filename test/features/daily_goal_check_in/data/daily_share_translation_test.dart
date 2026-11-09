import 'package:echo_loop/features/daily_goal_check_in/data/daily_check_in_share_image.dart';
import 'package:echo_loop/features/daily_goal_check_in/data/daily_share_decoded_image_cache.dart';
import 'package:echo_loop/features/daily_goal_check_in/domain/share_card_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../share_card_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final word in [false, true]) {
    test('${word ? "单词" : "句子"}英语界面隐藏译文，中文界面绘制译文', () async {
      await DailyShareFontLoader().load();
      final cache = DailyShareDecodedImageCache();
      final original = ShareCardTemplate.fromJson(cardJson(word: word));
      final images = <GeneratedDailyCheckInShareImage>[];
      Future<GeneratedDailyCheckInShareImage> render(
        String translation,
        bool chinese,
      ) async {
        final content = original.content;
        final image = await generateDailyCheckInShareImage(
          template: ShareCardTemplate(
            id: original.id,
            imageUrl: original.imageUrl,
            topColor: original.topColor,
            bottomColor: original.bottomColor,
            content: content is ShareCardWord
                ? ShareCardWord(content.english, {
                    'zh-CN': translation,
                  }, content.phonetic)
                : ShareCardSentence(content.english, {'zh-CN': translation}),
          ),
          data: DailyCheckInShareData(
            date: DateTime(2026, 11, 9),
            totalSeconds: 600,
            inputSeconds: 600,
            outputSeconds: 0,
            streak: 1,
            isChinese: chinese,
            nativeLanguage: 'zh-CN',
          ),
          assets: DailyCheckInShareAssets(
            background: shareTestPng,
            logo: shareTestPng,
            qrCode: shareTestPng,
          ),
          decodedImageCache: cache,
        );
        images.add(image);
        return image;
      }

      try {
        final english = await render('中文译文甲', false);
        final englishChanged = await render('完全不同的中文译文乙', false);
        // 英文输出不应受母语译文影响，覆盖实际像素生成而非仅检查开关。
        expect(english.pngBytes, orderedEquals(englishChanged.pngBytes));
        final chinese = await render('中文译文甲', true);
        final chineseChanged = await render('完全不同的中文译文乙', true);
        expect(chinese.pngBytes, isNot(orderedEquals(chineseChanged.pngBytes)));
      } finally {
        for (final image in images) {
          image.dispose();
        }
        cache.dispose();
      }
    });
  }
}
