// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Listen Master';

  @override
  String get library => 'Library';

  @override
  String get player => 'Player';

  @override
  String get account => 'Account';

  @override
  String get settings => 'Settings';

  @override
  String get audioLibrary => 'Audio Library';

  @override
  String get addAudio => 'Add Audio';

  @override
  String get noAudioYet => 'No audio files yet';

  @override
  String get tapToAdd => 'Tap + to add your first audio';

  @override
  String get added => 'Added';

  @override
  String get transcript => 'Transcript';

  @override
  String get playing => 'Playing';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAudio => 'Delete Audio';

  @override
  String deleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get selectAudioFile => 'Select Audio File';

  @override
  String get selectTranscript => 'Select Transcript (Optional)';

  @override
  String get noTranscript => 'No transcript available';

  @override
  String get noBookmarked => 'No bookmarked sentences';

  @override
  String get tapToBookmark => 'Tap ⭐ on sentences to bookmark them';

  @override
  String get playbackMode => 'Playback Mode';

  @override
  String get fullArticle => 'Full Article';

  @override
  String get singleSentence => 'Single Sentence';

  @override
  String get bookmarkedOnly => 'Bookmarked Only';

  @override
  String get playbackSettings => 'Playback Settings';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get loopPlayback => 'Loop Playback';

  @override
  String get loopCount => 'Loop Count';

  @override
  String get pauseInterval => 'Pause Interval';

  @override
  String get applySettings => 'Apply Settings';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get previousSentence => 'Previous Sentence';

  @override
  String get nextSentence => 'Next Sentence';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get addBookmark => 'Add bookmark';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get themeModeSystem => 'Follow System';

  @override
  String get themeModeLight => 'Light Mode';

  @override
  String get themeModeDark => 'Dark Mode';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get appDescription => 'Professional English listening practice app';

  @override
  String get enableLoop => 'Enable Loop';

  @override
  String get loopSettings => 'Loop Settings';

  @override
  String get displaySettings => 'Display Settings';

  @override
  String get showTranscript => 'Show Transcript';

  @override
  String get shortcutKey => 'Shortcut';

  @override
  String get seconds => 'seconds';

  @override
  String get infinite => '∞';

  @override
  String get singleSentenceMode => 'Single Sentence Mode';

  @override
  String get singleSentenceModeDesc => 'Show only current sentence';

  @override
  String get autoPlayNextSentence => 'Auto Play Next Sentence';

  @override
  String get sentenceRepeat => 'Sentence Repeat';

  @override
  String get repeatCount => 'Repeat Count';

  @override
  String get intervalTime => 'Interval (seconds)';

  @override
  String get audioLoop => 'Audio Loop';

  @override
  String get loopTimes => 'Loop Count';

  @override
  String get noLoop => 'No Loop';

  @override
  String get infiniteLoop => 'Infinite ∞';

  @override
  String get times => 'times';

  @override
  String get fullText => 'Full Text';

  @override
  String get bookmarked => 'Bookmarked';

  @override
  String get noSubtitle => 'No Subtitle';

  @override
  String get noSentenceSelected => 'No sentence selected';

  @override
  String get noBookmarkedSentences => 'No bookmarked sentences';

  @override
  String get tapBookmarkIcon => 'Tap bookmark icon to save';

  @override
  String get removeBookmarkTip => 'Remove bookmark';

  @override
  String get addBookmarkTip => 'Add bookmark';

  @override
  String get listMode => 'List Mode';
}
