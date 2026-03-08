// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Fluency';

  @override
  String get player => '播放器';

  @override
  String get account => '账户';

  @override
  String get settings => '设置';

  @override
  String get addAudio => '添加音频';

  @override
  String get noAudioYet => '还没有音频文件';

  @override
  String get tapToAdd => '点击 + 添加第一个音频';

  @override
  String get added => '添加于';

  @override
  String get transcript => '字幕';

  @override
  String get playing => '上次';

  @override
  String get delete => '删除';

  @override
  String get deleteAudio => '删除音频';

  @override
  String deleteConfirm(String name) {
    return '确定要删除「$name」吗？';
  }

  @override
  String get cancel => '取消';

  @override
  String get add => '添加';

  @override
  String get selectAudioFile => '选择音频文件';

  @override
  String get selectTranscript => '选择字幕（可选）';

  @override
  String get noTranscript => '无字幕';

  @override
  String get noBookmarked => '没有收藏的句子';

  @override
  String get tapToBookmark => '点击 ⭐ 收藏句子';

  @override
  String get playbackMode => '播放模式';

  @override
  String get fullArticle => '全文播放';

  @override
  String get singleSentence => '单句播放';

  @override
  String get bookmarkedOnly => '仅播放收藏';

  @override
  String get playbackSettings => '播放设置';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get loopPlayback => '循环播放';

  @override
  String get loopCount => '循环次数';

  @override
  String get pauseInterval => '暂停间隔';

  @override
  String get applySettings => '应用设置';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get stop => '停止';

  @override
  String get previousSentence => '上一句';

  @override
  String get nextSentence => '下一句';

  @override
  String get removeBookmark => '取消收藏';

  @override
  String get addBookmark => '添加收藏';

  @override
  String get appearance => '外观';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get language => '语言';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get appDescription => '专业的英语听力练习应用';

  @override
  String get enableLoop => '启用循环';

  @override
  String get loopSettings => '循环设置';

  @override
  String get displaySettings => '显示设置';

  @override
  String get showTranscript => '显示字幕';

  @override
  String get shortcutKey => '快捷键';

  @override
  String get seconds => '秒';

  @override
  String get infinite => '无限';

  @override
  String get singleSentenceMode => '单句模式';

  @override
  String get singleSentenceModeDesc => '只展示当前播放的句子';

  @override
  String get autoPlayNextSentence => '自动播放下一句';

  @override
  String get sentenceRepeat => '句子重复';

  @override
  String get repeatCount => '重复次数';

  @override
  String get intervalTime => '间隔时间（秒）';

  @override
  String get audioLoop => '音频循环';

  @override
  String get loopTimes => '循环次数';

  @override
  String get noLoop => '不循环';

  @override
  String get infiniteLoop => '无穷 ∞';

  @override
  String get times => '次';

  @override
  String get fullText => '全文';

  @override
  String get bookmarked => '收藏';

  @override
  String get noSubtitle => '无字幕';

  @override
  String get noSentenceSelected => '未选择句子';

  @override
  String get noBookmarkedSentences => '没有收藏的句子';

  @override
  String get tapBookmarkIcon => '点击句子旁的书签图标收藏';

  @override
  String get removeBookmarkTip => '取消收藏';

  @override
  String get addBookmarkTip => '收藏';

  @override
  String get listMode => '列表模式';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制到剪贴板';

  @override
  String get hotkeyReplay => 'R：重播';

  @override
  String get hotkeyPlayPause => '空格：播放/暂停';

  @override
  String get hotkeyToggleTranscript => '↑：显示/隐藏字幕';

  @override
  String get hotkeyNavigation => '←/→：上一句/下一句';

  @override
  String get noAudioLoaded => '未加载音频';

  @override
  String get enableAutoScroll => '启用自动滚动';

  @override
  String get disableAutoScroll => '禁用自动滚动';

  @override
  String get audioFileNotFound => '音频文件未找到。文件可能已被删除。';

  @override
  String get pickAudioFileFailed => '选择音频文件失败';

  @override
  String get pickTranscriptFileFailed => '选择字幕文件失败';

  @override
  String get fileExists => '文件已存在';

  @override
  String fileExistsMessage(String name) {
    return '已存在名为「$name」的音频文件，请先删除原音频后再导入。';
  }

  @override
  String get ok => '确定';

  @override
  String addedOn(String date) {
    return '添加于：$date';
  }

  @override
  String get collections => '合集';

  @override
  String get collection => '合集';

  @override
  String get createCollection => '创建合集';

  @override
  String get collectionName => '合集名称';

  @override
  String get enterCollectionName => '请输入合集名称';

  @override
  String get noCollectionsYet => '还没有合集';

  @override
  String get tapToCreateCollection => '点击 + 创建第一个合集';

  @override
  String get deleteCollection => '删除合集';

  @override
  String deleteCollectionConfirm(String name) {
    return '确定要删除「$name」吗？合集中的音频文件不会被删除。';
  }

  @override
  String get renameCollection => '重命名';

  @override
  String get starCollection => '星标';

  @override
  String get unstarCollection => '取消星标';

  @override
  String get starAudio => '星标';

  @override
  String get unstarAudio => '取消星标';

  @override
  String get sortByNameAsc => '名称 (A-Z)';

  @override
  String get sortByNameDesc => '名称 (Z-A)';

  @override
  String get sortByDateAsc => '最早创建';

  @override
  String get sortByDateDesc => '最近创建';

  @override
  String get sortCollections => '排序';

  @override
  String get gridView => '文件夹视图';

  @override
  String get listView => '列表视图';

  @override
  String audioCount(int count) {
    return '$count 个音频';
  }

  @override
  String get collectionNameEmpty => '合集名称不能为空';

  @override
  String get collectionNameExists => '已存在同名合集';

  @override
  String get addAudioToCollection => '添加音频';

  @override
  String get removeFromCollection => '从合集中移除';

  @override
  String removeFromCollectionConfirm(String name) {
    return '确定要将「$name」从合集中移除吗？';
  }

  @override
  String get emptyCollection => '合集中还没有音频';

  @override
  String get tapToAddAudio => '点击 + 添加音频文件';

  @override
  String get renameAudio => '重命名';

  @override
  String get audioName => '音频名称';

  @override
  String get audioAlreadyInCollection => '音频重复';

  @override
  String audioAlreadyInCollectionMessage(String name) {
    return '合集中已存在名为「$name」的音频。';
  }

  @override
  String get audioAlreadyInLibrary => '音频重复';

  @override
  String audioAlreadyInLibraryMessage(String name) {
    return '音频库中已存在名为「$name」的音频。';
  }

  @override
  String get study => '学习';

  @override
  String get favorites => '收藏';

  @override
  String get profile => '我的';

  @override
  String get studyComingSoon => '学习功能即将上线';

  @override
  String get favoritesComingSoon => '收藏功能即将上线';

  @override
  String get learningPlanProgress => '学习进度';

  @override
  String get learningPlanNotStarted => '未开始';

  @override
  String get firstStudy => '首学';

  @override
  String get review => '复习';

  @override
  String stepProgress(int completed, int total) {
    return '$completed/$total 完成';
  }

  @override
  String get stepBlindListening => '全文盲听';

  @override
  String get stepBlindListeningDesc => '不看字幕完整听 1-2 遍';

  @override
  String get stepIntensiveListening => '逐句精听';

  @override
  String get stepIntensiveListeningDesc => '逐句盲听，标记难句';

  @override
  String get stepShadowing => '跟读';

  @override
  String get stepShadowingDesc => '跟读难句';

  @override
  String get stepRetelling => '段级复述';

  @override
  String get stepRetellingDesc => '用自己的话复述';

  @override
  String get reviewRound0 => '首轮复习';

  @override
  String get reviewRound1 => '第二轮复习';

  @override
  String get reviewRound2 => '第三轮复习';

  @override
  String get reviewRound4 => '第四轮复习';

  @override
  String get reviewRound7 => '第五轮复习';

  @override
  String get reviewRound14 => '第六轮复习';

  @override
  String get reviewRound28 => '第七轮复习';

  @override
  String get reviewIntervalNow => '6小时后';

  @override
  String get reviewInterval1d => '1天后';

  @override
  String get reviewInterval2d => '2天后';

  @override
  String get reviewInterval4d => '4天后';

  @override
  String get reviewInterval7d => '7天后';

  @override
  String get reviewInterval14d => '14天后';

  @override
  String get reviewInterval28d => '28天后';

  @override
  String get startLearning => '开始学习';

  @override
  String get continueLearning => '继续学习';

  @override
  String get learningInProgress => '学习中';

  @override
  String get learningCompleted => '已完成';

  @override
  String get reviewReady => '可以复习了';

  @override
  String reviewCountdown(int days) {
    return '$days 天后可复习';
  }

  @override
  String reviewCountdownHours(int hours) {
    return '$hours 小时后可复习';
  }

  @override
  String get blindListenBriefingTitle => '全文盲听';

  @override
  String get blindListenBriefingSubtitle => '首学 - 全文盲听';

  @override
  String blindListenBriefingReviewSubtitle(int round) {
    return '第$round轮复习 - 全文盲听';
  }

  @override
  String get blindListenBriefingTip => '不看字幕，完整听一遍，感受大意即可';

  @override
  String get startPractice => '开始练习';

  @override
  String get blindListenAppBarTitle => '全文盲听';

  @override
  String blindListenPassLabel(int count) {
    return '第 $count 遍';
  }

  @override
  String get blindListenComplete => '听力完成';

  @override
  String blindListenPassInfo(int count) {
    return '已听 $count 遍';
  }

  @override
  String get selectDifficulty => '感觉如何？';

  @override
  String get selectDifficultyRequired => '请选择难度后继续';

  @override
  String get listenAgain => '再听一遍';

  @override
  String get practiceAgain => '再练一遍';

  @override
  String get nextStage => '下一步';

  @override
  String get difficultyVeryEasy => '很轻松';

  @override
  String get difficultyEasy => '偏轻松';

  @override
  String get difficultyMedium => '还可以';

  @override
  String get difficultyHard => '偏难';

  @override
  String get difficultyVeryHard => '很难';

  @override
  String get countdownNextPlay => '即将开始下一遍';

  @override
  String get skipCountdown => '跳过';

  @override
  String audioDuration(String duration) {
    return '时长：$duration';
  }

  @override
  String estimatedMinutes(int minutes) {
    return '预计 $minutes 分钟';
  }

  @override
  String get estimatedLessThanOneMinute => '预计不到 1 分钟';

  @override
  String get exitBlindListenTitle => '退出盲听？';

  @override
  String get exitBlindListenMessage => '音频正在播放中，确定要退出吗？';

  @override
  String get confirmExit => '退出';

  @override
  String get library => '资源库';

  @override
  String get collectionsTab => '合集';

  @override
  String get audioTab => '音频';

  @override
  String get uncategorized => '未归类';

  @override
  String get manageCollections => '管理合集';

  @override
  String get noAudioItems => '还没有添加音频';

  @override
  String get noAudioItemsHint => '导入音频文件开始学习吧';

  @override
  String audioWillBeKept(int count) {
    return '合集中的 $count 个音频将保留在资源库中';
  }

  @override
  String get done => '完成';

  @override
  String get sortAudio => '排序';

  @override
  String deleteAudioConfirm(String name) {
    return '确定要删除「$name」吗？该音频将从所有合集中移除。';
  }

  @override
  String get uploadTranscript => '上传字幕';

  @override
  String get replaceTranscriptTitle => '替换字幕';

  @override
  String get replaceTranscriptMessage => '字幕已存在，是否替换？';

  @override
  String get replace => '替换';

  @override
  String sentenceCountLabel(int count) {
    return '$count 句';
  }

  @override
  String wordCountLabel(int count) {
    return '$count 词';
  }

  @override
  String get noTranscriptWarning => '尚未上传字幕，需要字幕才能开始学习流程。';

  @override
  String get intensiveListenAppBarTitle => '逐句精听';

  @override
  String intensiveListenProgress(int current, int total) {
    return '精听 $current/$total';
  }

  @override
  String intensiveListenPlayCount(int current, int total) {
    return '第 $current/$total 遍';
  }

  @override
  String get intensiveListenPeek => '偷看字幕';

  @override
  String get intensiveListenHideSubtitle => '隐藏字幕';

  @override
  String get intensiveListenCantUnderstand => '听不懂';

  @override
  String get intensiveListenAutoMarkedDifficult => '已自动标记为难句，点此取消';

  @override
  String get intensiveListenMarkedDifficult => '已标记为难句，点此取消';

  @override
  String get intensiveListenNotDifficult => '点击标记为难句';

  @override
  String get aiTranslation => '翻译';

  @override
  String get aiAnalysis => '解析';

  @override
  String get aiLoadFailed => '加载失败，点击重试';

  @override
  String get aiRetry => '重试';

  @override
  String get aiGrammar => '语法';

  @override
  String get aiVocabulary => '词汇';

  @override
  String get aiUsage => '用法';

  @override
  String get intensiveListenWordDictNotFound => '未收录该单词';

  @override
  String get intensiveListenContinue => '继续';

  @override
  String get intensiveListenReplayingWithSubtitle => '带字幕重播中...';

  @override
  String intensiveListenPauseBetweenPlays(int seconds) {
    return '$seconds秒后播放下一遍';
  }

  @override
  String intensiveListenPauseBetweenSentences(int seconds) {
    return '$seconds秒后播放下一句';
  }

  @override
  String get intensiveListenCompleteTitle => '精听完成';

  @override
  String intensiveListenCompleteMessage(int total, int difficult) {
    return '你已完成全部 $total 个句子的精听。共标记 $difficult 个难句。';
  }

  @override
  String get intensiveListenCompleteNext => '下一步';

  @override
  String get exitIntensiveListenTitle => '退出精听？';

  @override
  String get exitIntensiveListenMessage => '进度已保存，下次可从断点继续。';

  @override
  String get intensiveListenBriefingTitle => '逐句精听';

  @override
  String get intensiveListenBriefingSubtitle => '首学 - 逐句精听';

  @override
  String get intensiveListenBriefingTip => '逐句盲听，听不懂时点击「听不懂」查看文本并标记难句。';

  @override
  String intensiveListenBriefingSentenceCount(int count) {
    return '共 $count 个句子';
  }

  @override
  String get intensiveListenNoSubtitle => '无字幕';

  @override
  String get intensiveListenNoSubtitleMessage => '该音频没有字幕，请先上传字幕文件。';

  @override
  String get intensiveListenSettings => '精听设置';

  @override
  String get intensiveListenRepeatCount => '每句循环次数';

  @override
  String intensiveListenRepeatCountValue(int count) {
    return '$count 次';
  }

  @override
  String get intensiveListenPauseLabel => '句间停顿';

  @override
  String get intensiveListenPauseSmart => '智能间隔';

  @override
  String get intensiveListenPauseFixed => '固定间隔';

  @override
  String get intensiveListenPauseMultiplierMode => '句长倍数';

  @override
  String get intensiveListenSettingsTemporaryHint => '设置仅对本次精听有效';

  @override
  String get intensiveListenPauseSmartDesc => '根据难度、句子长度和学习阶段自动调整';

  @override
  String intensiveListenPauseFixedUnit(int seconds) {
    return '$seconds秒';
  }

  @override
  String intensiveListenPauseMultiplierValue(String value) {
    return '$value倍';
  }

  @override
  String get intensiveListenPauseMultiplierLabel => '倍数';

  @override
  String blindListenCountdown(int seconds) {
    return '$seconds秒后播放下一遍';
  }

  @override
  String difficultyLabel(String difficulty) {
    return '难度: $difficulty';
  }

  @override
  String get backToPlan => '返回计划';

  @override
  String continueToStep(String step) {
    return '继续：$step';
  }

  @override
  String get completeFirstStudy => '完成首学';

  @override
  String get completeReview => '完成本轮复习';

  @override
  String stepProgressLabel(int current, int total, String stage) {
    return '步骤进度：$current/$total（$stage）';
  }

  @override
  String get manageTags => '管理标签';

  @override
  String get noTagsYet => '还没有创建标签';

  @override
  String get createTag => '创建标签';

  @override
  String get tagName => '标签名称';

  @override
  String get enterTagName => '输入标签名称';

  @override
  String get selectColor => '选择颜色';

  @override
  String get deleteTag => '删除标签';

  @override
  String deleteTagConfirm(String name) {
    return '确定要删除「$name」吗？将从所有音频中移除。';
  }

  @override
  String get listenAndRepeatAppBarTitle => '难句跟读';

  @override
  String listenAndRepeatProgress(int current, int total) {
    return '跟读 $current/$total';
  }

  @override
  String listenAndRepeatPlayCount(int current, int total) {
    return '第 $current/$total 遍';
  }

  @override
  String listenAndRepeatPauseBetweenPlays(int seconds) {
    return '跟读时间 $seconds秒';
  }

  @override
  String listenAndRepeatPauseBetweenSentences(int seconds) {
    return '$seconds秒后播放下一句';
  }

  @override
  String get listenAndRepeatListenHint => '先听，听完后跟读';

  @override
  String get listenAndRepeatYourTurnHint => '请跟读这个句子';

  @override
  String get listenAndRepeatCompleteTitle => '跟读完成';

  @override
  String listenAndRepeatCompleteMessage(int total) {
    return '你已完成全部 $total 个难句的跟读练习。';
  }

  @override
  String get listenAndRepeatNoDifficultSentences => '没有标记难句，跳过跟读环节。';

  @override
  String get exitListenAndRepeatTitle => '退出跟读？';

  @override
  String get exitListenAndRepeatMessage => '进度已保存，下次可从断点继续。';

  @override
  String get listenAndRepeatBriefingTitle => '难句跟读';

  @override
  String get listenAndRepeatBriefingSubtitle => '首学 - 难句跟读';

  @override
  String get listenAndRepeatBriefingTip => '听完后跟读，在停顿时间内大声朗读这个句子。';

  @override
  String listenAndRepeatBriefingDifficultCount(int count) {
    return '$count 个难句';
  }

  @override
  String listenAndRepeatBriefingPlayCount(int count) {
    return '每句 $count 遍';
  }

  @override
  String get listenAndRepeatRemoveDifficult => '已标记难句，点此取消收藏';

  @override
  String get listenAndRepeatSettings => '跟读设置';

  @override
  String get listenAndRepeatSettingsTemporaryHint => '设置仅对本次跟读有效';

  @override
  String get listenAndRepeatPauseSmartDesc => '根据难度、句子长度和学习阶段自动调整';

  @override
  String sentenceDuration(String duration) {
    return '$duration秒';
  }

  @override
  String difficultSentenceCount(int count) {
    return '标记 $count 个难句';
  }

  @override
  String intensiveListenPassInfo(int count) {
    return '精听 $count 遍';
  }

  @override
  String shadowingPassInfo(int count) {
    return '跟读 $count 遍';
  }

  @override
  String get retellBriefingTitle => '段级复述';

  @override
  String get retellBriefingSubtitle => '听一段音频，然后尝试复述。关键词会帮助你回忆内容。';

  @override
  String get retellBriefingTargetDuration => '目标段落时长';

  @override
  String retellBriefingParagraphCount(int count) {
    return '将分为 $count 个段落';
  }

  @override
  String retellBriefingSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get retellBriefingSentenceLevel => '逐句';

  @override
  String retellBriefingSentenceCount(int count) {
    return '共 $count 个句子';
  }

  @override
  String get retellTitle => '段级复述';

  @override
  String retellParagraphProgress(int current, int total) {
    return '段落 $current/$total';
  }

  @override
  String retellParagraphDuration(String duration) {
    return '段落时长 $duration';
  }

  @override
  String get retellListeningPhase => '认真听...';

  @override
  String retellRetellingCountdown(int seconds) {
    return '请复述 ${seconds}s';
  }

  @override
  String retellRepeatInfo(int current, int total) {
    return '第 $current/$total 遍';
  }

  @override
  String get retellCompleteFirstStudy => '完成首学';

  @override
  String get retellCompleteReview => '完成复习';

  @override
  String get retellCompleteFreePlay => '练习完成';

  @override
  String get retellCompleteTitle => '复述完成';

  @override
  String get retellPracticeAgain => '再来一遍';

  @override
  String retellCompleteMessage(int count) {
    return '共 $count 段复述完成';
  }

  @override
  String get retellExitConfirmTitle => '退出复述？';

  @override
  String get retellExitConfirmMessage => '当前段落进度将被保存。';

  @override
  String get retellDisplayKeywordsOnly => '仅可见词';

  @override
  String get retellDisplayShowAll => '全部显示';

  @override
  String get retellDisplayHideAll => '全部隐藏';

  @override
  String get retellSettingsTitle => '复述设置';

  @override
  String get retellRepeatCount => '每段重复次数';

  @override
  String get retellPauseMode => '复述停顿';

  @override
  String retellPassInfo(int count) {
    return '复述 $count 遍';
  }

  @override
  String get retellNoDifficultSentences => '没有可复述的句子。请先完成逐句精听。';

  @override
  String get retellKeywordMethod => '可见词生成方式';

  @override
  String get retellKeywordMethodOff => '关闭';

  @override
  String get retellKeywordMethodRandom => '随机';

  @override
  String get retellKeywordMethodAi => 'AI';

  @override
  String get retellKeywordMethodAiComingSoon => '即将推出';

  @override
  String get retellKeywordRatio => '可见词比例';

  @override
  String get pauseModeSmart => '智能';

  @override
  String get pauseModeFixed => '固定';

  @override
  String get pauseModeMultiplier => '倍数';

  @override
  String get fixedPauseSeconds => '固定间隔';

  @override
  String get pauseMultiplier => '倍数';

  @override
  String get settingsSessionOnly => '设置仅对本次会话生效';

  @override
  String get reviewDifficultPracticeTitle => '难句补练';

  @override
  String reviewDifficultPracticeProgress(int current, int total) {
    return '$current/$total 句';
  }

  @override
  String get reviewDifficultPracticeBlindListen => '正在播放…';

  @override
  String get reviewDifficultPracticeCompleteTitle => '难句补练完成';

  @override
  String reviewDifficultPracticeCompleteMessage(int total) {
    return '已完成全部 $total 个难句的练习。';
  }

  @override
  String get reviewDifficultPracticeNone => '没有需要补练的难句。';

  @override
  String get exitReviewDifficultPracticeTitle => '退出补练？';

  @override
  String get exitReviewDifficultPracticeMessage => '当前步骤的进度不会保存。';

  @override
  String get exitReviewDifficultPracticeConfirmMessage => '进度会保存，下次可继续。';

  @override
  String reviewDifficultPracticeAdvancing(int seconds) {
    return '$seconds秒后进入下一句';
  }

  @override
  String get developer => '开发者';

  @override
  String get unlockAllReviews => '解锁所有复习';

  @override
  String get unlockAllReviewsDescription => '跳过复习时间锁，用于测试';

  @override
  String get manageSubtitles => '管理字幕';

  @override
  String get localUpload => '本地上传';

  @override
  String get aiTranscription => 'AI 转录';

  @override
  String get deleteSubtitle => '删除字幕';

  @override
  String get startTranscription => '开始转录';

  @override
  String get alreadyTranscribedWithOption => '已使用该选项转录';

  @override
  String get transcriptionUploading => '上传中…';

  @override
  String get transcriptionProcessing => '转录中…';

  @override
  String get transcriptionComplete => '完成！';

  @override
  String get transcriptionFailed => '转录失败';

  @override
  String get transcriptionErrorConnection => '无法连接服务器';

  @override
  String get transcriptionErrorTimeout => '请求超时，请重试';

  @override
  String get transcriptionErrorServer => '服务器错误，请稍后重试';

  @override
  String get transcriptionErrorUnknown => '出了点问题';

  @override
  String transcriptionErrorFileTooLarge(int maxMb) {
    return '文件过大（最大 ${maxMb}MB）';
  }

  @override
  String transcriptionErrorTooLong(int maxMin) {
    return '音频过长（最长 $maxMin 分钟）';
  }

  @override
  String get deleteSubtitleConfirm => '确定删除字幕？';

  @override
  String get deleteSubtitleWarning => '删除字幕将影响学习进度。';

  @override
  String get languageMulti => '混合语言';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get overwriteExistingSubtitle => '覆盖现有字幕？';

  @override
  String get overwriteExistingSubtitleMessage => '这将替换当前字幕，确定继续吗？';

  @override
  String get overwrite => '覆盖';

  @override
  String get currentSubtitleExists => '当前：已有字幕';

  @override
  String get currentSubtitleLocal => '当前：本地上传';

  @override
  String currentSubtitleAi(String language) {
    return '当前：AI 转录（$language）';
  }

  @override
  String get noSubtitleYet => '暂无字幕';

  @override
  String get addSubtitlePromptTitle => '添加字幕？';

  @override
  String get addSubtitlePromptMessage => '现在添加字幕用于学习吗？';

  @override
  String get selectCollection => '合集（可选）';

  @override
  String get noCollection => '无';

  @override
  String get addSubtitle => '添加字幕';

  @override
  String get retryTranscription => '重试';

  @override
  String transcriptionFailedMessage(String message) {
    return '错误：$message';
  }

  @override
  String todayStudyTime(String time) {
    return '今日：$time';
  }

  @override
  String studyTimeMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String studyTimeHoursMinutes(int hours, int minutes) {
    return '$hours小时$minutes分钟';
  }

  @override
  String get studyTasks => '学习任务';

  @override
  String get continueLearningHero => '继续学习';

  @override
  String get startButton => '开始';

  @override
  String get continueButton => '继续';

  @override
  String get reviewButton => '复习';

  @override
  String streakDays(int count) {
    return '连续 $count 天';
  }

  @override
  String get todayStudyTimeShort => '今日';

  @override
  String get weekStudyTimeShort => '本周';

  @override
  String readyToReview(int count) {
    return '待复习 ($count)';
  }

  @override
  String upcomingReviews(int count) {
    return '待解锁 ($count)';
  }

  @override
  String upcomingReviewsSummary(int count) {
    return '$count 个复习任务将在稍后解锁';
  }

  @override
  String firstStudySection(int count) {
    return '首学 ($count)';
  }

  @override
  String completedSection(int count) {
    return '已完成 ($count)';
  }

  @override
  String get noStudyTasks => '暂无学习任务';

  @override
  String get noStudyTasksHint => '导入音频后即可开始学习。';

  @override
  String get goToLibrary => '去导入音频';

  @override
  String get allDoneTitle => '今日任务完成！';

  @override
  String get allDoneHint => '做得不错，稍后回来复习吧。';

  @override
  String overdueDays(int count) {
    return '逾期 $count 天';
  }

  @override
  String overdueHours(int count) {
    return '逾期 $count 小时';
  }

  @override
  String availableInDays(int count) {
    return '$count 天后';
  }

  @override
  String availableInHours(int count) {
    return '$count 小时后';
  }

  @override
  String subStageLabelFirstLearn(String subStage) {
    return '首学 - $subStage';
  }

  @override
  String subStageLabelReview(String reviewName, String subStage) {
    return '$reviewName - $subStage';
  }
}
