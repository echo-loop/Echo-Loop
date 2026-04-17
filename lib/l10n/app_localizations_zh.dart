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
  String get practiceControlModeAuto => '自动';

  @override
  String get practiceControlModeManual => '手动';

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
  String get language => '应用语言';

  @override
  String get languageDescription => '应用界面使用的语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get nativeLanguage => '母语';

  @override
  String get nativeLanguageDescription => '翻译和解析使用的语言';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get save => '保存';

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
  String get pinCollection => '置顶';

  @override
  String get unpinCollection => '取消置顶';

  @override
  String get pinAudio => '置顶';

  @override
  String get unpinAudio => '取消置顶';

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
  String get firstStudy => '首次学习';

  @override
  String get review => '复习';

  @override
  String stepProgress(int completed, int total) {
    return '$completed/$total 完成';
  }

  @override
  String get stepBlindListening => '全文盲听';

  @override
  String get stepBlindListeningDesc => '先盲听，感受整体难度和大意';

  @override
  String get stepIntensiveListening => '逐句精听';

  @override
  String get stepIntensiveListeningDesc => '逐句听，理解并标记难句';

  @override
  String get stepShadowing => '难句跟读';

  @override
  String get stepShadowingDesc => '针对弱项句子反复跟读';

  @override
  String get stepRetelling => '段落复述';

  @override
  String get stepRetellingDesc => '用英文复述每段大意';

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
  String reviewUnlockIn(int days) {
    return '$days天后解锁';
  }

  @override
  String reviewUnlockInHours(int hours) {
    return '$hours小时后解锁';
  }

  @override
  String get reviewUnlocked => '已解锁';

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
  String get blindListenBriefingSubtitle => '首次学习 - 全文盲听';

  @override
  String blindListenBriefingReviewSubtitle(int round) {
    return '第$round轮复习 - 全文盲听';
  }

  @override
  String get blindListenBriefingTip => '不看字幕，完整听一遍，感受大意和难度';

  @override
  String get startPractice => '开始练习';

  @override
  String get blindListenAppBarTitle => '全文盲听';

  @override
  String blindListenPassLabel(int count) {
    return '第 $count 遍';
  }

  @override
  String get blindListenComplete => '盲听完成';

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
  String get difficultyVeryEasy => '很简单';

  @override
  String get difficultyEasy => '简单';

  @override
  String get difficultyMedium => '中等';

  @override
  String get difficultyHard => '困难';

  @override
  String get difficultyVeryHard => '很困难';

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
    return '确定要删除「$name」吗？音频文件将被永久删除。';
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
  String get noTranscriptWarning => '这个音频还没有字幕';

  @override
  String get intensiveListenAppBarTitle => '逐句精听';

  @override
  String intensiveListenProgress(int current, int total) {
    return '第 $current/$total 句';
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
  String get intensiveListenCantUnderstand => '听不太懂';

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
  String get aiTranslationFailed => '翻译失败，请重试';

  @override
  String get aiAnalysisFailed => '解析失败，请重试';

  @override
  String get aiRetry => '重试';

  @override
  String get aiGrammar => '语法';

  @override
  String get aiVocabulary => '词汇';

  @override
  String get aiListening => '听力提示';

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
    return '你已完成全部 $total 个句子的精听。\n共标记 $difficult 个难句。';
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
  String get intensiveListenBriefingSubtitle => '首次学习 - 逐句精听';

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
  String get intensiveListenPauseSmart => '自动';

  @override
  String get intensiveListenPauseFixed => '固定间隔';

  @override
  String get intensiveListenPauseMultiplierMode => '句长倍数';

  @override
  String get intensiveListenSettingsTemporaryHint => '设置仅对本次精听有效';

  @override
  String get intensiveListenPauseSmartDesc => '根据难度、句子长度和学习阶段自动调整';

  @override
  String get intensiveListenControlModeAutoDesc => '自动循环、自动停顿、自动下一句';

  @override
  String get intensiveListenControlModeManualDesc => '手动重听、手动下一句';

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
  String continueToStep(String step) {
    return '继续：$step';
  }

  @override
  String get completeFirstStudy => '完成首次学习';

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
    return '第 $current/$total 句';
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
  String get listenAndRepeatListenHint => '先听再跟读';

  @override
  String get listenAndRepeatYourTurnHint => '请跟读';

  @override
  String get listenAndRepeatRecordButton => '录音';

  @override
  String get listenAndRepeatStopRecordingButton => '停止';

  @override
  String get listenAndRepeatPlayRecordingButton => '播放我的录音';

  @override
  String get listenAndRepeatRecordingInProgress => '录音中...';

  @override
  String get listenAndRepeatStartSpeaking => '请开口跟读';

  @override
  String get listenAndRepeatAnalyzing => '分析中...';

  @override
  String get listenAndRepeatTapToRecord => '点击开始录音';

  @override
  String get listenAndRepeatRatingPerfect => '完美!';

  @override
  String get listenAndRepeatRatingExcellent => '非常棒';

  @override
  String get listenAndRepeatRatingGood => '不错';

  @override
  String get listenAndRepeatRatingFair => '还行';

  @override
  String get listenAndRepeatRatingKeepGoing => '继续加油';

  @override
  String get listenAndRepeatAwaitingFinalTranscript => '正在确认最终转录...';

  @override
  String get listenAndRepeatYourTakeLabel => '你的转录';

  @override
  String get listenAndRepeatRecognitionInProgress => '正在识别录音...';

  @override
  String listenAndRepeatRecognitionPassed(int percent) {
    return '匹配了目标词的 $percent%。';
  }

  @override
  String listenAndRepeatRecognitionBelowThreshold(int percent) {
    return '匹配了目标词的 $percent%。';
  }

  @override
  String get listenAndRepeatRecognitionNoEnglish => '未检测到英语';

  @override
  String get listenAndRepeatRecognitionPermissionDenied => '需要麦克风和语音识别权限。';

  @override
  String get listenAndRepeatRecognitionUnavailable => '当前设备暂不支持语音识别。';

  @override
  String get listenAndRepeatRecognitionError => '识别错误';

  @override
  String get listenAndRepeatRecordingOnly => '录音';

  @override
  String get listenAndRepeatCompleteTitle => '跟读完成';

  @override
  String listenAndRepeatCompleteMessage(int total) {
    return '你已完成全部 $total 个难句的跟读练习。';
  }

  @override
  String get listenAndRepeatNoDifficultSentences => '精听全部听懂，跟读已自动完成';

  @override
  String get exitListenAndRepeatTitle => '退出跟读？';

  @override
  String get exitListenAndRepeatMessage => '进度已保存，下次可从断点继续。';

  @override
  String get listenAndRepeatBriefingTitle => '难句跟读';

  @override
  String get listenAndRepeatBriefingSubtitle => '首次学习 - 难句跟读';

  @override
  String get listenAndRepeatBriefingTip => '先听原句，在停顿期间跟读。';

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
  String get listenAndRepeatControlModeLabel => '控制模式';

  @override
  String get listenAndRepeatControlModeAuto => '自动';

  @override
  String get listenAndRepeatControlModeManual => '手动';

  @override
  String get listenAndRepeatControlModeAutoDesc => '自动录音、自动停止、自动下一句';

  @override
  String get listenAndRepeatControlModeManualDesc => '手动录音、手动停止、手动下一句';

  @override
  String get listenAndRepeatPauseSmartDesc => '根据难度、句子长度和学习阶段自动调整';

  @override
  String sentenceDuration(String duration) {
    return '$duration秒';
  }

  @override
  String difficultSentenceCount(int count) {
    return '$count 个难句';
  }

  @override
  String intensiveListenPassInfo(int count) {
    return '已练习 $count 遍';
  }

  @override
  String shadowingPassInfo(int count) {
    return '已练习 $count 遍';
  }

  @override
  String get retellBriefingTitle => '段落复述';

  @override
  String get retellBriefingSubtitle => '先盲听一段，再用英语复述大意。';

  @override
  String get retellBriefingTargetDuration => '段落时长';

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
  String get retellTitle => '段落复述';

  @override
  String retellParagraphProgress(int current, int total) {
    return '第 $current/$total 段';
  }

  @override
  String retellParagraphDuration(String duration) {
    return '$duration秒';
  }

  @override
  String get retellPreListenHint => '先听再复述';

  @override
  String get retellListeningPhase => '认真听...';

  @override
  String get retellPromptToRetell => '用自己的话复述';

  @override
  String retellRetellingCountdown(int seconds) {
    return '请复述 ${seconds}s';
  }

  @override
  String retellRepeatInfo(int current, int total) {
    return '第 $current/$total 遍';
  }

  @override
  String get retellCompleteFirstStudy => '完成首次学习';

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
  String get retellPauseMode => '段间停顿';

  @override
  String retellPassInfo(int count) {
    return '已练习 $count 遍';
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
  String get pauseModeSmart => '自动';

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
    return '第 $current/$total 句';
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
  String get reviewDifficultPracticeNone => '无需补练的难句，已自动完成';

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
  String get aiSectionTitle => 'AI';

  @override
  String get speechRecognition => '语音识别';

  @override
  String get speechRecognitionNotConfigured => '未设置';

  @override
  String get speechRecognitionEnabled => '已开启';

  @override
  String get speechRecognitionDisabled => '已关闭';

  @override
  String get speechRecognitionDescription => '开启语音识别后，跟读和复述练习时会自动识别你的发音并评估准确度。';

  @override
  String get asrBackendPlatform => 'Apple Speech';

  @override
  String get asrBackendPlatformDescription => '使用系统自带的语音识别，无需下载';

  @override
  String get asrBackendOffline => 'Echo Loop AI';

  @override
  String get asrBackendOfflineDescription => '使用应用自带的 AI 模型，支持离线使用，需下载';

  @override
  String asrModelTier(String tier) {
    return '模型：$tier（根据设备性能自动选择）';
  }

  @override
  String get localSpeechRecognition => '本地语音识别';

  @override
  String speechModelSize(String size) {
    return '模型大小：约 $size';
  }

  @override
  String speechModelReady(String size) {
    return '已就绪 · $size';
  }

  @override
  String speechModelDownloading(String progress) {
    return '正在下载... $progress';
  }

  @override
  String get speechModelDownloadFailed => '下载失败，点击重试。';

  @override
  String deleteModel(String size) {
    return '删除模型（$size）';
  }

  @override
  String get deleteModelAction => '删除模型';

  @override
  String get deleteModelConfirmTitle => '确认删除模型？';

  @override
  String deleteModelConfirmMessage(String size) {
    return '删除后将释放 $size 存储空间。';
  }

  @override
  String get disableSpeechRecognitionTitle => '关闭语音识别？';

  @override
  String get disableSpeechRecognitionMessage => '关闭后语音练习将无法评分。';

  @override
  String get alsoDeleteModel => '同时删除已下载的模型';

  @override
  String get disableAction => '关闭';

  @override
  String get speechRecognitionRequiredTitle => '需要下载语音识别模型';

  @override
  String get speechRecognitionRequiredMessage =>
      '语音识别用于自动评估跟读和复述效果，需要下载模型才能使用。你可以在设置中关闭此功能。';

  @override
  String get downloadAndEnable => '下载并启用';

  @override
  String get notNow => '暂不启用';

  @override
  String get speechModelRepairTitle => '模型下载不完整';

  @override
  String get speechModelRepairMessage => '语音识别模型未下载完成，需要重新下载才能使用语音练习。';

  @override
  String get downloadNow => '立即下载';

  @override
  String get later => '稍后';

  @override
  String get speechRecognitionNotEnabled => '语音识别未启用，可在设置中开启';

  @override
  String get retryDownload => '重试';

  @override
  String get downloadingSpeechModel => '正在下载语音识别模型';

  @override
  String get developer => '开发者';

  @override
  String get developerOptionsEnabled => '开发者选项已开启';

  @override
  String get developerOptionsDisable => '关闭开发者选项';

  @override
  String get timeMachine => '时光机';

  @override
  String get timeMachineUseSystemTime => '使用系统时间';

  @override
  String get timeMachineCurrentTime => '当前调试时间';

  @override
  String get timeMachineSelectDate => '选择日期';

  @override
  String get timeMachineSelectTime => '选择时间';

  @override
  String get timeMachineReset => '恢复系统时间';

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
  String get transcriptionEmptyResult => '未检测到语音';

  @override
  String get transcriptionEmptyResultHint => '音频可能包含过多背景噪音。';

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
  String get deleteSubtitleWarning => '删除字幕将同时清空该音频的所有收藏句子和学习进度。';

  @override
  String get languageAutoDetect => '自动检测';

  @override
  String get mixedLanguageNotSupported => '暂不支持混合语言音频';

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
    return '首次学习 ($count)';
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
    return '$count天前到期';
  }

  @override
  String overdueHours(int count) {
    return '$count小时前到期';
  }

  @override
  String get reviewDue => '待复习';

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
    return '首次学习 - $subStage';
  }

  @override
  String subStageLabelReview(String reviewName, String subStage) {
    return '$reviewName - $subStage';
  }

  @override
  String get favoritesSentences => '句子';

  @override
  String get favoritesVocabulary => '词汇';

  @override
  String get favoritesNoSentences => '暂无收藏句子';

  @override
  String get favoritesNoSentencesHint => '在精听或跟读中标记难句';

  @override
  String get favoritesNoVocabulary => '暂无收藏词汇';

  @override
  String get favoritesNoVocabularyHint => '在学习中点击单词查词并收藏';

  @override
  String favoritesBookmarkCount(int count) {
    return '$count 个句子';
  }

  @override
  String get favoritesVocabularySaved => '已收藏';

  @override
  String get favoritesVocabularyRemoved => '再次收藏';

  @override
  String get favoritesBookmarkRemoved => '再次收藏';

  @override
  String get undo => '撤销';

  @override
  String get favoritesSaveVocabulary => '收藏';

  @override
  String get favoritesUnsaveVocabulary => '取消收藏';

  @override
  String get bookmarkReviewTitle => '收藏复习';

  @override
  String get bookmarkReviewStart => '开始复习';

  @override
  String bookmarkReviewStartCount(int count) {
    return '开始复习 ($count)';
  }

  @override
  String get bookmarkReviewComplete => '复习完成';

  @override
  String bookmarkReviewCompleteMessage(int count) {
    return '已复习全部 $count 个收藏句子。';
  }

  @override
  String get bookmarkReviewAgain => '再来一遍';

  @override
  String get bookmarkReviewAudioSkipped => '音频不可用，跳过该句';

  @override
  String bookmarkReviewFromAudio(String name) {
    return '来自：$name';
  }

  @override
  String get difficultPracticeSettings => '练习设置';

  @override
  String get difficultPracticeSettingsHint => '设置仅对本次练习有效';

  @override
  String get difficultPracticeBlindListenRepeat => '盲听循环次数';

  @override
  String get difficultPracticeShadowReadingRepeat => '跟读循环次数';

  @override
  String get inputWordsShort => '输入';

  @override
  String get outputWordsShort => '输出';

  @override
  String listenTimeWords(String time, String words) {
    return '听: $time · $words词';
  }

  @override
  String speakTimeWords(String time, String words) {
    return '说: $time · $words词';
  }

  @override
  String get learnedWordFormsShort => '词汇量';

  @override
  String get todayNewShort => '今日';

  @override
  String get learnedWordsEmptyHint => '还没有记录到已学词汇，先完成一些学习内容吧。';

  @override
  String get learnedWordsSortTimeAsc => '最早学习';

  @override
  String get learnedWordsSortTimeDesc => '最近学习';

  @override
  String bookmarkReviewProgress(int current, int total) {
    return '第 $current/$total 句';
  }

  @override
  String get flashcardTitle => '单词卡片';

  @override
  String get flashcardViewAnswer => '想好了，查看答案';

  @override
  String get flashcardTapToFlip => '点击翻回正面';

  @override
  String get flashcardUnsaveHint => '掌握了就取消收藏';

  @override
  String flashcardProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get flashcardComplete => '复习完成';

  @override
  String flashcardWordsReviewed(int count) {
    return '已复习 $count 个单词';
  }

  @override
  String flashcardWordsRemoved(int count) {
    return '已取消收藏 $count 个';
  }

  @override
  String get flashcardPracticeAgain => '再来一遍';

  @override
  String get flashcardFinish => '完成';

  @override
  String get flashcardSettingsTitle => '卡片设置';

  @override
  String get flashcardSettingsSubtitle => '设置会自动保存';

  @override
  String get flashcardControlModeLabel => '控制模式';

  @override
  String get flashcardControlModeAuto => '自动';

  @override
  String get flashcardControlModeManual => '手动';

  @override
  String get flashcardControlModeAutoDesc => '自动翻转、自动切换下一张';

  @override
  String get flashcardControlModeManualDesc => '手动翻转、手动切换下一张';

  @override
  String get flashcardTimerMode => '单词切换时长';

  @override
  String get flashcardTimerSmart => '自动';

  @override
  String get flashcardTimerSmartDesc => '根据单词难度和练习次数自动调整';

  @override
  String get flashcardTimerFixed => '固定时长';

  @override
  String get flashcardTimerFixedDesc => '正面和背面分别设置固定时长';

  @override
  String get flashcardTimerFrontDuration => '正面时长';

  @override
  String get flashcardTimerBackDuration => '背面时长';

  @override
  String get flashcardSortMode => '单词排序方式';

  @override
  String get flashcardSortAlphaAsc => 'A → Z';

  @override
  String get flashcardSortAlphaDesc => 'Z → A';

  @override
  String get flashcardSortTimeAsc => '最早收藏';

  @override
  String get flashcardSortTimeDesc => '最近收藏';

  @override
  String get flashcardSortRandom => '随机';

  @override
  String get flashcardSortSmart => '自动';

  @override
  String get flashcardSortSmartDesc => '根据记忆规律自动决定顺序';

  @override
  String get flashcardSortRandomDesc => '每次随机打乱顺序';

  @override
  String get flashcardSortAlphaAscDesc => '按字母 A 到 Z 排列';

  @override
  String get flashcardSortAlphaDescDesc => '按字母 Z 到 A 排列';

  @override
  String get flashcardSortTimeAscDesc => '最早收藏的排在前面';

  @override
  String get flashcardSortTimeDescDesc => '最近收藏的排在前面';

  @override
  String get flashcardNoDefinition => '暂无释义';

  @override
  String get flashcardStartQuiz => '开始复习';

  @override
  String get flashcardTts => '发音';

  @override
  String get flashcardAutoPlaySentence => '自动播放例句';

  @override
  String get flashcardAutoPlayWord => '自动播放单词发音';

  @override
  String get freePlay => '自由练习';

  @override
  String get wordAiAnalysis => 'AI 解析';

  @override
  String get wordAiContextMeaning => '语境释义';

  @override
  String get wordAiCollocations => '常见搭配';

  @override
  String get wordAiUsage => '用法要点';

  @override
  String get wordAiWordFamily => '词族扩展';

  @override
  String get storage => '存储';

  @override
  String get clearCache => '清除缓存';

  @override
  String get clearCacheConfirm => '将清除所有缓存数据（如 AI 翻译和解析结果），需要时会重新获取。是否继续？';

  @override
  String get clearCacheSuccess => '缓存已清除';

  @override
  String clearCacheSuccessWithSize(String size) {
    return '缓存已清除，释放了 $size';
  }

  @override
  String get clearCacheEmpty => '缓存已为空';

  @override
  String get confirm => '确认';

  @override
  String get autoCompletedNoDifficult => '0 个难句，已跳过';

  @override
  String get autoCompletedNoDifficultReview => '0 个难句，已跳过';

  @override
  String get termsOfService => '服务条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get writeFeedback => '意见反馈';

  @override
  String updateAvailable(String version) {
    return '发现新版本 v$version';
  }

  @override
  String get updateNow => '立即更新';

  @override
  String get updateLater => '稍后提醒';

  @override
  String get forceUpdateTitle => '需要更新';

  @override
  String get forceUpdateMessage => '当前版本已不再受支持，请更新以继续使用。';

  @override
  String get copyDownloadLink => '复制下载链接';

  @override
  String get linkCopied => '已复制';

  @override
  String get checkForUpdate => '检查更新';

  @override
  String get alreadyLatest => '已是最新版本';

  @override
  String get checkUpdateFailed => '检查失败，请检查网络';

  @override
  String get demoMode => '演示模式';

  @override
  String get demoModeSubtitle => '开启后使用演示数据，方便截图展示';

  @override
  String get practiceRemoveMark => '取消标记';

  @override
  String get practiceAddMark => '重新标记';

  @override
  String blindListenSegmentProgress(int current, int total) {
    return '第 $current/$total 段';
  }

  @override
  String blindListenSegmentDuration(int duration) {
    return '$duration秒';
  }

  @override
  String get blindListenListeningHint => '认真听...';

  @override
  String get blindListenPreListenHint => '先听再回忆';

  @override
  String blindListenRepeatInfo(int current, int total) {
    return '第 $current/$total 遍';
  }

  @override
  String get blindListenSettingsTitle => '盲听设置';

  @override
  String get blindListenPauseBetween => '段间停顿';

  @override
  String get blindListenTargetDuration => '段落时长';

  @override
  String get blindListenDisplayHideAll => '隐藏字幕';

  @override
  String get blindListenDisplayShowAll => '显示字幕';

  @override
  String get blindListenRecallHint => '回想刚才听到的内容';

  @override
  String get blindListenControlModeAutoDesc => '自动重复、自动停顿、自动下一段';

  @override
  String get blindListenControlModeManualDesc => '手动重听、手动下一段';

  @override
  String get blindListenNoParagraph => '不分段';

  @override
  String blindListenParagraphCount(int count) {
    return '$count 个段落';
  }

  @override
  String get resetLearningProgress => '重置学习进度';

  @override
  String get resetLearningProgressConfirmTitle => '重置学习进度？';

  @override
  String resetLearningProgressConfirmMessage(String name) {
    return '将清除「$name」的所有学习进度，此操作不可撤销。';
  }

  @override
  String get resetLearningProgressDone => '学习进度已重置';

  @override
  String reviewReminderBody(String audioName, int round) {
    return '$audioName · 第$round轮复习时间到了';
  }

  @override
  String get stageBlindListen => '盲听';

  @override
  String get stageIntensiveListen => '精听';

  @override
  String get stageListenAndRepeat => '跟读';

  @override
  String get stageRetell => '复述';

  @override
  String get stageReviewDifficultPractice => '难句补练';

  @override
  String get stageBookmarkReview => '句子复习';

  @override
  String get stageFlashcard => '单词复习';

  @override
  String stageBreakdownTitle(String date) {
    return '$date';
  }

  @override
  String get stageBreakdownToday => '（今天）';

  @override
  String get stageBreakdownTotal => '合计';

  @override
  String get stageBreakdownLessThanOneMin => '<1分';

  @override
  String get stageBreakdownListenShort => '听';

  @override
  String get stageBreakdownSpeakShort => '说';

  @override
  String get stageBreakdownNoStageData => '详细分布数据从此版本开始记录';

  @override
  String get stageBreakdownNoRecord => '当天没有学习记录';

  @override
  String get chartLegendListening => '听';

  @override
  String get chartLegendSpeaking => '说';

  @override
  String get chartLegendOther => '其它';

  @override
  String get chartLegendOtherHint => '思考、停顿等';

  @override
  String get reminderSectionTitle => '提醒';

  @override
  String get reminderSettings => '提醒设置';

  @override
  String get savedReviewReminderSection => '收藏复习提醒';

  @override
  String get savedReviewReminderToggle => '收藏内容提醒';

  @override
  String get savedReviewReminderTime => '每日提醒时间';

  @override
  String get savedReviewReminderDescription => '通勤或睡前复习收藏内容，效果更好';

  @override
  String get audioReviewReminderSection => '音频复习提醒';

  @override
  String get audioReviewReminderToggle => '音频到期提醒';

  @override
  String get audioReviewReminderDescription => '到复习时间时通知你，帮你保持复习节奏';

  @override
  String recentCompletions(int count) {
    return '最近完成 ($count)';
  }

  @override
  String get recentCompletionsSummary => '过去24小时';

  @override
  String get timeAgoJustNow => '刚刚';

  @override
  String timeAgoMinutes(int minutes) {
    return '$minutes分钟前';
  }

  @override
  String timeAgoHours(int hours) {
    return '$hours小时前';
  }

  @override
  String get exportAudio => '导出';

  @override
  String get exportAudioFile => '音频';

  @override
  String get exportSubtitleFile => '字幕';

  @override
  String get exportSelectFiles => '选择要导出的文件';

  @override
  String get exportData => '导出数据';

  @override
  String get exportDataSubtitle => '导出全部数据到 ZIP 文件';

  @override
  String get importData => '导入数据';

  @override
  String get importDataSubtitle => '从备份文件恢复数据';

  @override
  String get exporting => '正在导出...';

  @override
  String get importing => '正在导入...';

  @override
  String get exportSuccess => '导出完成';

  @override
  String get importSuccess => '导入完成';

  @override
  String get importConfirmTitle => '确认导入';

  @override
  String get importConfirmMessage => '这将替换当前所有数据，包括学习进度、收藏和音频文件。此操作不可撤销。';

  @override
  String get backupTime => '备份时间';

  @override
  String get backupVersion => '应用版本';

  @override
  String get backupFileCount => '媒体文件';

  @override
  String get backupSize => '总大小';

  @override
  String get importIncompatible => '此备份由更新版本的应用创建，请先更新应用。';

  @override
  String get importInvalidFile => '无效的备份文件';

  @override
  String get exportingDatabase => '正在导出数据库...';

  @override
  String get exportingPreferences => '正在导出设置...';

  @override
  String get exportingMedia => '正在导出媒体文件...';

  @override
  String get exportingPacking => '正在打包备份文件...';

  @override
  String get importingExtracting => '正在解压备份...';

  @override
  String get importingMedia => '正在恢复媒体文件...';

  @override
  String get importingDatabase => '正在恢复数据库...';

  @override
  String get importingPreferences => '正在恢复设置...';

  @override
  String get activityCalendar => '学习日历';

  @override
  String get noActivityThisMonth => '本月暂无学习记录';

  @override
  String monthlySummaryTitle(String month) {
    return '$month月统计';
  }

  @override
  String get monthlyTotal => '总计';

  @override
  String get monthlyActiveDays => '学习天数';

  @override
  String get monthlyAvgPerDay => '日均';

  @override
  String get monthlyBestStreak => '最长连续';

  @override
  String daysSuffix(int days) {
    return '$days天';
  }

  @override
  String activeDaysFraction(int active, int total) {
    return '$active/$total天';
  }

  @override
  String get senseGroupSplit => '拆分意群';

  @override
  String get senseGroupLoading => '拆分中...';

  @override
  String get senseGroupSingleGroup => '此句为单个意群';

  @override
  String get senseGroupSave => '收藏';

  @override
  String get senseGroupSaved => '已收藏';

  @override
  String get annotationBtnSenseGroup => '意群';

  @override
  String get annotationBtnSenseGroupMedium => '大意群';

  @override
  String get annotationBtnSenseGroupFine => '小意群';

  @override
  String get annotationBtnTranslation => '翻译';

  @override
  String get annotationBtnAnalysis => '解析';

  @override
  String get senseGroupLoadFailed => '意群拆分失败，请重试';

  @override
  String get senseGroupNotAvailable => '仅 AI 转录的音频支持意群拆分';

  @override
  String get wordTimestampsNotFound => '词级字幕未找到，请重启应用重试';

  @override
  String get recycleBinTitle => '回收站';

  @override
  String get recycleBinEmpty => '没有已移除的内容';

  @override
  String get recycleBinClearAll => '清空';

  @override
  String recycleBinClearAllConfirm(int count) {
    return '永久删除全部 $count 条内容？此操作不可撤销。';
  }

  @override
  String get recycleBinRestore => '恢复';

  @override
  String get recycleBinDelete => '删除';

  @override
  String get recycleBinSortTimeDesc => '最近移除';

  @override
  String get recycleBinSortTimeAsc => '最早移除';

  @override
  String recycleBinItemCount(int count) {
    return '$count 条';
  }

  @override
  String filesSelected(int count) {
    return '已选择 $count 个文件';
  }

  @override
  String processingFileOf(int current, int total) {
    return '正在处理 $current/$total...';
  }

  @override
  String multipleAudioAdded(int count) {
    return '已添加 $count 个音频';
  }

  @override
  String duplicatesSkipped(int count) {
    return '跳过 $count 个重复项';
  }

  @override
  String get duplicatesSkippedDetail => '以下音频在库中已存在，已跳过：';

  @override
  String get removeFile => '移除';

  @override
  String get goToSettings => '前往设置';

  @override
  String get dictionaryDownloading => '词典下载中...';

  @override
  String get dictionaryDownloadFailed => '词典下载失败';

  @override
  String get dictionaryNotDownloaded => '词典尚未下载';

  @override
  String get download => '下载';

  @override
  String get retry => '重试';

  @override
  String get guideNext => '下一步';

  @override
  String get guideDone => '知道了';

  @override
  String get guideLibraryCollectionListDescription =>
      '这里是合集列表。合集用于将音频按主题分类整理，点击任意合集，可以查看其中包含的音频。';

  @override
  String get guideLibraryCollectionMenuDescription => '点击这里，可以置顶、重命名或删除合集。';

  @override
  String get guideLibraryCreateCollectionDescription => '点击这里，可以创建新的合集。';

  @override
  String get guideCollectionAudioListDescription => '点击任意音频，可以查看它的学习计划和当前进度。';

  @override
  String get guideCollectionAudioMenuDescription =>
      '点击这里，可以管理该音频的字幕、所属合集、标签等信息。';

  @override
  String get guideCollectionUploadDescription => '点击这里，可以上传你自己的音频。';

  @override
  String get guidePlanAddSubtitleTitle => '添加字幕';

  @override
  String get guidePlanAddSubtitleDescription =>
      '可以用 AI 一键生成字幕，或上传本地字幕文件。完成后即可开始学习这段音频。';

  @override
  String get guidePlanAiTranscriptionTitle => '使用 AI 转录';

  @override
  String get guidePlanAiTranscriptionDescription =>
      '如果你手头没有字幕文件，使用 AI 转录是最快的方式。';

  @override
  String get guidePlanStartTranscriptionDescription => '点击这里，让 AI 为这段音频生成字幕。';

  @override
  String get guidePlanFreePlayTitle => '自由练习';

  @override
  String get guidePlanFreePlayDescription =>
      '这是一个全能的、灵活的音频播放器，适合自由练习，你可以按照自己的节奏学习。';

  @override
  String get guidePlanStartLearningTitle => '按计划学习';

  @override
  String get guidePlanStartLearningDescription =>
      '点击这里即可按照学习计划逐步学习。Echo Loop 会自动引导你学习，并及时提醒你复习。';

  @override
  String get guideMainShellVisitLibraryTitle => '从资源库开始';

  @override
  String get guideMainShellVisitLibraryDescription => '点击这里，了解如何使用本 App。';

  @override
  String get guideStudyTasksOverviewTitle => '这里是你的学习任务';

  @override
  String get guideStudyTasksOverviewDescription =>
      '包括待学习的新音频、到期的复习任务和已完成的任务等。Echo Loop 会自动帮你安排学习节奏。';

  @override
  String get guideStudyStatsHeaderTitle => '今日学习统计';

  @override
  String get guideStudyStatsHeaderDescription =>
      '今天的听力时长、口语练习时长和新学词汇量都汇总在这里。点击卡片或柱状图，可查看更详细的数据分布。';

  @override
  String get guideStudyStreakDescription => '点击这里查看学习日历。坚持每天打卡，逐步养成稳定的学习习惯。';

  @override
  String guideFavoritesSentencesListDescription(String dumbbellIcon) {
    return '这里是你收藏的句子，并按来源音频分组展示。点击 $dumbbellIcon 按钮，可以一键复习该音频中的所有收藏句子。';
  }

  @override
  String get guideFavoritesSentencesReviewDescription => '点击这里，一键复习所有收藏的句子。';

  @override
  String get guideFavoritesVocabularyListDescription =>
      '这里是你收藏的单词和意群。展开后可查看释义，也可以收听它们在原句中的发音。';

  @override
  String get guideFavoritesFlashcardDescription =>
      '点击这里进入闪卡模式，复习所有收藏的词汇。通过看单词、听原句，可以更高效地巩固记忆。';

  @override
  String get guideIntensiveListenCantUnderstandDescription =>
      '遇到听不懂的句子时点这里，会自动标记为难句并进入单句解析模式。';

  @override
  String get guideSentenceAnnotationSentenceDescription =>
      '点击任意单词可查看词典；长按句子可复制文字。';

  @override
  String get guideSentenceAnnotationSenseGroupDescription => '按意群切分，帮你轻松听懂长难句。';

  @override
  String get guideSentenceAnnotationTranslationDescription => '把这句话翻译成你的母语。';

  @override
  String get guideSentenceAnnotationAnalysisDescription =>
      '查看这句话的语法、重点短语、听力要点。';

  @override
  String get resetNewUserGuide => '重置新手引导';

  @override
  String get resetNewUserGuideSubtitle => '清除所有引导已看过状态，方便测试';

  @override
  String get resetNewUserGuideDone => '新手引导已重置';
}
