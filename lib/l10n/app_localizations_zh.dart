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
  String get reviewIntervalNow => '当前';

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
  String get intensiveListenMarkedDifficult => '已自动标记为难句，点此取消';

  @override
  String get intensiveListenNotDifficult => '点击标记为难句';

  @override
  String get intensiveListenTranslationPlaceholder => '翻译功能将在未来版本中提供';

  @override
  String get intensiveListenAnalysisPlaceholder => '分析功能将在未来版本中提供';

  @override
  String get intensiveListenWordDictTitle => '词典';

  @override
  String get intensiveListenWordDictPlaceholder => '词典功能即将上线';

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
  String get intensiveListenPauseSmartDesc => '根据句子长度自动判定';

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
}
