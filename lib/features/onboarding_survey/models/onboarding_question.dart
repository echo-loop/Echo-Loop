/// Onboarding 问卷题目静态元数据
///
/// 四道题：学习目标 → （仅当目标=应对考试）考试类型 → 每日学习时长 → 来源渠道。
/// 题目和选项不可变，运行时不会从配置或后端拉取。
library;

import 'package:flutter/foundation.dart';

/// 题目 ID（用于埋点参数 question_id）
abstract final class OnboardingQuestionId {
  static const goal = 'goal';
  static const examType = 'exam_type';
  static const dailyMinutes = 'daily_minutes';
  static const referralSource = 'referral_source';
}

/// 学习目标编码（Q1）
abstract final class OnboardingGoal {
  static const exam = 'exam';
  static const daily = 'daily';
  static const work = 'work';
  static const travel = 'travel';
  static const content = 'content';
  static const other = 'other';

  /// 全部合法值，用于 SP 解码时校验
  static const all = [exam, daily, work, travel, content, other];
}

/// 应对考试时的二级菜单：考试类型编码
abstract final class OnboardingExamType {
  static const gaokao = 'gaokao';
  static const cet = 'cet';
  static const tem = 'tem';
  static const ielts = 'ielts';
  static const toefl = 'toefl';
  static const other = 'other';

  static const all = [gaokao, cet, tem, ielts, toefl, other];
}

/// 每日学习时长编码（Q2）
///
/// 含 `flexible` 故用 String 而非 int。
abstract final class OnboardingDailyMinutes {
  static const m5 = '5';
  static const m10 = '10';
  static const m20 = '20';
  static const m30 = '30';
  static const flexible = 'flexible';

  static const all = [m5, m10, m20, m30, flexible];
}

/// 来源渠道编码（Q3）
///
/// 中英文用户看到的渠道列表不同（详见 onboarding_survey_screen.dart 的
/// `_buildReferralSourceStep`），但编码集合统一以便埋点分析。
///
/// 改版（2026-10）后，抖音/快手、TikTok/Instagram 合并为 [shortVideo]，
/// 百度搜索并入 [searchEngine]，Google Play 并入 [appStore]。旧编码保留在
/// [_legacyAliases] 中，读取旧 SP 数据时通过 [normalize] 映射到新编码。
abstract final class OnboardingReferralSource {
  // 中文用户主要渠道
  static const xiaohongshu = 'xiaohongshu';
  static const wechat = 'wechat';
  static const bilibili = 'bilibili';
  static const shortVideo = 'short_video';
  static const searchEngine = 'search_engine';
  static const teacherSchool = 'teacher_school';
  // 英文用户主要渠道
  static const youtube = 'youtube';
  static const reddit = 'reddit';
  static const xTwitter = 'x_twitter';
  static const googleSearch = 'google_search';
  // 通用渠道
  static const github = 'github';
  static const appStore = 'app_store';
  static const friend = 'friend';
  static const other = 'other';

  /// 当前界面可选的编码集合（新答案只会写入这些值）。
  static const all = [
    xiaohongshu,
    wechat,
    bilibili,
    shortVideo,
    searchEngine,
    teacherSchool,
    youtube,
    reddit,
    xTwitter,
    googleSearch,
    github,
    appStore,
    friend,
    other,
  ];

  /// 已下线的旧编码 → 新编码。仅用于读取历史 SP 数据，不再出现在选项中。
  static const _legacyAliases = <String, String>{
    'douyin': shortVideo,
    'kuaishou': shortVideo,
    'tiktok': shortVideo,
    'instagram': shortVideo,
    'baidu_search': searchEngine,
    'google_play': appStore,
  };

  /// "其他"补充说明的最大长度（字符数）。
  static const referralOtherTextMaxLength = 50;

  /// 把 SP 中读到的编码规范化为当前编码；未知编码返回 null。
  static String? normalize(String raw) {
    if (all.contains(raw)) return raw;
    return _legacyAliases[raw];
  }
}

/// 单个选项的元数据。
///
/// 显示文本通过 [labelKey] 在 ARB 中查表，编码 [code] 用于持久化和埋点。
@immutable
class OnboardingOption {
  /// 写入 SP / 埋点的稳定编码
  final String code;

  /// l10n key（见 app_zh.arb / app_en.arb）
  final String labelKey;

  const OnboardingOption({required this.code, required this.labelKey});
}
