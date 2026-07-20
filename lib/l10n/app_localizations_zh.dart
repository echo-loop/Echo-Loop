// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Echo Loop';

  @override
  String get premiumTitle => 'Echo Loop 会员';

  @override
  String get premiumTagline => '使用更多 AI，学习更高效。';

  @override
  String get aiQuotaExceededTitle => '本月免费额度已用完';

  @override
  String get aiQuotaExceededMessage => '升级会员，获得更多 AI 额度和 AI 功能。';

  @override
  String get aiQuotaExceededCta => '升级会员';

  @override
  String get aiQuotaExceededDismiss => '知道了';

  @override
  String get aiQuotaExceededSubscribe => '立即升级';

  @override
  String get premiumEntryTitle => '会员与订阅';

  @override
  String get premiumUnavailableOnPlatform => '当前平台暂不支持订阅';

  @override
  String get premiumEntryBadgeActive => '会员';

  @override
  String get premiumEntryBadgeUpgrade => '升级';

  @override
  String get premiumActive => '你已是会员';

  @override
  String get premiumBenefitTranslation => '更多 AI 翻译';

  @override
  String get premiumBenefitAnalysis => '更多 AI 句子拆解';

  @override
  String get premiumBenefitWordAnalysis => '更多 AI 单词讲解';

  @override
  String get premiumBenefitTranscription => '更多 AI 字幕转录';

  @override
  String get premiumBenefitSenseGroups => '更多 AI 句子意群拆分';

  @override
  String get premiumSubscribe => '订阅';

  @override
  String premiumStartTrial(int days) {
    return '开始 $days 天免费试用';
  }

  @override
  String get premiumRestore => '恢复购买';

  @override
  String get premiumManage => '管理订阅';

  @override
  String get premiumCurrentPlan => '当前套餐';

  @override
  String get premiumPlanMonthly => '月度会员';

  @override
  String get premiumPlanYearly => '年度会员';

  @override
  String get premiumPlanLifetime => '终身会员';

  @override
  String get premiumPlanGeneric => '会员';

  @override
  String get premiumStatusActive => '有效';

  @override
  String get premiumStatusExpiring => '即将到期';

  @override
  String get premiumStatusLifetime => '永久';

  @override
  String premiumRenewsOn(String date) {
    return '$date 自动续订';
  }

  @override
  String premiumExpiresOn(String date) {
    return '$date 到期';
  }

  @override
  String get premiumLifetimeAccessNote => '永久有效，无需续订';

  @override
  String get premiumNoPlans => '暂无可用套餐，请稍后再试。';

  @override
  String get premiumLoginRequired => '订阅前请先登录。';

  @override
  String get premiumPurchaseFailed => '购买失败，请重试。';

  @override
  String get premiumRestoreAccountMismatch =>
      '此订阅已绑定到另一个 Echo Loop 账号。请登录原账号后重试。';

  @override
  String get premiumRestoreNone => '未找到可恢复的购买。';

  @override
  String get premiumRestored => '已恢复购买。';

  @override
  String get premiumWebCheckoutCta => '查看订阅方案';

  @override
  String get premiumUseWebCheckoutFallback => '商店支付遇到问题？使用网页支付';

  @override
  String get premiumUseStoreCheckout => '继续使用商店支付';

  @override
  String get premiumWebVerifying => '正在等待支付结果确认…';

  @override
  String get premiumWebOpenFailed => '无法打开结账页面，请重试。';

  @override
  String get premiumRefresh => '刷新';

  @override
  String get premiumPeriodMonthly => '月付';

  @override
  String get premiumPeriodYearly => '年付';

  @override
  String get premiumPeriodLifetime => '终身';

  @override
  String get premiumPriceSuffixMonth => '/月';

  @override
  String get premiumPriceSuffixYear => '/年';

  @override
  String get premiumPriceSuffixFirstYear => '/首年';

  @override
  String get premiumPriceSuffixFirstMonth => '/首月';

  @override
  String get premiumPriceSuffixLifetime => '一次性';

  @override
  String premiumSavePercent(int percent) {
    return '立省 $percent%';
  }

  @override
  String premiumPerMonthEquivalent(String price) {
    return '≈ $price/月';
  }

  @override
  String premiumIntroFirstYear(String price) {
    return '首年 $price';
  }

  @override
  String premiumIntroFirstMonth(String price) {
    return '首月 $price';
  }

  @override
  String premiumRenewalPricePerYear(String price) {
    return '$price/年';
  }

  @override
  String premiumRenewalPricePerMonth(String price) {
    return '$price/月';
  }

  @override
  String premiumRenewalPricePerPeriod(String price) {
    return '$price';
  }

  @override
  String premiumTryFreeThen(int days, String renewal) {
    return '免费试用 $days 天，之后 $renewal';
  }

  @override
  String premiumOfferThen(String intro, String renewal) {
    return '$intro，之后 $renewal';
  }

  @override
  String premiumSpecialOfferPercent(int percent, String period) {
    return '特别优惠：首$period立减 $percent%';
  }

  @override
  String premiumSpecialOfferIntro(String intro, String renewal) {
    return '特别优惠：$intro，之后 $renewal';
  }

  @override
  String get premiumOfferPeriodYear => '年';

  @override
  String get premiumOfferPeriodMonth => '月';

  @override
  String get premiumTermsShort => '服务条款';

  @override
  String get premiumPrivacyShort => '隐私政策';

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
  String get importAction => '导入';

  @override
  String get selectAudioFile => '选择音频文件';

  @override
  String get subtitlePairedBadge => '已匹配字幕，将一并导入';

  @override
  String get audioFilePickerCloudDriveHint =>
      '从网盘选择前，请先安装并登录对应网盘。少部分网盘可能不支持从文件选择器中直接选择。';

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
  String get waveformZoom => '缩放';

  @override
  String waveformLoading(int progress) {
    return '正在加载波形 $progress%';
  }

  @override
  String get waveformLoadFailed => '波形生成失败，仍可在下方编辑字幕。';

  @override
  String get waveformAudioMissing => '没有找到音频，仍可在下方编辑字幕。';

  @override
  String get waveformRetry => '重试';

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
  String get themeMode => '主题';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get language => '界面语言';

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
  String get wholeTextLoop => '整篇循环';

  @override
  String get singleSentenceLoop => '单句循环';

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
  String get singleSentenceMode => '精听模式';

  @override
  String get singleSentenceModeDesc => '只展示当前播放的句子';

  @override
  String get autoPlayNextSentence => '自动播放下一句';

  @override
  String get repeatCount => '重复次数';

  @override
  String get infiniteRepeat => '无限 ∞';

  @override
  String get intervalTime => '间隔时长';

  @override
  String get times => '次';

  @override
  String loopCountValue(int count) {
    return '$count 次';
  }

  @override
  String loopIntervalValue(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get sleepTimer => '定时停止';

  @override
  String sleepTimerMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get sleepTimerRemaining => '剩余时间';

  @override
  String get sleepTimerOff => '关闭定时';

  @override
  String sleepTimerA11yActive(String time) {
    return '定时停止，剩余 $time，点击调整';
  }

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
  String get addAudioFailed => '添加音频失败';

  @override
  String audioUnsupportedFormat(String ext) {
    return '不支持的音频格式：$ext。仅支持 MP3、WAV、M4A、AAC、FLAC。';
  }

  @override
  String get audioErrorUnsupportedTitle => '不支持的音频格式';

  @override
  String get audioErrorGenericTitle => '添加音频失败';

  @override
  String get pickTranscriptFileFailed => '选择字幕文件失败';

  @override
  String subtitleUnsupportedFormat(String ext) {
    return '不支持 .$ext 格式的字幕，仅支持 SRT 和 VTT 文件。';
  }

  @override
  String get subtitleFormatInvalid => '字幕格式无效，仅支持标准的 SRT 或 VTT 文件。';

  @override
  String get subtitleFileEmpty => '字幕文件为空或已损坏，未发现任何字幕条目。';

  @override
  String get subtitleErrorUnsupportedTitle => '不支持的字幕格式';

  @override
  String get subtitleErrorInvalidTitle => '字幕格式无效';

  @override
  String get subtitleErrorEmptyTitle => '未发现字幕内容';

  @override
  String get subtitleErrorGenericTitle => '上传失败';

  @override
  String get fileExists => '文件已存在';

  @override
  String fileExistsMessage(String name) {
    return '已存在名为「$name」的音频文件，请先删除原音频后再导入。';
  }

  @override
  String get back => '返回';

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
  String get newCollectionOptionTitle => '新建合集';

  @override
  String get newCollectionOptionDescription => '手动添加音频或练习材料';

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
    return '确定要删除「$name」吗？';
  }

  @override
  String get deleteCollectionAlsoDeleteAudio => '同时删除音频文件';

  @override
  String deleteCollectionKeepAudioHint(int count) {
    return '合集中共 $count 个音频文件，将保留。';
  }

  @override
  String deleteCollectionDeleteAudioHint(int count) {
    return '合集中共 $count 个音频文件，将一并删除。';
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
  String get sortDefault => '默认';

  @override
  String get sortByOriginalDateAsc => '最早发布';

  @override
  String get sortByOriginalDateDesc => '最新发布';

  @override
  String publishedOn(String date) {
    return '发布于 $date';
  }

  @override
  String get discoverEntryTitleA => '发现精选资源';

  @override
  String get discoverEntrySubtitleA => '播客 · 托福 · 雅思 · 专四专八，教材...';

  @override
  String get officialCollectionEmpty => '该合集暂无音频';

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
  String get permanentlyDeleteAudio => '彻底删除该音频';

  @override
  String get permanentlyDeleteAudioHint => '将删除音频文件，并从所有合集中移除。';

  @override
  String audioBelongsToCollections(String names) {
    return '此音频还在以下合集：$names';
  }

  @override
  String get audioNotInOtherCollections => '未被其它合集引用，可放心删除。';

  @override
  String selectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String removeFromCollectionBatch(int count) {
    return '从合集移除 $count 项';
  }

  @override
  String permanentlyDeleteBatch(int count) {
    return '彻底删除 $count 项音频';
  }

  @override
  String get permanentlyDeleteBatchHint => '将删除音频文件，并从所有合集移除。';

  @override
  String get removeFromCollectionBatchHint => '仅从当前合集移除，音频文件保留。';

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
  String get stepBlindListeningDesc => '挑战一下：盲听全文，抓住大意';

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
  String get stepRetellingDesc => '挑战一下：用自己的话复述每段大意';

  @override
  String get warmUpCardTitle => '听前预热';

  @override
  String get warmUpCardSubtitle => '先听一遍，抓住大意，不必听懂每句';

  @override
  String get warmUpCardBadge => '推荐先做';

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
  String get blindListenBriefingTip => '挑战盲听全文，尝试抓住大意';

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
    return '确定要永久删除「$name」吗？';
  }

  @override
  String deleteAudioConfirmKeepFile(String name) {
    return '确定要删除「$name」吗？';
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
  String get aiVocabulary => '重点词汇';

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
  String get intensiveListenCompleteHint => '坚持间隔复习，就能彻底掌握这些难句。';

  @override
  String get intensiveListenCompleteNext => '下一步';

  @override
  String get statSentences => '句子';

  @override
  String get statDifficultSentences => '难句';

  @override
  String get statParagraphs => '段落';

  @override
  String get exitIntensiveListenTitle => '退出精听？';

  @override
  String get exitIntensiveListenMessage => '进度已保存，下次可从断点继续。';

  @override
  String get intensiveListenBriefingTitle => '逐句精听';

  @override
  String get intensiveListenBriefingTip => '逐句盲听，听不懂时点击「听不懂」查看文本和讲解。';

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
  String get intensiveListenSettingsTemporaryHint => '设置会被记住，下次自动沿用';

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
    return '${value}x';
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
  String get listenAndRepeatNoDifficultSentences => '没有难句，无需跟读';

  @override
  String get exitListenAndRepeatTitle => '退出跟读？';

  @override
  String get exitListenAndRepeatMessage => '进度已保存，下次可从断点继续。';

  @override
  String get listenAndRepeatBriefingTitle => '难句跟读';

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
  String durationMinutesSeconds(int minutes, int seconds) {
    return '$minutes分$seconds秒';
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
  String get retellAutoPlaybackPromptTitle => '复述后自动回听？';

  @override
  String get retellAutoPlaybackPromptMessage =>
      '开启后，复述后会自动播放录音，方便你及时纠正发音。你也可以随时在设置中修改。';

  @override
  String get retellAutoPlaybackKeepOff => '暂不开启';

  @override
  String get retellAutoPlaybackEnable => '开启';

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
  String get speechRecognitionDescription =>
      '语音识别用于练习评分和后续本地转录。你可以选择适合当前设备的模型。';

  @override
  String get asrEngine => '语音引擎';

  @override
  String get asrBackendPlatform => 'Apple AI';

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
  String get asrModelFastDescription => '速度最快，适合低端设备。';

  @override
  String get asrModelBalancedDescription => '准确率和速度平衡。';

  @override
  String get asrModelAccurateDescription => '准确率更高，但体积更大、速度更慢。';

  @override
  String get localSpeechRecognition => '本地语音识别';

  @override
  String speechModelSize(String size) {
    return '模型大小：约 $size';
  }

  @override
  String speechModelApproxSize(String size) {
    return '约 $size';
  }

  @override
  String speechModelReady(String size) {
    return '就绪 · $size';
  }

  @override
  String get speechModelStatusReady => '就绪';

  @override
  String get speechModelStatusNeedsDownload => '需下载';

  @override
  String speechModelDownloading(String progress) {
    return '正在下载... $progress';
  }

  @override
  String get speechModelDownloadFailed => '下载失败，点击重试。';

  @override
  String get speechModelDownloadFailedTitle => '语音识别模型下载失败';

  @override
  String get speechModelDownloadFailedGenericPurpose => '语音识别模型用于练习后自动评分。';

  @override
  String get speechModelDownloadFailedListenAndRepeatPurpose =>
      '语音识别模型用于跟读后自动评分。';

  @override
  String get speechModelDownloadFailedRetellPurpose => '语音识别模型用于复述后自动评分。';

  @override
  String get speechModelDownloadFailedDisableHint => '暂时不需要自动评分，可关闭：';

  @override
  String get speechModelDisablePathGeneric => '设置 > 学习设置';

  @override
  String get speechModelDisablePathListenAndRepeat => '设置 > 学习设置 > 跟读时显示评分';

  @override
  String get speechModelDisablePathRetell => '设置 > 学习设置 > 复述时显示评分';

  @override
  String get downloadErrorStorage => '存储空间不足，请清理后重试。';

  @override
  String get downloadErrorNetwork => '网络异常，请检查网络后重试。';

  @override
  String get downloadErrorCorrupted => '下载文件校验失败，请重试。';

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
      '语音识别用于自动评估跟读和复述效果，开始前需要先下载模型。';

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
  String get aiTranscription => '云端转录';

  @override
  String get aiTranscriptionSubtitle => '精度高，速度快，需联网登录';

  @override
  String get offlineTranscription => '本地转录';

  @override
  String get offlineTranscriptionSubtitle => '离线、隐私，无需登录';

  @override
  String get transcriptionModelTier => '识别模型';

  @override
  String get localTranscriptionDecoding => '正在解码音频…';

  @override
  String get localTranscriptionForegroundHint => '转录完成前请保持应用在前台，切到后台或锁屏会中断转录。';

  @override
  String localTranscriptionProgressPercent(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get localTranscriptionModelRequiredTitle => '需要语音模型';

  @override
  String localTranscriptionModelRequiredMessage(String modelName) {
    return '本地转录需先下载 $modelName 语音模型（仅一次，之后完全离线）。';
  }

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
  String get transcriptionErrorServer => '请检查音频是否正常，稍后再试';

  @override
  String get transcriptionErrorUnknown => '请检查音频是否正常，稍后再试';

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
  String get autoMergeShortSentences => '自动合并短句';

  @override
  String get autoMergeShortSentencesHint => '目标 4-7 秒，关闭后保留更短的句子';

  @override
  String get overwriteExistingSubtitle => '覆盖现有字幕？';

  @override
  String get overwriteExistingSubtitleMessage => '这将替换当前字幕，确定继续吗？';

  @override
  String get overwrite => '覆盖';

  @override
  String get audioContentEmptyWarning => '疑似空音频';

  @override
  String get audioContentDamagedWarning => '音频异常';

  @override
  String get audioContentSilentWarning => '疑似静音音频';

  @override
  String get transcriptionDamagedConfirmTitle => '音频可能损坏';

  @override
  String get transcriptionDamagedConfirmMessage => '该音频可能已损坏或格式不兼容，仍要转录吗？';

  @override
  String get transcriptionSilentConfirmTitle => '音频疑似为空';

  @override
  String get transcriptionSilentConfirmMessage => '该音频疑似全程静音、无人声，仍要转录吗？';

  @override
  String get transcriptionSilentConfirmProceed => '仍要转录';

  @override
  String transcriptionAudioFileSize(Object size) {
    return '文件大小：$size';
  }

  @override
  String transcriptionAudioDuration(Object duration) {
    return '时长：$duration';
  }

  @override
  String get transcriptionAudioUnknown => '未检测到';

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
  String get freePlay => '随心听';

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
  String get storage => '其它';

  @override
  String get clearCache => '清除缓存';

  @override
  String get clearCacheConfirm => '将清理临时缓存以释放空间，不影响学习记录和收藏，需要时自动重新生成。是否继续？';

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
  String get autoCompletedNoDifficultReview => '0 个难句，已跳过';

  @override
  String get termsOfService => '服务条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get writeFeedback => '意见反馈';

  @override
  String get rateUs => '评价我们';

  @override
  String get joinCommunity => '加入学习社群';

  @override
  String get joinCommunityInviteSubtitle => '找搭子，共享学习资料，提需求';

  @override
  String get networkError => '无法连接，请检查网络后重试';

  @override
  String get viewSourceCode => '查看源代码';

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
  String get releaseNotesTitle => '更新内容';

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
  String get pauseLearning => '暂停学习';

  @override
  String get resumeLearning => '恢复学习';

  @override
  String get pausedChipLabel => '已暂停';

  @override
  String get pauseLearningConfirmTitle => '暂停学习？';

  @override
  String get pauseLearningConfirmMessage => '该音频将停止复习调度，可随时恢复学习。';

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
  String get reminderSettings => '复习提醒';

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
  String get notificationPromptTitle => '开启提醒，让记忆更牢';

  @override
  String get notificationPromptBody => '记得牢的关键是适时回顾。我们只在关键节点轻轻提醒。';

  @override
  String get notificationPromptTitleLearning => '记得及时复习';

  @override
  String get notificationPromptBodyLearning => '开启提醒，我们会在合适的时间提醒你巩固刚学过的内容。';

  @override
  String get notificationPromptTitleBookmark => '收藏后别忘复习';

  @override
  String get notificationPromptBodyBookmark => '开启提醒，帮你定时回顾收藏内容。';

  @override
  String get notificationPromptCtaGrant => '开启提醒';

  @override
  String get notificationPromptCtaDismiss => '稍后再说';

  @override
  String get notificationDisabledBanner => '通知已关闭，将无法接收复习提醒。';

  @override
  String get notificationDisabledBannerCta => '前往设置';

  @override
  String get notificationNotGrantedBanner => '允许通知，按时收到每日复习提醒。';

  @override
  String get notificationNotGrantedBannerCta => '开启';

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
  String get exportAudio => '导出音频';

  @override
  String get exportAudioFile => '音频';

  @override
  String get exportSubtitleFile => '字幕';

  @override
  String get exportSelectFiles => '选择要导出的文件';

  @override
  String get exportPdf => '导出 PDF';

  @override
  String get pdfExporting => '正在生成 PDF…';

  @override
  String pdfExportFailed(String error) {
    return '导出 PDF 失败：$error';
  }

  @override
  String pdfMetaDuration(String duration) {
    return '时长 $duration';
  }

  @override
  String pdfMetaSentences(int count) {
    return '$count 句';
  }

  @override
  String pdfMetaWords(int count) {
    return '$count 词';
  }

  @override
  String get pdfAppendixTitle => '附录 · 句子解析';

  @override
  String get pdfPreviewTitle => '导出预览';

  @override
  String get pdfShare => '分享';

  @override
  String get pdfOptionTranslation => '难句译文';

  @override
  String get pdfOptionVocab => '收藏词汇释义';

  @override
  String get pdfOptionAnalysis => '难句讲解';

  @override
  String get pdfExportReminderTitle => 'PDF 是你的复习笔记';

  @override
  String get pdfExportReminderMessage =>
      '建议完成首次学习后再导出 PDF。\n\n精听、跟读、盲听帮助你掌握内容，PDF 会整理你的翻译、解析和收藏词汇，方便之后复习。';

  @override
  String get pdfExportReminderConfirm => '知道了';

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
  String get backupAndRestore => '备份与恢复';

  @override
  String get backupAndRestoreSubtitle => '换手机或重装后恢复学习数据';

  @override
  String get backupData => '备份';

  @override
  String get backupDataSubtitle => '备份学习数据、媒体文件和离线词典';

  @override
  String get restoreData => '恢复';

  @override
  String get restoreDataSubtitle => '从本地备份文件恢复全部数据';

  @override
  String get backupReadyTitle => '备份文件已准备好';

  @override
  String get backupFileName => '文件名';

  @override
  String get restoreOverwriteTitle => '覆盖并恢复全部数据？';

  @override
  String get restoreOverwriteMessage => '恢复后将覆盖当前设备上的学习数据、设置、音频、字幕和词典，且无法撤销。';

  @override
  String get restoreOverwriteAction => '覆盖并恢复';

  @override
  String get exportingResources => '正在备份离线词典...';

  @override
  String get importingResources => '正在恢复离线词典...';

  @override
  String backupFailed(String error) {
    return '备份失败：$error';
  }

  @override
  String restoreFailed(String error) {
    return '恢复失败：$error';
  }

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
  String get senseGroupSignInRequiredTitle => '登录后使用 AI 功能';

  @override
  String get senseGroupSignInRequiredMessage =>
      'AI 翻译、解析和意群拆分需要使用云端 AI 服务。登录后可以继续生成新结果，已缓存的结果仍可正常查看。';

  @override
  String get senseGroupSyntheticTimingNoticeTitle => '意群时间可能不准';

  @override
  String get senseGroupSyntheticTimingNoticeMessage =>
      '这个意群播放时间是从你上传的字幕推测出来的，可能不准确。';

  @override
  String get transcriptionSignInRequiredTitle => '登录后使用 AI 转录';

  @override
  String get transcriptionSignInRequiredMessage =>
      'AI 转录需要使用云端转录服务。登录后可以继续用 AI 生成字幕。';

  @override
  String get senseGroupNotAvailable => '当前音频暂不支持意群播放';

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
  String get importList => '导入列表';

  @override
  String filesSelected(int count) {
    return '已选择 $count 个文件';
  }

  @override
  String processingFileOf(int current, int total) {
    return '正在处理 $current/$total...';
  }

  @override
  String importingFileProgress(int current, int total, String name) {
    return '正在导入 $current/$total：$name';
  }

  @override
  String multipleAudioAdded(int count) {
    return '已添加 $count 个音频';
  }

  @override
  String audioImportedCount(int count) {
    return '成功导入 $count 个音频';
  }

  @override
  String audioImportedWithSubtitleCount(int count) {
    return '其中 $count 个包含字幕';
  }

  @override
  String duplicatesSkipped(int count) {
    return '跳过 $count 个重复项';
  }

  @override
  String get duplicatesSkippedDetail => '以下音频与本合集中已有音频内容完全相同，已跳过：';

  @override
  String duplicateExistingFileName(String name) {
    return '重复文件名: $name';
  }

  @override
  String duplicateOfExisting(String name) {
    return '与「$name」内容相同';
  }

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
  String dictionaryBaseFormHint(String lemma) {
    return '以下为原形「$lemma」的查词结果';
  }

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
  String get guidePlanFreePlayTitle => '随心听';

  @override
  String get guidePlanFreePlayDescription =>
      '这是一个全能、灵活的音频播放器，你可以按照自己的节奏随心听、随心练。';

  @override
  String get guidePlanStartLearningTitle => '按计划学习';

  @override
  String get guidePlanStartLearningDescription =>
      '点击这里即可按照学习计划逐步学习。Echo Loop 会自动引导你学习，并及时提醒你复习。';

  @override
  String get guidePlanPauseLearningTitle => '暂停学习';

  @override
  String get guidePlanPauseLearningDescription =>
      '如果你不想继续学这段音频，可以随时在这里暂停。该音频将停止复习提醒，之后可一键恢复。';

  @override
  String get guideRetellSkipTitle => '跳过本次复述';

  @override
  String get guideRetellSkipDescription => '复述能快速提升口语；如果当前更想专注练听力，可以点这里跳过本次复述。';

  @override
  String get learningProgressLoadFailed => '学习进度加载失败，请稍后重试';

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
      '遇到听不懂的句子时点这里，会自动标记为难句并进入讲解模式。';

  @override
  String get guideIntensiveListenAnnotationContinueDescription =>
      '搞懂这句后点「继续」进入下一句。';

  @override
  String get guideIntensiveListenAnnotationPlayDescription => '点击播放按钮，播放当前句。';

  @override
  String get guideSentenceTileNumberDescription => '点击编号从这句开始播放。';

  @override
  String get guideSentenceTileBodyDescription => '点击句子查看讲解。';

  @override
  String get guideSubtitleEditorBoundaryHandleDescription =>
      '拖动波形图上的红绿手柄，可以调整当前句子的起止时间。';

  @override
  String get guideSubtitleEditorSentencePlayDescription => '点击左侧播放按钮，可以播放这一句。';

  @override
  String get guideSubtitleEditorSentenceMenuDescription => '点击右侧菜单，可以合并或删除这一句。';

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

  @override
  String get newUserGuideToggle => '新手引导';

  @override
  String get newUserGuideSubtitle => '开启后在各页面首次使用时显示操作引导';

  @override
  String get newUserGuideResetAction => '重置';

  @override
  String get resetOnboarding => '重置 Onboarding 问卷';

  @override
  String get resetOnboardingDone => 'Onboarding 已重置，请重启 App 以重新进入问卷';

  @override
  String get discoverOfficialCollections => '发现精选合集';

  @override
  String get discoverEmpty => '暂无精选合集';

  @override
  String get discoverLoadFailed => '加载失败，点击重试';

  @override
  String get discoverRetry => '重试';

  @override
  String get discoverPodcastEntryTitle => '精选播客';

  @override
  String discoverPodcastEntrySubtitle(int count) {
    return '共 $count 个播客，订阅后可自动获取最新单集';
  }

  @override
  String get discoverPodcastTitle => '精选播客';

  @override
  String get discoverPodcastEmpty => '暂无精选播客';

  @override
  String get podcastCatalogSignInRequiredMessage =>
      '登录后可以将精选播客添加到我的合集，并继续学习后续单集。';

  @override
  String get podcastCatalogSubscribeFailed =>
      '添加失败。部分 RSS 或 Apple Podcasts 在当前网络环境下可能不可访问，请稍后重试或切换网络。';

  @override
  String get podcastEnrollNeededTitle => '需要先添加播客';

  @override
  String get podcastEnrollNeededMessage => '添加到我的合集后，就可以下载并学习这期节目。';

  @override
  String get podcastPreviewNetworkFailed =>
      '无法获取播客内容。Apple Podcasts 或部分 RSS 源在当前网络下可能不可访问，请稍后重试或切换网络。';

  @override
  String get podcastPreviewAppleFailed =>
      '无法解析 Apple Podcasts 链接。当前网络可能无法访问 Apple 播客查询服务，请稍后重试或切换网络。';

  @override
  String get podcastPreviewParseFailed => '播客源格式暂不支持，无法读取单集列表。';

  @override
  String get podcastFeedBlocked => '该播客源在当前网络下拦截了自动访问。请稍后重试，或切换到其他网络。';

  @override
  String get podcastPreviewEmpty => '暂未获取到单集。';

  @override
  String get officialBadge => '精选';

  @override
  String get officialDeprecatedBadge => '已下架';

  @override
  String get addToMyCollections => '添加到我的合集';

  @override
  String get officialCollectionSignInRequiredTitle => '登录后添加合集';

  @override
  String get officialCollectionSignInRequiredMessage =>
      '登录后可以将精选合集添加到我的合集，并同步后续学习内容。';

  @override
  String get goLearn => '去学习';

  @override
  String get removeFromMyCollections => '从我的合集移除';

  @override
  String get enrollNeededTitle => '需要先添加合集';

  @override
  String get enrollNeededMessage => '添加到我的合集后，就可以开始学习这条音频。';

  @override
  String get enrollSucceeded => '已添加到我的合集';

  @override
  String get enrollFailed => '添加失败，请检查网络后重试';

  @override
  String removeOfficialConfirmTitle(String name) {
    return '移除《$name》？';
  }

  @override
  String get removeOfficialConfirmMessage => '将删除本合集所有音频、字幕和相关学习记录，此操作不可恢复。';

  @override
  String get removeOfficialConfirmConfirm => '确认移除';

  @override
  String get officialCollectionDeprecated => '该合集已下架，本地副本仍可继续使用。';

  @override
  String get downloadCancel => '取消下载';

  @override
  String get downloadLater => '先不管';

  @override
  String downloadCompleted(String name) {
    return '《$name》下载完成';
  }

  @override
  String downloadFailed(String name) {
    return '《$name》下载失败，请重试';
  }

  @override
  String get updateOfficialSubtitle => '更新字幕';

  @override
  String get updateOfficialSubtitleConfirm => '确定更新字幕？';

  @override
  String get updateOfficialSubtitleWarning => '更新字幕将替换本地字幕，并清空该音频的所有收藏句子和学习进度。';

  @override
  String get officialSubtitleUpdated => '字幕已更新';

  @override
  String get officialSubtitleUpdateFailed => '字幕更新失败，请重试';

  @override
  String downloadInProgressSnackbar(String name) {
    return '正在下载《$name》，完成后再开始这条';
  }

  @override
  String get downloadLoading => '加载中';

  @override
  String get audioListColumnName => '名称';

  @override
  String get audioListColumnDuration => '时长';

  @override
  String get onboardingTitle => '先聊两句';

  @override
  String get onboardingSubtitle => '10 秒帮你定制学习节奏';

  @override
  String get onboardingBack => '上一步';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingExamPrompt => '你当前在备考哪一类考试？';

  @override
  String get onboardingExamGaokao => '中高考';

  @override
  String get onboardingExamCet => '大学四六级';

  @override
  String get onboardingExamTem => '专四专八';

  @override
  String get onboardingExamIelts => '雅思 IELTS';

  @override
  String get onboardingExamToefl => '托福 TOEFL';

  @override
  String get onboardingExamOther => '其他';

  @override
  String onboardingProgress(int current, int total) {
    return '第 $current 题 / 共 $total 题';
  }

  @override
  String get onboardingNext => '下一题';

  @override
  String get onboardingDone => '完成';

  @override
  String get onboardingFinishedTitle => '记下了，准备好出发';

  @override
  String get onboardingFinishedHint => '我们会按你的目标和节奏来安排练习。';

  @override
  String get onboardingSummaryEyebrow => '你知道么？';

  @override
  String get onboardingSummaryHeadline => '提升英语听说，\n关键不在听得更多，\n而在练得更透';

  @override
  String get onboardingSummaryPoint1 => '选择适合你水平的音频反复练习';

  @override
  String get onboardingSummaryPoint2 => '按意群理解内容，在语境中掌握词汇';

  @override
  String get onboardingSummaryPoint3 => '通过大量精听和跟读积累输入与语感';

  @override
  String get onboardingSummaryPoint4 => '通过复述练习口语，把听懂变成会说';

  @override
  String get onboardingStart => '开始学习';

  @override
  String get onboardingQ1Prompt => '你练习英语听说的主要目标是什么？';

  @override
  String get onboardingQ1OptionExam => '应对考试';

  @override
  String get onboardingQ1OptionDaily => '日常交流';

  @override
  String get onboardingQ1OptionWork => '工作沟通';

  @override
  String get onboardingQ1OptionTravel => '出国旅行';

  @override
  String get onboardingQ1OptionContent => '听懂影视播客';

  @override
  String get onboardingQ1OptionOther => '其他';

  @override
  String get onboardingQ2Prompt => '你计划每天练习多久？';

  @override
  String get onboardingQ2Option5 => '约 5 分钟';

  @override
  String get onboardingQ2Option10 => '约 10 分钟';

  @override
  String get onboardingQ2Option20 => '约 20 分钟';

  @override
  String get onboardingQ2Option30 => '30 分钟以上';

  @override
  String get onboardingQ2OptionFlexible => '不固定';

  @override
  String get onboardingQ3Prompt => '你是从哪里知道我们的？';

  @override
  String get onboardingQ3OptionAppStore => '应用商店';

  @override
  String get onboardingQ3OptionGooglePlay => 'Google Play';

  @override
  String get onboardingQ3OptionYoutube => 'YouTube';

  @override
  String get onboardingQ3OptionReddit => 'Reddit';

  @override
  String get onboardingQ3OptionXTwitter => 'X';

  @override
  String get onboardingQ3OptionTiktok => 'TikTok';

  @override
  String get onboardingQ3OptionInstagram => 'Instagram';

  @override
  String get onboardingQ3OptionXiaohongshu => '小红书';

  @override
  String get onboardingQ3OptionWechat => '微信';

  @override
  String get onboardingQ3OptionDouyin => '抖音';

  @override
  String get onboardingQ3OptionKuaishou => '快手';

  @override
  String get onboardingQ3OptionBilibili => 'B 站';

  @override
  String get onboardingQ3OptionBaiduSearch => '百度搜索';

  @override
  String get onboardingQ3OptionGoogleSearch => 'Google 搜索';

  @override
  String get onboardingQ3OptionGithub => 'GitHub';

  @override
  String get onboardingQ3OptionFriend => '朋友推荐';

  @override
  String get onboardingQ3OptionOther => '其他';

  @override
  String get onboardingPermissionsHint => '为了保证体验我们将请求以下权限';

  @override
  String get onboardingPermissionsNotification => '系统通知';

  @override
  String get onboardingPermissionsMicrophone => '录音';

  @override
  String get onboardingPermissionsSpeech => '语音识别';

  @override
  String get playbackSection => '播放';

  @override
  String get learningSection => '学习';

  @override
  String get learningSettings => '学习设置';

  @override
  String get speakingPracticeSection => '口语练习';

  @override
  String get autoSkipRetellToggle => '自动跳过复述';

  @override
  String get autoSkipRetellSubtitle => '学习计划遇到复述任务时自动跳过';

  @override
  String get autoSkipRetellDescription => '开启后，复述类任务会自动标记为已跳过；你随时可以在随心听里完成它们。';

  @override
  String get autoExpandCachedAnnotationToggle => '自动展开句子讲解';

  @override
  String get autoExpandCachedAnnotationSubtitle => '自动展示查看过的翻译、解析和意群';

  @override
  String get autoShowAiExplanationToggle => '自动显示 AI 讲解';

  @override
  String get autoShowAiExplanationSubtitle => '进入句子讲解时自动显示选中的 AI 辅助内容';

  @override
  String get autoShowAiAnalysisToggle => 'AI 解析';

  @override
  String get autoShowAiTranslationToggle => 'AI 翻译';

  @override
  String get autoShowAiSenseGroupsToggle => 'AI 意群分割';

  @override
  String get autoPlayRetellRecordingToggle => '自动播放复述录音';

  @override
  String get autoPlayRetellRecordingSubtitle => '复述结束后自动回听自己的录音，用于对照和纠音';

  @override
  String get listenAndRepeatRatingToggle => '跟读时显示评分';

  @override
  String get listenAndRepeatRatingSubtitle => '关闭后保留录音回听，但不再识别和评分';

  @override
  String get retellRatingToggle => '复述时显示评分';

  @override
  String get retellRatingSubtitle => '关闭后只保留录音回听，不再显示评分';

  @override
  String get retellSkip => '跳过';

  @override
  String get retellSkippedSuffix => '已跳过';

  @override
  String get skipSilenceTitle => '自动跳过静音';

  @override
  String get skipSilenceDescription => '跳过句子之间较长的静音部分';

  @override
  String get silenceThreshold => '静音阈值';

  @override
  String silenceThresholdValue(int seconds) {
    return '$seconds 秒';
  }

  @override
  String silenceSkipped(int seconds) {
    return '已跳过 $seconds 秒静音部分';
  }

  @override
  String get speechPermDialogTitleRequest => '需要授权';

  @override
  String get speechPermDialogTitleDenied => '权限已被拒绝';

  @override
  String get speechPermDialogTitleRestricted => '设备已限制';

  @override
  String get speechPermItemMic => '麦克风';

  @override
  String get speechPermItemMicDesc => '录制你的朗读用于发音评测';

  @override
  String get speechPermItemSpeech => '语音识别';

  @override
  String get speechPermItemSpeechDesc => '对比朗读内容，逐字标注错误';

  @override
  String get speechPermStatusPending => '待授权';

  @override
  String get speechPermStatusDenied => '已拒绝';

  @override
  String get speechPermDeniedHint => '你曾拒绝过权限，需要在系统设置中手动开启';

  @override
  String get speechPermRestrictedHint => '当前设备被家长控制或 MDM 限制，无法使用录音';

  @override
  String get speechPermActionGrant => '授权';

  @override
  String get speechPermActionOpenSettings => '前往设置';

  @override
  String get speechPermUnsupportedToast => '当前平台不支持录音';

  @override
  String get authSignInTitle => '登录 Echo Loop';

  @override
  String get authChooseMethod => '选择一种方式继续。';

  @override
  String get authContinueWithEmail => '使用邮箱验证码继续';

  @override
  String get authContinueWithApple => '使用 Apple 继续';

  @override
  String get authContinueWithGoogle => '使用 Google 继续';

  @override
  String get authProviderComingSoon => '即将支持';

  @override
  String get authGoogleUnavailable => '当前设备无法使用 Google 登录，请改用邮箱验证码登录。';

  @override
  String get authGoogleServicesOutdated => '当前设备的 Google 服务版本过低，暂不可用。';

  @override
  String get authPasswordlessHint => '无需密码，我们会向你的邮箱发送一次性验证码。';

  @override
  String get authEmailTitle => '邮箱登录';

  @override
  String get authEmailOtpTitle => '继续使用邮箱';

  @override
  String get authEmailOtpDescription => '输入你的邮箱，我们会发送一次性验证码。';

  @override
  String get authEmailOtpAutoCreateHint => '首次使用会自动创建账号。';

  @override
  String get authEmailLabel => '邮箱';

  @override
  String get authOtpLabel => '6 位验证码';

  @override
  String get authOtpRequired => '请输入 6 位验证码';

  @override
  String get authOtpInvalid => '请输入有效的 6 位验证码';

  @override
  String get authOtpIncorrectOrExpired => '验证码不正确或已过期。';

  @override
  String get authEnterOtpTitle => '输入验证码';

  @override
  String get authOtpHelpText => '如果没有收到邮件，请检查垃圾邮件箱。';

  @override
  String get authSendOtpButton => '发送验证码';

  @override
  String get authSendingOtp => '发送中';

  @override
  String get authVerifyOtpButton => '继续';

  @override
  String get authVerifyingOtp => '验证中';

  @override
  String get authResendOtpButton => '重新发送验证码';

  @override
  String authResendOtpCountdown(int seconds) {
    return '$seconds 秒后可重发';
  }

  @override
  String get authOtpResent => '已重新发送验证码。';

  @override
  String get authPasswordLabel => '密码';

  @override
  String get authConfirmPasswordLabel => '确认密码';

  @override
  String get authSignInButton => '登录';

  @override
  String get authSigningIn => '登录中';

  @override
  String get authCreateAccount => '创建账号';

  @override
  String get authCreateAccountTitle => '创建你的账号';

  @override
  String get authCreatingAccount => '创建中';

  @override
  String get authAlreadyHaveAccount => '已有账号？登录';

  @override
  String get authForgotPassword => '忘记密码？';

  @override
  String get authForgotPasswordTitle => '重置密码';

  @override
  String get authForgotPasswordDescription => '输入你的邮箱，我们会发送一封重置密码邮件。';

  @override
  String get authResetPasswordTitle => '设置新密码';

  @override
  String get authResetPasswordDescription => '输入你的新密码，完成密码找回。';

  @override
  String get authNewPasswordLabel => '新密码';

  @override
  String get authConfirmNewPasswordLabel => '确认新密码';

  @override
  String get authUpdatePasswordButton => '更新密码';

  @override
  String get authUpdatingPassword => '更新中';

  @override
  String get authSendResetLink => '发送重置链接';

  @override
  String get authSendingResetLink => '发送中';

  @override
  String get authBackToSignIn => '返回登录';

  @override
  String get authCheckEmailTitle => '请查收邮件';

  @override
  String authCheckEmailMessage(String email) {
    return '我们已向 $email 发送 6 位验证码。';
  }

  @override
  String get authResetEmailSent => '如果账号存在，我们已发送重置链接。';

  @override
  String get authEmailRequired => '请输入邮箱';

  @override
  String get authEmailInvalid => '请输入有效邮箱';

  @override
  String get authPasswordRequired => '请输入密码';

  @override
  String get authPasswordTooShort => '密码至少 6 位';

  @override
  String get authConfirmPasswordRequired => '请再次输入密码';

  @override
  String get authConfirmPasswordMismatch => '两次输入的密码不一致';

  @override
  String get authShowPassword => '显示密码';

  @override
  String get authHidePassword => '隐藏密码';

  @override
  String get authUnavailable => '认证服务尚未配置，请稍后再试。';

  @override
  String get authUnknownError => '操作失败，请稍后重试。';

  @override
  String get authAgreeRequired => '请先同意服务条款和隐私政策';

  @override
  String get authTermsAgreementPrefix => '我已阅读并同意';

  @override
  String get authTermsContinuationPrefix => '继续即表示你同意';

  @override
  String get authTermsJoiner => '和';

  @override
  String get authTermsOfService => '服务条款';

  @override
  String get authPrivacyPolicy => '隐私政策';

  @override
  String get authSignedInStatus => '已登录';

  @override
  String get authSignedOutStatus => '未登录';

  @override
  String get authSignedInWithApple => '已通过 Apple 登录';

  @override
  String get authSignedInWithGoogle => '已通过 Google 登录';

  @override
  String get authAppleAccount => 'Apple 账号';

  @override
  String get authGoogleAccount => 'Google 账号';

  @override
  String get authSignOut => '退出登录';

  @override
  String get editSubtitles => '编辑字幕';

  @override
  String get mergeWithNextSentence => '合并下一句';

  @override
  String get deleteSentence => '删除句子';

  @override
  String get sentenceDeleted => '已删除句子';

  @override
  String get playSentence => '播放句子';

  @override
  String get stopPlayback => '停止播放';

  @override
  String get editWord => '编辑单词';

  @override
  String get splitSentenceHere => '从此处分句';

  @override
  String get wordEditAction => '编辑';

  @override
  String get wordSplitBeforeAction => '断句';

  @override
  String get saveSubtitleEdits => '保存字幕修改';

  @override
  String get subtitleStructureChangedWarning => '这会清除该音频的学习进度和收藏句子。';

  @override
  String get subtitleEditsSaved => '字幕修改已保存。';

  @override
  String get discardSubtitleEditsTitle => '放弃修改？';

  @override
  String get discardSubtitleEditsMessage => '当前字幕修改尚未保存。';

  @override
  String get discard => '放弃';

  @override
  String get importAudio => '导入音频';

  @override
  String get importAudioFromFile => '从本地文件导入';

  @override
  String get importAudioFromFileDescription => '选择手机或网盘中的音频文件';

  @override
  String get importAudioFromUrl => '从链接导入';

  @override
  String get importAudioFromUrlDescription => '粘贴音频直链，下载后加入资源库';

  @override
  String get importAudioFromCloudDrive => '从网盘导入';

  @override
  String get importAudioFromBaiduNetdisk => '从百度网盘导入';

  @override
  String get cloudDriveSourceShort => '网盘';

  @override
  String get baiduNetdisk => '百度网盘';

  @override
  String get baiduNetdiskAllFiles => '全部文件';

  @override
  String get baiduNetdiskWaitingAuthorization => '等待百度授权...';

  @override
  String get baiduNetdiskLoadingFiles => '正在加载百度网盘文件...';

  @override
  String get baiduNetdiskImportFailed => '百度网盘导入失败。';

  @override
  String get baiduNetdiskConnectTitle => '连接百度网盘';

  @override
  String get baiduNetdiskConnectDescription =>
      '授权 Echo Loop 浏览你的百度网盘，并导入选中的音频文件。';

  @override
  String get baiduNetdiskConnectAction => '连接百度网盘';

  @override
  String get baiduNetdiskLogoutTooltip => '退出百度网盘登录';

  @override
  String get baiduNetdiskSelectAllAction => '全选';

  @override
  String get baiduNetdiskClearSelectionAction => '取消';

  @override
  String get baiduNetdiskLogoutTitle => '退出百度网盘登录？';

  @override
  String get baiduNetdiskLogoutMessage => 'Echo Loop 会清除当前设备上保存的百度网盘授权。';

  @override
  String get baiduNetdiskLogoutConfirm => '退出登录';

  @override
  String get baiduNetdiskNoSupportedAudio => '此文件夹中没有支持的音频文件。';

  @override
  String get importAudioShort => '导入';

  @override
  String importAudioSelectedCount(int count) {
    return '导入 $count 个';
  }

  @override
  String importAudioAndSubtitleCount(int audioCount, int subtitleCount) {
    String _temp0 = intl.Intl.pluralLogic(
      audioCount,
      locale: localeName,
      other: '$audioCount 个音频',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subtitleCount,
      locale: localeName,
      other: '，$subtitleCount 个字幕',
      zero: '',
    );
    return '导入（$_temp0$_temp1）';
  }

  @override
  String get baiduNetdiskImporting => '正在导入...';

  @override
  String baiduNetdiskImportingFile(String name) {
    return '正在导入 $name...';
  }

  @override
  String baiduNetdiskImportedCount(int count) {
    return '已从百度网盘导入 $count 个';
  }

  @override
  String baiduNetdiskSkippedSummary(int duplicates, int failures) {
    return '跳过重复项：$duplicates · 失败：$failures';
  }

  @override
  String get audioUrlLabel => '音频链接';

  @override
  String get audioUrlHint => 'https://example.com/audio.mp3';

  @override
  String get pasteAudioLink => '粘贴链接';

  @override
  String get audioClipboardNoValidLink => '剪切板中没有可用链接';

  @override
  String get downloadAndImportAudio => '下载并导入';

  @override
  String get audioUrlInvalid => '请输入有效的音频链接';

  @override
  String get audioUrlUnsupported => '链接不是支持的音频格式';

  @override
  String get audioUrlNotDirectAudio => '该链接不是可直接下载的音频文件';

  @override
  String get audioUrlDuplicate => '已存在同名音频';

  @override
  String get audioDownloadFailed => '下载音频失败';

  @override
  String get audioDownloadInProgress => '正在下载音频';

  @override
  String get audioImportComplete => '导入完成';

  @override
  String get audioImportCanceled => '已取消音频导入';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get subscribePodcast => '订阅 Podcast';

  @override
  String get subscribePodcastOptionDescription => '通过 Apple Podcasts 或 RSS 添加';

  @override
  String get podcastUrlLabel => 'Apple Podcasts 或 RSS 链接';

  @override
  String get podcastUrlHint =>
      'https://podcasts.apple.com/... 或 https://…/feed.xml';

  @override
  String get podcastSubscribing => '正在获取 Podcast Feed…';

  @override
  String podcastSubscribeFailed(String error) {
    return '订阅失败：$error';
  }

  @override
  String podcastRefreshFailed(String error) {
    return '刷新失败：$error';
  }

  @override
  String podcastAlreadySubscribed(String name) {
    return '已订阅该播客，合集名为「$name」';
  }

  @override
  String get podcastRefreshFeed => '刷新 Feed';

  @override
  String get podcastUnsubscribe => '退订';

  @override
  String podcastUnsubscribeConfirmTitle(String name) {
    return '退订「$name」？';
  }

  @override
  String get podcastUnsubscribeConfirmMessage => '该合集内所有单集及已下载的音频文件将被删除。';

  @override
  String get podcastFeedInfo => 'Feed 信息';

  @override
  String get podcastDetails => '详情';

  @override
  String get podcastEpisodeMeta => '单集信息';

  @override
  String get podcastShowMore => '更多';

  @override
  String get podcastShowLess => '收起';

  @override
  String get podcastTitle => '标题';

  @override
  String get podcastAuthor => '作者';

  @override
  String get podcastDescription => '简介';

  @override
  String get podcastFeedUrl => 'RSS 链接';

  @override
  String get podcastAppleLink => 'Apple 播客';

  @override
  String get podcastOriginalLink => '链接';

  @override
  String get podcastAudioType => '音频类型';

  @override
  String get podcastOpenLinkFailed => '无法打开链接';

  @override
  String podcastLastRefreshed(String time) {
    return '上次刷新：$time';
  }

  @override
  String get podcastEpisodeGuid => 'GUID';

  @override
  String get podcastEnclosureUrl => '音频链接';

  @override
  String get ttsSettings => '语音合成';

  @override
  String get ttsSettingsDescription => '选择朗读单词和例句时使用的语音引擎与口音。';

  @override
  String get ttsEngine => '语音引擎';

  @override
  String get ttsEnginePlatform => '系统语音';

  @override
  String get ttsEnginePlatformApple => 'Apple AI';

  @override
  String get ttsEnginePlatformDescription => '设备自带，速度快、无需下载，但音质一般。';

  @override
  String get ttsEngineEchoLoop => 'Echo Loop AI (Advanced)';

  @override
  String get ttsEngineComingSoon => '即将推出';

  @override
  String get ttsEngineEchoLoopDescription => '音质最好，需下载模型，推荐高性能设备使用。';

  @override
  String get ttsEnginePiper => 'Echo Loop AI (Balanced)';

  @override
  String get ttsEnginePiperDescription => '音质自然流畅，需下载模型，推荐中等配置设备使用。';

  @override
  String get ttsModel => '模型';

  @override
  String get ttsModelHighQuality => '高质量';

  @override
  String get ttsModelHighQualityDescription => '音质最佳，速度可接受。约 300 MB。';

  @override
  String get ttsModelLite => '轻量';

  @override
  String get ttsModelLiteDescription => '体积小、速度慢，适合低端设备。约 100 MB。';

  @override
  String get ttsModelRecommended => '推荐';

  @override
  String get ttsModelNotDownloaded => '未下载';

  @override
  String get ttsAccent => '口音';

  @override
  String get ttsAccentUs => '美音';

  @override
  String get ttsAccentUk => '英音';

  @override
  String get ttsAccentHint => '（部分机型不区分美音和英音）';

  @override
  String get ttsVoice => '音色';

  @override
  String get ttsVoiceFemale => '女';

  @override
  String get ttsVoiceMale => '男';

  @override
  String get ttsDeleteModel => '删除模型';

  @override
  String get ttsDeleteModelConfirm => '删除 Echo Loop 语音模型？可随时重新下载。';

  @override
  String get ttsCancelDownload => '取消';

  @override
  String get ttsDownloadedModelsTitle => '已下载的 Echo Loop 模型';

  @override
  String ttsDownloadedModelsDesc(String size) {
    return '未在使用 · 占用 $size';
  }

  @override
  String get asrDeleteAllModelsConfirm => '删除所有已下载的 Echo Loop 语音识别模型？可随时重新下载。';

  @override
  String get asrDownloadedModelsTitle => '已下载的语音识别模型';

  @override
  String asrDownloadedModelsDesc(String size) {
    return '未在使用 · 占用 $size';
  }

  @override
  String get dictionarySettings => '词典设置';

  @override
  String get dictionaryDefault => '默认词典';

  @override
  String get dictionaryDefaultDescription => '选择查词时默认展示的词典';

  @override
  String get dictionarySources => '词典源';

  @override
  String get dictionarySourcesDescription => '关闭的词典不会出现在查词切换器中';

  @override
  String get dictionaryWebAdsNotice => '在线词典可能含其自带广告，与 Echo Loop 无关。';

  @override
  String get dictSourceLocal => '本地词典';

  @override
  String get dictSourceAi => 'AI 词典';

  @override
  String get dictSourceCambridge => 'Cambridge';

  @override
  String get dictSourceAlwaysOn => '始终启用';

  @override
  String dictSourceCannotDisable(String name) {
    return '$name为基础词源，无法关闭';
  }

  @override
  String get dictDefaultBadge => '默认';

  @override
  String dictSwitcherSemantics(String name) {
    return '切换词典源，当前 $name';
  }

  @override
  String get cambridgeNotFound => 'Cambridge 未收录该词';

  @override
  String get dictTryOtherSource => '试试其它词典';

  @override
  String get dictCambridgeOpenInBrowser => '在浏览器中打开';

  @override
  String get aiNoAnalysis => '暂无 AI 解析';

  @override
  String get aiSignInRequired => '登录后可使用 AI 词典';

  @override
  String get dictPhraseTooLong => '词组过长，最多选择 8 个单词';

  @override
  String get ttsPlayUk => '播放英式发音';

  @override
  String get ttsPlayUs => '播放美式发音';

  @override
  String get dictAiSynonyms => '近义词';

  @override
  String get dictAiAntonyms => '反义词';

  @override
  String get dictAiExpressions => '常见搭配';

  @override
  String get dictAiWordFamily => '词族';

  @override
  String get dictAiForms => '词形变化';

  @override
  String get dictAiEtymology => '词源';

  @override
  String get dictAiTips => '学习提示';

  @override
  String get dictAiMultiKeyPoints => '学习要点';

  @override
  String get dictAiMultiMeanings => '含义与例句';

  @override
  String get dictAiMultiNaturalness => '纠错';

  @override
  String get dictAiMultiPronunciationTips => '发音提示';

  @override
  String get dictAiMultiSimilarExpressions => '相似表达';

  @override
  String get dictAiMultiBackground => '背景知识';

  @override
  String get chatOpenTooltip => '问 AI';

  @override
  String get chatSentenceTitle => 'AI 助教';

  @override
  String get chatInputPlaceholder => '有问题尽管问…';

  @override
  String get chatSend => '发送';

  @override
  String get chatStop => '停止';

  @override
  String get chatClear => '清空对话';

  @override
  String get chatNewChat => '新建会话';

  @override
  String get chatRegenerate => '重新生成';

  @override
  String get chatEdit => '编辑';

  @override
  String get chatEditTitle => '编辑消息';

  @override
  String get chatCopy => '复制';

  @override
  String get chatCopied => '已复制';

  @override
  String chatContextLabel(String summary) {
    return '正在讨论：$summary';
  }

  @override
  String get chatEmptyGreeting => '关于这句话，有什么想问的？';

  @override
  String get chatErrorNetwork => '网络不可用，点击重试。';

  @override
  String get chatErrorGenerate => '生成失败，点击重试。';

  @override
  String get chatQuotaTitle => '免费额度已用完';

  @override
  String get chatUpgrade => '升级';

  @override
  String get chatSignInTitle => '需要登录';

  @override
  String get chatSignInMessage => '登录后即可使用 AI 助手。';

  @override
  String get chatScrollToBottom => '回到底部';

  @override
  String get chatThinking => '思考中…';

  @override
  String get chatFollowUp => '问 AI';

  @override
  String get chatFollowUpExplain => '详细解释';

  @override
  String get chatFollowUpTranslate => '翻译';

  @override
  String get chatFollowUpExample => '举个例子';

  @override
  String get chatFollowUpInstruction => '请仅根据下方引用的内容回答问题。';

  @override
  String get chatQuoteRemove => '移除引用';
}
