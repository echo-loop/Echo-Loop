/// 复述设置模型
///
/// 控制段落复述播放器的重复次数、停顿模式和文本显示模式。
/// 仅在会话内生效，不持久化。
library;

import '../database/enums.dart';
import 'intensive_listen_settings.dart';
import 'rating_thresholds.dart';

// 复用跟读模块的控制模式枚举（ShadowingControlMode）

/// 可见词生成方式
enum KeywordMethod {
  /// 关闭（不显示可见词提示）
  off,

  /// 随机选择
  random,

  /// AI 智能选择（暂未实现）
  ai,
}

/// 可见词比例（按难度档位）
///
/// 5 档与音频难度 [DifficultyLevel] 一一对应：
/// 越难的音频显示越多可见词作为提示。
enum KeywordRatio {
  /// 20%（对应"很轻松"难度）
  veryEasy(20),

  /// 30%（对应"偏轻松"难度）
  easy(30),

  /// 40%（对应"还可以"难度）
  medium(40),

  /// 50%（对应"偏难"难度）
  hard(50),

  /// 60%（对应"很难"难度）
  veryHard(60);

  /// 百分比（0–100）
  final int percent;

  const KeywordRatio(this.percent);

  /// 比例值（0.0–1.0），供 keyword 提取算法直接乘
  double get value => percent / 100.0;

  /// 按音频难度自动映射档位（不考虑学习阶段，作为基线档位）
  ///
  /// veryEasy→20%, easy→30%, medium→40%, hard→50%, veryHard→60%。
  static KeywordRatio forDifficulty(DifficultyLevel level) => switch (level) {
    DifficultyLevel.veryEasy => KeywordRatio.veryEasy,
    DifficultyLevel.easy => KeywordRatio.easy,
    DifficultyLevel.medium => KeywordRatio.medium,
    DifficultyLevel.hard => KeywordRatio.hard,
    DifficultyLevel.veryHard => KeywordRatio.veryHard,
  };

  /// stage 在学习时间轴上的位置（0=firstLearn，8=completed）
  ///
  /// 用于按"高/中/低"三段式曲线推算可见词比例的下降时机。
  static int _stagePosition(LearningStage stage) => switch (stage) {
    LearningStage.firstLearn => 0,
    LearningStage.review0 => 1,
    LearningStage.review1 => 2,
    LearningStage.review2 => 3,
    LearningStage.review4 => 4,
    LearningStage.review7 => 5,
    LearningStage.review14 => 6,
    LearningStage.review28 => 7,
    LearningStage.completed => 8,
  };

  /// 按音频难度 + 学习阶段联合映射档位
  ///
  /// 三段式曲线：每个难度都按"起点→中段→终点"逐档下降。
  /// - 起点：min(基线 +2 档, 80%)，首次学习提示最多
  /// - 终点：min(基线, 40%)；medium/hard/veryHard 都收敛到 40%，
  ///   veryEasy/easy 收敛到自己的基线（15% / 25%）
  /// - 中段：起点 -1 档
  /// - 难度高于 medium 时，曲线整体后移（hard 后移 1 stage，veryHard 后移 2）：
  ///   越难的音频越晚降到 40%
  ///
  /// 完整映射表见 retell 设计文档；medium 列：firstLearn=60%, review2=50%,
  /// review7=40%。
  static KeywordRatio forDifficultyAndStage(
    DifficultyLevel difficulty,
    LearningStage stage,
  ) {
    final mediumIndex = KeywordRatio.medium.index;
    final maxIndex = KeywordRatio.values.length - 1;
    final baseIndex = forDifficulty(difficulty).index;
    final endIndex = baseIndex < mediumIndex ? baseIndex : mediumIndex;
    final startIndex = (endIndex + 2).clamp(0, maxIndex);
    final shift = baseIndex > mediumIndex ? baseIndex - mediumIndex : 0;
    final adjustedStagePos = _stagePosition(stage) - shift;
    // medium 曲线：stage<2 起点，2≤stage<5 中段，stage≥5 终点
    final descent = adjustedStagePos < 2
        ? 0
        : adjustedStagePos < 5
        ? 1
        : 2;
    final descentClamped = descent.clamp(0, startIndex - endIndex);
    return KeywordRatio.values[startIndex - descentClamped];
  }
}

/// 复述文本显示模式
enum RetellDisplayMode {
  /// 仅显示关键词，其余灰色矩形遮盖
  keywordsOnly,

  /// 全部正常显示
  showAll,

  /// 全部灰色矩形遮盖
  hideAll,
}

/// 复述设置（会话内临时生效）
class RetellSettings {
  /// 每段重复次数（1-5，默认 1）
  ///
  /// 播放→复述为一遍，达到遍数后推进下一段。
  final int repeatCount;

  /// 停顿模式（默认 smart）
  final PauseMode pauseMode;

  /// 固定间隔秒数（5-60，默认 15）
  final int fixedPauseSeconds;

  /// 段长倍数（1.0-3.0，默认 1.5）
  final double pauseMultiplier;

  /// 可见词生成方式（默认 random）
  final KeywordMethod keywordMethod;

  /// 可见词比例（默认 1/3）
  final KeywordRatio keywordRatio;

  /// 控制模式（自动/手动，默认 auto）
  final ShadowingControlMode controlMode;

  /// 是否为手动控制模式
  bool get isManualMode => controlMode == ShadowingControlMode.manual;

  /// 固定间隔可选值（秒）
  static const List<int> fixedPauseOptions = [10, 20, 30, 45, 60, 90, 120, 180];

  /// 倍数可选值
  static const List<double> multiplierOptions = [
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    4.0,
    5.0,
    6.0,
  ];

  const RetellSettings({
    this.repeatCount = 1,
    this.pauseMode = PauseMode.smart,
    this.fixedPauseSeconds = 30,
    this.pauseMultiplier = 0.5,
    this.keywordMethod = KeywordMethod.random,
    this.keywordRatio = KeywordRatio.medium,
    this.controlMode = ShadowingControlMode.auto,
  });

  RetellSettings copyWith({
    int? repeatCount,
    PauseMode? pauseMode,
    int? fixedPauseSeconds,
    double? pauseMultiplier,
    KeywordMethod? keywordMethod,
    KeywordRatio? keywordRatio,
    ShadowingControlMode? controlMode,
  }) {
    return RetellSettings(
      repeatCount: repeatCount ?? this.repeatCount,
      pauseMode: pauseMode ?? this.pauseMode,
      fixedPauseSeconds: fixedPauseSeconds ?? this.fixedPauseSeconds,
      pauseMultiplier: pauseMultiplier ?? this.pauseMultiplier,
      keywordMethod: keywordMethod ?? this.keywordMethod,
      keywordRatio: keywordRatio ?? this.keywordRatio,
      controlMode: controlMode ?? this.controlMode,
    );
  }

  /// 根据段落时长计算复述阶段最大录音时长
  ///
  /// 公式：`max(30s, 5s + 5×段落时长)`。
  Duration calculateRetellingDuration(Duration paragraphDuration) {
    final computed = 5000 + paragraphDuration.inMilliseconds * 5;
    return Duration(milliseconds: computed < 30000 ? 30000 : computed);
  }

  /// 根据段落时长和评估分数计算复述停顿时间
  ///
  /// Smart 模式下评估越好倒计时越短：
  /// - perfect (≥0.90): 2s + 段落×0.5
  /// - excellent (≥0.75): 2s + 段落×1.0
  /// - good (≥0.50): 2s + 段落×1.5
  /// - 其它/无评分: 2s + 段落×2.0
  Duration calculatePauseDuration(Duration paragraphDuration, {double? score}) {
    return switch (pauseMode) {
      PauseMode.smart => () {
        const t = RatingThresholds.retell;
        final multiplier = switch (score) {
          double s when s >= t.perfect => 0.5,
          double s when s >= t.excellent => 1.0,
          double s when s >= t.good => 1.5,
          _ => 2.0,
        };
        final ms = (2000 + paragraphDuration.inMilliseconds * multiplier)
            .round();
        return Duration(milliseconds: ms.clamp(3000, 60000));
      }(),
      PauseMode.fixed => Duration(seconds: fixedPauseSeconds),
      PauseMode.multiplier => () {
        final ms = (paragraphDuration.inMilliseconds * pauseMultiplier).round();
        return Duration(milliseconds: ms < 3000 ? 3000 : ms);
      }(),
    };
  }
}
