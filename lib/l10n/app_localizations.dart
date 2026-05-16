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
  /// **'Echo Loop'**
  String get appTitle;

  /// No description provided for @practiceControlModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get practiceControlModeAuto;

  /// No description provided for @practiceControlModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get practiceControlModeManual;

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
  /// **'Last'**
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
  /// **'Theme'**
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
  /// **'Interface Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Language used for the app interface'**
  String get languageDescription;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get languageSystem;

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

  /// No description provided for @nativeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Native Language'**
  String get nativeLanguage;

  /// No description provided for @nativeLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Language for translations and analysis'**
  String get nativeLanguageDescription;

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

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

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

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @hotkeyReplay.
  ///
  /// In en, this message translates to:
  /// **'R: Replay'**
  String get hotkeyReplay;

  /// No description provided for @hotkeyPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Space: Play/Pause'**
  String get hotkeyPlayPause;

  /// No description provided for @hotkeyToggleTranscript.
  ///
  /// In en, this message translates to:
  /// **'↑: Show/Hide Transcript'**
  String get hotkeyToggleTranscript;

  /// No description provided for @hotkeyNavigation.
  ///
  /// In en, this message translates to:
  /// **'←/→: Previous/Next Sentence'**
  String get hotkeyNavigation;

  /// No description provided for @noAudioLoaded.
  ///
  /// In en, this message translates to:
  /// **'No audio loaded'**
  String get noAudioLoaded;

  /// No description provided for @enableAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Enable auto-scroll'**
  String get enableAutoScroll;

  /// No description provided for @disableAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Disable auto-scroll'**
  String get disableAutoScroll;

  /// No description provided for @audioFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Audio file not found. The file may have been deleted.'**
  String get audioFileNotFound;

  /// No description provided for @pickAudioFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select audio file'**
  String get pickAudioFileFailed;

  /// No description provided for @pickTranscriptFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select transcript file'**
  String get pickTranscriptFileFailed;

  /// No description provided for @fileExists.
  ///
  /// In en, this message translates to:
  /// **'File Exists'**
  String get fileExists;

  /// No description provided for @fileExistsMessage.
  ///
  /// In en, this message translates to:
  /// **'An audio file named \"{name}\" already exists. Please delete the original audio first.'**
  String fileExistsMessage(String name);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @addedOn.
  ///
  /// In en, this message translates to:
  /// **'Added: {date}'**
  String addedOn(String date);

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// No description provided for @createCollection.
  ///
  /// In en, this message translates to:
  /// **'Create Collection'**
  String get createCollection;

  /// No description provided for @collectionName.
  ///
  /// In en, this message translates to:
  /// **'Collection Name'**
  String get collectionName;

  /// No description provided for @enterCollectionName.
  ///
  /// In en, this message translates to:
  /// **'Enter collection name'**
  String get enterCollectionName;

  /// No description provided for @noCollectionsYet.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get noCollectionsYet;

  /// No description provided for @tapToCreateCollection.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first collection'**
  String get tapToCreateCollection;

  /// No description provided for @deleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Delete Collection'**
  String get deleteCollection;

  /// No description provided for @deleteCollectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? Audio files in this collection will not be deleted.'**
  String deleteCollectionConfirm(String name);

  /// No description provided for @renameCollection.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameCollection;

  /// No description provided for @pinCollection.
  ///
  /// In en, this message translates to:
  /// **'Pin to Top'**
  String get pinCollection;

  /// No description provided for @unpinCollection.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinCollection;

  /// No description provided for @pinAudio.
  ///
  /// In en, this message translates to:
  /// **'Pin to Top'**
  String get pinAudio;

  /// No description provided for @unpinAudio.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinAudio;

  /// No description provided for @sortByNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name (A-Z)'**
  String get sortByNameAsc;

  /// No description provided for @sortByNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Name (Z-A)'**
  String get sortByNameDesc;

  /// No description provided for @sortByDateAsc.
  ///
  /// In en, this message translates to:
  /// **'Oldest First'**
  String get sortByDateAsc;

  /// No description provided for @sortByDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Newest First'**
  String get sortByDateDesc;

  /// No description provided for @sortDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get sortDefault;

  /// No description provided for @sortByOriginalDateAsc.
  ///
  /// In en, this message translates to:
  /// **'Oldest Published'**
  String get sortByOriginalDateAsc;

  /// No description provided for @sortByOriginalDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Latest Published'**
  String get sortByOriginalDateDesc;

  /// No description provided for @publishedOn.
  ///
  /// In en, this message translates to:
  /// **'Published {date}'**
  String publishedOn(String date);

  /// No description provided for @discoverEntryTitleA.
  ///
  /// In en, this message translates to:
  /// **'Discover Curated Collections'**
  String get discoverEntryTitleA;

  /// No description provided for @discoverEntrySubtitleA.
  ///
  /// In en, this message translates to:
  /// **'TOEFL · IELTS · TEM · VOA…'**
  String get discoverEntrySubtitleA;

  /// No description provided for @officialCollectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'This collection has no audios yet'**
  String get officialCollectionEmpty;

  /// No description provided for @sortCollections.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortCollections;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid View'**
  String get gridView;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get listView;

  /// No description provided for @audioCount.
  ///
  /// In en, this message translates to:
  /// **'{count} audios'**
  String audioCount(int count);

  /// No description provided for @collectionNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot be empty'**
  String get collectionNameEmpty;

  /// No description provided for @collectionNameExists.
  ///
  /// In en, this message translates to:
  /// **'A collection with this name already exists'**
  String get collectionNameExists;

  /// No description provided for @addAudioToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add Audio'**
  String get addAudioToCollection;

  /// No description provided for @removeFromCollection.
  ///
  /// In en, this message translates to:
  /// **'Remove from Collection'**
  String get removeFromCollection;

  /// No description provided for @removeFromCollectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from this collection?'**
  String removeFromCollectionConfirm(String name);

  /// No description provided for @emptyCollection.
  ///
  /// In en, this message translates to:
  /// **'No audio in this collection'**
  String get emptyCollection;

  /// No description provided for @tapToAddAudio.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add audio files'**
  String get tapToAddAudio;

  /// No description provided for @renameAudio.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameAudio;

  /// No description provided for @audioName.
  ///
  /// In en, this message translates to:
  /// **'Audio Name'**
  String get audioName;

  /// No description provided for @audioAlreadyInCollection.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Audio'**
  String get audioAlreadyInCollection;

  /// No description provided for @audioAlreadyInCollectionMessage.
  ///
  /// In en, this message translates to:
  /// **'An audio named \"{name}\" already exists in this collection.'**
  String audioAlreadyInCollectionMessage(String name);

  /// No description provided for @audioAlreadyInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Audio'**
  String get audioAlreadyInLibrary;

  /// No description provided for @audioAlreadyInLibraryMessage.
  ///
  /// In en, this message translates to:
  /// **'An audio named \"{name}\" already exists in the library.'**
  String audioAlreadyInLibraryMessage(String name);

  /// No description provided for @study.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get study;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get favorites;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @studyComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Study feature coming soon'**
  String get studyComingSoon;

  /// No description provided for @favoritesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Favorites feature coming soon'**
  String get favoritesComingSoon;

  /// No description provided for @learningPlanProgress.
  ///
  /// In en, this message translates to:
  /// **'Learning Progress'**
  String get learningPlanProgress;

  /// No description provided for @learningPlanNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get learningPlanNotStarted;

  /// No description provided for @firstStudy.
  ///
  /// In en, this message translates to:
  /// **'Initial Learning'**
  String get firstStudy;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @stepProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} completed'**
  String stepProgress(int completed, int total);

  /// No description provided for @stepBlindListening.
  ///
  /// In en, this message translates to:
  /// **'Blind Listening'**
  String get stepBlindListening;

  /// No description provided for @stepBlindListeningDesc.
  ///
  /// In en, this message translates to:
  /// **'Blind listen to get the overall difficulty and gist'**
  String get stepBlindListeningDesc;

  /// No description provided for @stepIntensiveListening.
  ///
  /// In en, this message translates to:
  /// **'Intensive Listening'**
  String get stepIntensiveListening;

  /// No description provided for @stepIntensiveListeningDesc.
  ///
  /// In en, this message translates to:
  /// **'Listen sentence by sentence, understand and mark difficult ones'**
  String get stepIntensiveListeningDesc;

  /// No description provided for @stepShadowing.
  ///
  /// In en, this message translates to:
  /// **'Listen & Repeat'**
  String get stepShadowing;

  /// No description provided for @stepShadowingDesc.
  ///
  /// In en, this message translates to:
  /// **'Repeat weak sentences over and over'**
  String get stepShadowingDesc;

  /// No description provided for @stepRetelling.
  ///
  /// In en, this message translates to:
  /// **'Paragraph Retelling'**
  String get stepRetelling;

  /// No description provided for @stepRetellingDesc.
  ///
  /// In en, this message translates to:
  /// **'Retell the gist of each paragraph in English'**
  String get stepRetellingDesc;

  /// No description provided for @reviewRound0.
  ///
  /// In en, this message translates to:
  /// **'Review 1'**
  String get reviewRound0;

  /// No description provided for @reviewRound1.
  ///
  /// In en, this message translates to:
  /// **'Review 2'**
  String get reviewRound1;

  /// No description provided for @reviewRound2.
  ///
  /// In en, this message translates to:
  /// **'Review 3'**
  String get reviewRound2;

  /// No description provided for @reviewRound4.
  ///
  /// In en, this message translates to:
  /// **'Review 4'**
  String get reviewRound4;

  /// No description provided for @reviewRound7.
  ///
  /// In en, this message translates to:
  /// **'Review 5'**
  String get reviewRound7;

  /// No description provided for @reviewRound14.
  ///
  /// In en, this message translates to:
  /// **'Review 6'**
  String get reviewRound14;

  /// No description provided for @reviewRound28.
  ///
  /// In en, this message translates to:
  /// **'Review 7'**
  String get reviewRound28;

  /// No description provided for @reviewIntervalNow.
  ///
  /// In en, this message translates to:
  /// **'After 6 hours'**
  String get reviewIntervalNow;

  /// No description provided for @reviewInterval1d.
  ///
  /// In en, this message translates to:
  /// **'After 1 day'**
  String get reviewInterval1d;

  /// No description provided for @reviewInterval2d.
  ///
  /// In en, this message translates to:
  /// **'After 2 days'**
  String get reviewInterval2d;

  /// No description provided for @reviewInterval4d.
  ///
  /// In en, this message translates to:
  /// **'After 4 days'**
  String get reviewInterval4d;

  /// No description provided for @reviewInterval7d.
  ///
  /// In en, this message translates to:
  /// **'After 7 days'**
  String get reviewInterval7d;

  /// No description provided for @reviewInterval14d.
  ///
  /// In en, this message translates to:
  /// **'After 14 days'**
  String get reviewInterval14d;

  /// No description provided for @reviewInterval28d.
  ///
  /// In en, this message translates to:
  /// **'After 28 days'**
  String get reviewInterval28d;

  /// No description provided for @reviewUnlockIn.
  ///
  /// In en, this message translates to:
  /// **'Unlocks in {days} days'**
  String reviewUnlockIn(int days);

  /// No description provided for @reviewUnlockInHours.
  ///
  /// In en, this message translates to:
  /// **'Unlocks in {hours} hours'**
  String reviewUnlockInHours(int hours);

  /// No description provided for @reviewUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get reviewUnlocked;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get startLearning;

  /// No description provided for @continueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get continueLearning;

  /// No description provided for @learningInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get learningInProgress;

  /// No description provided for @learningCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get learningCompleted;

  /// No description provided for @reviewReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to review'**
  String get reviewReady;

  /// No description provided for @reviewCountdown.
  ///
  /// In en, this message translates to:
  /// **'Available in {days} days'**
  String reviewCountdown(int days);

  /// No description provided for @reviewCountdownHours.
  ///
  /// In en, this message translates to:
  /// **'Available in {hours} hours'**
  String reviewCountdownHours(int hours);

  /// No description provided for @blindListenBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Blind Listening'**
  String get blindListenBriefingTitle;

  /// No description provided for @blindListenBriefingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Initial Learning - Blind Listening'**
  String get blindListenBriefingSubtitle;

  /// No description provided for @blindListenBriefingReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review {round} - Blind Listening'**
  String blindListenBriefingReviewSubtitle(int round);

  /// No description provided for @blindListenBriefingTip.
  ///
  /// In en, this message translates to:
  /// **'Listen without subtitles, try to get the gist'**
  String get blindListenBriefingTip;

  /// No description provided for @startPractice.
  ///
  /// In en, this message translates to:
  /// **'Start Practice'**
  String get startPractice;

  /// No description provided for @blindListenAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Blind Listening'**
  String get blindListenAppBarTitle;

  /// No description provided for @blindListenPassLabel.
  ///
  /// In en, this message translates to:
  /// **'Pass {count}'**
  String blindListenPassLabel(int count);

  /// No description provided for @blindListenComplete.
  ///
  /// In en, this message translates to:
  /// **'Blind Listen Complete'**
  String get blindListenComplete;

  /// No description provided for @blindListenPassInfo.
  ///
  /// In en, this message translates to:
  /// **'Listened {count} time(s)'**
  String blindListenPassInfo(int count);

  /// No description provided for @selectDifficulty.
  ///
  /// In en, this message translates to:
  /// **'How did it feel?'**
  String get selectDifficulty;

  /// No description provided for @selectDifficultyRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a difficulty to continue'**
  String get selectDifficultyRequired;

  /// No description provided for @listenAgain.
  ///
  /// In en, this message translates to:
  /// **'Listen Again'**
  String get listenAgain;

  /// No description provided for @practiceAgain.
  ///
  /// In en, this message translates to:
  /// **'Practice Again'**
  String get practiceAgain;

  /// No description provided for @nextStage.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextStage;

  /// No description provided for @difficultyVeryEasy.
  ///
  /// In en, this message translates to:
  /// **'Very Easy'**
  String get difficultyVeryEasy;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @difficultyVeryHard.
  ///
  /// In en, this message translates to:
  /// **'Very Hard'**
  String get difficultyVeryHard;

  /// No description provided for @countdownNextPlay.
  ///
  /// In en, this message translates to:
  /// **'Next play starts in'**
  String get countdownNextPlay;

  /// No description provided for @skipCountdown.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipCountdown;

  /// No description provided for @audioDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}'**
  String audioDuration(String duration);

  /// No description provided for @estimatedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Est. {minutes} min'**
  String estimatedMinutes(int minutes);

  /// No description provided for @estimatedLessThanOneMinute.
  ///
  /// In en, this message translates to:
  /// **'Est. < 1 min'**
  String get estimatedLessThanOneMinute;

  /// No description provided for @exitBlindListenTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Listening?'**
  String get exitBlindListenTitle;

  /// No description provided for @exitBlindListenMessage.
  ///
  /// In en, this message translates to:
  /// **'Audio is still playing. Are you sure you want to exit?'**
  String get exitBlindListenMessage;

  /// No description provided for @confirmExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get confirmExit;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @collectionsTab.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collectionsTab;

  /// No description provided for @audioTab.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioTab;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @manageCollections.
  ///
  /// In en, this message translates to:
  /// **'Manage Collections'**
  String get manageCollections;

  /// No description provided for @noAudioItems.
  ///
  /// In en, this message translates to:
  /// **'No audio files yet'**
  String get noAudioItems;

  /// No description provided for @noAudioItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Import audio files to start learning'**
  String get noAudioItemsHint;

  /// No description provided for @audioWillBeKept.
  ///
  /// In en, this message translates to:
  /// **'{count} audio files in this collection will be kept in the library'**
  String audioWillBeKept(int count);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @sortAudio.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortAudio;

  /// No description provided for @deleteAudioConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? The audio file will be permanently deleted.'**
  String deleteAudioConfirm(String name);

  /// No description provided for @uploadTranscript.
  ///
  /// In en, this message translates to:
  /// **'Upload Transcript'**
  String get uploadTranscript;

  /// No description provided for @replaceTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace Transcript'**
  String get replaceTranscriptTitle;

  /// No description provided for @replaceTranscriptMessage.
  ///
  /// In en, this message translates to:
  /// **'A transcript already exists. Do you want to replace it?'**
  String get replaceTranscriptMessage;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @sentenceCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} sentences'**
  String sentenceCountLabel(int count);

  /// No description provided for @wordCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wordCountLabel(int count);

  /// No description provided for @noTranscriptWarning.
  ///
  /// In en, this message translates to:
  /// **'This audio has no transcript yet'**
  String get noTranscriptWarning;

  /// No description provided for @intensiveListenAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Intensive Listening'**
  String get intensiveListenAppBarTitle;

  /// No description provided for @intensiveListenProgress.
  ///
  /// In en, this message translates to:
  /// **'Sentence {current}/{total}'**
  String intensiveListenProgress(int current, int total);

  /// No description provided for @intensiveListenPlayCount.
  ///
  /// In en, this message translates to:
  /// **'Round {current}/{total}'**
  String intensiveListenPlayCount(int current, int total);

  /// No description provided for @intensiveListenPeek.
  ///
  /// In en, this message translates to:
  /// **'Peek'**
  String get intensiveListenPeek;

  /// No description provided for @intensiveListenHideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get intensiveListenHideSubtitle;

  /// No description provided for @intensiveListenCantUnderstand.
  ///
  /// In en, this message translates to:
  /// **'Unclear'**
  String get intensiveListenCantUnderstand;

  /// No description provided for @intensiveListenAutoMarkedDifficult.
  ///
  /// In en, this message translates to:
  /// **'Auto-marked difficult, tap to undo'**
  String get intensiveListenAutoMarkedDifficult;

  /// No description provided for @intensiveListenMarkedDifficult.
  ///
  /// In en, this message translates to:
  /// **'Marked difficult, tap to undo'**
  String get intensiveListenMarkedDifficult;

  /// No description provided for @intensiveListenNotDifficult.
  ///
  /// In en, this message translates to:
  /// **'Tap to mark as difficult'**
  String get intensiveListenNotDifficult;

  /// No description provided for @aiTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get aiTranslation;

  /// No description provided for @aiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get aiAnalysis;

  /// No description provided for @aiLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load, tap to retry'**
  String get aiLoadFailed;

  /// No description provided for @aiTranslationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed, please retry'**
  String get aiTranslationFailed;

  /// No description provided for @aiAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed, please retry'**
  String get aiAnalysisFailed;

  /// No description provided for @aiRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get aiRetry;

  /// No description provided for @aiGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get aiGrammar;

  /// No description provided for @aiVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Key Vocabulary'**
  String get aiVocabulary;

  /// No description provided for @aiListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get aiListening;

  /// No description provided for @intensiveListenWordDictNotFound.
  ///
  /// In en, this message translates to:
  /// **'Word not found in dictionary'**
  String get intensiveListenWordDictNotFound;

  /// No description provided for @intensiveListenContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get intensiveListenContinue;

  /// No description provided for @intensiveListenReplayingWithSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replaying with subtitles...'**
  String get intensiveListenReplayingWithSubtitle;

  /// No description provided for @intensiveListenPauseBetweenPlays.
  ///
  /// In en, this message translates to:
  /// **'Next play in {seconds}s'**
  String intensiveListenPauseBetweenPlays(int seconds);

  /// No description provided for @intensiveListenPauseBetweenSentences.
  ///
  /// In en, this message translates to:
  /// **'Next sentence in {seconds}s'**
  String intensiveListenPauseBetweenSentences(int seconds);

  /// No description provided for @intensiveListenCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Intensive Listening Complete'**
  String get intensiveListenCompleteTitle;

  /// No description provided for @intensiveListenCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed intensive listening for all {total} sentences.\n{difficult} sentence(s) marked as difficult.'**
  String intensiveListenCompleteMessage(int total, int difficult);

  /// No description provided for @intensiveListenCompleteNext.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get intensiveListenCompleteNext;

  /// No description provided for @exitIntensiveListenTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Intensive Listening?'**
  String get exitIntensiveListenTitle;

  /// No description provided for @exitIntensiveListenMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress will be saved. You can continue from where you left off.'**
  String get exitIntensiveListenMessage;

  /// No description provided for @intensiveListenBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Intensive Listening'**
  String get intensiveListenBriefingTitle;

  /// No description provided for @intensiveListenBriefingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Initial Learning - Intensive Listening'**
  String get intensiveListenBriefingSubtitle;

  /// No description provided for @intensiveListenBriefingTip.
  ///
  /// In en, this message translates to:
  /// **'Listen sentence by sentence. Tap \'Unclear\' to reveal text and mark difficult sentences.'**
  String get intensiveListenBriefingTip;

  /// No description provided for @intensiveListenBriefingSentenceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sentences'**
  String intensiveListenBriefingSentenceCount(int count);

  /// No description provided for @intensiveListenNoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No Subtitle Available'**
  String get intensiveListenNoSubtitle;

  /// No description provided for @intensiveListenNoSubtitleMessage.
  ///
  /// In en, this message translates to:
  /// **'This audio has no subtitle. Please upload a subtitle file first.'**
  String get intensiveListenNoSubtitleMessage;

  /// No description provided for @intensiveListenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get intensiveListenSettings;

  /// No description provided for @intensiveListenRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'Repeat per sentence'**
  String get intensiveListenRepeatCount;

  /// No description provided for @intensiveListenRepeatCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} time(s)'**
  String intensiveListenRepeatCountValue(int count);

  /// No description provided for @intensiveListenPauseLabel.
  ///
  /// In en, this message translates to:
  /// **'Pause between sentences'**
  String get intensiveListenPauseLabel;

  /// No description provided for @intensiveListenPauseSmart.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get intensiveListenPauseSmart;

  /// No description provided for @intensiveListenPauseFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get intensiveListenPauseFixed;

  /// No description provided for @intensiveListenPauseMultiplierMode.
  ///
  /// In en, this message translates to:
  /// **'Multiplier'**
  String get intensiveListenPauseMultiplierMode;

  /// No description provided for @intensiveListenSettingsTemporaryHint.
  ///
  /// In en, this message translates to:
  /// **'Settings apply to this session only'**
  String get intensiveListenSettingsTemporaryHint;

  /// No description provided for @intensiveListenPauseSmartDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-adjusted based on difficulty, sentence length, and learning stage'**
  String get intensiveListenPauseSmartDesc;

  /// No description provided for @intensiveListenControlModeAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-loop, auto-pause, auto-next'**
  String get intensiveListenControlModeAutoDesc;

  /// No description provided for @intensiveListenControlModeManualDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap to replay, tap next'**
  String get intensiveListenControlModeManualDesc;

  /// No description provided for @intensiveListenPauseFixedUnit.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String intensiveListenPauseFixedUnit(int seconds);

  /// No description provided for @intensiveListenPauseMultiplierValue.
  ///
  /// In en, this message translates to:
  /// **'{value}x'**
  String intensiveListenPauseMultiplierValue(String value);

  /// No description provided for @intensiveListenPauseMultiplierLabel.
  ///
  /// In en, this message translates to:
  /// **'Multiplier'**
  String get intensiveListenPauseMultiplierLabel;

  /// No description provided for @blindListenCountdown.
  ///
  /// In en, this message translates to:
  /// **'Next play in {seconds}s'**
  String blindListenCountdown(int seconds);

  /// No description provided for @difficultyLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty: {difficulty}'**
  String difficultyLabel(String difficulty);

  /// No description provided for @continueToStep.
  ///
  /// In en, this message translates to:
  /// **'Continue: {step}'**
  String continueToStep(String step);

  /// No description provided for @completeFirstStudy.
  ///
  /// In en, this message translates to:
  /// **'Complete Initial Learning'**
  String get completeFirstStudy;

  /// No description provided for @completeReview.
  ///
  /// In en, this message translates to:
  /// **'Complete Review'**
  String get completeReview;

  /// No description provided for @stepProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Step {current}/{total} ({stage})'**
  String stepProgressLabel(int current, int total, String stage);

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get manageTags;

  /// No description provided for @noTagsYet.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get noTagsYet;

  /// No description provided for @createTag.
  ///
  /// In en, this message translates to:
  /// **'Create Tag'**
  String get createTag;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get tagName;

  /// No description provided for @enterTagName.
  ///
  /// In en, this message translates to:
  /// **'Enter tag name'**
  String get enterTagName;

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get selectColor;

  /// No description provided for @deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete Tag'**
  String get deleteTag;

  /// No description provided for @deleteTagConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? It will be removed from all audio.'**
  String deleteTagConfirm(String name);

  /// No description provided for @listenAndRepeatAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen & Repeat'**
  String get listenAndRepeatAppBarTitle;

  /// No description provided for @listenAndRepeatProgress.
  ///
  /// In en, this message translates to:
  /// **'Sentence {current}/{total}'**
  String listenAndRepeatProgress(int current, int total);

  /// No description provided for @listenAndRepeatPlayCount.
  ///
  /// In en, this message translates to:
  /// **'Round {current}/{total}'**
  String listenAndRepeatPlayCount(int current, int total);

  /// No description provided for @listenAndRepeatPauseBetweenPlays.
  ///
  /// In en, this message translates to:
  /// **'Repeat time {seconds}s'**
  String listenAndRepeatPauseBetweenPlays(int seconds);

  /// No description provided for @listenAndRepeatPauseBetweenSentences.
  ///
  /// In en, this message translates to:
  /// **'Next sentence in {seconds}s'**
  String listenAndRepeatPauseBetweenSentences(int seconds);

  /// No description provided for @listenAndRepeatListenHint.
  ///
  /// In en, this message translates to:
  /// **'Listen then repeat'**
  String get listenAndRepeatListenHint;

  /// No description provided for @listenAndRepeatYourTurnHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get listenAndRepeatYourTurnHint;

  /// No description provided for @listenAndRepeatRecordButton.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get listenAndRepeatRecordButton;

  /// No description provided for @listenAndRepeatStopRecordingButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get listenAndRepeatStopRecordingButton;

  /// No description provided for @listenAndRepeatPlayRecordingButton.
  ///
  /// In en, this message translates to:
  /// **'Play My Recording'**
  String get listenAndRepeatPlayRecordingButton;

  /// No description provided for @listenAndRepeatRecordingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get listenAndRepeatRecordingInProgress;

  /// No description provided for @listenAndRepeatStartSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Start speaking'**
  String get listenAndRepeatStartSpeaking;

  /// No description provided for @listenAndRepeatAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get listenAndRepeatAnalyzing;

  /// No description provided for @listenAndRepeatTapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get listenAndRepeatTapToRecord;

  /// No description provided for @listenAndRepeatRatingPerfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect!'**
  String get listenAndRepeatRatingPerfect;

  /// No description provided for @listenAndRepeatRatingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get listenAndRepeatRatingExcellent;

  /// No description provided for @listenAndRepeatRatingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get listenAndRepeatRatingGood;

  /// No description provided for @listenAndRepeatRatingFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get listenAndRepeatRatingFair;

  /// No description provided for @listenAndRepeatRatingKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get listenAndRepeatRatingKeepGoing;

  /// No description provided for @listenAndRepeatAwaitingFinalTranscript.
  ///
  /// In en, this message translates to:
  /// **'Confirming final transcript...'**
  String get listenAndRepeatAwaitingFinalTranscript;

  /// No description provided for @listenAndRepeatYourTakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Take'**
  String get listenAndRepeatYourTakeLabel;

  /// No description provided for @listenAndRepeatRecognitionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Checking your recording...'**
  String get listenAndRepeatRecognitionInProgress;

  /// No description provided for @listenAndRepeatRecognitionPassed.
  ///
  /// In en, this message translates to:
  /// **'Matched {percent}% of the target words.'**
  String listenAndRepeatRecognitionPassed(int percent);

  /// No description provided for @listenAndRepeatRecognitionBelowThreshold.
  ///
  /// In en, this message translates to:
  /// **'Matched {percent}% of the target words.'**
  String listenAndRepeatRecognitionBelowThreshold(int percent);

  /// No description provided for @listenAndRepeatRecognitionNoEnglish.
  ///
  /// In en, this message translates to:
  /// **'No English speech detected'**
  String get listenAndRepeatRecognitionNoEnglish;

  /// No description provided for @listenAndRepeatRecognitionPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone or speech recognition permission is required.'**
  String get listenAndRepeatRecognitionPermissionDenied;

  /// No description provided for @listenAndRepeatRecognitionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is unavailable on this device.'**
  String get listenAndRepeatRecognitionUnavailable;

  /// No description provided for @listenAndRepeatRecognitionError.
  ///
  /// In en, this message translates to:
  /// **'Recognition error'**
  String get listenAndRepeatRecognitionError;

  /// No description provided for @listenAndRepeatRecordingOnly.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get listenAndRepeatRecordingOnly;

  /// No description provided for @listenAndRepeatCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen & Repeat Complete'**
  String get listenAndRepeatCompleteTitle;

  /// No description provided for @listenAndRepeatCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed listen & repeat for all {total} difficult sentences.'**
  String listenAndRepeatCompleteMessage(int total);

  /// No description provided for @listenAndRepeatNoDifficultSentences.
  ///
  /// In en, this message translates to:
  /// **'All sentences understood. Listen & repeat auto-completed.'**
  String get listenAndRepeatNoDifficultSentences;

  /// No description provided for @exitListenAndRepeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Listen & Repeat?'**
  String get exitListenAndRepeatTitle;

  /// No description provided for @exitListenAndRepeatMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress will be saved. You can continue from where you left off.'**
  String get exitListenAndRepeatMessage;

  /// No description provided for @listenAndRepeatBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen & Repeat'**
  String get listenAndRepeatBriefingTitle;

  /// No description provided for @listenAndRepeatBriefingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Initial Learning - Listen & Repeat'**
  String get listenAndRepeatBriefingSubtitle;

  /// No description provided for @listenAndRepeatBriefingTip.
  ///
  /// In en, this message translates to:
  /// **'Listen first, then repeat during the pause.'**
  String get listenAndRepeatBriefingTip;

  /// No description provided for @listenAndRepeatBriefingDifficultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} difficult sentences'**
  String listenAndRepeatBriefingDifficultCount(int count);

  /// No description provided for @listenAndRepeatBriefingPlayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} plays per sentence'**
  String listenAndRepeatBriefingPlayCount(int count);

  /// No description provided for @listenAndRepeatRemoveDifficult.
  ///
  /// In en, this message translates to:
  /// **'Marked difficult, tap to remove'**
  String get listenAndRepeatRemoveDifficult;

  /// No description provided for @listenAndRepeatSettings.
  ///
  /// In en, this message translates to:
  /// **'Repeat Settings'**
  String get listenAndRepeatSettings;

  /// No description provided for @listenAndRepeatSettingsTemporaryHint.
  ///
  /// In en, this message translates to:
  /// **'Settings apply to this session only'**
  String get listenAndRepeatSettingsTemporaryHint;

  /// No description provided for @listenAndRepeatControlModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Control Mode'**
  String get listenAndRepeatControlModeLabel;

  /// No description provided for @listenAndRepeatControlModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get listenAndRepeatControlModeAuto;

  /// No description provided for @listenAndRepeatControlModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get listenAndRepeatControlModeManual;

  /// No description provided for @listenAndRepeatControlModeAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-record, auto-stop, auto-advance'**
  String get listenAndRepeatControlModeAutoDesc;

  /// No description provided for @listenAndRepeatControlModeManualDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap to record, tap to stop, tap next'**
  String get listenAndRepeatControlModeManualDesc;

  /// No description provided for @listenAndRepeatPauseSmartDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-adjusted based on difficulty, sentence length, and learning stage'**
  String get listenAndRepeatPauseSmartDesc;

  /// No description provided for @sentenceDuration.
  ///
  /// In en, this message translates to:
  /// **'{duration}s'**
  String sentenceDuration(String duration);

  /// No description provided for @difficultSentenceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} difficult sentences'**
  String difficultSentenceCount(int count);

  /// No description provided for @intensiveListenPassInfo.
  ///
  /// In en, this message translates to:
  /// **'Practiced {count}x'**
  String intensiveListenPassInfo(int count);

  /// No description provided for @shadowingPassInfo.
  ///
  /// In en, this message translates to:
  /// **'Practiced {count}x'**
  String shadowingPassInfo(int count);

  /// No description provided for @retellBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Paragraph Retelling'**
  String get retellBriefingTitle;

  /// No description provided for @retellBriefingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Listen to a paragraph, then retell in your own words. Keywords help you recall the content.'**
  String get retellBriefingSubtitle;

  /// No description provided for @retellBriefingTargetDuration.
  ///
  /// In en, this message translates to:
  /// **'Paragraph duration'**
  String get retellBriefingTargetDuration;

  /// No description provided for @retellBriefingParagraphCount.
  ///
  /// In en, this message translates to:
  /// **'Will be divided into {count} paragraphs'**
  String retellBriefingParagraphCount(int count);

  /// No description provided for @retellBriefingSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String retellBriefingSeconds(int seconds);

  /// No description provided for @retellBriefingSentenceLevel.
  ///
  /// In en, this message translates to:
  /// **'Per Sentence'**
  String get retellBriefingSentenceLevel;

  /// No description provided for @retellBriefingSentenceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sentences total'**
  String retellBriefingSentenceCount(int count);

  /// No description provided for @retellTitle.
  ///
  /// In en, this message translates to:
  /// **'Paragraph Retelling'**
  String get retellTitle;

  /// No description provided for @retellParagraphProgress.
  ///
  /// In en, this message translates to:
  /// **'Paragraph {current}/{total}'**
  String retellParagraphProgress(int current, int total);

  /// No description provided for @retellParagraphDuration.
  ///
  /// In en, this message translates to:
  /// **'{duration}s'**
  String retellParagraphDuration(String duration);

  /// No description provided for @retellPreListenHint.
  ///
  /// In en, this message translates to:
  /// **'Listen first, then retell'**
  String get retellPreListenHint;

  /// No description provided for @retellListeningPhase.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get retellListeningPhase;

  /// No description provided for @retellPromptToRetell.
  ///
  /// In en, this message translates to:
  /// **'Retell it in your own words'**
  String get retellPromptToRetell;

  /// No description provided for @retellRetellingCountdown.
  ///
  /// In en, this message translates to:
  /// **'Retell {seconds}s'**
  String retellRetellingCountdown(int seconds);

  /// No description provided for @retellRepeatInfo.
  ///
  /// In en, this message translates to:
  /// **'Round {current}/{total}'**
  String retellRepeatInfo(int current, int total);

  /// No description provided for @retellCompleteFirstStudy.
  ///
  /// In en, this message translates to:
  /// **'Complete Initial Learning'**
  String get retellCompleteFirstStudy;

  /// No description provided for @retellCompleteReview.
  ///
  /// In en, this message translates to:
  /// **'Complete Review'**
  String get retellCompleteReview;

  /// No description provided for @retellCompleteFreePlay.
  ///
  /// In en, this message translates to:
  /// **'Practice Complete'**
  String get retellCompleteFreePlay;

  /// No description provided for @retellCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Retelling Complete'**
  String get retellCompleteTitle;

  /// No description provided for @retellPracticeAgain.
  ///
  /// In en, this message translates to:
  /// **'Practice Again'**
  String get retellPracticeAgain;

  /// No description provided for @retellCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} paragraphs retold'**
  String retellCompleteMessage(int count);

  /// No description provided for @retellExitConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Retelling?'**
  String get retellExitConfirmTitle;

  /// No description provided for @retellExitConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Current paragraph progress will be saved.'**
  String get retellExitConfirmMessage;

  /// No description provided for @retellDisplayKeywordsOnly.
  ///
  /// In en, this message translates to:
  /// **'Visible Only'**
  String get retellDisplayKeywordsOnly;

  /// No description provided for @retellDisplayShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get retellDisplayShowAll;

  /// No description provided for @retellDisplayHideAll.
  ///
  /// In en, this message translates to:
  /// **'Hide All'**
  String get retellDisplayHideAll;

  /// No description provided for @retellSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Retell Settings'**
  String get retellSettingsTitle;

  /// No description provided for @retellRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'Repeat per paragraph'**
  String get retellRepeatCount;

  /// No description provided for @retellPauseMode.
  ///
  /// In en, this message translates to:
  /// **'Pause between paragraphs'**
  String get retellPauseMode;

  /// No description provided for @retellPassInfo.
  ///
  /// In en, this message translates to:
  /// **'Practiced {count}x'**
  String retellPassInfo(int count);

  /// No description provided for @retellNoDifficultSentences.
  ///
  /// In en, this message translates to:
  /// **'No sentences to retell. Complete intensive listening first.'**
  String get retellNoDifficultSentences;

  /// No description provided for @retellKeywordMethod.
  ///
  /// In en, this message translates to:
  /// **'Visible words'**
  String get retellKeywordMethod;

  /// No description provided for @retellKeywordMethodOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get retellKeywordMethodOff;

  /// No description provided for @retellKeywordMethodRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get retellKeywordMethodRandom;

  /// No description provided for @retellKeywordMethodAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get retellKeywordMethodAi;

  /// No description provided for @retellKeywordMethodAiComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get retellKeywordMethodAiComingSoon;

  /// No description provided for @retellKeywordRatio.
  ///
  /// In en, this message translates to:
  /// **'Visible ratio'**
  String get retellKeywordRatio;

  /// No description provided for @pauseModeSmart.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get pauseModeSmart;

  /// No description provided for @pauseModeFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get pauseModeFixed;

  /// No description provided for @pauseModeMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Multiplier'**
  String get pauseModeMultiplier;

  /// No description provided for @fixedPauseSeconds.
  ///
  /// In en, this message translates to:
  /// **'Fixed pause'**
  String get fixedPauseSeconds;

  /// No description provided for @pauseMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Multiplier'**
  String get pauseMultiplier;

  /// No description provided for @settingsSessionOnly.
  ///
  /// In en, this message translates to:
  /// **'Settings apply to current session only'**
  String get settingsSessionOnly;

  /// No description provided for @reviewDifficultPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Difficult Sentence Practice'**
  String get reviewDifficultPracticeTitle;

  /// No description provided for @reviewDifficultPracticeProgress.
  ///
  /// In en, this message translates to:
  /// **'Sentence {current}/{total}'**
  String reviewDifficultPracticeProgress(int current, int total);

  /// No description provided for @reviewDifficultPracticeBlindListen.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get reviewDifficultPracticeBlindListen;

  /// No description provided for @reviewDifficultPracticeCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Difficult Practice Complete'**
  String get reviewDifficultPracticeCompleteTitle;

  /// No description provided for @reviewDifficultPracticeCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve practiced all {total} difficult sentences.'**
  String reviewDifficultPracticeCompleteMessage(int total);

  /// No description provided for @reviewDifficultPracticeNone.
  ///
  /// In en, this message translates to:
  /// **'No difficult sentences to practice. Auto-completed.'**
  String get reviewDifficultPracticeNone;

  /// No description provided for @exitReviewDifficultPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Practice?'**
  String get exitReviewDifficultPracticeTitle;

  /// No description provided for @exitReviewDifficultPracticeMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress will not be saved for this step.'**
  String get exitReviewDifficultPracticeMessage;

  /// No description provided for @exitReviewDifficultPracticeConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress will be saved and you can continue next time.'**
  String get exitReviewDifficultPracticeConfirmMessage;

  /// No description provided for @reviewDifficultPracticeAdvancing.
  ///
  /// In en, this message translates to:
  /// **'Next sentence in {seconds}s'**
  String reviewDifficultPracticeAdvancing(int seconds);

  /// No description provided for @aiSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiSectionTitle;

  /// No description provided for @speechRecognition.
  ///
  /// In en, this message translates to:
  /// **'Speech Recognition'**
  String get speechRecognition;

  /// No description provided for @speechRecognitionNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get speechRecognitionNotConfigured;

  /// No description provided for @speechRecognitionEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get speechRecognitionEnabled;

  /// No description provided for @speechRecognitionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get speechRecognitionDisabled;

  /// No description provided for @speechRecognitionDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, speech recognition automatically evaluates your pronunciation during repeat and retell practice.'**
  String get speechRecognitionDescription;

  /// No description provided for @asrBackendPlatform.
  ///
  /// In en, this message translates to:
  /// **'Apple Speech'**
  String get asrBackendPlatform;

  /// No description provided for @asrBackendPlatformDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses the built-in system speech recognition, no download needed'**
  String get asrBackendPlatformDescription;

  /// No description provided for @asrBackendOffline.
  ///
  /// In en, this message translates to:
  /// **'Echo Loop AI'**
  String get asrBackendOffline;

  /// No description provided for @asrBackendOfflineDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses the app\'s AI model, works offline, requires download'**
  String get asrBackendOfflineDescription;

  /// No description provided for @asrModelTier.
  ///
  /// In en, this message translates to:
  /// **'Model: {tier} (auto-selected for your device)'**
  String asrModelTier(String tier);

  /// No description provided for @localSpeechRecognition.
  ///
  /// In en, this message translates to:
  /// **'Local Speech Recognition'**
  String get localSpeechRecognition;

  /// No description provided for @speechModelSize.
  ///
  /// In en, this message translates to:
  /// **'Model size: ~{size}'**
  String speechModelSize(String size);

  /// No description provided for @speechModelReady.
  ///
  /// In en, this message translates to:
  /// **'Ready · {size}'**
  String speechModelReady(String size);

  /// No description provided for @speechModelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading... {progress}'**
  String speechModelDownloading(String progress);

  /// No description provided for @speechModelDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Tap to retry.'**
  String get speechModelDownloadFailed;

  /// No description provided for @deleteModel.
  ///
  /// In en, this message translates to:
  /// **'Delete Model ({size})'**
  String deleteModel(String size);

  /// No description provided for @deleteModelAction.
  ///
  /// In en, this message translates to:
  /// **'Delete Model'**
  String get deleteModelAction;

  /// No description provided for @deleteModelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Model?'**
  String get deleteModelConfirmTitle;

  /// No description provided for @deleteModelConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will free up {size} of storage space.'**
  String deleteModelConfirmMessage(String size);

  /// No description provided for @disableSpeechRecognitionTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable Speech Recognition?'**
  String get disableSpeechRecognitionTitle;

  /// No description provided for @disableSpeechRecognitionMessage.
  ///
  /// In en, this message translates to:
  /// **'Speech practice scoring will be unavailable.'**
  String get disableSpeechRecognitionMessage;

  /// No description provided for @alsoDeleteModel.
  ///
  /// In en, this message translates to:
  /// **'Also delete downloaded model'**
  String get alsoDeleteModel;

  /// No description provided for @disableAction.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disableAction;

  /// No description provided for @speechRecognitionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech Recognition Model Required'**
  String get speechRecognitionRequiredTitle;

  /// No description provided for @speechRecognitionRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is used to automatically evaluate your read-along and retelling. A model download is required. You can disable this in Settings.'**
  String get speechRecognitionRequiredMessage;

  /// No description provided for @downloadAndEnable.
  ///
  /// In en, this message translates to:
  /// **'Download & Enable'**
  String get downloadAndEnable;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @speechModelRepairTitle.
  ///
  /// In en, this message translates to:
  /// **'Model Download Incomplete'**
  String get speechModelRepairTitle;

  /// No description provided for @speechModelRepairMessage.
  ///
  /// In en, this message translates to:
  /// **'The speech recognition model needs to be re-downloaded to use voice practice.'**
  String get speechModelRepairMessage;

  /// No description provided for @downloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download Now'**
  String get downloadNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @speechRecognitionNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Voice recognition not enabled. Enable in Settings.'**
  String get speechRecognitionNotEnabled;

  /// No description provided for @retryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryDownload;

  /// No description provided for @downloadingSpeechModel.
  ///
  /// In en, this message translates to:
  /// **'Downloading Speech Recognition Model'**
  String get downloadingSpeechModel;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @developerOptionsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Developer options enabled'**
  String get developerOptionsEnabled;

  /// No description provided for @developerOptionsDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable developer options'**
  String get developerOptionsDisable;

  /// No description provided for @timeMachine.
  ///
  /// In en, this message translates to:
  /// **'Time Machine'**
  String get timeMachine;

  /// No description provided for @timeMachineUseSystemTime.
  ///
  /// In en, this message translates to:
  /// **'Using system time'**
  String get timeMachineUseSystemTime;

  /// No description provided for @timeMachineCurrentTime.
  ///
  /// In en, this message translates to:
  /// **'Debug time'**
  String get timeMachineCurrentTime;

  /// No description provided for @timeMachineSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get timeMachineSelectDate;

  /// No description provided for @timeMachineSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get timeMachineSelectTime;

  /// No description provided for @timeMachineReset.
  ///
  /// In en, this message translates to:
  /// **'Use system time'**
  String get timeMachineReset;

  /// No description provided for @manageSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Manage Subtitles'**
  String get manageSubtitles;

  /// No description provided for @localUpload.
  ///
  /// In en, this message translates to:
  /// **'Local Upload'**
  String get localUpload;

  /// No description provided for @aiTranscription.
  ///
  /// In en, this message translates to:
  /// **'AI Transcription'**
  String get aiTranscription;

  /// No description provided for @deleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Subtitle'**
  String get deleteSubtitle;

  /// No description provided for @startTranscription.
  ///
  /// In en, this message translates to:
  /// **'Start Transcription'**
  String get startTranscription;

  /// No description provided for @alreadyTranscribedWithOption.
  ///
  /// In en, this message translates to:
  /// **'Already transcribed with this option'**
  String get alreadyTranscribedWithOption;

  /// No description provided for @transcriptionUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get transcriptionUploading;

  /// No description provided for @transcriptionProcessing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing...'**
  String get transcriptionProcessing;

  /// No description provided for @transcriptionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete!'**
  String get transcriptionComplete;

  /// No description provided for @transcriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed'**
  String get transcriptionFailed;

  /// No description provided for @transcriptionErrorConnection.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to server'**
  String get transcriptionErrorConnection;

  /// No description provided for @transcriptionErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out, please retry'**
  String get transcriptionErrorTimeout;

  /// No description provided for @transcriptionErrorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error, please retry later'**
  String get transcriptionErrorServer;

  /// No description provided for @transcriptionErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get transcriptionErrorUnknown;

  /// No description provided for @transcriptionEmptyResult.
  ///
  /// In en, this message translates to:
  /// **'No speech detected'**
  String get transcriptionEmptyResult;

  /// No description provided for @transcriptionEmptyResultHint.
  ///
  /// In en, this message translates to:
  /// **'The audio may contain too much background noise.'**
  String get transcriptionEmptyResultHint;

  /// No description provided for @transcriptionErrorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large (max {maxMb}MB)'**
  String transcriptionErrorFileTooLarge(int maxMb);

  /// No description provided for @transcriptionErrorTooLong.
  ///
  /// In en, this message translates to:
  /// **'Audio too long (max {maxMin} minutes)'**
  String transcriptionErrorTooLong(int maxMin);

  /// No description provided for @deleteSubtitleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the subtitle?'**
  String get deleteSubtitleConfirm;

  /// No description provided for @deleteSubtitleWarning.
  ///
  /// In en, this message translates to:
  /// **'Deleting the subtitle will also clear all bookmarked sentences and learning progress for this audio.'**
  String get deleteSubtitleWarning;

  /// No description provided for @languageAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto Detect'**
  String get languageAutoDetect;

  /// No description provided for @mixedLanguageNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Mixed language audio is not supported yet'**
  String get mixedLanguageNotSupported;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @overwriteExistingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrite existing subtitle?'**
  String get overwriteExistingSubtitle;

  /// No description provided for @overwriteExistingSubtitleMessage.
  ///
  /// In en, this message translates to:
  /// **'This will replace the current subtitle. Continue?'**
  String get overwriteExistingSubtitleMessage;

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @currentSubtitleExists.
  ///
  /// In en, this message translates to:
  /// **'Current: Has Subtitle'**
  String get currentSubtitleExists;

  /// No description provided for @currentSubtitleLocal.
  ///
  /// In en, this message translates to:
  /// **'Current: Local Upload'**
  String get currentSubtitleLocal;

  /// No description provided for @currentSubtitleAi.
  ///
  /// In en, this message translates to:
  /// **'Current: AI ({language})'**
  String currentSubtitleAi(String language);

  /// No description provided for @noSubtitleYet.
  ///
  /// In en, this message translates to:
  /// **'No subtitle yet'**
  String get noSubtitleYet;

  /// No description provided for @addSubtitlePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Subtitle?'**
  String get addSubtitlePromptTitle;

  /// No description provided for @addSubtitlePromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a subtitle now for learning?'**
  String get addSubtitlePromptMessage;

  /// No description provided for @selectCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection (Optional)'**
  String get selectCollection;

  /// No description provided for @noCollection.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noCollection;

  /// No description provided for @addSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add Subtitle'**
  String get addSubtitle;

  /// No description provided for @retryTranscription.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryTranscription;

  /// No description provided for @transcriptionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String transcriptionFailedMessage(String message);

  /// Today's study time label
  ///
  /// In en, this message translates to:
  /// **'Today: {time}'**
  String todayStudyTime(String time);

  /// Study time in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String studyTimeMinutes(int minutes);

  /// Study time in hours and minutes
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String studyTimeHoursMinutes(int hours, int minutes);

  /// No description provided for @studyTasks.
  ///
  /// In en, this message translates to:
  /// **'Study Tasks'**
  String get studyTasks;

  /// No description provided for @continueLearningHero.
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get continueLearningHero;

  /// No description provided for @startButton.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startButton;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @reviewButton.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewButton;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d streak'**
  String streakDays(int count);

  /// No description provided for @todayStudyTimeShort.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayStudyTimeShort;

  /// No description provided for @weekStudyTimeShort.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weekStudyTimeShort;

  /// No description provided for @readyToReview.
  ///
  /// In en, this message translates to:
  /// **'Ready to Review ({count})'**
  String readyToReview(int count);

  /// No description provided for @upcomingReviews.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Reviews ({count})'**
  String upcomingReviews(int count);

  /// No description provided for @upcomingReviewsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} review tasks will unlock later'**
  String upcomingReviewsSummary(int count);

  /// No description provided for @firstStudySection.
  ///
  /// In en, this message translates to:
  /// **'Initial Learning ({count})'**
  String firstStudySection(int count);

  /// No description provided for @completedSection.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String completedSection(int count);

  /// No description provided for @noStudyTasks.
  ///
  /// In en, this message translates to:
  /// **'No study tasks yet'**
  String get noStudyTasks;

  /// No description provided for @noStudyTasksHint.
  ///
  /// In en, this message translates to:
  /// **'Import audio files to start learning.'**
  String get noStudyTasksHint;

  /// No description provided for @goToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Go to Library'**
  String get goToLibrary;

  /// No description provided for @allDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'All done for now!'**
  String get allDoneTitle;

  /// No description provided for @allDoneHint.
  ///
  /// In en, this message translates to:
  /// **'Great work today. Come back later for reviews.'**
  String get allDoneHint;

  /// No description provided for @overdueDays.
  ///
  /// In en, this message translates to:
  /// **'Due {count}d ago'**
  String overdueDays(int count);

  /// No description provided for @overdueHours.
  ///
  /// In en, this message translates to:
  /// **'Due {count}h ago'**
  String overdueHours(int count);

  /// No description provided for @reviewDue.
  ///
  /// In en, this message translates to:
  /// **'Review due'**
  String get reviewDue;

  /// No description provided for @availableInDays.
  ///
  /// In en, this message translates to:
  /// **'in {count}d'**
  String availableInDays(int count);

  /// No description provided for @availableInHours.
  ///
  /// In en, this message translates to:
  /// **'in {count}h'**
  String availableInHours(int count);

  /// No description provided for @subStageLabelFirstLearn.
  ///
  /// In en, this message translates to:
  /// **'Initial Learning - {subStage}'**
  String subStageLabelFirstLearn(String subStage);

  /// No description provided for @subStageLabelReview.
  ///
  /// In en, this message translates to:
  /// **'{reviewName} - {subStage}'**
  String subStageLabelReview(String reviewName, String subStage);

  /// No description provided for @favoritesSentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences'**
  String get favoritesSentences;

  /// No description provided for @favoritesVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get favoritesVocabulary;

  /// No description provided for @favoritesNoSentences.
  ///
  /// In en, this message translates to:
  /// **'No saved sentences yet'**
  String get favoritesNoSentences;

  /// No description provided for @favoritesNoSentencesHint.
  ///
  /// In en, this message translates to:
  /// **'Mark difficult sentences during intensive listening or shadowing'**
  String get favoritesNoSentencesHint;

  /// No description provided for @favoritesNoVocabulary.
  ///
  /// In en, this message translates to:
  /// **'No saved vocabulary yet'**
  String get favoritesNoVocabulary;

  /// No description provided for @favoritesNoVocabularyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a word during learning to look it up and save it'**
  String get favoritesNoVocabularyHint;

  /// No description provided for @favoritesBookmarkCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sentences'**
  String favoritesBookmarkCount(int count);

  /// No description provided for @favoritesVocabularySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get favoritesVocabularySaved;

  /// No description provided for @favoritesVocabularyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get favoritesVocabularyRemoved;

  /// No description provided for @favoritesBookmarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed'**
  String get favoritesBookmarkRemoved;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @favoritesSaveVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get favoritesSaveVocabulary;

  /// No description provided for @favoritesUnsaveVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get favoritesUnsaveVocabulary;

  /// No description provided for @bookmarkReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmark Review'**
  String get bookmarkReviewTitle;

  /// No description provided for @bookmarkReviewStart.
  ///
  /// In en, this message translates to:
  /// **'Start Review'**
  String get bookmarkReviewStart;

  /// No description provided for @bookmarkReviewStartCount.
  ///
  /// In en, this message translates to:
  /// **'Start Review ({count})'**
  String bookmarkReviewStartCount(int count);

  /// No description provided for @bookmarkReviewComplete.
  ///
  /// In en, this message translates to:
  /// **'Review Complete'**
  String get bookmarkReviewComplete;

  /// No description provided for @bookmarkReviewCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reviewed all {count} bookmarked sentences.'**
  String bookmarkReviewCompleteMessage(int count);

  /// No description provided for @bookmarkReviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Review Again'**
  String get bookmarkReviewAgain;

  /// No description provided for @bookmarkReviewAudioSkipped.
  ///
  /// In en, this message translates to:
  /// **'Audio unavailable, skipping this sentence'**
  String get bookmarkReviewAudioSkipped;

  /// No description provided for @bookmarkReviewFromAudio.
  ///
  /// In en, this message translates to:
  /// **'From: {name}'**
  String bookmarkReviewFromAudio(String name);

  /// No description provided for @difficultPracticeSettings.
  ///
  /// In en, this message translates to:
  /// **'Practice Settings'**
  String get difficultPracticeSettings;

  /// No description provided for @difficultPracticeSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Settings apply to this session only'**
  String get difficultPracticeSettingsHint;

  /// No description provided for @difficultPracticeBlindListenRepeat.
  ///
  /// In en, this message translates to:
  /// **'Blind listen repeats'**
  String get difficultPracticeBlindListenRepeat;

  /// No description provided for @difficultPracticeShadowReadingRepeat.
  ///
  /// In en, this message translates to:
  /// **'Shadow reading repeats'**
  String get difficultPracticeShadowReadingRepeat;

  /// No description provided for @inputWordsShort.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get inputWordsShort;

  /// No description provided for @outputWordsShort.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get outputWordsShort;

  /// No description provided for @listenTimeWords.
  ///
  /// In en, this message translates to:
  /// **'Listen: {time} · {words}'**
  String listenTimeWords(String time, String words);

  /// No description provided for @speakTimeWords.
  ///
  /// In en, this message translates to:
  /// **'Speak: {time} · {words}'**
  String speakTimeWords(String time, String words);

  /// No description provided for @learnedWordFormsShort.
  ///
  /// In en, this message translates to:
  /// **'Vocab'**
  String get learnedWordFormsShort;

  /// No description provided for @todayNewShort.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayNewShort;

  /// No description provided for @learnedWordsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No learned words yet. Finish some listening first.'**
  String get learnedWordsEmptyHint;

  /// No description provided for @learnedWordsSortTimeAsc.
  ///
  /// In en, this message translates to:
  /// **'Oldest Learned'**
  String get learnedWordsSortTimeAsc;

  /// No description provided for @learnedWordsSortTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Recently Learned'**
  String get learnedWordsSortTimeDesc;

  /// No description provided for @bookmarkReviewProgress.
  ///
  /// In en, this message translates to:
  /// **'Sentence {current}/{total}'**
  String bookmarkReviewProgress(int current, int total);

  /// No description provided for @flashcardTitle.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get flashcardTitle;

  /// No description provided for @flashcardViewAnswer.
  ///
  /// In en, this message translates to:
  /// **'Ready? View answer'**
  String get flashcardViewAnswer;

  /// No description provided for @flashcardTapToFlip.
  ///
  /// In en, this message translates to:
  /// **'Tap to flip back'**
  String get flashcardTapToFlip;

  /// No description provided for @flashcardUnsaveHint.
  ///
  /// In en, this message translates to:
  /// **'Unmark when mastered'**
  String get flashcardUnsaveHint;

  /// No description provided for @flashcardProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String flashcardProgress(int current, int total);

  /// No description provided for @flashcardComplete.
  ///
  /// In en, this message translates to:
  /// **'Review Complete'**
  String get flashcardComplete;

  /// No description provided for @flashcardWordsReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed {count} words'**
  String flashcardWordsReviewed(int count);

  /// No description provided for @flashcardWordsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved {count} words'**
  String flashcardWordsRemoved(int count);

  /// No description provided for @flashcardPracticeAgain.
  ///
  /// In en, this message translates to:
  /// **'Practice Again'**
  String get flashcardPracticeAgain;

  /// No description provided for @flashcardFinish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get flashcardFinish;

  /// No description provided for @flashcardSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Card Settings'**
  String get flashcardSettingsTitle;

  /// No description provided for @flashcardSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Settings are saved automatically'**
  String get flashcardSettingsSubtitle;

  /// No description provided for @flashcardControlModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Control Mode'**
  String get flashcardControlModeLabel;

  /// No description provided for @flashcardControlModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get flashcardControlModeAuto;

  /// No description provided for @flashcardControlModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get flashcardControlModeManual;

  /// No description provided for @flashcardControlModeAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto flip, auto advance'**
  String get flashcardControlModeAutoDesc;

  /// No description provided for @flashcardControlModeManualDesc.
  ///
  /// In en, this message translates to:
  /// **'Manual flip, manual advance'**
  String get flashcardControlModeManualDesc;

  /// No description provided for @flashcardTimerMode.
  ///
  /// In en, this message translates to:
  /// **'Card Advance Timer'**
  String get flashcardTimerMode;

  /// No description provided for @flashcardTimerSmart.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get flashcardTimerSmart;

  /// No description provided for @flashcardTimerSmartDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjusts based on word difficulty and practice count'**
  String get flashcardTimerSmartDesc;

  /// No description provided for @flashcardTimerFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get flashcardTimerFixed;

  /// No description provided for @flashcardTimerFixedDesc.
  ///
  /// In en, this message translates to:
  /// **'Set fixed duration for front and back'**
  String get flashcardTimerFixedDesc;

  /// No description provided for @flashcardTimerFrontDuration.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get flashcardTimerFrontDuration;

  /// No description provided for @flashcardTimerBackDuration.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get flashcardTimerBackDuration;

  /// No description provided for @flashcardSortMode.
  ///
  /// In en, this message translates to:
  /// **'Word Sort Order'**
  String get flashcardSortMode;

  /// No description provided for @flashcardSortAlphaAsc.
  ///
  /// In en, this message translates to:
  /// **'A → Z'**
  String get flashcardSortAlphaAsc;

  /// No description provided for @flashcardSortAlphaDesc.
  ///
  /// In en, this message translates to:
  /// **'Z → A'**
  String get flashcardSortAlphaDesc;

  /// No description provided for @flashcardSortTimeAsc.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get flashcardSortTimeAsc;

  /// No description provided for @flashcardSortTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get flashcardSortTimeDesc;

  /// No description provided for @flashcardSortRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get flashcardSortRandom;

  /// No description provided for @flashcardSortSmart.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get flashcardSortSmart;

  /// No description provided for @flashcardSortSmartDesc.
  ///
  /// In en, this message translates to:
  /// **'Order based on memory patterns'**
  String get flashcardSortSmartDesc;

  /// No description provided for @flashcardSortRandomDesc.
  ///
  /// In en, this message translates to:
  /// **'Shuffle randomly each time'**
  String get flashcardSortRandomDesc;

  /// No description provided for @flashcardSortAlphaAscDesc.
  ///
  /// In en, this message translates to:
  /// **'Sort alphabetically A to Z'**
  String get flashcardSortAlphaAscDesc;

  /// No description provided for @flashcardSortAlphaDescDesc.
  ///
  /// In en, this message translates to:
  /// **'Sort alphabetically Z to A'**
  String get flashcardSortAlphaDescDesc;

  /// No description provided for @flashcardSortTimeAscDesc.
  ///
  /// In en, this message translates to:
  /// **'Oldest saved first'**
  String get flashcardSortTimeAscDesc;

  /// No description provided for @flashcardSortTimeDescDesc.
  ///
  /// In en, this message translates to:
  /// **'Newest saved first'**
  String get flashcardSortTimeDescDesc;

  /// No description provided for @flashcardNoDefinition.
  ///
  /// In en, this message translates to:
  /// **'No definition'**
  String get flashcardNoDefinition;

  /// No description provided for @flashcardStartQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start Review'**
  String get flashcardStartQuiz;

  /// No description provided for @flashcardTts.
  ///
  /// In en, this message translates to:
  /// **'Pronounce'**
  String get flashcardTts;

  /// No description provided for @flashcardAutoPlaySentence.
  ///
  /// In en, this message translates to:
  /// **'Auto-play Sentence'**
  String get flashcardAutoPlaySentence;

  /// No description provided for @flashcardAutoPlayWord.
  ///
  /// In en, this message translates to:
  /// **'Auto-play Word'**
  String get flashcardAutoPlayWord;

  /// No description provided for @freePlay.
  ///
  /// In en, this message translates to:
  /// **'Free Play'**
  String get freePlay;

  /// No description provided for @wordAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis'**
  String get wordAiAnalysis;

  /// No description provided for @wordAiContextMeaning.
  ///
  /// In en, this message translates to:
  /// **'Contextual Meaning'**
  String get wordAiContextMeaning;

  /// No description provided for @wordAiCollocations.
  ///
  /// In en, this message translates to:
  /// **'Collocations'**
  String get wordAiCollocations;

  /// No description provided for @wordAiUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage Notes'**
  String get wordAiUsage;

  /// No description provided for @wordAiWordFamily.
  ///
  /// In en, this message translates to:
  /// **'Word Family'**
  String get wordAiWordFamily;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get storage;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @clearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will clear all cached data such as AI translations and analyses. They will be re-fetched when needed. Continue?'**
  String get clearCacheConfirm;

  /// No description provided for @clearCacheSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get clearCacheSuccess;

  /// No description provided for @clearCacheSuccessWithSize.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared, freed {size}'**
  String clearCacheSuccessWithSize(String size);

  /// No description provided for @clearCacheEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cache is already empty'**
  String get clearCacheEmpty;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @autoCompletedNoDifficult.
  ///
  /// In en, this message translates to:
  /// **'0 difficult sentences, skipped'**
  String get autoCompletedNoDifficult;

  /// No description provided for @autoCompletedNoDifficultReview.
  ///
  /// In en, this message translates to:
  /// **'0 difficult sentences, skipped'**
  String get autoCompletedNoDifficultReview;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @writeFeedback.
  ///
  /// In en, this message translates to:
  /// **'Write Feedback'**
  String get writeFeedback;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'New Version v{version}'**
  String updateAvailable(String version);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @forceUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get forceUpdateTitle;

  /// No description provided for @forceUpdateMessage.
  ///
  /// In en, this message translates to:
  /// **'Your current version is no longer supported. Please update to continue.'**
  String get forceUpdateMessage;

  /// No description provided for @copyDownloadLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Download Link'**
  String get copyDownloadLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @checkForUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdate;

  /// No description provided for @alreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get alreadyLatest;

  /// No description provided for @checkUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed, please check your network'**
  String get checkUpdateFailed;

  /// No description provided for @demoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo Mode'**
  String get demoMode;

  /// No description provided for @demoModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use demo data for screenshots and presentations'**
  String get demoModeSubtitle;

  /// No description provided for @practiceRemoveMark.
  ///
  /// In en, this message translates to:
  /// **'Unmark'**
  String get practiceRemoveMark;

  /// No description provided for @practiceAddMark.
  ///
  /// In en, this message translates to:
  /// **'Re-mark'**
  String get practiceAddMark;

  /// No description provided for @blindListenSegmentProgress.
  ///
  /// In en, this message translates to:
  /// **'Paragraph {current}/{total}'**
  String blindListenSegmentProgress(int current, int total);

  /// No description provided for @blindListenSegmentDuration.
  ///
  /// In en, this message translates to:
  /// **'{duration}s'**
  String blindListenSegmentDuration(int duration);

  /// No description provided for @blindListenListeningHint.
  ///
  /// In en, this message translates to:
  /// **'Listen carefully...'**
  String get blindListenListeningHint;

  /// No description provided for @blindListenPreListenHint.
  ///
  /// In en, this message translates to:
  /// **'Listen first, then recall'**
  String get blindListenPreListenHint;

  /// No description provided for @blindListenRepeatInfo.
  ///
  /// In en, this message translates to:
  /// **'Round {current}/{total}'**
  String blindListenRepeatInfo(int current, int total);

  /// No description provided for @blindListenSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Listening Settings'**
  String get blindListenSettingsTitle;

  /// No description provided for @blindListenPauseBetween.
  ///
  /// In en, this message translates to:
  /// **'Pause between paragraphs'**
  String get blindListenPauseBetween;

  /// No description provided for @blindListenTargetDuration.
  ///
  /// In en, this message translates to:
  /// **'Paragraph duration'**
  String get blindListenTargetDuration;

  /// No description provided for @blindListenDisplayHideAll.
  ///
  /// In en, this message translates to:
  /// **'Hide Subtitles'**
  String get blindListenDisplayHideAll;

  /// No description provided for @blindListenDisplayShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show Subtitles'**
  String get blindListenDisplayShowAll;

  /// No description provided for @blindListenRecallHint.
  ///
  /// In en, this message translates to:
  /// **'Try to recall what you just heard'**
  String get blindListenRecallHint;

  /// No description provided for @blindListenControlModeAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-repeat, auto-pause, auto-next'**
  String get blindListenControlModeAutoDesc;

  /// No description provided for @blindListenControlModeManualDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap to replay, tap next'**
  String get blindListenControlModeManualDesc;

  /// No description provided for @blindListenNoParagraph.
  ///
  /// In en, this message translates to:
  /// **'No split'**
  String get blindListenNoParagraph;

  /// No description provided for @blindListenParagraphCount.
  ///
  /// In en, this message translates to:
  /// **'{count} paragraphs'**
  String blindListenParagraphCount(int count);

  /// No description provided for @resetLearningProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset Progress'**
  String get resetLearningProgress;

  /// No description provided for @resetLearningProgressConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Learning Progress?'**
  String get resetLearningProgressConfirmTitle;

  /// No description provided for @resetLearningProgressConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will clear all learning progress for \"{name}\". This action cannot be undone.'**
  String resetLearningProgressConfirmMessage(String name);

  /// No description provided for @resetLearningProgressDone.
  ///
  /// In en, this message translates to:
  /// **'Learning progress has been reset'**
  String get resetLearningProgressDone;

  /// No description provided for @reviewReminderBody.
  ///
  /// In en, this message translates to:
  /// **'{audioName} · Review round {round} is ready'**
  String reviewReminderBody(String audioName, int round);

  /// No description provided for @stageBlindListen.
  ///
  /// In en, this message translates to:
  /// **'Blind Listen'**
  String get stageBlindListen;

  /// No description provided for @stageIntensiveListen.
  ///
  /// In en, this message translates to:
  /// **'Intensive Listen'**
  String get stageIntensiveListen;

  /// No description provided for @stageListenAndRepeat.
  ///
  /// In en, this message translates to:
  /// **'Shadowing'**
  String get stageListenAndRepeat;

  /// No description provided for @stageRetell.
  ///
  /// In en, this message translates to:
  /// **'Retelling'**
  String get stageRetell;

  /// No description provided for @stageReviewDifficultPractice.
  ///
  /// In en, this message translates to:
  /// **'Difficult Drill'**
  String get stageReviewDifficultPractice;

  /// No description provided for @stageBookmarkReview.
  ///
  /// In en, this message translates to:
  /// **'Sentence Review'**
  String get stageBookmarkReview;

  /// No description provided for @stageFlashcard.
  ///
  /// In en, this message translates to:
  /// **'Word Review'**
  String get stageFlashcard;

  /// No description provided for @stageBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String stageBreakdownTitle(String date);

  /// No description provided for @stageBreakdownToday.
  ///
  /// In en, this message translates to:
  /// **' (Today)'**
  String get stageBreakdownToday;

  /// No description provided for @stageBreakdownTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get stageBreakdownTotal;

  /// No description provided for @stageBreakdownLessThanOneMin.
  ///
  /// In en, this message translates to:
  /// **'<1m'**
  String get stageBreakdownLessThanOneMin;

  /// No description provided for @stageBreakdownListenShort.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get stageBreakdownListenShort;

  /// No description provided for @stageBreakdownSpeakShort.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get stageBreakdownSpeakShort;

  /// No description provided for @stageBreakdownNoStageData.
  ///
  /// In en, this message translates to:
  /// **'Detailed breakdown data starts recording from this version'**
  String get stageBreakdownNoStageData;

  /// No description provided for @stageBreakdownNoRecord.
  ///
  /// In en, this message translates to:
  /// **'No study record for this day'**
  String get stageBreakdownNoRecord;

  /// No description provided for @chartLegendListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get chartLegendListening;

  /// No description provided for @chartLegendSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get chartLegendSpeaking;

  /// No description provided for @chartLegendOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get chartLegendOther;

  /// No description provided for @chartLegendOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Thinking, pauses, etc.'**
  String get chartLegendOtherHint;

  /// No description provided for @reminderSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminderSectionTitle;

  /// No description provided for @reminderSettings.
  ///
  /// In en, this message translates to:
  /// **'Review Reminder'**
  String get reminderSettings;

  /// No description provided for @savedReviewReminderSection.
  ///
  /// In en, this message translates to:
  /// **'Saved Review Reminder'**
  String get savedReviewReminderSection;

  /// No description provided for @savedReviewReminderToggle.
  ///
  /// In en, this message translates to:
  /// **'Saved Content Reminder'**
  String get savedReviewReminderToggle;

  /// No description provided for @savedReviewReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder Time'**
  String get savedReviewReminderTime;

  /// No description provided for @savedReviewReminderDescription.
  ///
  /// In en, this message translates to:
  /// **'Review saved content during commute or before bed for best results'**
  String get savedReviewReminderDescription;

  /// No description provided for @audioReviewReminderSection.
  ///
  /// In en, this message translates to:
  /// **'Audio Review Reminder'**
  String get audioReviewReminderSection;

  /// No description provided for @audioReviewReminderToggle.
  ///
  /// In en, this message translates to:
  /// **'Audio Due Reminder'**
  String get audioReviewReminderToggle;

  /// No description provided for @audioReviewReminderDescription.
  ///
  /// In en, this message translates to:
  /// **'Get notified when it\'s time to review, helping you stay on track'**
  String get audioReviewReminderDescription;

  /// No description provided for @recentCompletions.
  ///
  /// In en, this message translates to:
  /// **'Recently Completed ({count})'**
  String recentCompletions(int count);

  /// No description provided for @recentCompletionsSummary.
  ///
  /// In en, this message translates to:
  /// **'Past 24 hours'**
  String get recentCompletionsSummary;

  /// No description provided for @timeAgoJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeAgoJustNow;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeAgoMinutes(int minutes);

  /// No description provided for @timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeAgoHours(int hours);

  /// No description provided for @exportAudio.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportAudio;

  /// No description provided for @exportAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get exportAudioFile;

  /// No description provided for @exportSubtitleFile.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get exportSubtitleFile;

  /// No description provided for @exportSelectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select files to export'**
  String get exportSelectFiles;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export all data to a ZIP file'**
  String get exportDataSubtitle;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @importDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore data from a backup file'**
  String get importDataSubtitle;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exporting;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get importing;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export complete'**
  String get exportSuccess;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get importSuccess;

  /// No description provided for @importConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get importConfirmTitle;

  /// No description provided for @importConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will replace all current data including learning progress, favorites, and audio files. This action cannot be undone.'**
  String get importConfirmMessage;

  /// No description provided for @backupTime.
  ///
  /// In en, this message translates to:
  /// **'Backup time'**
  String get backupTime;

  /// No description provided for @backupVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get backupVersion;

  /// No description provided for @backupFileCount.
  ///
  /// In en, this message translates to:
  /// **'Media files'**
  String get backupFileCount;

  /// No description provided for @backupSize.
  ///
  /// In en, this message translates to:
  /// **'Total size'**
  String get backupSize;

  /// No description provided for @importIncompatible.
  ///
  /// In en, this message translates to:
  /// **'This backup was created with a newer version of the app. Please update the app first.'**
  String get importIncompatible;

  /// No description provided for @importInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file'**
  String get importInvalidFile;

  /// No description provided for @exportingDatabase.
  ///
  /// In en, this message translates to:
  /// **'Exporting database...'**
  String get exportingDatabase;

  /// No description provided for @exportingPreferences.
  ///
  /// In en, this message translates to:
  /// **'Exporting preferences...'**
  String get exportingPreferences;

  /// No description provided for @exportingMedia.
  ///
  /// In en, this message translates to:
  /// **'Exporting media files...'**
  String get exportingMedia;

  /// No description provided for @exportingPacking.
  ///
  /// In en, this message translates to:
  /// **'Packing backup file...'**
  String get exportingPacking;

  /// No description provided for @importingExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting backup...'**
  String get importingExtracting;

  /// No description provided for @importingMedia.
  ///
  /// In en, this message translates to:
  /// **'Restoring media files...'**
  String get importingMedia;

  /// No description provided for @importingDatabase.
  ///
  /// In en, this message translates to:
  /// **'Restoring database...'**
  String get importingDatabase;

  /// No description provided for @importingPreferences.
  ///
  /// In en, this message translates to:
  /// **'Restoring preferences...'**
  String get importingPreferences;

  /// No description provided for @activityCalendar.
  ///
  /// In en, this message translates to:
  /// **'Activity Calendar'**
  String get activityCalendar;

  /// No description provided for @noActivityThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No learning activity this month'**
  String get noActivityThisMonth;

  /// No description provided for @monthlySummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'{month} Stats'**
  String monthlySummaryTitle(String month);

  /// No description provided for @monthlyTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get monthlyTotal;

  /// No description provided for @monthlyActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get monthlyActiveDays;

  /// No description provided for @monthlyAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg/day'**
  String get monthlyAvgPerDay;

  /// No description provided for @monthlyBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best streak'**
  String get monthlyBestStreak;

  /// No description provided for @daysSuffix.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String daysSuffix(int days);

  /// No description provided for @activeDaysFraction.
  ///
  /// In en, this message translates to:
  /// **'{active}/{total} days'**
  String activeDaysFraction(int active, int total);

  /// No description provided for @senseGroupSplit.
  ///
  /// In en, this message translates to:
  /// **'Split into Groups'**
  String get senseGroupSplit;

  /// No description provided for @senseGroupLoading.
  ///
  /// In en, this message translates to:
  /// **'Splitting...'**
  String get senseGroupLoading;

  /// No description provided for @senseGroupSingleGroup.
  ///
  /// In en, this message translates to:
  /// **'This sentence is a single group'**
  String get senseGroupSingleGroup;

  /// No description provided for @senseGroupSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get senseGroupSave;

  /// No description provided for @senseGroupSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get senseGroupSaved;

  /// No description provided for @annotationBtnSenseGroup.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get annotationBtnSenseGroup;

  /// No description provided for @annotationBtnSenseGroupMedium.
  ///
  /// In en, this message translates to:
  /// **'Larger Groups'**
  String get annotationBtnSenseGroupMedium;

  /// No description provided for @annotationBtnSenseGroupFine.
  ///
  /// In en, this message translates to:
  /// **'Smaller Groups'**
  String get annotationBtnSenseGroupFine;

  /// No description provided for @annotationBtnTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get annotationBtnTranslation;

  /// No description provided for @annotationBtnAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get annotationBtnAnalysis;

  /// No description provided for @senseGroupLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Sense group splitting failed, please retry'**
  String get senseGroupLoadFailed;

  /// No description provided for @senseGroupNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Only available for AI-transcribed audio'**
  String get senseGroupNotAvailable;

  /// No description provided for @wordTimestampsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Word-level timestamps not found. Please restart the app to retry.'**
  String get wordTimestampsNotFound;

  /// No description provided for @recycleBinTitle.
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin'**
  String get recycleBinTitle;

  /// No description provided for @recycleBinEmpty.
  ///
  /// In en, this message translates to:
  /// **'No removed items'**
  String get recycleBinEmpty;

  /// No description provided for @recycleBinClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get recycleBinClearAll;

  /// No description provided for @recycleBinClearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all {count} items? This cannot be undone.'**
  String recycleBinClearAllConfirm(int count);

  /// No description provided for @recycleBinRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get recycleBinRestore;

  /// No description provided for @recycleBinDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get recycleBinDelete;

  /// No description provided for @recycleBinSortTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Recently Removed'**
  String get recycleBinSortTimeDesc;

  /// No description provided for @recycleBinSortTimeAsc.
  ///
  /// In en, this message translates to:
  /// **'Oldest Removed'**
  String get recycleBinSortTimeAsc;

  /// No description provided for @recycleBinItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String recycleBinItemCount(int count);

  /// No description provided for @filesSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} files selected'**
  String filesSelected(int count);

  /// No description provided for @processingFileOf.
  ///
  /// In en, this message translates to:
  /// **'Processing {current} of {total}...'**
  String processingFileOf(int current, int total);

  /// No description provided for @multipleAudioAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} audio files added'**
  String multipleAudioAdded(int count);

  /// No description provided for @duplicatesSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count} duplicates'**
  String duplicatesSkipped(int count);

  /// No description provided for @duplicatesSkippedDetail.
  ///
  /// In en, this message translates to:
  /// **'The following audio files already exist in the library and were skipped:'**
  String get duplicatesSkippedDetail;

  /// No description provided for @removeFile.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeFile;

  /// No description provided for @goToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get goToSettings;

  /// No description provided for @dictionaryDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading dictionary...'**
  String get dictionaryDownloading;

  /// No description provided for @dictionaryDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Dictionary download failed'**
  String get dictionaryDownloadFailed;

  /// No description provided for @dictionaryNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Dictionary not yet downloaded'**
  String get dictionaryNotDownloaded;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @guideNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get guideNext;

  /// No description provided for @guideDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get guideDone;

  /// No description provided for @guideLibraryCollectionListDescription.
  ///
  /// In en, this message translates to:
  /// **'This is your collection list. Collections let you categorize audio by topic — tap any collection to see the audio inside.'**
  String get guideLibraryCollectionListDescription;

  /// No description provided for @guideLibraryCollectionMenuDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to pin, rename, or delete this collection.'**
  String get guideLibraryCollectionMenuDescription;

  /// No description provided for @guideLibraryCreateCollectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to create a new collection.'**
  String get guideLibraryCreateCollectionDescription;

  /// No description provided for @guideCollectionAudioListDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap any audio to view its learning plan and current progress.'**
  String get guideCollectionAudioListDescription;

  /// No description provided for @guideCollectionAudioMenuDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to manage this audio\'s subtitles, collection, tags, and more.'**
  String get guideCollectionAudioMenuDescription;

  /// No description provided for @guideCollectionUploadDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to upload your own audio.'**
  String get guideCollectionUploadDescription;

  /// No description provided for @guidePlanAddSubtitleTitle.
  ///
  /// In en, this message translates to:
  /// **'Add subtitles'**
  String get guidePlanAddSubtitleTitle;

  /// No description provided for @guidePlanAddSubtitleDescription.
  ///
  /// In en, this message translates to:
  /// **'Generate subtitles with AI in one tap, or upload a local subtitle file. You can start learning this audio right after.'**
  String get guidePlanAddSubtitleDescription;

  /// No description provided for @guidePlanAiTranscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Use AI transcription'**
  String get guidePlanAiTranscriptionTitle;

  /// No description provided for @guidePlanAiTranscriptionDescription.
  ///
  /// In en, this message translates to:
  /// **'If you do not have a subtitle file, AI transcription is the fastest way.'**
  String get guidePlanAiTranscriptionDescription;

  /// No description provided for @guidePlanStartTranscriptionDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to let AI generate subtitles for this audio.'**
  String get guidePlanStartTranscriptionDescription;

  /// No description provided for @guidePlanFreePlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Free Practice'**
  String get guidePlanFreePlayTitle;

  /// No description provided for @guidePlanFreePlayDescription.
  ///
  /// In en, this message translates to:
  /// **'A flexible, all-in-one audio player for free practice. Learn at your own pace.'**
  String get guidePlanFreePlayDescription;

  /// No description provided for @guidePlanStartLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow the plan'**
  String get guidePlanStartLearningTitle;

  /// No description provided for @guidePlanStartLearningDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to follow the learning plan step by step. Echo Loop will guide you and remind you to review at the right time.'**
  String get guidePlanStartLearningDescription;

  /// No description provided for @learningProgressLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load learning progress. Please try again later.'**
  String get learningProgressLoadFailed;

  /// No description provided for @guideMainShellVisitLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Start from Library'**
  String get guideMainShellVisitLibraryTitle;

  /// No description provided for @guideMainShellVisitLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to learn how to use this app.'**
  String get guideMainShellVisitLibraryDescription;

  /// No description provided for @guideStudyTasksOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Your study tasks'**
  String get guideStudyTasksOverviewTitle;

  /// No description provided for @guideStudyTasksOverviewDescription.
  ///
  /// In en, this message translates to:
  /// **'This area includes new audio to learn, due reviews, completed tasks, and more. Echo Loop will pace your learning for you.'**
  String get guideStudyTasksOverviewDescription;

  /// No description provided for @guideStudyStatsHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Today at a glance'**
  String get guideStudyStatsHeaderTitle;

  /// No description provided for @guideStudyStatsHeaderDescription.
  ///
  /// In en, this message translates to:
  /// **'Your listening time, speaking practice time, and new vocabulary for today are all summarized here. Tap a card or bar for a more detailed breakdown.'**
  String get guideStudyStatsHeaderDescription;

  /// No description provided for @guideStudyStreakDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to open your activity calendar. Check in every day and build a steady learning habit.'**
  String get guideStudyStreakDescription;

  /// No description provided for @guideFavoritesSentencesListDescription.
  ///
  /// In en, this message translates to:
  /// **'Your saved sentences, grouped by source audio. Tap {dumbbellIcon} to review every saved sentence from that audio at once.'**
  String guideFavoritesSentencesListDescription(String dumbbellIcon);

  /// No description provided for @guideFavoritesSentencesReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to review every saved sentence at once.'**
  String get guideFavoritesSentencesReviewDescription;

  /// No description provided for @guideFavoritesVocabularyListDescription.
  ///
  /// In en, this message translates to:
  /// **'Your saved words and phrases. Expand a card to see definitions and hear how they sound in the original sentences.'**
  String get guideFavoritesVocabularyListDescription;

  /// No description provided for @guideFavoritesFlashcardDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here to enter flashcard mode and review every saved word. Seeing the word and hearing it in context makes memory stick.'**
  String get guideFavoritesFlashcardDescription;

  /// No description provided for @guideIntensiveListenCantUnderstandDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap here when a sentence is hard to follow. It will be auto-marked as difficult and you\'ll enter single-sentence analysis mode.'**
  String get guideIntensiveListenCantUnderstandDescription;

  /// No description provided for @guideSentenceAnnotationSentenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap any word to open the dictionary; long-press the sentence to copy the text.'**
  String get guideSentenceAnnotationSentenceDescription;

  /// No description provided for @guideSentenceAnnotationSenseGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'Break the sentence into sense groups to make long, complex lines easier to follow.'**
  String get guideSentenceAnnotationSenseGroupDescription;

  /// No description provided for @guideSentenceAnnotationTranslationDescription.
  ///
  /// In en, this message translates to:
  /// **'Translate this sentence into your native language.'**
  String get guideSentenceAnnotationTranslationDescription;

  /// No description provided for @guideSentenceAnnotationAnalysisDescription.
  ///
  /// In en, this message translates to:
  /// **'Check the grammar, key phrases and listening tips for this sentence.'**
  String get guideSentenceAnnotationAnalysisDescription;

  /// No description provided for @resetNewUserGuide.
  ///
  /// In en, this message translates to:
  /// **'Reset New User Guide'**
  String get resetNewUserGuide;

  /// No description provided for @resetNewUserGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all guide seen states for testing'**
  String get resetNewUserGuideSubtitle;

  /// No description provided for @resetNewUserGuideDone.
  ///
  /// In en, this message translates to:
  /// **'New user guide has been reset'**
  String get resetNewUserGuideDone;

  /// No description provided for @resetOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Reset Onboarding Survey'**
  String get resetOnboarding;

  /// No description provided for @resetOnboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Onboarding reset; please restart the app to retake the survey'**
  String get resetOnboardingDone;

  /// No description provided for @discoverOfficialCollections.
  ///
  /// In en, this message translates to:
  /// **'Discover Curated Collections'**
  String get discoverOfficialCollections;

  /// No description provided for @discoverEmpty.
  ///
  /// In en, this message translates to:
  /// **'No curated collections yet'**
  String get discoverEmpty;

  /// No description provided for @discoverLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load, tap to retry'**
  String get discoverLoadFailed;

  /// No description provided for @discoverRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get discoverRetry;

  /// No description provided for @officialBadge.
  ///
  /// In en, this message translates to:
  /// **'Curated'**
  String get officialBadge;

  /// No description provided for @officialDeprecatedBadge.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get officialDeprecatedBadge;

  /// No description provided for @addToMyCollections.
  ///
  /// In en, this message translates to:
  /// **'Add to My Collections'**
  String get addToMyCollections;

  /// No description provided for @goLearn.
  ///
  /// In en, this message translates to:
  /// **'Go Learn'**
  String get goLearn;

  /// No description provided for @removeFromMyCollections.
  ///
  /// In en, this message translates to:
  /// **'Remove from My Collections'**
  String get removeFromMyCollections;

  /// No description provided for @enrollNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Collection First'**
  String get enrollNeededTitle;

  /// No description provided for @enrollNeededMessage.
  ///
  /// In en, this message translates to:
  /// **'Add this collection to your library, then you can start learning.'**
  String get enrollNeededMessage;

  /// No description provided for @enrollSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Added to My Collections'**
  String get enrollSucceeded;

  /// No description provided for @enrollFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add, please check your network and retry'**
  String get enrollFailed;

  /// No description provided for @removeOfficialConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"?'**
  String removeOfficialConfirmTitle(String name);

  /// No description provided for @removeOfficialConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'All audios, subtitles, and learning records in this collection will be deleted. This cannot be undone.'**
  String get removeOfficialConfirmMessage;

  /// No description provided for @removeOfficialConfirmConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeOfficialConfirmConfirm;

  /// No description provided for @officialCollectionDeprecated.
  ///
  /// In en, this message translates to:
  /// **'This collection has been removed by the publisher. Your local copy remains available.'**
  String get officialCollectionDeprecated;

  /// No description provided for @preparingLearningMaterial.
  ///
  /// In en, this message translates to:
  /// **'Preparing Learning Material'**
  String get preparingLearningMaterial;

  /// No description provided for @downloadingAudioAndSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading audio and subtitle...'**
  String get downloadingAudioAndSubtitle;

  /// No description provided for @downloadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Download'**
  String get downloadCancel;

  /// No description provided for @downloadLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get downloadLater;

  /// No description provided for @downloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'{name} downloaded'**
  String downloadCompleted(String name);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'{name} download failed, please retry'**
  String downloadFailed(String name);

  /// No description provided for @updateOfficialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update Subtitle'**
  String get updateOfficialSubtitle;

  /// No description provided for @updateOfficialSubtitleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Update subtitle?'**
  String get updateOfficialSubtitleConfirm;

  /// No description provided for @updateOfficialSubtitleWarning.
  ///
  /// In en, this message translates to:
  /// **'Updating the subtitle will replace the local subtitle and clear all bookmarked sentences and learning progress for this audio.'**
  String get updateOfficialSubtitleWarning;

  /// No description provided for @officialSubtitleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Subtitle updated'**
  String get officialSubtitleUpdated;

  /// No description provided for @officialSubtitleUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Subtitle update failed, please retry'**
  String get officialSubtitleUpdateFailed;

  /// No description provided for @downloadInProgressSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Downloading {name}, please wait'**
  String downloadInProgressSnackbar(String name);

  /// No description provided for @downloadLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get downloadLoading;

  /// No description provided for @audioListColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get audioListColumnName;

  /// No description provided for @audioListColumnDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get audioListColumnDuration;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick chat'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'10 seconds to tailor your practice'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingExamPrompt.
  ///
  /// In en, this message translates to:
  /// **'Which exam are you currently preparing for?'**
  String get onboardingExamPrompt;

  /// No description provided for @onboardingExamGaokao.
  ///
  /// In en, this message translates to:
  /// **'Gaokao'**
  String get onboardingExamGaokao;

  /// No description provided for @onboardingExamCet.
  ///
  /// In en, this message translates to:
  /// **'CET-4 / CET-6'**
  String get onboardingExamCet;

  /// No description provided for @onboardingExamTem.
  ///
  /// In en, this message translates to:
  /// **'TEM-4 / TEM-8'**
  String get onboardingExamTem;

  /// No description provided for @onboardingExamIelts.
  ///
  /// In en, this message translates to:
  /// **'IELTS'**
  String get onboardingExamIelts;

  /// No description provided for @onboardingExamToefl.
  ///
  /// In en, this message translates to:
  /// **'TOEFL'**
  String get onboardingExamToefl;

  /// No description provided for @onboardingExamOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get onboardingExamOther;

  /// No description provided for @onboardingProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String onboardingProgress(int current, int total);

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get onboardingDone;

  /// No description provided for @onboardingFinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get onboardingFinishedTitle;

  /// No description provided for @onboardingFinishedHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tailor practice to your goals and pace.'**
  String get onboardingFinishedHint;

  /// No description provided for @onboardingSummaryEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Did you know?'**
  String get onboardingSummaryEyebrow;

  /// No description provided for @onboardingSummaryHeadline.
  ///
  /// In en, this message translates to:
  /// **'Improving listening & speaking\nisn\'t about hearing more,\nit\'s about practicing deeper.'**
  String get onboardingSummaryHeadline;

  /// No description provided for @onboardingSummaryPoint1.
  ///
  /// In en, this message translates to:
  /// **'Drill on audio that matches your level'**
  String get onboardingSummaryPoint1;

  /// No description provided for @onboardingSummaryPoint2.
  ///
  /// In en, this message translates to:
  /// **'Read in sense groups, learn words in context'**
  String get onboardingSummaryPoint2;

  /// No description provided for @onboardingSummaryPoint3.
  ///
  /// In en, this message translates to:
  /// **'Build input and intuition through intensive listening and shadowing'**
  String get onboardingSummaryPoint3;

  /// No description provided for @onboardingSummaryPoint4.
  ///
  /// In en, this message translates to:
  /// **'Practice speaking through retelling, turning comprehension into output'**
  String get onboardingSummaryPoint4;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start learning'**
  String get onboardingStart;

  /// No description provided for @onboardingQ1Prompt.
  ///
  /// In en, this message translates to:
  /// **'What\'s your main goal for English listening & speaking practice?'**
  String get onboardingQ1Prompt;

  /// No description provided for @onboardingQ1OptionExam.
  ///
  /// In en, this message translates to:
  /// **'For an exam'**
  String get onboardingQ1OptionExam;

  /// No description provided for @onboardingQ1OptionDaily.
  ///
  /// In en, this message translates to:
  /// **'Everyday conversation'**
  String get onboardingQ1OptionDaily;

  /// No description provided for @onboardingQ1OptionWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get onboardingQ1OptionWork;

  /// No description provided for @onboardingQ1OptionTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel abroad'**
  String get onboardingQ1OptionTravel;

  /// No description provided for @onboardingQ1OptionContent.
  ///
  /// In en, this message translates to:
  /// **'Understanding videos & podcasts'**
  String get onboardingQ1OptionContent;

  /// No description provided for @onboardingQ1OptionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get onboardingQ1OptionOther;

  /// No description provided for @onboardingQ2Prompt.
  ///
  /// In en, this message translates to:
  /// **'How long do you plan to practice each day?'**
  String get onboardingQ2Prompt;

  /// No description provided for @onboardingQ2Option5.
  ///
  /// In en, this message translates to:
  /// **'About 5 min'**
  String get onboardingQ2Option5;

  /// No description provided for @onboardingQ2Option10.
  ///
  /// In en, this message translates to:
  /// **'About 10 min'**
  String get onboardingQ2Option10;

  /// No description provided for @onboardingQ2Option20.
  ///
  /// In en, this message translates to:
  /// **'About 20 min'**
  String get onboardingQ2Option20;

  /// No description provided for @onboardingQ2Option30.
  ///
  /// In en, this message translates to:
  /// **'30 min or more'**
  String get onboardingQ2Option30;

  /// No description provided for @onboardingQ2OptionFlexible.
  ///
  /// In en, this message translates to:
  /// **'It varies'**
  String get onboardingQ2OptionFlexible;

  /// No description provided for @onboardingPermissionsHint.
  ///
  /// In en, this message translates to:
  /// **'To ensure the best experience, we\'ll request these permissions'**
  String get onboardingPermissionsHint;

  /// No description provided for @onboardingPermissionsNotification.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get onboardingPermissionsNotification;

  /// No description provided for @onboardingPermissionsMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get onboardingPermissionsMicrophone;

  /// No description provided for @onboardingPermissionsSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get onboardingPermissionsSpeech;

  /// No description provided for @playbackSection.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playbackSection;

  /// No description provided for @learningSection.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get learningSection;

  /// No description provided for @learningSettings.
  ///
  /// In en, this message translates to:
  /// **'Study Plan'**
  String get learningSettings;

  /// No description provided for @speakingPracticeSection.
  ///
  /// In en, this message translates to:
  /// **'Speaking practice'**
  String get speakingPracticeSection;

  /// No description provided for @autoSkipRetellToggle.
  ///
  /// In en, this message translates to:
  /// **'Auto-skip speaking practice'**
  String get autoSkipRetellToggle;

  /// No description provided for @autoSkipRetellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-skip speaking tasks in your learning plan'**
  String get autoSkipRetellSubtitle;

  /// No description provided for @autoSkipRetellDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, speaking practice tasks are auto-marked as skipped; you can complete them anytime in free practice.'**
  String get autoSkipRetellDescription;

  /// No description provided for @retellSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get retellSkip;

  /// No description provided for @retellSkippedSuffix.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get retellSkippedSuffix;

  /// No description provided for @skipSilenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-skip Silence'**
  String get skipSilenceTitle;

  /// No description provided for @skipSilenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Skip long silent gaps between sentences'**
  String get skipSilenceDescription;

  /// No description provided for @silenceThreshold.
  ///
  /// In en, this message translates to:
  /// **'Silence Threshold'**
  String get silenceThreshold;

  /// No description provided for @silenceThresholdValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String silenceThresholdValue(int seconds);

  /// No description provided for @silenceSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped {seconds}s of silence part'**
  String silenceSkipped(int seconds);

  /// No description provided for @speechPermDialogTitleRequest.
  ///
  /// In en, this message translates to:
  /// **'Permissions Required'**
  String get speechPermDialogTitleRequest;

  /// No description provided for @speechPermDialogTitleDenied.
  ///
  /// In en, this message translates to:
  /// **'Permissions Denied'**
  String get speechPermDialogTitleDenied;

  /// No description provided for @speechPermDialogTitleRestricted.
  ///
  /// In en, this message translates to:
  /// **'Device Restricted'**
  String get speechPermDialogTitleRestricted;

  /// No description provided for @speechPermItemMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get speechPermItemMic;

  /// No description provided for @speechPermItemMicDesc.
  ///
  /// In en, this message translates to:
  /// **'Record your speech for pronunciation scoring'**
  String get speechPermItemMicDesc;

  /// No description provided for @speechPermItemSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech Recognition'**
  String get speechPermItemSpeech;

  /// No description provided for @speechPermItemSpeechDesc.
  ///
  /// In en, this message translates to:
  /// **'Detect mispronounced words'**
  String get speechPermItemSpeechDesc;

  /// No description provided for @speechPermStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Not granted'**
  String get speechPermStatusPending;

  /// No description provided for @speechPermStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get speechPermStatusDenied;

  /// No description provided for @speechPermDeniedHint.
  ///
  /// In en, this message translates to:
  /// **'You previously denied access. Please enable it in System Settings.'**
  String get speechPermDeniedHint;

  /// No description provided for @speechPermRestrictedHint.
  ///
  /// In en, this message translates to:
  /// **'Recording is restricted on this device by parental controls or MDM.'**
  String get speechPermRestrictedHint;

  /// No description provided for @speechPermActionGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get speechPermActionGrant;

  /// No description provided for @speechPermActionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get speechPermActionOpenSettings;

  /// No description provided for @speechPermUnsupportedToast.
  ///
  /// In en, this message translates to:
  /// **'Recording is not supported on this platform'**
  String get speechPermUnsupportedToast;
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
