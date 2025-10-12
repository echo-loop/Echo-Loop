import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen Master'**
  String get appTitle;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @audioLibrary.
  ///
  /// In en, this message translates to:
  /// **'Audio Library'**
  String get audioLibrary;

  /// No description provided for @addAudio.
  ///
  /// In en, this message translates to:
  /// **'Add Audio'**
  String get addAudio;

  /// No description provided for @noAudioYet.
  ///
  /// In en, this message translates to:
  /// **'No audio files yet'**
  String get noAudioYet;

  /// No description provided for @tapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first audio'**
  String get tapToAdd;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @transcript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcript;

  /// No description provided for @playing.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get playing;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAudio.
  ///
  /// In en, this message translates to:
  /// **'Delete Audio'**
  String get deleteAudio;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteConfirm(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @selectAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Select Audio File'**
  String get selectAudioFile;

  /// No description provided for @selectTranscript.
  ///
  /// In en, this message translates to:
  /// **'Select Transcript (Optional)'**
  String get selectTranscript;

  /// No description provided for @noTranscript.
  ///
  /// In en, this message translates to:
  /// **'No transcript available'**
  String get noTranscript;

  /// No description provided for @noBookmarked.
  ///
  /// In en, this message translates to:
  /// **'No bookmarked sentences'**
  String get noBookmarked;

  /// No description provided for @tapToBookmark.
  ///
  /// In en, this message translates to:
  /// **'Tap ⭐ on sentences to bookmark them'**
  String get tapToBookmark;

  /// No description provided for @playbackMode.
  ///
  /// In en, this message translates to:
  /// **'Playback Mode'**
  String get playbackMode;

  /// No description provided for @fullArticle.
  ///
  /// In en, this message translates to:
  /// **'Full Article'**
  String get fullArticle;

  /// No description provided for @singleSentence.
  ///
  /// In en, this message translates to:
  /// **'Single Sentence'**
  String get singleSentence;

  /// No description provided for @bookmarkedOnly.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked Only'**
  String get bookmarkedOnly;

  /// No description provided for @playbackSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback Settings'**
  String get playbackSettings;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// No description provided for @loopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Loop Playback'**
  String get loopPlayback;

  /// No description provided for @loopCount.
  ///
  /// In en, this message translates to:
  /// **'Loop Count'**
  String get loopCount;

  /// No description provided for @pauseInterval.
  ///
  /// In en, this message translates to:
  /// **'Pause Interval'**
  String get pauseInterval;

  /// No description provided for @applySettings.
  ///
  /// In en, this message translates to:
  /// **'Apply Settings'**
  String get applySettings;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @previousSentence.
  ///
  /// In en, this message translates to:
  /// **'Previous Sentence'**
  String get previousSentence;

  /// No description provided for @nextSentence.
  ///
  /// In en, this message translates to:
  /// **'Next Sentence'**
  String get nextSentence;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get addBookmark;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get themeModeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Professional English listening practice app'**
  String get appDescription;

  /// No description provided for @enableLoop.
  ///
  /// In en, this message translates to:
  /// **'Enable Loop'**
  String get enableLoop;

  /// No description provided for @loopSettings.
  ///
  /// In en, this message translates to:
  /// **'Loop Settings'**
  String get loopSettings;

  /// No description provided for @displaySettings.
  ///
  /// In en, this message translates to:
  /// **'Display Settings'**
  String get displaySettings;

  /// No description provided for @showTranscript.
  ///
  /// In en, this message translates to:
  /// **'Show Transcript'**
  String get showTranscript;

  /// No description provided for @shortcutKey.
  ///
  /// In en, this message translates to:
  /// **'Shortcut'**
  String get shortcutKey;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @infinite.
  ///
  /// In en, this message translates to:
  /// **'∞'**
  String get infinite;

  /// No description provided for @singleSentenceMode.
  ///
  /// In en, this message translates to:
  /// **'Single Sentence Mode'**
  String get singleSentenceMode;

  /// No description provided for @singleSentenceModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Show only current sentence'**
  String get singleSentenceModeDesc;

  /// No description provided for @autoPlayNextSentence.
  ///
  /// In en, this message translates to:
  /// **'Auto Play Next Sentence'**
  String get autoPlayNextSentence;

  /// No description provided for @sentenceRepeat.
  ///
  /// In en, this message translates to:
  /// **'Sentence Repeat'**
  String get sentenceRepeat;

  /// No description provided for @repeatCount.
  ///
  /// In en, this message translates to:
  /// **'Repeat Count'**
  String get repeatCount;

  /// No description provided for @intervalTime.
  ///
  /// In en, this message translates to:
  /// **'Interval (seconds)'**
  String get intervalTime;

  /// No description provided for @audioLoop.
  ///
  /// In en, this message translates to:
  /// **'Audio Loop'**
  String get audioLoop;

  /// No description provided for @loopTimes.
  ///
  /// In en, this message translates to:
  /// **'Loop Count'**
  String get loopTimes;

  /// No description provided for @noLoop.
  ///
  /// In en, this message translates to:
  /// **'No Loop'**
  String get noLoop;

  /// No description provided for @infiniteLoop.
  ///
  /// In en, this message translates to:
  /// **'Infinite ∞'**
  String get infiniteLoop;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get times;

  /// No description provided for @fullText.
  ///
  /// In en, this message translates to:
  /// **'Full Text'**
  String get fullText;

  /// No description provided for @bookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get bookmarked;

  /// No description provided for @noSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No Subtitle'**
  String get noSubtitle;

  /// No description provided for @noSentenceSelected.
  ///
  /// In en, this message translates to:
  /// **'No sentence selected'**
  String get noSentenceSelected;

  /// No description provided for @noBookmarkedSentences.
  ///
  /// In en, this message translates to:
  /// **'No bookmarked sentences'**
  String get noBookmarkedSentences;

  /// No description provided for @tapBookmarkIcon.
  ///
  /// In en, this message translates to:
  /// **'Tap bookmark icon to save'**
  String get tapBookmarkIcon;

  /// No description provided for @removeBookmarkTip.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmarkTip;

  /// No description provided for @addBookmarkTip.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get addBookmarkTip;

  /// No description provided for @listMode.
  ///
  /// In en, this message translates to:
  /// **'List Mode'**
  String get listMode;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
