// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '听力大师';

  @override
  String get library => '音频库';

  @override
  String get player => '播放器';

  @override
  String get account => '账户';

  @override
  String get settings => '设置';

  @override
  String get audioLibrary => '音频库';

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
  String get playing => '播放中';

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
}
