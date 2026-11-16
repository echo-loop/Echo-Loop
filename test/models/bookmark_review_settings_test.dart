import 'package:echo_loop/models/bookmark_review_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults match the FSRS bookmark review contract', () {
    const settings = BookmarkReviewSettings();
    expect(settings.showNextReviewTime, isFalse);
    expect(settings.dailyReviewGoal, isNull);
    expect(settings.order, BookmarkReviewOrder.smart);
    expect(settings.autoShowAiExplanation, isTrue);
    expect(settings.autoShowAiAnalysis, isFalse);
    expect(settings.autoShowAiTranslation, isTrue);
    expect(settings.autoShowAiSenseGroups, isFalse);
  });

  test('json round trip preserves all settings', () {
    const original = BookmarkReviewSettings(
      showNextReviewTime: true,
      dailyReviewGoal: 60,
      order: BookmarkReviewOrder.random,
    );
    expect(
      BookmarkReviewSettings.fromJson(original.toJson()).toJson(),
      original.toJson(),
    );
  });

  test('invalid values fall back to defaults', () {
    final settings = BookmarkReviewSettings.fromJson({
      'showNextReviewTime': 'yes',
      'dailyReviewGoal': 25,
      'order': 'unknown',
    });
    expect(settings.showNextReviewTime, isFalse);
    expect(settings.dailyReviewGoal, isNull);
    expect(settings.order, BookmarkReviewOrder.smart);
  });

  test('accepts daily review goals from 5 to 100 in five-card steps', () {
    expect(
      BookmarkReviewSettings.fromJson({'dailyReviewGoal': 5}).dailyReviewGoal,
      5,
    );
    expect(
      BookmarkReviewSettings.fromJson({'dailyReviewGoal': 15}).dailyReviewGoal,
      15,
    );
    expect(
      BookmarkReviewSettings.fromJson({'dailyReviewGoal': 105}).dailyReviewGoal,
      isNull,
    );
  });

  test('missing AI auto-show values use bookmark review defaults', () {
    final settings = BookmarkReviewSettings.fromJson({});
    expect(settings.autoShowAiExplanation, isTrue);
    expect(settings.autoShowAiAnalysis, isFalse);
    expect(settings.autoShowAiTranslation, isTrue);
    expect(settings.autoShowAiSenseGroups, isFalse);
  });

  test('显示视频画面默认开启，旧数据缺字段时也开启，并可往返序列化', () {
    expect(const BookmarkReviewSettings().showVideo, isTrue);
    expect(BookmarkReviewSettings.fromJson({}).showVideo, isTrue);
    expect(
      BookmarkReviewSettings.fromJson({'showVideo': 'x'}).showVideo,
      isTrue,
    );
    final off = const BookmarkReviewSettings().copyWith(showVideo: false);
    expect(BookmarkReviewSettings.fromJson(off.toJson()).showVideo, isFalse);
  });
}
