/// 埋点事件名常量
///
/// 集中管理所有事件名和参数名，编译时检查、IDE 自动补全、重命名安全。
/// 命名规范：`<对象>_<动作>`，全部小写下划线连接。
library;

/// 事件名常量
abstract class Events {
  // ── 页面浏览 ──
  /// 页面切换（使用 PostHog 官方 Mobile 保留名，兼容官方 Dashboard 模板）
  static const screenView = r'$screen';

  // ── 学习会话 ──
  /// 进入学习页面（避免 Firebase 保留名 session_start）
  static const learningStart = 'learning_start';

  /// 离开学习页面
  static const learningEnd = 'learning_end';

  // ── 盲听 ──
  /// 开始全文盲听
  static const blindListenStart = 'blind_listen_start';

  /// 盲听一遍完成
  static const blindListenComplete = 'blind_listen_complete';

  /// 盲听后设置难度
  static const blindListenDifficultySet = 'blind_listen_difficulty_set';

  // ── 精听 ──
  /// 开始逐句精听
  static const intensiveListenStart = 'intensive_listen_start';

  /// 精听完成全部句子
  static const intensiveListenComplete = 'intensive_listen_complete';

  // ── 跟读 ──
  /// 开始跟读
  static const listenRepeatStart = 'listen_repeat_start';

  /// 跟读完成全部句子
  static const listenRepeatComplete = 'listen_repeat_complete';

  // ── 复述 ──
  /// 开始段落复述
  static const retellStart = 'retell_start';

  /// 复述完成全部段落
  static const retellComplete = 'retell_complete';

  // ── 难句补练 ──
  /// 开始难句补练
  static const difficultPracticeStart = 'difficult_practice_start';

  /// 难句补练完成
  static const difficultPracticeComplete = 'difficult_practice_complete';

  // ── 学习进度 ──
  /// 首次学习四步骤全部完成
  static const firstLearnComplete = 'first_learn_complete';

  /// 学习阶段推进
  static const stageAdvance = 'stage_advance';

  // ── 内容创建 ──
  /// 创建合集
  static const collectionCreate = 'collection_create';

  /// 上传音频
  static const audioUpload = 'audio_upload';

  /// 删除合集
  static const collectionDelete = 'collection_delete';

  /// 删除音频
  static const audioDelete = 'audio_delete';

  // ── AI 功能 ──
  /// 请求翻译
  static const translationRequested = 'translation_requested';

  /// 请求语法解析
  static const analysisRequested = 'analysis_requested';

  /// 请求意群拆分
  static const senseGroupRequested = 'sense_group_requested';

  // ── 字幕 ──
  /// 本地上传字幕成功
  static const subtitleUploaded = 'subtitle_uploaded';

  /// AI 转录任务发起
  static const transcriptionStarted = 'transcription_started';

  /// AI 转录任务完成
  static const transcriptionComplete = 'transcription_complete';

  // ── 复习会话 ──
  /// 收藏句子复习开始
  static const bookmarkReviewStart = 'bookmark_review_start';

  /// 收藏句子复习完成（dispose 时上报，含中途退出）
  static const bookmarkReviewComplete = 'bookmark_review_complete';

  /// 收藏/取消收藏句子
  static const bookmarkToggle = 'bookmark_toggle';

  /// 单词卡片复习开始
  static const flashcardStart = 'flashcard_start';

  /// 单词卡片复习完成（全部翻完）
  static const flashcardComplete = 'flashcard_complete';

  // ── 录音完成（三个界面共用，mode 参数区分） ──
  /// 单次录音评估完成
  static const recordingComplete = 'recording_complete';

  // ── 查单词 ──
  /// 用户查询单词
  static const wordLookup = 'word_lookup';

  /// 收藏单词
  static const wordSave = 'word_save';

  // ── 设置 ──
  /// 提醒时间修改
  static const reminderUpdated = 'reminder_updated';

  /// 语音识别设置变更
  static const asrSettingChanged = 'asr_setting_changed';

  // ── 统计查看 ──
  /// 查看今日学习时长明细
  static const studyTimeViewed = 'study_time_viewed';

  // ── 精品合集 ──
  /// 点击发现精品合集入口
  static const discoverEntryTapped = 'discover_entry_tapped';

  /// 成功添加官方合集
  static const officialCollectionEnroll = 'official_collection_enroll';

  /// 查看官方合集详情
  static const officialCollectionDetailViewed = 'official_collection_detail_viewed';

  // ── 学习 Tab ──
  /// 查看活动日历
  static const activityCalendarViewed = 'activity_calendar_viewed';

  /// 点击学习任务卡片
  static const studyTaskTapped = 'study_task_tapped';

  /// 查看某天阶段明细
  static const dayBreakdownViewed = 'day_breakdown_viewed';

  // ── 收藏复习按钮 ──
  /// 点击句子复习按钮
  static const bookmarkReviewButtonTapped = 'bookmark_review_button_tapped';

  /// 点击单词卡片复习按钮
  static const flashcardButtonTapped = 'flashcard_button_tapped';

  // ── 设置 ──
  /// 主题模式切换
  static const themeModeChanged = 'theme_mode_changed';

  /// App 语言切换
  static const appLocaleChanged = 'app_locale_changed';

  /// 母语切换
  static const nativeLanguageChanged = 'native_language_changed';

  /// 清除缓存成功
  static const cacheCleared = 'cache_cleared';

  // ── 复述跳过 ──
  /// 「自动跳过复述」全局开关切换（设置页）
  static const retellToggleChanged = 'retell_toggle_changed';

  /// 复述子阶段被跳过（手动按钮 / 自动跳过策略）
  /// params: stage, subStage, source ∈ {'manual', 'auto'}
  static const retellSkipped = 'retell_skipped';

  // ── Onboarding 问卷（首启 2 题，只采集不消费） ──
  /// 进入问卷页
  static const onboardingSurveyShown = 'onboarding_survey_shown';

  /// 单题选择（每题答完打一次）
  static const onboardingSurveyQuestionAnswered =
      'onboarding_survey_question_answered';

  /// 问卷全部完成
  static const onboardingSurveyCompleted = 'onboarding_survey_completed';

  // ── 系统授权 ──
  /// 冷启动时上报 4 类系统授权状态快照（mic / speech / notification / network）
  static const appPermissionSnapshot = 'app_permission_snapshot';
}

/// User property 名称常量（写入分析通道用于分群留存）
abstract class UserProperties {
  /// 学习目标（exam / daily / work / travel / other）
  static const englishGoal = 'english_goal';

  /// 考试类型（仅 goal == exam 时设置；gaokao / cet / tem / ielts / toefl / other）
  static const examType = 'exam_type';

  /// 每日学习时长（"5" / "10" / "20" / "30" / "flexible"）
  static const dailyMinutesTarget = 'daily_minutes_target';
}

/// 事件参数名常量
abstract class EventParams {
  // ── 通用 ──
  static const audioId = 'audio_id';
  static const stage = 'stage';
  static const durationMs = 'duration_ms';

  // ── 内容管理 ──
  static const collectionId = 'collection_id';

  // ── 页面浏览 ──
  /// PostHog 官方保留属性名，用于填充 Activity 流的 URL/Screen 列
  static const screenName = r'$screen_name';
  static const previousScreen = 'previous_screen';

  // ── 学习会话 ──
  static const isFreePractice = 'is_free_practice';

  // ── 盲听 ──
  static const difficulty = 'difficulty';
  static const passNumber = 'pass_number';

  // ── 精听 ──
  static const totalSentences = 'total_sentences';
  static const difficultCount = 'difficult_count';
  static const totalDifficultSentences = 'total_difficult_sentences';

  // ── 复述 ──
  static const totalParagraphs = 'total_paragraphs';

  // ── 学习进度 ──
  static const totalDurationMs = 'total_duration_ms';
  static const fromStage = 'from_stage';
  static const toStage = 'to_stage';

  /// 阶段推进触发来源（如 'retell_disabled'，仅复述静默推进时附带）
  static const trigger = 'trigger';

  // ── 复述开关 ──
  /// 复述开关当前值
  static const enabled = 'enabled';

  /// 复述开关切换来源：'intro_dialog' 或 'settings_page'
  static const source = 'source';

  /// 引导弹窗用户选择：'enable' / 'dismiss'
  static const choice = 'choice';

  // ── 录音评估 ──
  /// 录音来源界面：listen_repeat / retell / difficult_practice
  static const mode = 'mode';

  /// 录音评分（0.0 ~ 1.0，null 表示识别失败）
  static const score = 'score';

  // ── 查单词 ──
  static const word = 'word';

  // ── 设置 ──
  static const reminderEnabled = 'reminder_enabled';

  /// 格式 HH:mm（仅收藏复习提醒时间）
  static const reminderTime = 'reminder_time';

  static const asrEnabled = 'asr_enabled';

  /// 值：'platform'（系统 ASR）或 'offline'（本地模型）
  static const asrBackend = 'asr_backend';

  // ── 复习会话 ──
  static const totalCards = 'total_cards';
  static const totalSentencesCount = 'total_sentences_count';
  static const sentenceIndex = 'sentence_index';
  static const action = 'action'; // 'add' 或 'remove'

  // ── 精品合集 ──
  static const remoteId = 'remote_id';
  static const collectionName = 'collection_name';
  static const audioCount = 'audio_count';
  static const enrolledCount = 'enrolled_count';
  static const enrolled = 'enrolled';

  // ── 学习 Tab ──
  static const streak = 'streak';
  static const taskType = 'task_type';
  static const audioName = 'audio_name';
  static const isOverdue = 'is_overdue';
  static const subStage = 'sub_stage';
  static const dateParam = 'date';

  // ── 设置 ──
  static const previousMode = 'previous_mode';
  static const newMode = 'new_mode';
  static const previousLocale = 'previous_locale';
  static const newLocale = 'new_locale';
  static const previousLanguage = 'previous_language';
  static const newLanguage = 'new_language';
  static const bytesFreed = 'bytes_freed';

  // ── Onboarding 问卷 ──
  /// 是否首启触发（即每次进入问卷，都为 true；保留参数便于后期扩展）
  static const isFirstLaunch = 'is_first_launch';

  /// 题目 ID（goal / daily_minutes）
  static const questionId = 'question_id';

  /// 答案编码
  static const answerCode = 'answer_code';

  /// Q1 学习目标
  static const goal = 'goal';

  /// Q1.5 考试类型（仅 goal == exam 时上报）
  static const examType = 'exam_type';

  /// Q2 每日学习时长
  static const dailyMinutes = 'daily_minutes';

  /// 完成耗时（秒）
  static const elapsedSeconds = 'elapsed_seconds';

  // ── 系统授权状态（冷启动快照 + 用户画像） ──
  /// 麦克风权限
  static const microphoneStatus = 'microphone_status';

  /// 语音识别权限
  static const speechStatus = 'speech_status';

  /// 通知权限
  static const notificationStatus = 'notification_status';

  /// 网络授权（仅 iOS 有意义；其他平台填 not_applicable）
  static const networkStatus = 'network_status';
}
