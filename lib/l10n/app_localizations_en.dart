// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Echo Loop';

  @override
  String get premiumTitle => 'Echo Loop Premium';

  @override
  String get premiumTagline => 'Unlock more AI-powered features';

  @override
  String get aiQuotaExceededTitle => 'You\'ve reached your free monthly limit';

  @override
  String get aiQuotaExceededMessage =>
      'Upgrade for more AI access and features.';

  @override
  String get aiQuotaExceededCta => 'Upgrade to Premium';

  @override
  String get aiQuotaExceededDismiss => 'Got it';

  @override
  String get aiQuotaExceededSubscribe => 'Upgrade Now';

  @override
  String get premiumEntryTitle => 'Subscription';

  @override
  String get premiumUnavailableOnPlatform =>
      'Subscriptions are not yet available on this platform';

  @override
  String get premiumEntryBadgeActive => 'Premium';

  @override
  String get premiumEntryBadgeUpgrade => 'Upgrade';

  @override
  String get premiumActive => 'You\'re already on the Premium plan.';

  @override
  String get premiumBenefitTranslation => 'More AI translations';

  @override
  String get premiumBenefitAnalysis => 'More AI sentence analysis';

  @override
  String get premiumBenefitWordAnalysis =>
      'More AI word and phrase explanation';

  @override
  String get premiumBenefitTranscription => 'More AI subtitle transcriptions';

  @override
  String get premiumBenefitAiAssistant => 'More AI assistant chats';

  @override
  String get premiumBenefitPrioritySupport => 'Priority support';

  @override
  String get premiumBenefitSenseGroups => 'More AI sentence chunking';

  @override
  String get premiumSubscribe => 'Subscribe';

  @override
  String premiumStartTrial(int days) {
    return 'Start $days-day free trial';
  }

  @override
  String get premiumRestore => 'Restore Purchases';

  @override
  String get premiumManage => 'Manage Subscription';

  @override
  String get premiumCurrentPlan => 'Current plan';

  @override
  String get premiumPlanMonthly => 'Monthly membership';

  @override
  String get premiumPlanYearly => 'Annual membership';

  @override
  String get premiumPlanLifetime => 'Lifetime membership';

  @override
  String get premiumPlanGeneric => 'Membership';

  @override
  String get premiumStatusActive => 'Active';

  @override
  String get premiumStatusExpiring => 'Expiring';

  @override
  String get premiumStatusLifetime => 'Lifetime';

  @override
  String premiumRenewsOn(String date) {
    return 'Renews on $date';
  }

  @override
  String premiumExpiresOn(String date) {
    return 'Expires on $date';
  }

  @override
  String get premiumLifetimeAccessNote => 'Lifetime access, no renewal needed';

  @override
  String get premiumNoPlans =>
      'No plans available right now. Please try again later.';

  @override
  String get premiumLoginRequired => 'Please sign in before subscribing.';

  @override
  String get premiumRestoreLoginRequired =>
      'Please sign in before restoring purchases.';

  @override
  String get premiumPurchaseFailed => 'Purchase failed. Please try again.';

  @override
  String get premiumRestoreAccountMismatch =>
      'This subscription is linked to another Echo Loop account. Sign in to the original account and try again.';

  @override
  String get premiumRestoreNone => 'No purchases found to restore.';

  @override
  String get premiumRestored => 'Purchases restored.';

  @override
  String get premiumWebCheckoutCta => 'Continue to secure checkout';

  @override
  String get premiumUseWebCheckoutFallback =>
      'Store payment not working? Use web checkout';

  @override
  String get premiumUseStoreCheckout => 'Continue with store payment';

  @override
  String get premiumWebVerifying => 'Waiting for payment to be confirmed…';

  @override
  String get premiumWebOpenFailed =>
      'Couldn\'t open the checkout page. Please try again.';

  @override
  String get premiumRefresh => 'Refresh';

  @override
  String get premiumRefreshStatus => 'Refresh premium status';

  @override
  String get premiumPurchasePendingSync =>
      'Purchase successful. Your membership is syncing and will activate shortly.';

  @override
  String get premiumPeriodMonthly => 'Monthly';

  @override
  String get premiumPeriodYearly => 'Yearly';

  @override
  String get premiumPeriodLifetime => 'Lifetime';

  @override
  String get premiumPriceSuffixMonth => '/mo';

  @override
  String get premiumPriceSuffixYear => '/yr';

  @override
  String get premiumPriceSuffixFirstYear => '/first yr';

  @override
  String get premiumPriceSuffixFirstMonth => '/first mo';

  @override
  String get premiumPriceSuffixLifetime => 'One-time';

  @override
  String premiumSavePercent(int percent) {
    return 'Save $percent%';
  }

  @override
  String premiumPerMonthEquivalent(String price) {
    return '≈ $price/mo';
  }

  @override
  String premiumIntroFirstYear(String price) {
    return 'First year $price';
  }

  @override
  String premiumIntroFirstMonth(String price) {
    return 'First month $price';
  }

  @override
  String premiumRenewalPricePerYear(String price) {
    return '$price/yr';
  }

  @override
  String premiumRenewalPricePerMonth(String price) {
    return '$price/mo';
  }

  @override
  String premiumRenewalPricePerPeriod(String price) {
    return '$price';
  }

  @override
  String premiumTryFreeThen(int days, String renewal) {
    return 'Try free for $days days, then $renewal';
  }

  @override
  String premiumOfferThen(String intro, String renewal) {
    return '$intro, then $renewal';
  }

  @override
  String premiumSpecialOfferPercent(int percent, String period) {
    return 'Special offer: $percent% off your first $period';
  }

  @override
  String premiumSpecialOfferIntro(String intro, String renewal) {
    return 'Special offer: $intro, then $renewal';
  }

  @override
  String get premiumOfferPeriodYear => 'year';

  @override
  String get premiumOfferPeriodMonth => 'month';

  @override
  String get premiumTermsShort => 'Terms';

  @override
  String get premiumPrivacyShort => 'Privacy';

  @override
  String get practiceControlModeAuto => 'Auto';

  @override
  String get practiceControlModeManual => 'Manual';

  @override
  String get player => 'Player';

  @override
  String get account => 'Account';

  @override
  String get settings => 'Settings';

  @override
  String get addAudio => 'Add Audio';

  @override
  String get noAudioYet => 'No audio files yet';

  @override
  String get tapToAdd => 'Tap + to add your first audio';

  @override
  String get added => 'Added';

  @override
  String get transcript => 'subtitles';

  @override
  String get playing => 'Last';

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
  String get importAction => 'Import';

  @override
  String get selectAudioFile => 'Select Audio File';

  @override
  String get subtitlePairedBadge => 'Subtitle matched, imported together';

  @override
  String get audioFilePickerCloudDriveHint =>
      'Before selecting files from cloud storage, install and sign in to the cloud storage app first. Some apps may not support direct file selection from the file picker.';

  @override
  String get selectTranscript => 'Select Subtitles (Optional)';

  @override
  String get noTranscript => 'No subtitles available';

  @override
  String get noBookmarked => 'No saved sentences';

  @override
  String get tapToBookmark => 'Tap ⭐ on sentences to bookmark them';

  @override
  String get playbackMode => 'Playback Mode';

  @override
  String get fullArticle => 'Full Article';

  @override
  String get singleSentence => 'Single Sentence';

  @override
  String get bookmarkedOnly => 'saved Only';

  @override
  String get playbackSettings => 'Playback Settings';

  @override
  String get waveformZoom => 'Zoom';

  @override
  String waveformLoading(int progress) {
    return 'Loading waveform $progress%';
  }

  @override
  String get waveformLoadFailed =>
      'Waveform unavailable. You can still edit subtitles below.';

  @override
  String get waveformAudioMissing =>
      'No audio found. You can still edit subtitles below.';

  @override
  String get waveformRetry => 'Retry';

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
  String get themeMode => 'Theme';

  @override
  String get themeModeSystem => 'Follow System';

  @override
  String get themeModeLight => 'Light Mode';

  @override
  String get themeModeDark => 'Dark Mode';

  @override
  String get language => 'Interface Language';

  @override
  String get languageDescription => 'Language used for the app interface';

  @override
  String get languageSystem => 'Follow System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get nativeLanguage => 'Native Language';

  @override
  String get nativeLanguageDescription => 'translations & analysis language';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get save => 'Save';

  @override
  String get enableLoop => 'Enable Loop';

  @override
  String get loopSettings => 'Loop Settings';

  @override
  String get wholeTextLoop => 'loop entire media';

  @override
  String get singleSentenceLoop => 'Single-sentence loop';

  @override
  String get displaySettings => 'Display Settings';

  @override
  String get showTranscript => 'Show subtitles';

  @override
  String get shortcutKey => 'Shortcut';

  @override
  String get seconds => 'seconds';

  @override
  String get infinite => '∞';

  @override
  String get singleSentenceMode => 'Intensive Listening';

  @override
  String get singleSentenceModeDesc => 'Show only current sentence';

  @override
  String get autoPlayNextSentence => 'Auto-Play Next Sentence';

  @override
  String get repeatCount => 'Repeat Count';

  @override
  String get infiniteRepeat => 'Infinite ∞';

  @override
  String get intervalTime => 'Interval Duration';

  @override
  String get times => 'times';

  @override
  String loopCountValue(int count) {
    return '${count}x';
  }

  @override
  String loopIntervalValue(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepTimerMinutes(int count) {
    return '$count min';
  }

  @override
  String get sleepTimerRemaining => 'Time remaining';

  @override
  String get sleepTimerOff => 'Turn off timer';

  @override
  String sleepTimerA11yActive(String time) {
    return 'Sleep timer, $time remaining, tap to adjust';
  }

  @override
  String get fullText => 'full playback';

  @override
  String get bookmarked => 'saved';

  @override
  String get noSubtitle => 'No Subtitle';

  @override
  String get noSentenceSelected => 'No sentence selected';

  @override
  String get noBookmarkedSentences => 'No saved sentences';

  @override
  String get tapBookmarkIcon => 'Tap bookmark icon to save';

  @override
  String get removeBookmarkTip => 'Remove bookmark';

  @override
  String get addBookmarkTip => 'Add bookmark';

  @override
  String get listMode => 'List Mode';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get hotkeyReplay => 'R: Replay';

  @override
  String get hotkeyPlayPause => 'Space: Play/Pause';

  @override
  String get hotkeyToggleTranscript => '↑: Show/Hide Subtitles';

  @override
  String get hotkeyNavigation => '←/→: Previous/Next Sentence';

  @override
  String get noAudioLoaded => 'No audio loaded';

  @override
  String get enableAutoScroll => 'Enable auto-scroll';

  @override
  String get disableAutoScroll => 'Disable auto-scroll';

  @override
  String get audioFileNotFound =>
      'Audio file not found. The file may have been deleted.';

  @override
  String get pickAudioFileFailed => 'Failed to select audio file';

  @override
  String get addAudioFailed => 'Failed to add audio';

  @override
  String audioUnsupportedFormat(String ext) {
    return 'Unsupported audio format: $ext. Only MP3, WAV, M4A, AAC, FLAC are supported.';
  }

  @override
  String get audioErrorUnsupportedTitle => 'Unsupported audio format';

  @override
  String get audioErrorGenericTitle => 'Failed to add audio';

  @override
  String get pickTranscriptFileFailed => 'Failed to select subtitle file';

  @override
  String subtitleUnsupportedFormat(String ext) {
    return 'Unsupported subtitle format: .$ext. Only SRT and VTT files are supported.';
  }

  @override
  String get subtitleFormatInvalid =>
      'Invalid subtitle format. Only standard SRT and VTT files are supported.';

  @override
  String get subtitleFileEmpty =>
      'Subtitle file is empty or corrupted — no subtitle entries found.';

  @override
  String get subtitleErrorUnsupportedTitle => 'Unsupported subtitle format';

  @override
  String get subtitleErrorInvalidTitle => 'Invalid subtitle format';

  @override
  String get subtitleErrorEmptyTitle => 'No subtitle entries found';

  @override
  String get subtitleErrorGenericTitle => 'Upload failed';

  @override
  String get fileExists => 'File Already Exists';

  @override
  String fileExistsMessage(String name) {
    return 'An audio file named \"$name\" already exists. Please delete the original audio first.';
  }

  @override
  String get back => 'Back';

  @override
  String get ok => 'OK';

  @override
  String addedOn(String date) {
    return 'Added: $date';
  }

  @override
  String updatedOn(String date) {
    return 'Updated $date';
  }

  @override
  String get collections => 'Collections';

  @override
  String get collection => 'Collection';

  @override
  String get createCollection => 'Create Collection';

  @override
  String get newCollectionOptionTitle => 'New Collection';

  @override
  String get newCollectionOptionDescription => 'Add audio manually';

  @override
  String get collectionName => 'Collection Name';

  @override
  String get enterCollectionName => 'Enter collection name';

  @override
  String get noCollectionsYet => 'No collections yet';

  @override
  String get tapToCreateCollection => 'Tap + to create your first collection';

  @override
  String get deleteCollection => 'Delete Collection';

  @override
  String deleteCollectionConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get deleteCollectionAlsoDeleteAudio => 'Also delete audio file(s)?';

  @override
  String deleteCollectionKeepAudioHint(int count) {
    return '$count audio file(s) in this collection will be kept.';
  }

  @override
  String deleteCollectionDeleteAudioHint(int count) {
    return '$count audio file(s) in this collection will also be deleted.';
  }

  @override
  String get renameCollection => 'Rename';

  @override
  String get pinCollection => 'Pin to Top';

  @override
  String get unpinCollection => 'Unpin';

  @override
  String get pinAudio => 'Pin to Top';

  @override
  String get unpinAudio => 'Unpin';

  @override
  String get sortByNameAsc => 'Name (A-Z)';

  @override
  String get sortByNameDesc => 'Name (Z-A)';

  @override
  String get sortByDateAsc => 'oldest First';

  @override
  String get sortByDateDesc => 'Newest First';

  @override
  String get sortDefault => 'Default';

  @override
  String get sortByOriginalDateAsc => 'Oldest Released';

  @override
  String get sortByOriginalDateDesc => 'Latest Released';

  @override
  String publishedOn(String date) {
    return 'Released $date';
  }

  @override
  String get discoverEntryTitleA => 'Discover Resources';

  @override
  String get discoverEntrySubtitleA =>
      'Podcasts · TOEFL · IELTS · TEM(4/8), textbook audio files...';

  @override
  String get officialCollectionEmpty => 'This collection has no audio yet';

  @override
  String get sortCollections => 'Sort';

  @override
  String get gridView => 'Grid View';

  @override
  String get listView => 'List View';

  @override
  String audioCount(int count) {
    return '$count audios';
  }

  @override
  String get collectionNameEmpty => 'Collection name cannot be empty';

  @override
  String get collectionNameExists =>
      'A collection with this name already exists';

  @override
  String get addAudioToCollection => 'Add Audio';

  @override
  String get removeFromCollection => 'Remove from Collection';

  @override
  String removeFromCollectionConfirm(String name) {
    return 'Remove \"$name\" from this collection?';
  }

  @override
  String get permanentlyDeleteAudio => 'Permanently delete the audio(s)';

  @override
  String get permanentlyDeleteAudioHint =>
      'Remove the audio(s) from all collections.';

  @override
  String audioBelongsToCollections(String names) {
    return 'Also in: $names';
  }

  @override
  String get audioNotInOtherCollections =>
      'Not in any other collection — safe to delete.';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String removeFromCollectionBatch(int count) {
    return 'Remove $count from collection';
  }

  @override
  String permanentlyDeleteBatch(int count) {
    return 'Permanently delete $count audio';
  }

  @override
  String get permanentlyDeleteBatchHint =>
      'Remove the audio(s) from all collections.';

  @override
  String get removeFromCollectionBatchHint =>
      'Only remove from this collection; the audio files are kept.';

  @override
  String get emptyCollection => 'No audio in this collection';

  @override
  String get tapToAddAudio => 'Tap + to add audio files';

  @override
  String get renameAudio => 'Rename';

  @override
  String get audioName => 'Audio Name';

  @override
  String get audioAlreadyInCollection => 'Duplicate Audio';

  @override
  String audioAlreadyInCollectionMessage(String name) {
    return 'An audio named \"$name\" already exists in this collection.';
  }

  @override
  String get audioAlreadyInLibrary => 'Duplicate Audio';

  @override
  String audioAlreadyInLibraryMessage(String name) {
    return 'An audio named \"$name\" already exists in the library.';
  }

  @override
  String get study => 'Study';

  @override
  String get favorites => 'Saved';

  @override
  String get profile => 'Profile';

  @override
  String get studyComingSoon => 'Study features coming soon';

  @override
  String get favoritesComingSoon => 'Save features coming soon';

  @override
  String get learningPlanProgress => 'Learning Progress';

  @override
  String get learningPlanNotStarted => 'Not started';

  @override
  String get firstStudy => 'First Round';

  @override
  String get review => 'Review';

  @override
  String stepProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String get stepBlindListening => 'Listen without subtitles';

  @override
  String get stepBlindListeningDesc =>
      'Listen to the entire audio/video without subtitles.Get the gist.';

  @override
  String get stepIntensiveListening => 'Listen sentence by sentence';

  @override
  String get stepIntensiveListeningDesc =>
      'Listen sentence by sentence with automatic pauses.For challenging sentences, tap “Unclear” to save them and view AI analysis.';

  @override
  String get stepShadowing => 'Listen & Repeat';

  @override
  String get stepShadowingDesc =>
      'Repeat your saved sentences.By default, each sentence is played three times.';

  @override
  String get stepRetelling => 'Listen & Retell';

  @override
  String get stepRetellingDesc =>
      'Listen and Retell segment by segment. Follow the original transcript or retell it in your own words';

  @override
  String get warmUpCardTitle => 'Warm-up Listening';

  @override
  String get warmUpCardSubtitle =>
      'Listen once to get the main idea. You don\'t need to catch every word.';

  @override
  String get warmUpCardBadge => 'Recommended First';

  @override
  String get reviewRound0 => 'Review 1';

  @override
  String get reviewRound1 => 'Review 2';

  @override
  String get reviewRound2 => 'Review 3';

  @override
  String get reviewRound4 => 'Review 4';

  @override
  String get reviewRound7 => 'Review 5';

  @override
  String get reviewRound14 => 'Review 6';

  @override
  String get reviewRound28 => 'Review 7';

  @override
  String reviewUnlockIn(int days) {
    return 'Unlocks in $days days';
  }

  @override
  String reviewUnlockInHours(int hours) {
    return 'Unlocks in $hours hours';
  }

  @override
  String get reviewUnlocked => 'Unlocked';

  @override
  String get unlockReviewNow => 'Unlock now';

  @override
  String get startLearning => 'Start practicing';

  @override
  String get continueLearning => 'Continue practicing';

  @override
  String get learningInProgress => 'In Progress';

  @override
  String get learningCompleted => 'Completed';

  @override
  String get reviewReady => 'Ready to review';

  @override
  String reviewCountdown(int days) {
    return 'Unlocked in $days days';
  }

  @override
  String reviewCountdownHours(int hours) {
    return 'Unlocked in $hours hours';
  }

  @override
  String get blindListenBriefingTitle => 'Listenwithout subtitles';

  @override
  String get blindListenBriefingSubtitle =>
      'First Round - Listen without subtitles';

  @override
  String blindListenBriefingReviewSubtitle(int round) {
    return 'Review $round - Listen without subtitles';
  }

  @override
  String get blindListenBriefingTip =>
      'Challenge yourself: listen without subtitles and get the gist';

  @override
  String get startPractice => 'Start Practicing';

  @override
  String get blindListenAppBarTitle => 'Listen without subtitles';

  @override
  String blindListenPassLabel(int count) {
    return 'Pass $count';
  }

  @override
  String get blindListenComplete => 'Listening without subtitles Complete';

  @override
  String blindListenPassInfo(int count) {
    return 'Listened $count time(s)';
  }

  @override
  String get selectDifficulty => 'How difficult was this?';

  @override
  String get selectDifficultyRequired => 'Select a difficulty to continue';

  @override
  String get listenAgain => 'Listen Again';

  @override
  String get practiceAgain => 'Practice Again';

  @override
  String get nextStage => 'Next';

  @override
  String get difficultyVeryEasy => 'Very Easy';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyVeryHard => 'Very Hard';

  @override
  String get countdownNextPlay => 'Next play starts in';

  @override
  String get skipCountdown => 'Skip';

  @override
  String audioDuration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String estimatedMinutes(int minutes) {
    return 'Est. $minutes min';
  }

  @override
  String get estimatedLessThanOneMinute => 'Est. < 1 min';

  @override
  String get exitBlindListenTitle => 'Exit Listening?';

  @override
  String get exitBlindListenMessage =>
      'Audio is still playing. Are you sure you want to exit?';

  @override
  String get confirmExit => 'Exit';

  @override
  String get library => 'Library';

  @override
  String get collectionsTab => 'Collections';

  @override
  String get audioTab => 'Audio';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get manageCollections => 'Manage Collections';

  @override
  String get noAudioItems => 'No audio files yet';

  @override
  String get noAudioItemsHint => 'Import audio files to start practicing';

  @override
  String audioWillBeKept(int count) {
    return '$count audio files in this collection will be kept in the library';
  }

  @override
  String get done => 'Done';

  @override
  String get sortAudio => 'Sort';

  @override
  String deleteAudioConfirm(String name) {
    return 'Permanently delete \"$name\"?';
  }

  @override
  String deleteAudioConfirmKeepFile(String name) {
    return 'Are you sure you want to delete \"$name\"? The audio file is shared by other entries and will be kept.';
  }

  @override
  String get uploadTranscript => 'Upload Subtitles';

  @override
  String get replaceTranscriptTitle => 'Replace Subtitles';

  @override
  String get replaceTranscriptMessage =>
      'A subtitle file already exists. Do you want to replace it?';

  @override
  String get replace => 'Replace';

  @override
  String sentenceCountLabel(int count) {
    return '$count sentences';
  }

  @override
  String wordCountLabel(int count) {
    return '$count words';
  }

  @override
  String get noTranscriptWarning => 'This audio has no subtitles yet';

  @override
  String get intensiveListenAppBarTitle => 'Listen sentence by sentence';

  @override
  String intensiveListenProgress(int current, int total) {
    return 'Sentence $current/$total';
  }

  @override
  String intensiveListenPlayCount(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String get intensiveListenPeek => 'Peek at subtitles';

  @override
  String get intensiveListenHideSubtitle => 'Hide subtitles';

  @override
  String get intensiveListenCantUnderstand => 'Unclear';

  @override
  String get intensiveListenAutoMarkedDifficult => 'Auto-save, tap to undo';

  @override
  String get intensiveListenMarkedDifficult => 'Already saved, tap to undo';

  @override
  String get intensiveListenNotDifficult => 'Tap to mark as challenging';

  @override
  String get aiTranslation => 'Translation';

  @override
  String get aiAnalysis => 'Analysis';

  @override
  String get aiLoadFailed => 'Failed to load, tap to retry';

  @override
  String get aiTranslationFailed => 'Translation failed, please retry';

  @override
  String get aiAnalysisFailed => 'Analysis failed, please retry';

  @override
  String get aiRetry => 'Retry';

  @override
  String get aiGrammar => 'Grammar';

  @override
  String get aiVocabulary => 'Key Vocabulary';

  @override
  String get aiListening => 'Listening tips';

  @override
  String get intensiveListenWordDictNotFound => 'Word not found in dictionary';

  @override
  String get intensiveListenContinue => 'Continue';

  @override
  String get intensiveListenReplayingWithSubtitle =>
      'Replaying with subtitles...';

  @override
  String intensiveListenPauseBetweenPlays(int seconds) {
    return 'Next play in ${seconds}s';
  }

  @override
  String intensiveListenPauseBetweenSentences(int seconds) {
    return 'Next sentence in ${seconds}s';
  }

  @override
  String get intensiveListenCompleteTitle =>
      'Listening sentence by sentence Complete';

  @override
  String get intensiveListenCompleteHint =>
      'Keep reviewing with spaced repetition to fully master it.';

  @override
  String get intensiveListenCompleteNext => 'Next Step';

  @override
  String get statSentences => 'Sentences';

  @override
  String get statDifficultSentences => 'challenging';

  @override
  String get statParagraphs => 'Segments';

  @override
  String get exitIntensiveListenTitle => 'Exit Listening sentence by sentence?';

  @override
  String get exitIntensiveListenMessage =>
      'Your progress will be saved. You can continue where you left off.';

  @override
  String get intensiveListenBriefingTitle => 'Listen sentence by sentence';

  @override
  String get intensiveListenBriefingTip =>
      'Listen sentence by sentence. Tap \'Unclear\' to view transcript and analysis.';

  @override
  String intensiveListenBriefingSentenceCount(int count) {
    return '$count sentences';
  }

  @override
  String get intensiveListenNoSubtitle => 'No Subtitles Available';

  @override
  String get intensiveListenNoSubtitleMessage =>
      'This audio has no subtitles. Please upload a subtitle file first.';

  @override
  String get intensiveListenSettings => 'Settings';

  @override
  String get intensiveListenRepeatCount => 'Repeat per sentence';

  @override
  String intensiveListenRepeatCountValue(int count) {
    return '$count time(s)';
  }

  @override
  String get intensiveListenPauseLabel => 'Pause between sentences';

  @override
  String get intensiveListenPauseSmart => 'Auto';

  @override
  String get intensiveListenPauseFixed => 'Fixed';

  @override
  String get intensiveListenPauseMultiplierMode => 'Multiplier';

  @override
  String get intensiveListenSettingsTemporaryHint =>
      'Settings are remembered for next time';

  @override
  String get intensiveListenPauseSmartDesc =>
      'Auto-adjusted based on difficulty, sentence length, and learning stage';

  @override
  String get intensiveListenControlModeAutoDesc =>
      'Auto-loop, auto-pause, auto-next';

  @override
  String get intensiveListenControlModeManualDesc => 'Tap to replay, tap next';

  @override
  String intensiveListenPauseFixedUnit(int seconds) {
    return '${seconds}s';
  }

  @override
  String intensiveListenPauseMultiplierValue(String value) {
    return '${value}x';
  }

  @override
  String get intensiveListenPauseMultiplierLabel => 'Multiplier';

  @override
  String blindListenCountdown(int seconds) {
    return 'Next play in ${seconds}s';
  }

  @override
  String difficultyLabel(String difficulty) {
    return 'Difficulty level: $difficulty';
  }

  @override
  String continueToStep(String step) {
    return 'Continue: $step';
  }

  @override
  String get completeFirstStudy => 'First Round Complete';

  @override
  String get completeReview => 'Review Complete';

  @override
  String stepProgressLabel(int current, int total, String stage) {
    return 'Stage $current/$total ($stage)';
  }

  @override
  String get manageTags => 'Manage Tags';

  @override
  String get noTagsYet => 'No tags yet';

  @override
  String get createTag => 'Create Tag';

  @override
  String get tagName => 'Tag Name';

  @override
  String get enterTagName => 'Enter tag name';

  @override
  String get selectColor => 'Select Color';

  @override
  String get deleteTag => 'Delete Tag';

  @override
  String deleteTagConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"? It will be removed from all audio files.';
  }

  @override
  String get listenAndRepeatAppBarTitle => 'Listen & Repeat';

  @override
  String listenAndRepeatProgress(int current, int total) {
    return 'Sentence $current/$total';
  }

  @override
  String listenAndRepeatPlayCount(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String listenAndRepeatPauseBetweenPlays(int seconds) {
    return 'Repeat time ${seconds}s';
  }

  @override
  String listenAndRepeatPauseBetweenSentences(int seconds) {
    return 'Next sentence in ${seconds}s';
  }

  @override
  String get listenAndRepeatListenHint => 'Listen, then repeat';

  @override
  String get listenAndRepeatYourTurnHint => 'Repeat';

  @override
  String get listenAndRepeatRecordButton => 'Record';

  @override
  String get listenAndRepeatStopRecordingButton => 'Stop';

  @override
  String get listenAndRepeatPlayRecordingButton => 'Play My Recording';

  @override
  String get listenAndRepeatRecordingInProgress => 'Recording...';

  @override
  String get listenAndRepeatStartSpeaking => 'Start speaking';

  @override
  String get listenAndRepeatAnalyzing => 'Analyzing...';

  @override
  String get listenAndRepeatTapToRecord => 'Tap to record';

  @override
  String get listenAndRepeatRatingPerfect => 'Perfect!';

  @override
  String get listenAndRepeatRatingExcellent => 'Excellent';

  @override
  String get listenAndRepeatRatingGood => 'Good';

  @override
  String get listenAndRepeatRatingFair => 'Fair';

  @override
  String get listenAndRepeatRatingKeepGoing => 'Keep going';

  @override
  String get listenAndRepeatAwaitingFinalTranscript =>
      'Confirming final transcription...';

  @override
  String get listenAndRepeatYourTakeLabel => 'Your transcrit';

  @override
  String get listenAndRepeatRecognitionInProgress =>
      'Checking your recording...';

  @override
  String listenAndRepeatRecognitionPassed(int percent) {
    return 'Matched $percent% of the target words.';
  }

  @override
  String listenAndRepeatRecognitionBelowThreshold(int percent) {
    return 'Matched $percent% of the target words.';
  }

  @override
  String get listenAndRepeatRecognitionNoEnglish =>
      'No spoken English detected';

  @override
  String get listenAndRepeatRecognitionPermissionDenied =>
      'Microphone or speech recognition permission is required.';

  @override
  String get listenAndRepeatRecognitionUnavailable =>
      'Speech recognition is unavailable on this device.';

  @override
  String get listenAndRepeatRecognitionError => 'Recognition error';

  @override
  String get listenAndRepeatRecordingOnly => 'Recording';

  @override
  String get listenAndRepeatCompleteTitle => 'Listen & Repeat Complete';

  @override
  String get listenAndRepeatNoDifficultSentences =>
      'No saved sentences, no Listen & Repeat needed';

  @override
  String get exitListenAndRepeatTitle => 'Exit Listen & Repeat?';

  @override
  String get exitListenAndRepeatMessage =>
      'Your progress will be saved. You can continue where you left off.';

  @override
  String get listenAndRepeatBriefingTitle => 'Listen & Repeat';

  @override
  String get listenAndRepeatBriefingTip =>
      'Listen first, then repeat during the pause. By default, each saved sentence will be played three times.';

  @override
  String listenAndRepeatBriefingDifficultCount(int count) {
    return '$count difficult sentences';
  }

  @override
  String listenAndRepeatBriefingPlayCount(int count) {
    return '$count plays per sentence';
  }

  @override
  String get listenAndRepeatRemoveDifficult => 'Auto-saved, tap to undo';

  @override
  String get listenAndRepeatSettings => 'Repeat Settings';

  @override
  String get listenAndRepeatSettingsTemporaryHint =>
      'Settings apply to this session only';

  @override
  String get listenAndRepeatControlModeLabel => 'Control Mode';

  @override
  String get listenAndRepeatControlModeAuto => 'Auto';

  @override
  String get listenAndRepeatControlModeManual => 'Manual';

  @override
  String get listenAndRepeatControlModeAutoDesc =>
      'Auto-record, auto-pause, auto-play next';

  @override
  String get listenAndRepeatControlModeManualDesc =>
      'Tap to record, tap to pause, tap to play the next sentence';

  @override
  String get listenAndRepeatPauseSmartDesc =>
      'Automatically adjusted based on difficulty, sentence length, and learning stage';

  @override
  String sentenceDuration(String duration) {
    return '${duration}s';
  }

  @override
  String difficultSentenceCount(int count) {
    return '$count challenging sentences';
  }

  @override
  String intensiveListenPassInfo(int count) {
    return 'Practiced ${count}x';
  }

  @override
  String shadowingPassInfo(int count) {
    return 'Practiced ${count}x';
  }

  @override
  String get retellBriefingTitle => 'Listen & Retell';

  @override
  String get retellBriefingSubtitle =>
      'Listen and retell segment by segment. Follow the original transcript or use your own words. Visible words help you recall what you heard.';

  @override
  String get retellBriefingTargetDuration => 'segment length';

  @override
  String retellBriefingParagraphCount(int count) {
    return 'Split into $count segments';
  }

  @override
  String retellBriefingSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get retellBriefingSentenceLevel => 'Per Sentence';

  @override
  String retellBriefingSentenceCount(int count) {
    return '$count sentences total';
  }

  @override
  String get retellTitle => 'Listen & Retell';

  @override
  String retellParagraphProgress(int current, int total) {
    return 'Segment $current/$total';
  }

  @override
  String retellParagraphDuration(String duration) {
    return '${duration}s';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String get retellPreListenHint => 'Listen first, then retell';

  @override
  String get retellListeningPhase => 'Listening closely...';

  @override
  String get retellPromptToRetell => 'Retell what you heard';

  @override
  String retellRetellingCountdown(int seconds) {
    return 'Retell ${seconds}s';
  }

  @override
  String retellRepeatInfo(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String get retellCompleteFirstStudy => 'First Round Complete';

  @override
  String get retellCompleteReview => 'Review Complete';

  @override
  String get retellCompleteFreePlay => 'Practice Complete';

  @override
  String get retellCompleteTitle => 'Listen & Retell Complete';

  @override
  String get retellPracticeAgain => 'Practice Again';

  @override
  String get retellExitConfirmTitle => 'Exit Listen & Retell?';

  @override
  String get retellExitConfirmMessage =>
      'Current segment progress will be saved.';

  @override
  String get retellDisplayKeywordsOnly => 'Partially Visible';

  @override
  String get retellDisplayShowAll => 'Fully Visible';

  @override
  String get retellDisplayHideAll => 'Hided';

  @override
  String get retellSettingsTitle => 'Retell Settings';

  @override
  String get retellAutoPlaybackPromptTitle =>
      'Auto-play your recording after retelling?';

  @override
  String get retellAutoPlaybackPromptMessage =>
      'When enabled, your recording plays automatically after each retelling so you can review your pronunciation right away. You can change this anytime in Settings.';

  @override
  String get retellAutoPlaybackKeepOff => 'Not Now';

  @override
  String get retellAutoPlaybackEnable => 'Enable';

  @override
  String get retellRepeatCount => 'Repeat per segment';

  @override
  String get retellPauseMode => 'Pause between segments';

  @override
  String retellPassInfo(int count) {
    return 'Practiced ${count}x';
  }

  @override
  String get retellNoDifficultSentences =>
      'No sentences to retell. Listen sentence by sentence first.';

  @override
  String get retellKeywordMethod => 'Visible words';

  @override
  String get retellKeywordMethodOff => 'Off';

  @override
  String get retellKeywordMethodRandom => 'Random';

  @override
  String get retellKeywordMethodAi => 'AI';

  @override
  String get retellKeywordMethodAiComingSoon => 'Coming soon';

  @override
  String get retellKeywordRatio => 'Visible Words';

  @override
  String get pauseModeSmart => 'Auto';

  @override
  String get pauseModeFixed => 'Fixed';

  @override
  String get pauseModeMultiplier => 'Multiplier';

  @override
  String get fixedPauseSeconds => 'Fixed pause';

  @override
  String get pauseMultiplier => 'Multiplier';

  @override
  String get settingsSessionOnly => 'Settings apply to current session only';

  @override
  String get reviewDifficultPracticeTitle => 'Practice saved Sentences';

  @override
  String reviewDifficultPracticeProgress(int current, int total) {
    return 'Sentence $current/$total';
  }

  @override
  String get reviewDifficultPracticeBlindListen => 'Listening...';

  @override
  String get reviewDifficultPracticeCompleteTitle =>
      'Saved Sentences Practice Complete';

  @override
  String get reviewDifficultPracticeNone =>
      'No saved sentences to practice. Auto-completed.';

  @override
  String get exitReviewDifficultPracticeTitle => 'Exit Practice?';

  @override
  String get exitReviewDifficultPracticeMessage =>
      'Your progress will not be saved for this step.';

  @override
  String get exitReviewDifficultPracticeConfirmMessage =>
      'Your progress will be saved and you can continue next time.';

  @override
  String reviewDifficultPracticeAdvancing(int seconds) {
    return 'Next sentence in ${seconds}s';
  }

  @override
  String get aiSectionTitle => 'AI';

  @override
  String get speechRecognition => 'Speech Recognition';

  @override
  String get speechRecognitionNotConfigured => 'Not configured';

  @override
  String get speechRecognitionEnabled => 'Enabled';

  @override
  String get speechRecognitionDisabled => 'Disabled';

  @override
  String get speechRecognitionDescription =>
      'Speech recognition powers practice ratings and future local transcription. Choose the model that fits your device.';

  @override
  String get asrEngine => 'Speech Engine';

  @override
  String get asrBackendPlatform => 'Apple AI';

  @override
  String get asrBackendPlatformDescription =>
      'Use the built-in system speech recognition.No download needed';

  @override
  String get asrBackendOffline => 'Echo Loop AI';

  @override
  String get asrBackendOfflineDescription =>
      'Use the app\'s AI model. It works offline after downloading';

  @override
  String asrModelTier(String tier) {
    return 'Model: $tier (auto-selected for your device)';
  }

  @override
  String get asrModelFastDescription => 'Fastest. Best for low-end devices.';

  @override
  String get asrModelBalancedDescription => 'Balanced accuracy and speed.';

  @override
  String get asrModelAccurateDescription =>
      'More accurate, but larger and slower.';

  @override
  String get localSpeechRecognition => 'Local Speech Recognition';

  @override
  String speechModelSize(String size) {
    return 'Model size: ~$size';
  }

  @override
  String speechModelApproxSize(String size) {
    return '~$size';
  }

  @override
  String speechModelReady(String size) {
    return 'Ready · $size';
  }

  @override
  String get speechModelStatusReady => 'Ready';

  @override
  String get speechModelStatusNeedsDownload => 'Download';

  @override
  String speechModelDownloading(String progress) {
    return 'Downloading... $progress';
  }

  @override
  String get speechModelDownloadFailed => 'Download failed. Tap to retry.';

  @override
  String get speechModelDownloadFailedTitle =>
      'Speech Recognition Model Download Failed';

  @override
  String get speechModelDownloadFailedGenericPurpose =>
      'The speech recognition model is used for automatic scoring your spoken responses.';

  @override
  String get speechModelDownloadFailedListenAndRepeatPurpose =>
      'The speech recognition model is used for automatic scoring your pronunciation.';

  @override
  String get speechModelDownloadFailedRetellPurpose =>
      'The speech recognition model is used for automatic scoring your retelling.';

  @override
  String get speechModelDownloadFailedDisableHint =>
      'If you do not need automatic scoring for now, turn it off:';

  @override
  String get speechModelDisablePathGeneric => 'Settings > Learning Settings';

  @override
  String get speechModelDisablePathListenAndRepeat =>
      'Settings > Learning Settings > Show rating during read-aloud';

  @override
  String get speechModelDisablePathRetell =>
      'Settings > Learning Settings > Show rating during retelling';

  @override
  String get downloadErrorStorage =>
      'Not enough storage. Free up space and retry.';

  @override
  String get downloadErrorNetwork =>
      'Network error. Check your connection and retry.';

  @override
  String get downloadErrorCorrupted =>
      'Downloaded file verification failed. Please retry.';

  @override
  String deleteModel(String size) {
    return 'Delete Model ($size)';
  }

  @override
  String get deleteModelAction => 'Delete Model';

  @override
  String get deleteModelConfirmTitle => 'Delete Model?';

  @override
  String deleteModelConfirmMessage(String size) {
    return 'This will free up $size of storage space.';
  }

  @override
  String get disableSpeechRecognitionTitle => 'Disable Speech Recognition?';

  @override
  String get disableSpeechRecognitionMessage =>
      'Speech scoring will be unavailable.';

  @override
  String get alsoDeleteModel => 'Also delete downloaded model';

  @override
  String get disableAction => 'Disable';

  @override
  String get speechRecognitionRequiredTitle =>
      'Speech Recognition Model Required';

  @override
  String get speechRecognitionRequiredMessage =>
      'Speech recognition is used to automatically evaluate your pronunciation and retelling. A model download is required before starting.';

  @override
  String get downloadAndEnable => 'Download & Enable';

  @override
  String get notNow => 'Not Now';

  @override
  String get speechModelRepairTitle => 'Model Download Incomplete';

  @override
  String get speechModelRepairMessage =>
      'The speech recognition model needs to be re-downloaded to use voice practice.';

  @override
  String get downloadNow => 'Download Now';

  @override
  String get later => 'Later';

  @override
  String get speechRecognitionNotEnabled =>
      'Voice recognition not enabled. Enable in Settings.';

  @override
  String get retryDownload => 'Retry';

  @override
  String get downloadingSpeechModel => 'Downloading Speech Recognition Model';

  @override
  String get developer => 'Developer';

  @override
  String get developerOptionsEnabled => 'Developer options enabled';

  @override
  String get developerOptionsDisable => 'Disable developer options';

  @override
  String get timeMachine => 'Time Machine';

  @override
  String get timeMachineUseSystemTime => 'Use system time';

  @override
  String get timeMachineCurrentTime => 'Debug time';

  @override
  String get timeMachineSelectDate => 'Select date';

  @override
  String get timeMachineSelectTime => 'Select time';

  @override
  String get timeMachineReset => 'Use system time';

  @override
  String get manageSubtitles => 'Manage Subtitles';

  @override
  String get localUpload => 'Local Upload';

  @override
  String get aiTranscription => 'Cloud Transcription';

  @override
  String get aiTranscriptionSubtitle =>
      'Higher accuracy, needs network + sign-in';

  @override
  String get offlineTranscription => 'On-Device Transcription';

  @override
  String get offlineTranscriptionSubtitle => 'Offline, private, no sign-in';

  @override
  String get transcriptionModelTier => 'Recognition model';

  @override
  String get localTranscriptionDecoding => 'Decoding audio...';

  @override
  String get localTranscriptionForegroundHint =>
      'Keep the app open and on-screen until it finishes — transcription pauses if you switch apps or lock the screen.';

  @override
  String localTranscriptionProgressPercent(int percent) {
    return '$percent% done';
  }

  @override
  String get localTranscriptionModelRequiredTitle => 'Speech model needed';

  @override
  String localTranscriptionModelRequiredMessage(String modelName) {
    return 'On-device transcription requires downloading the $modelName speech model once (offline afterwards).';
  }

  @override
  String get deleteSubtitle => 'Delete Subtitles';

  @override
  String get startTranscription => 'Start Transcription';

  @override
  String get alreadyTranscribedWithOption =>
      'Already transcribed with this option';

  @override
  String get transcriptionUploading => 'Uploading...';

  @override
  String get transcriptionCompressing => 'Compressing audio...';

  @override
  String get transcriptionProcessing => 'Transcribing...';

  @override
  String get transcriptionComplete => 'Complete!';

  @override
  String get transcriptionFailed => 'Transcription failed';

  @override
  String get transcriptionErrorConnection => 'Unable to connect to server';

  @override
  String get transcriptionErrorTimeout => 'Request timed out, please retry';

  @override
  String get transcriptionErrorServer =>
      'Please check the audio and try again later';

  @override
  String get transcriptionErrorUnknown =>
      'Please check the audio and try again later';

  @override
  String get transcriptionErrorCompression =>
      'Audio compression failed. Please check the audio and try again.';

  @override
  String get transcriptionErrorCompressedFileTooLarge =>
      'Compressed file still exceeds 25MB';

  @override
  String get transcriptionEmptyResult => 'No speech detected';

  @override
  String get transcriptionEmptyResultHint =>
      'The audio may contain too much background noise.';

  @override
  String transcriptionErrorFileTooLarge(int maxMb) {
    return 'File too large (max ${maxMb}MB)';
  }

  @override
  String transcriptionErrorTooLong(int maxMin) {
    return 'Audio too long (max $maxMin minutes)';
  }

  @override
  String get deleteSubtitleConfirm =>
      'Are you sure you want to delete the subtitles?';

  @override
  String get deleteSubtitleWarning =>
      'Deleting the subtitles will also clear all saved sentences and learning progress of this audio.';

  @override
  String get languageAutoDetect => 'Auto Detect';

  @override
  String get mixedLanguageNotSupported =>
      'Mixed-language audio is not supported yet';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get autoMergeShortSentences => 'Auto-merge short sentences';

  @override
  String get autoMergeShortSentencesHint =>
      'Targets 4-7s; turn off to keep shorter sentences';

  @override
  String get overwriteExistingSubtitle => 'Overwrite existing subtitles?';

  @override
  String get overwriteExistingSubtitleMessage =>
      'This will replace the current subtitles. Continue?';

  @override
  String get overwrite => 'Overwrite';

  @override
  String get audioContentEmptyWarning => 'Possibly empty';

  @override
  String get audioContentDamagedWarning => 'Audio issue';

  @override
  String get audioContentSilentWarning => 'Possibly silent';

  @override
  String get transcriptionDamagedConfirmTitle => 'Audio may be damaged';

  @override
  String get transcriptionDamagedConfirmMessage =>
      'This audio may be damaged or in an incompatible format. Transcribe anyway?';

  @override
  String get transcriptionSilentConfirmTitle => 'Audio may be empty';

  @override
  String get transcriptionSilentConfirmMessage =>
      'This audio appears to be silent with no speech. Transcribe anyway?';

  @override
  String get transcriptionSilentConfirmProceed => 'Transcribe anyway';

  @override
  String transcriptionAudioFileSize(Object size) {
    return 'File size: $size';
  }

  @override
  String transcriptionAudioDuration(Object duration) {
    return 'Duration: $duration';
  }

  @override
  String get transcriptionAudioUnknown => 'Not detected';

  @override
  String get currentSubtitleExists => 'Current: Has Subtitle';

  @override
  String get currentSubtitleLocal => 'Current: Local Upload';

  @override
  String currentSubtitleAi(String language) {
    return 'Current: AI ($language)';
  }

  @override
  String get noSubtitleYet => 'No subtitle yet';

  @override
  String get addSubtitlePromptTitle => 'Add Subtitle?';

  @override
  String get addSubtitlePromptMessage => 'Add a subtitle now for learning?';

  @override
  String get selectCollection => 'Collection (Optional)';

  @override
  String get noCollection => 'None';

  @override
  String get addSubtitle => 'Add Subtitle';

  @override
  String get retryTranscription => 'Retry';

  @override
  String transcriptionFailedMessage(String message) {
    return 'Error: $message';
  }

  @override
  String todayStudyTime(String time) {
    return 'Today: $time';
  }

  @override
  String studyTimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String studyTimeHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get studyTasks => 'Study Tasks';

  @override
  String get continueLearningHero => 'Continue Learning';

  @override
  String get startButton => 'Start';

  @override
  String get continueButton => 'Continue';

  @override
  String streakDays(int count) {
    return '${count}d streak';
  }

  @override
  String get todayStudyTimeShort => 'Today';

  @override
  String get weekStudyTimeShort => 'This Week';

  @override
  String readyToReview(int count) {
    return 'Ready to Review ($count)';
  }

  @override
  String upcomingReviews(int count) {
    return 'Upcoming Reviews ($count)';
  }

  @override
  String upcomingReviewsSummary(int count) {
    return '$count review tasks will unlock later';
  }

  @override
  String firstStudySection(int count) {
    return 'First Round ($count)';
  }

  @override
  String completedSection(int count) {
    return 'Completed ($count)';
  }

  @override
  String get noStudyTasks => 'No study tasks yet';

  @override
  String get noStudyTasksHint => 'Import audio files to start practicing.';

  @override
  String get goToLibrary => 'Go to Library';

  @override
  String get allDoneTitle => 'All done for now!';

  @override
  String get allDoneHint => 'Well Done! Come back later for reviews.';

  @override
  String overdueDays(int count) {
    return 'Due ${count}d ago';
  }

  @override
  String overdueHours(int count) {
    return 'Due ${count}h ago';
  }

  @override
  String get reviewDue => 'Review due';

  @override
  String availableInDays(int count) {
    return 'in ${count}d';
  }

  @override
  String availableInHours(int count) {
    return 'in ${count}h';
  }

  @override
  String subStageLabelFirstLearn(String subStage) {
    return 'First Round - $subStage';
  }

  @override
  String subStageLabelReview(String reviewName, String subStage) {
    return '$reviewName - $subStage';
  }

  @override
  String get favoritesSentences => 'Sentences';

  @override
  String get favoritesVocabulary => 'Vocabulary';

  @override
  String get favoritesNoSentences => 'No saved sentences yet';

  @override
  String get favoritesNoSentencesHint =>
      'Bookmark challenging sentences during listening sentence by sentence or repeating';

  @override
  String get favoritesNoVocabulary => 'No saved vocabulary yet';

  @override
  String get favoritesNoVocabularyHint =>
      'Tap a word to look it up and save it';

  @override
  String favoritesBookmarkCount(int count) {
    return '$count sentences';
  }

  @override
  String get favoritesVocabularySaved => 'Saved';

  @override
  String get favoritesVocabularyRemoved => 'Removed';

  @override
  String get favoritesBookmarkRemoved => 'Bookmark removed';

  @override
  String get undo => 'Undo';

  @override
  String get favoritesSaveVocabulary => 'Save';

  @override
  String get favoritesUnsaveVocabulary => 'Remove';

  @override
  String get bookmarkReviewTitle => 'Review Saved Items';

  @override
  String get bookmarkReviewStart => 'Start Review';

  @override
  String bookmarkReviewStartCount(int count) {
    return 'Start Review ($count)';
  }

  @override
  String get bookmarkReviewComplete => 'Review Complete';

  @override
  String get bookmarkReviewAgain => 'Review Again';

  @override
  String get bookmarkReviewAudioSkipped =>
      'Audio unavailable, skip this sentence';

  @override
  String bookmarkReviewFromAudio(String name) {
    return 'From: $name';
  }

  @override
  String get difficultPracticeSettings => 'Practice Settings';

  @override
  String get difficultPracticeSettingsHint =>
      'Settings apply to this session only';

  @override
  String get difficultPracticeBlindListenRepeat =>
      'Times to Listen without subtitles';

  @override
  String get difficultPracticeShadowReadingRepeat =>
      'Times to Listen and Repeat';

  @override
  String get inputWordsShort => 'Input';

  @override
  String get outputWordsShort => 'Output';

  @override
  String listenTimeWords(String time, String words) {
    return 'Listen: $time · $words';
  }

  @override
  String speakTimeWords(String time, String words) {
    return 'Speak: $time · $words';
  }

  @override
  String get learnedWordFormsShort => 'Vocab';

  @override
  String get todayNewShort => 'Today';

  @override
  String get learnedWordsEmptyHint =>
      'No words learned yet. Complete a listening session first.';

  @override
  String get learnedWordsSortTimeAsc => 'Oldest Learned';

  @override
  String get learnedWordsSortTimeDesc => 'Recently Learned';

  @override
  String bookmarkReviewProgress(int current, int total) {
    return 'Sentence $current/$total';
  }

  @override
  String get flashcardTitle => 'Flashcards';

  @override
  String get flashcardViewAnswer => 'Ready? View answer';

  @override
  String get flashcardTapToFlip => 'Tap to flip back';

  @override
  String get flashcardUnsaveHint => 'Unmark when mastered';

  @override
  String flashcardProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get flashcardComplete => 'Review Complete';

  @override
  String flashcardWordsReviewed(int count) {
    return 'Reviewed $count words';
  }

  @override
  String flashcardWordsRemoved(int count) {
    return 'Unsaved $count words';
  }

  @override
  String get flashcardPracticeAgain => 'Practice Again';

  @override
  String get flashcardFinish => 'Done';

  @override
  String get flashcardSettingsTitle => 'Flashcard Settings';

  @override
  String get flashcardSettingsSubtitle => 'Settings are saved automatically';

  @override
  String get flashcardControlModeLabel => 'Control Mode';

  @override
  String get flashcardControlModeAuto => 'Auto';

  @override
  String get flashcardControlModeManual => 'Manual';

  @override
  String get flashcardControlModeAutoDesc => 'Auto flip, auto advance';

  @override
  String get flashcardControlModeManualDesc => 'Manual flip, manual advance';

  @override
  String get flashcardTimerMode => 'Flashcard Advance Timer';

  @override
  String get flashcardTimerSmart => 'Auto';

  @override
  String get flashcardTimerSmartDesc =>
      'Adjust based on word difficulty and practice count';

  @override
  String get flashcardTimerFixed => 'Fixed';

  @override
  String get flashcardTimerFixedDesc => 'Set fixed duration for front and back';

  @override
  String get flashcardTimerFrontDuration => 'Front';

  @override
  String get flashcardTimerBackDuration => 'Back';

  @override
  String get flashcardSortMode => 'Word List Order';

  @override
  String get flashcardSortAlphaAsc => 'A → Z';

  @override
  String get flashcardSortAlphaDesc => 'Z → A';

  @override
  String get flashcardSortTimeAsc => 'Oldest';

  @override
  String get flashcardSortTimeDesc => 'Newest';

  @override
  String get flashcardSortRandom => 'Random';

  @override
  String get flashcardSortSmart => 'Auto';

  @override
  String get flashcardSortSmartDesc => 'Order based on memory patterns';

  @override
  String get flashcardSortRandomDesc => 'Shuffle randomly each time';

  @override
  String get flashcardSortAlphaAscDesc => 'Sort A to Z';

  @override
  String get flashcardSortAlphaDescDesc => 'Sort Z to A';

  @override
  String get flashcardSortTimeAscDesc => 'Oldest saved first';

  @override
  String get flashcardSortTimeDescDesc => 'Newest saved first';

  @override
  String get flashcardNoDefinition => 'No definition';

  @override
  String get flashcardStartQuiz => 'Start Review';

  @override
  String get flashcardTts => 'Pronounce';

  @override
  String get flashcardAutoPlaySentence => 'Auto-play Sentence';

  @override
  String get flashcardAutoPlayWord => 'Auto-play Word';

  @override
  String get freePlay => 'Listen Your Way';

  @override
  String get wordAiAnalysis => 'AI Analysis';

  @override
  String get wordAiContextMeaning => 'Contextual Meaning';

  @override
  String get wordAiCollocations => 'Collocations';

  @override
  String get wordAiUsage => 'Usage Notes';

  @override
  String get wordAiWordFamily => 'Word Family';

  @override
  String get storage => 'Other';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get clearCacheConfirm =>
      'This clears temporary cache to free up space. Your learning records and favorites are not affected, and data is regenerated when needed. Continue?';

  @override
  String get clearCacheSuccess => 'Cache cleared';

  @override
  String clearCacheSuccessWithSize(String size) {
    return 'Cache cleared, freed $size';
  }

  @override
  String get clearCacheEmpty => 'Cache is already empty';

  @override
  String get confirm => 'Confirm';

  @override
  String get autoCompletedNoDifficultReview => '0 saved sentence, skipped';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get writeFeedback => 'Write Feedback';

  @override
  String get rateUs => 'Rate Us';

  @override
  String get joinCommunity => 'Join Community';

  @override
  String get joinCommunityInviteSubtitle =>
      'Find study buddies, share resources, request features';

  @override
  String get networkError =>
      'Unable to connect. Please check your network and try again.';

  @override
  String get viewSourceCode => 'View Source Code';

  @override
  String updateAvailable(String version) {
    return 'New Version v$version';
  }

  @override
  String get updateNow => 'Update Now';

  @override
  String get updateLater => 'Later';

  @override
  String get forceUpdateTitle => 'Update Required';

  @override
  String get forceUpdateMessage =>
      'Your current version is no longer supported. Please update to continue.';

  @override
  String get releaseNotesTitle => 'What\'s New';

  @override
  String get copyDownloadLink => 'Copy Download Link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get checkForUpdate => 'Check for Updates';

  @override
  String get alreadyLatest => 'Already up to date';

  @override
  String get checkUpdateFailed => 'Check failed, please check your network';

  @override
  String get demoMode => 'Demo Mode';

  @override
  String get demoModeSubtitle => 'Use demo data for screenshots';

  @override
  String get practiceRemoveMark => 'Unmark';

  @override
  String get practiceAddMark => 'Re-mark';

  @override
  String blindListenSegmentProgress(int current, int total) {
    return 'Segment $current/$total';
  }

  @override
  String blindListenSegmentDuration(int duration) {
    return '${duration}s';
  }

  @override
  String get blindListenListeningHint => 'Listen closely...';

  @override
  String get blindListenPreListenHint => 'Listen first, then recall';

  @override
  String blindListenRepeatInfo(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String get blindListenSettingsTitle => 'Listening Settings';

  @override
  String get blindListenPauseBetween => 'Pause between segments';

  @override
  String get blindListenTargetDuration => 'Segment length';

  @override
  String get blindListenDisplayHideAll => 'Hide Subtitles';

  @override
  String get blindListenDisplayShowAll => 'Show Subtitles';

  @override
  String get blindListenRecallHint => 'Recall what you just heard';

  @override
  String get blindListenControlModeAutoDesc =>
      'Auto-repeat, auto-pause, auto-next';

  @override
  String get blindListenControlModeManualDesc => 'Tap to replay, tap next';

  @override
  String get blindListenNoParagraph => 'No segmentation';

  @override
  String blindListenParagraphCount(int count) {
    return '$count segment';
  }

  @override
  String get resetLearningProgress => 'Reset Progress';

  @override
  String get resetLearningProgressConfirmTitle => 'Reset Learning Progress?';

  @override
  String resetLearningProgressConfirmMessage(String name) {
    return 'This will clear all learning progress for \"$name\". This action cannot be undone.';
  }

  @override
  String get resetLearningProgressDone => 'Learning progress has been reset';

  @override
  String get pauseLearning => 'Pause Learning';

  @override
  String get resumeLearning => 'Resume Learning';

  @override
  String get pausedChipLabel => 'Paused';

  @override
  String get pauseLearningConfirmTitle => 'Pause Learning?';

  @override
  String get pauseLearningConfirmMessage =>
      'Review scheduling for this audio will stop. You can resume anytime.';

  @override
  String reviewReminderBody(String audioName, int round) {
    return '$audioName · Review round $round is ready';
  }

  @override
  String get stageBlindListen => 'Listen without subtitles';

  @override
  String get stageIntensiveListen => 'Listen sentence by sentence';

  @override
  String get stageListenAndRepeat => 'Listen & Repeat';

  @override
  String get stageRetell => 'Listen & Retell';

  @override
  String get stageReviewDifficultPractice => 'Practice saved sentences';

  @override
  String get stageBookmarkReview => 'Sentence Review';

  @override
  String get stageFlashcard => 'Word Review';

  @override
  String stageBreakdownTitle(String date) {
    return '$date';
  }

  @override
  String get stageBreakdownToday => ' (Today)';

  @override
  String get stageBreakdownTotal => 'Total';

  @override
  String get stageBreakdownLessThanOneMin => '<1m';

  @override
  String get stageBreakdownListenShort => 'Listen';

  @override
  String get stageBreakdownSpeakShort => 'Speak';

  @override
  String get stageBreakdownNoStageData =>
      'Detailed breakdown data starts recording from this version';

  @override
  String get stageBreakdownNoRecord => 'No study record for this day';

  @override
  String get chartLegendListening => 'Listening';

  @override
  String get chartLegendSpeaking => 'Speaking';

  @override
  String get chartLegendOther => 'Other';

  @override
  String get chartLegendOtherHint => 'Thinking, pauses, etc.';

  @override
  String get reminderSectionTitle => 'Reminders';

  @override
  String get reminderSettings => 'Review Reminder';

  @override
  String get savedReviewReminderSection => '‘Saved’ Review Reminder';

  @override
  String get savedReviewReminderToggle => 'Saved Content Reminder';

  @override
  String get savedReviewReminderTime => 'Daily Reminder Time';

  @override
  String get savedReviewReminderDescription =>
      'Review saved content during commute or before bed for best results';

  @override
  String get audioReviewReminderSection => 'Audio Review Reminder';

  @override
  String get audioReviewReminderToggle => 'Audio Due Reminder';

  @override
  String get audioReviewReminderDescription =>
      'Get notified when it\'s time to review, helping you stay on track';

  @override
  String get notificationPromptTitle => 'Lock in what you\'ve learned';

  @override
  String get notificationPromptBody =>
      'Memory sticks when you review at the right moments. We\'ll nudge you only when it matters.';

  @override
  String get notificationPromptTitleLearning => 'Review while it\'s fresh';

  @override
  String get notificationPromptBodyLearning =>
      'Turn on reminders — we\'ll nudge you at the right time to reinforce what you just learned.';

  @override
  String get notificationPromptTitleBookmark =>
      'Don\'t forget your saved items';

  @override
  String get notificationPromptBodyBookmark =>
      'Turn on reminders to review your saved content on a regular schedule.';

  @override
  String get notificationPromptCtaGrant => 'Turn on reminders';

  @override
  String get notificationPromptCtaDismiss => 'Maybe later';

  @override
  String get notificationDisabledBanner =>
      'Notifications are off. You won\'t receive review reminders.';

  @override
  String get notificationDisabledBannerCta => 'Open Settings';

  @override
  String get notificationNotGrantedBanner =>
      'Allow notifications to receive daily review reminders.';

  @override
  String get notificationNotGrantedBannerCta => 'Turn on';

  @override
  String recentCompletions(int count) {
    return 'Recently Completed ($count)';
  }

  @override
  String get recentCompletionsSummary => 'Past 24 hours';

  @override
  String get timeAgoJustNow => 'Just now';

  @override
  String timeAgoMinutes(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeAgoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String get exportAudio => 'Export Audio';

  @override
  String get exportAudioFile => 'Audio';

  @override
  String get exportSubtitleFile => 'Subtitles';

  @override
  String get exportSelectFiles => 'Select files to export';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get pdfExporting => 'Generating PDF…';

  @override
  String pdfExportFailed(String error) {
    return 'Failed to export PDF: $error';
  }

  @override
  String pdfMetaDuration(String duration) {
    return 'Duration $duration';
  }

  @override
  String pdfMetaSentences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sentences',
      one: '1 sentence',
    );
    return '$_temp0';
  }

  @override
  String pdfMetaWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String get pdfAppendixTitle => 'Appendix · Sentence Analysis';

  @override
  String get pdfPreviewTitle => 'Export Preview';

  @override
  String get pdfShare => 'Share';

  @override
  String get pdfOptionTranslation => 'Translations of saved sentences';

  @override
  String get pdfOptionVocab => 'meanings of saved words';

  @override
  String get pdfOptionAnalysis => 'Key Sentence Analysis';

  @override
  String get pdfExportReminderTitle => 'The PDF is your review notes';

  @override
  String get pdfExportReminderMessage =>
      'We recommend exporting the PDF after completing your First Round.\n\n listening sentence by sentence, repeating, and listening without subtitles help you master what you heard, and the PDF collects the translations and analysis of saved sentences, and saved words for later review.';

  @override
  String get pdfExportReminderConfirm => 'Got it';

  @override
  String get exportData => 'Export Data';

  @override
  String get exportDataSubtitle => 'Export all data to a ZIP file';

  @override
  String get importData => 'Import Data';

  @override
  String get importDataSubtitle => 'Restore data from a backup file';

  @override
  String get exporting => 'Exporting...';

  @override
  String get importing => 'Importing...';

  @override
  String get exportSuccess => 'Export complete';

  @override
  String get importSuccess => 'Import complete';

  @override
  String get importConfirmTitle => 'Confirm Import';

  @override
  String get importConfirmMessage =>
      'This will replace all current data, including learning progress, saved items, and audio files. This action cannot be undone.';

  @override
  String get backupTime => 'Backup time';

  @override
  String get backupVersion => 'App version';

  @override
  String get backupFileCount => 'Media files';

  @override
  String get backupSize => 'Total size';

  @override
  String get importIncompatible =>
      'This backup was created with a newer version of the app. Please update the app first.';

  @override
  String get importInvalidFile => 'Invalid backup file';

  @override
  String get exportingDatabase => 'Exporting database...';

  @override
  String get exportingPreferences => 'Exporting preferences...';

  @override
  String get exportingMedia => 'Exporting media files...';

  @override
  String get exportingPacking => 'Packing backup file...';

  @override
  String get importingExtracting => 'Extracting backup...';

  @override
  String get importingMedia => 'Restoring media files...';

  @override
  String get importingDatabase => 'Restoring database...';

  @override
  String get importingPreferences => 'Restoring preferences...';

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get backupAndRestoreSubtitle =>
      'Restore your learning data after reinstalling or changing devices';

  @override
  String get backupData => 'Back Up';

  @override
  String get backupDataSubtitle =>
      'Back up learning data, media, and offline dictionaries';

  @override
  String get restoreData => 'Restore';

  @override
  String get restoreDataSubtitle => 'Restore all data from a local backup file';

  @override
  String get backupReadyTitle => 'Backup file is ready';

  @override
  String get backupFileName => 'File name';

  @override
  String get restoreOverwriteTitle => 'Overwrite and restore all data?';

  @override
  String get restoreOverwriteMessage =>
      'This will overwrite learning data, settings, audio files, subtitles, and dictionaries on this device. This action cannot be undone.';

  @override
  String get restoreOverwriteAction => 'Overwrite & Restore';

  @override
  String get exportingResources => 'Backing up offline dictionaries...';

  @override
  String get importingResources => 'Restoring offline dictionaries...';

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get activityCalendar => 'Activity Calendar';

  @override
  String get noActivityThisMonth => 'No learning activity this month';

  @override
  String monthlySummaryTitle(String month) {
    return '$month Statistics';
  }

  @override
  String get monthlyTotal => 'Total';

  @override
  String get monthlyActiveDays => 'Active days';

  @override
  String get monthlyAvgPerDay => 'Avg/day';

  @override
  String get monthlyBestStreak => 'Best streak';

  @override
  String daysSuffix(int days) {
    return '${days}d';
  }

  @override
  String activeDaysFraction(int active, int total) {
    return '$active/$total days';
  }

  @override
  String get senseGroupSplit => 'Split into Sense Groups';

  @override
  String get senseGroupLoading => 'Splitting...';

  @override
  String get senseGroupSingleGroup => 'This sentence is a single sense group';

  @override
  String get senseGroupSave => 'Save';

  @override
  String get senseGroupSaved => 'Saved';

  @override
  String get annotationBtnSenseGroup => 'Sense Groups';

  @override
  String get annotationBtnSenseGroupMedium => 'Larger chunks';

  @override
  String get annotationBtnSenseGroupFine => 'Smaller chunks';

  @override
  String get annotationBtnTranslation => 'Translation';

  @override
  String get annotationBtnAnalysis => 'Analysis';

  @override
  String get senseGroupLoadFailed =>
      'Sense group splitting failed, please retry';

  @override
  String get senseGroupSignInRequiredTitle => 'Sign in to use AI features';

  @override
  String get senseGroupSignInRequiredMessage =>
      'AI translation, analysis, and sense group splitting use the cloud AI service. Sign in to generate new results. Cached results remain available.';

  @override
  String get senseGroupSyntheticTimingNoticeTitle => 'Timing may be inaccurate';

  @override
  String get senseGroupSyntheticTimingNoticeMessage =>
      'This sense group playback timing is estimated from your uploaded subtitles and may be inaccurate.';

  @override
  String get transcriptionSignInRequiredTitle =>
      'Sign in to use AI transcription';

  @override
  String get transcriptionSignInRequiredMessage =>
      'AI transcription uses the cloud transcription service. Sign in to transcribe audio with AI.';

  @override
  String get senseGroupNotAvailable =>
      'Sense group playback is not available for this audio yet';

  @override
  String get wordTimestampsNotFound =>
      'Word-level timestamps not found. Please restart the app to retry.';

  @override
  String get recycleBinTitle => 'Recycle Bin';

  @override
  String get recycleBinEmpty => 'No removed items';

  @override
  String get recycleBinClearAll => 'Clear All';

  @override
  String recycleBinClearAllConfirm(int count) {
    return 'Permanently delete all $count items? This cannot be undone.';
  }

  @override
  String get recycleBinRestore => 'Restore';

  @override
  String get recycleBinDelete => 'Delete';

  @override
  String get recycleBinSortTimeDesc => 'Recently Removed';

  @override
  String get recycleBinSortTimeAsc => 'Oldest Removed';

  @override
  String recycleBinItemCount(int count) {
    return '$count items';
  }

  @override
  String get importList => 'Import List';

  @override
  String filesSelected(int count) {
    return '$count files selected';
  }

  @override
  String processingFileOf(int current, int total) {
    return 'Processing $current of $total...';
  }

  @override
  String importingFileProgress(int current, int total, String name) {
    return 'Importing $current/$total: $name';
  }

  @override
  String multipleAudioAdded(int count) {
    return '$count audio files added';
  }

  @override
  String audioImportedCount(int count) {
    return '$count audio files imported';
  }

  @override
  String audioImportedWithSubtitleCount(int count) {
    return '$count with subtitles';
  }

  @override
  String duplicatesSkipped(int count) {
    return 'Skipped $count duplicates';
  }

  @override
  String get duplicatesSkippedDetail =>
      'The following audio files have identical content to those already in this collection and were skipped:';

  @override
  String duplicateExistingFileName(String name) {
    return 'Duplicate file name: $name';
  }

  @override
  String duplicateOfExisting(String name) {
    return 'Same content as \"$name\"';
  }

  @override
  String get removeFile => 'Remove';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get dictionaryDownloading => 'Downloading dictionary...';

  @override
  String get dictionaryDownloadFailed => 'Dictionary download failed';

  @override
  String get dictionaryNotDownloaded => 'Dictionary not yet downloaded';

  @override
  String dictionaryBaseFormHint(String lemma) {
    return 'Showing results for base form “$lemma”';
  }

  @override
  String get download => 'Download';

  @override
  String get retry => 'Retry';

  @override
  String get guideNext => 'Next';

  @override
  String get guideDone => 'Done';

  @override
  String get guideLibraryCollectionListDescription =>
      'This is your collection list. Collections let you sort audios by topic — tap any collection to see the audio files in it.';

  @override
  String get guideLibraryCollectionMenuDescription =>
      'Tap here to pin, rename, or delete this collection.';

  @override
  String get guideLibraryCreateCollectionDescription =>
      'Tap here to create a new collection.';

  @override
  String get guideCollectionAudioListDescription =>
      'Tap any audio to view its practice plan and current progress.';

  @override
  String get guideCollectionAudioMenuDescription =>
      'Tap here to manage this audio\'s subtitles, the collection it belongs to, tags, and more.';

  @override
  String get guideCollectionUploadDescription =>
      'Tap here to upload your own audio.';

  @override
  String get guidePlanAddSubtitleTitle => 'Add subtitles';

  @override
  String get guidePlanAddSubtitleDescription =>
      'Generate subtitles with AI in one tap, or upload a local subtitle file. You can start practicing this audio right after.';

  @override
  String get guidePlanAiTranscriptionTitle => 'Use AI transcription';

  @override
  String get guidePlanAiTranscriptionDescription =>
      'If you do not have a subtitle file, AI transcription is the fastest way.';

  @override
  String get guidePlanStartTranscriptionDescription =>
      'Tap here to let AI generate subtitles for this audio.';

  @override
  String get guidePlanFreePlayTitle => 'Listen Your Way';

  @override
  String get guidePlanFreePlayDescription =>
      'A flexible, all-in-one audio player for listening in your own way and at your own pace.';

  @override
  String get guidePlanStartLearningTitle => 'Follow the default practice plan';

  @override
  String get guidePlanStartLearningDescription =>
      'Tap here to follow the default practice plan step by step. Echo Loop will guide you and remind you to review at the right time.';

  @override
  String get guidePlanPauseLearningTitle => 'Pause learning';

  @override
  String get guidePlanPauseLearningDescription =>
      'If you no longer want to practice this audio, tap here to pause anytime. Review reminders will stop, and you can resume with one tap later.';

  @override
  String get guideRetellSkipTitle => 'Skip retelling this time';

  @override
  String get guideRetellSkipDescription =>
      'Retelling builds spoken English fast. If you want to focus on listening for now, tap here to skip this step.';

  @override
  String get learningProgressLoadFailed =>
      'Failed to load learning progress. Please try again later.';

  @override
  String get guideMainShellVisitLibraryTitle => 'Start from Library';

  @override
  String get guideMainShellVisitLibraryDescription =>
      'Tap here to learn how to use this app.';

  @override
  String get guideStudyTasksOverviewTitle => 'Your study tasks';

  @override
  String get guideStudyTasksOverviewDescription =>
      'This area includes new audio to practice, due reviews, completed tasks, and more. Echo Loop will pace your learning for you.';

  @override
  String get guideStudyStatsHeaderTitle => 'Today at a glance';

  @override
  String get guideStudyStatsHeaderDescription =>
      'Your listening time, speaking practice time, and new vocabulary for today are all summarized here. Tap a card or bar for a more detailed breakdown.';

  @override
  String get guideStudyStreakDescription =>
      'Tap here to open your activity calendar. Check in every day and build a good learning habit little by little.';

  @override
  String guideFavoritesSentencesListDescription(String dumbbellIcon) {
    return 'Your saved sentences, grouped by source audio. Tap $dumbbellIcon to review all the saved sentences from the same audio at once.';
  }

  @override
  String get guideFavoritesSentencesReviewDescription =>
      'Tap here to review every saved sentence at once.';

  @override
  String get guideFavoritesVocabularyListDescription =>
      'Your saved words, phrases, and sense groups. Expand a flashcard to view meanings of a saved item and hear it in its original sentence.';

  @override
  String get guideFavoritesFlashcardDescription =>
      'Tap here to enter flashcard mode and review every saved words. Viewing the word and hearing it in context makes memory stick.';

  @override
  String get guideIntensiveListenCantUnderstandDescription =>
      'Tap here when a sentence is hard to follow. It will be auto-saved and you\'ll enter the explanation mode.';

  @override
  String get guideSentenceTileNumberDescription =>
      'Tap the number to play from this sentence.';

  @override
  String get guideSentenceTileBodyDescription =>
      'Tap the sentence to view explanations.';

  @override
  String get guideSubtitleEditorBoundaryHandleDescription =>
      'Drag the red or green handles on the waveform to adjust the current sentence\'s start and end time.';

  @override
  String get guideSubtitleEditorSentencePlayDescription =>
      'Tap the play button on the left to play this sentence.';

  @override
  String get guideSubtitleEditorSentenceMenuDescription =>
      'Tap the menu on the right to merge or delete this sentence.';

  @override
  String get guideSentenceAnnotationSentenceDescription =>
      'Tap any word to open the dictionary; long-press the sentence to copy the text.';

  @override
  String get guideSentenceAnnotationSenseGroupDescription =>
      'Break the sentence into sense groups to make long, complex lines easier to follow.';

  @override
  String get guideSentenceAnnotationTranslationDescription =>
      'Translate this sentence into your native language.';

  @override
  String get guideSentenceAnnotationAnalysisDescription =>
      'Check the grammar, key phrases and listening tips for this sentence.';

  @override
  String get resetNewUserGuide => 'Reset New User Guide';

  @override
  String get resetNewUserGuideSubtitle =>
      'Clear all guide seen states for testing';

  @override
  String get resetNewUserGuideDone => 'New user guide has been reset';

  @override
  String get newUserGuideToggle => 'New User Guide';

  @override
  String get newUserGuideSubtitle =>
      'Show step-by-step tips on first use of each page';

  @override
  String get newUserGuideResetAction => 'Reset';

  @override
  String get resetOnboarding => 'Reset Onboarding Survey';

  @override
  String get resetOnboardingDone =>
      'Onboarding reset; please restart the app to retake the survey';

  @override
  String get discoverOfficialCollections => 'Discover Curated Collections';

  @override
  String get discoverEmpty => 'No curated collections yet';

  @override
  String get discoverLoadFailed => 'Failed to load, tap to retry';

  @override
  String get discoverRetry => 'Retry';

  @override
  String get discoverPodcastEntryTitle => 'Podcasts';

  @override
  String discoverPodcastEntrySubtitle(int count) {
    return '$count podcasts. Subscribe to keep new episodes in your library.';
  }

  @override
  String get discoverPodcastTitle => 'Curated Podcasts';

  @override
  String get discoverPodcastEmpty => 'No curated podcasts yet';

  @override
  String get podcastCatalogSignInRequiredMessage =>
      'Sign in to add curated podcasts to My Collections and keep learning future episodes.';

  @override
  String get podcastCatalogSubscribeFailed =>
      'Failed to add. Some RSS feeds or Apple Podcasts may be unavailable on the current network. Try again later or switch networks.';

  @override
  String get podcastEnrollNeededTitle => 'Add Podcast First';

  @override
  String get podcastEnrollNeededMessage =>
      'Add this podcast to My Collections, then you can download and learn this episode.';

  @override
  String get podcastPreviewNetworkFailed =>
      'Could not fetch podcast content. Apple Podcasts or some RSS feeds may be unavailable on the current network. Try again later or switch networks.';

  @override
  String get podcastPreviewAppleFailed =>
      'Could not recognize the Apple Podcast link. The current network may not reach Apple\'s podcast lookup service. Try again later or switch networks.';

  @override
  String get podcastPreviewParseFailed =>
      'This podcast feed format is not supported, so the episode list could not be read.';

  @override
  String get podcastFeedBlocked =>
      'This podcast source is blocking automated access on the current network. Try again later or switch to a different network.';

  @override
  String get podcastPreviewEmpty => 'No episodes were found yet.';

  @override
  String get officialBadge => 'Curated';

  @override
  String get officialDeprecatedBadge => 'Removed';

  @override
  String get addToMyCollections => 'Add to My Collections';

  @override
  String get officialCollectionSignInRequiredTitle =>
      'Sign in to add collections';

  @override
  String get officialCollectionSignInRequiredMessage =>
      'Sign in to add any curated collections to My Collections and sync new episodes.';

  @override
  String get goLearn => 'Start Practicing';

  @override
  String get removeFromMyCollections => 'Remove from My Collections';

  @override
  String get enrollNeededTitle => 'Add Collection First';

  @override
  String get enrollNeededMessage =>
      'Add this collection to My Collection, then you can start practicing.';

  @override
  String get enrollSucceeded => 'Added to My Collections';

  @override
  String get enrollFailed =>
      'Failed to add, please check your network and retry';

  @override
  String removeOfficialConfirmTitle(String name) {
    return 'Remove \"$name\"?';
  }

  @override
  String get removeOfficialConfirmMessage =>
      'All audio files, their subtitles, and learning records in this collection will be deleted. This cannot be undone.';

  @override
  String get removeOfficialConfirmConfirm => 'Remove';

  @override
  String get officialCollectionDeprecated =>
      'This collection has been removed. You can still use the local copy.';

  @override
  String get downloadCancel => 'Cancel Download';

  @override
  String get downloadLater => 'Later';

  @override
  String downloadCompleted(String name) {
    return '$name downloaded';
  }

  @override
  String downloadFailed(String name) {
    return '$name download failed, please retry';
  }

  @override
  String get updateOfficialSubtitle => 'Update Subtitles';

  @override
  String get updateOfficialSubtitleConfirm => 'Update subtitles?';

  @override
  String get updateOfficialSubtitleWarning =>
      'Updating subtitles means replacing the local subtitles and clearing all saved sentences and learning progress of this audio.';

  @override
  String get officialSubtitleUpdated => 'Subtitles updated';

  @override
  String get officialSubtitleUpdateFailed =>
      'Subtitles update failed, please retry';

  @override
  String downloadInProgressSnackbar(String name) {
    return 'Downloading $name, please wait';
  }

  @override
  String get downloadLoading => 'Loading';

  @override
  String get audioListColumnName => 'Name';

  @override
  String get audioListColumnDuration => 'Duration';

  @override
  String get onboardingTitle => 'Quick chat';

  @override
  String get onboardingSubtitle => '10 seconds to tailor your practice';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingExamPrompt =>
      'Which exam are you currently preparing for?';

  @override
  String get onboardingExamGaokao => 'the Gaokao';

  @override
  String get onboardingExamCet => 'CET-4 / CET-6';

  @override
  String get onboardingExamTem => 'TEM-4 / TEM-8';

  @override
  String get onboardingExamIelts => 'IELTS';

  @override
  String get onboardingExamToefl => 'TOEFL';

  @override
  String get onboardingExamOther => 'Other';

  @override
  String onboardingProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingDone => 'Done';

  @override
  String get onboardingFinishedTitle => 'All set';

  @override
  String get onboardingFinishedHint =>
      'We\'ll tailor practice to your goals and pace.';

  @override
  String get onboardingSummaryEyebrow => 'Did you know?';

  @override
  String get onboardingSummaryHeadline =>
      'Improving listening & speaking\nisn\'t about practicing with more materials,\nit\'s about practicing more thoroughly.';

  @override
  String get onboardingSummaryPoint1 =>
      'Practice with audio that matches your level';

  @override
  String get onboardingSummaryPoint2 =>
      'Understand what you hear in chunks and master vocabulary in context.';

  @override
  String get onboardingSummaryPoint3 =>
      'Develop a natural feel for English through extensive close listening and repetition.';

  @override
  String get onboardingSummaryPoint4 =>
      'Practice speaking through retelling, and turn what you hear into what you can say.';

  @override
  String get onboardingStart => 'Start Practicing';

  @override
  String get onboardingQ1Prompt =>
      'What\'s your main goal for improving your English listening & speaking?';

  @override
  String get onboardingQ1OptionExam => 'For an exam';

  @override
  String get onboardingQ1OptionDaily => 'Daily conversation';

  @override
  String get onboardingQ1OptionWork => 'Work';

  @override
  String get onboardingQ1OptionTravel => 'Travel abroad';

  @override
  String get onboardingQ1OptionContent => 'Understanding videos & podcasts';

  @override
  String get onboardingQ1OptionOther => 'Other';

  @override
  String get onboardingQ2Prompt => 'How long do you plan to practice each day?';

  @override
  String get onboardingQ2Option5 => 'About 5 min';

  @override
  String get onboardingQ2Option10 => 'About 10 min';

  @override
  String get onboardingQ2Option20 => 'About 20 min';

  @override
  String get onboardingQ2Option30 => '30 min or more';

  @override
  String get onboardingQ2OptionFlexible => 'It varies';

  @override
  String get onboardingQ3Prompt => 'How did you hear about us?';

  @override
  String get onboardingQ3OptionAppStore => 'App Store';

  @override
  String get onboardingQ3OptionGooglePlay => 'Google Play';

  @override
  String get onboardingQ3OptionYoutube => 'YouTube';

  @override
  String get onboardingQ3OptionReddit => 'Reddit';

  @override
  String get onboardingQ3OptionXTwitter => 'X / Twitter';

  @override
  String get onboardingQ3OptionTiktok => 'TikTok';

  @override
  String get onboardingQ3OptionInstagram => 'Instagram';

  @override
  String get onboardingQ3OptionXiaohongshu => 'Xiaohongshu';

  @override
  String get onboardingQ3OptionWechat => 'WeChat';

  @override
  String get onboardingQ3OptionDouyin => 'Douyin';

  @override
  String get onboardingQ3OptionKuaishou => 'Kuaishou';

  @override
  String get onboardingQ3OptionBilibili => 'Bilibili';

  @override
  String get onboardingQ3OptionBaiduSearch => 'Baidu search';

  @override
  String get onboardingQ3OptionGoogleSearch => 'Google search';

  @override
  String get onboardingQ3OptionGithub => 'GitHub';

  @override
  String get onboardingQ3OptionFriend => 'word of mouth';

  @override
  String get onboardingQ3OptionOther => 'Other';

  @override
  String get onboardingPermissionsHint =>
      'To ensure the best experience, we\'ll request these permissions';

  @override
  String get onboardingPermissionsNotification => 'Notifications';

  @override
  String get onboardingPermissionsMicrophone => 'Microphone';

  @override
  String get onboardingPermissionsSpeech => 'Speech recognition';

  @override
  String get playbackSection => 'Playback';

  @override
  String get learningSection => 'Learning';

  @override
  String get learningSettings => 'Learning Settings';

  @override
  String get speakingPracticeSection => 'Speaking practice';

  @override
  String get autoSkipRetellToggle => 'Auto-skip retelling practice';

  @override
  String get autoSkipRetellSubtitle =>
      'Auto-skip retelling tasks in your learning plan';

  @override
  String get autoExpandCachedAnnotationToggle =>
      'Auto-expand Sentence Analysis';

  @override
  String get autoExpandCachedAnnotationSubtitle =>
      'Auto-show cached translation, analysis and sense groups';

  @override
  String get autoShowAiExplanationToggle => 'Auto-show AI explanations';

  @override
  String get autoShowAiExplanationSubtitle =>
      'Automatically show selected AI help when you enter sentence explanations';

  @override
  String get autoShowAiAnalysisToggle => 'AI Analysis';

  @override
  String get autoShowAiTranslationToggle => 'AI Translation';

  @override
  String get autoShowAiSenseGroupsToggle => 'AI Sense Groups';

  @override
  String get autoPlayRetellRecordingToggle => 'Auto-play retelling recording';

  @override
  String get autoPlayRetellRecordingSubtitle =>
      'After each retelling, automatically play your recording for pronunciation review';

  @override
  String get listenAndRepeatRatingToggle => 'Show rating after each repeat';

  @override
  String get listenAndRepeatRatingSubtitle =>
      'When off, recordings are kept but recognition and scoring are skipped';

  @override
  String get retellRatingToggle => 'Show rating after each retelling';

  @override
  String get retellRatingSubtitle =>
      'When off, your recording can still be played back, but scores aren\'t shown';

  @override
  String get retellSkip => 'Skip';

  @override
  String get retellSkippedSuffix => 'Skipped';

  @override
  String get skipSilenceTitle => 'Auto-skip Silence';

  @override
  String get skipSilenceDescription => 'Skip long silences between sentences';

  @override
  String get silenceThreshold => 'Silence Threshold';

  @override
  String silenceThresholdValue(int seconds) {
    return '${seconds}s';
  }

  @override
  String silenceSkipped(int seconds) {
    return 'Skipped ${seconds}s of silence';
  }

  @override
  String get speechPermDialogTitleRequest => 'Permissions Required';

  @override
  String get speechPermDialogTitleDenied => 'Permissions Denied';

  @override
  String get speechPermDialogTitleRestricted => 'Device Restricted';

  @override
  String get speechPermItemMic => 'Microphone';

  @override
  String get speechPermItemMicDesc =>
      'Record your speech for pronunciation evaluation';

  @override
  String get speechPermItemSpeech => 'Speech Recognition';

  @override
  String get speechPermItemSpeechDesc => 'Detect mispronounced words';

  @override
  String get speechPermStatusPending => 'Not granted';

  @override
  String get speechPermStatusDenied => 'Denied';

  @override
  String get speechPermDeniedHint =>
      'You once denied access. Please enable it in System Settings.';

  @override
  String get speechPermRestrictedHint =>
      'Recording is restricted on this device by parental controls or MDM.';

  @override
  String get speechPermActionGrant => 'Grant';

  @override
  String get speechPermActionOpenSettings => 'Open Settings';

  @override
  String get speechPermUnsupportedToast =>
      'Recording is not supported on this platform';

  @override
  String get authSignInTitle => 'Sign in to Echo Loop';

  @override
  String get authChooseMethod => 'Choose how you\'d like to continue.';

  @override
  String get authContinueWithEmail => 'Continue with Email Code';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authProviderComingSoon => 'Coming soon';

  @override
  String get authGoogleUnavailable =>
      'Google sign-in is unavailable on this device. Use an email code instead.';

  @override
  String get authGoogleServicesOutdated =>
      'Google services are outdated. Please update and try again.';

  @override
  String get authPasswordlessHint =>
      'No password needed. We will email you a one-time code.';

  @override
  String get authEmailTitle => 'Email sign in';

  @override
  String get authEmailOtpTitle => 'Continue with email';

  @override
  String get authEmailOtpDescription =>
      'Enter your email and we will send a one-time code.';

  @override
  String get authEmailOtpAutoCreateHint =>
      'First-time use will create your account automatically.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authOtpLabel => '6-digit code';

  @override
  String get authOtpRequired => 'Enter the 6-digit code';

  @override
  String get authOtpInvalid => 'Enter a valid 6-digit code';

  @override
  String get authOtpIncorrectOrExpired =>
      'Verification code is incorrect or expired.';

  @override
  String get authEnterOtpTitle => 'Enter code';

  @override
  String get authOtpHelpText => 'Check spam if you do not see the email.';

  @override
  String get authSendOtpButton => 'Send Code';

  @override
  String get authSendingOtp => 'Sending code';

  @override
  String get authVerifyOtpButton => 'Continue';

  @override
  String get authVerifyingOtp => 'Verifying';

  @override
  String get authResendOtpButton => 'Resend code';

  @override
  String authResendOtpCountdown(int seconds) {
    return '${seconds}s until resend';
  }

  @override
  String get authOtpResent => 'A new code has been sent.';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authConfirmPasswordLabel => 'Confirm Password';

  @override
  String get authSignInButton => 'Sign In';

  @override
  String get authSigningIn => 'Signing in';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authCreateAccountTitle => 'Create your account';

  @override
  String get authCreatingAccount => 'Creating account';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authForgotPasswordTitle => 'Reset password';

  @override
  String get authForgotPasswordDescription =>
      'Enter your email and we will send a password reset link.';

  @override
  String get authResetPasswordTitle => 'Set a new password';

  @override
  String get authResetPasswordDescription =>
      'Enter your new password to finish password recovery.';

  @override
  String get authNewPasswordLabel => 'New Password';

  @override
  String get authConfirmNewPasswordLabel => 'Confirm New Password';

  @override
  String get authUpdatePasswordButton => 'Update Password';

  @override
  String get authUpdatingPassword => 'Updating password';

  @override
  String get authSendResetLink => 'Send Reset Link';

  @override
  String get authSendingResetLink => 'Sending link';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authCheckEmailTitle => 'Check your email';

  @override
  String authCheckEmailMessage(String email) {
    return 'We sent a 6-digit code to $email.';
  }

  @override
  String get authResetEmailSent =>
      'If an account exists, a reset link has been sent.';

  @override
  String get authEmailRequired => 'Enter your email';

  @override
  String get authEmailInvalid => 'Enter a valid email';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get authConfirmPasswordRequired => 'Confirm your password';

  @override
  String get authConfirmPasswordMismatch => 'Passwords do not match';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authUnavailable => 'Authentication is not configured yet.';

  @override
  String get authUnknownError => 'Something went wrong. Try again.';

  @override
  String get authAgreeRequired =>
      'Please agree to the terms and privacy policy first.';

  @override
  String get authTermsAgreementPrefix => 'I have read and agree to the';

  @override
  String get authTermsContinuationPrefix => 'By continuing, you agree to the';

  @override
  String get authTermsJoiner => ' and ';

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authSignedInStatus => 'Signed in';

  @override
  String get authSignedOutStatus => 'Signed out';

  @override
  String get authSignedInWithApple => 'Signed in with Apple';

  @override
  String get authSignedInWithGoogle => 'Signed in with Google';

  @override
  String get authAppleAccount => 'Apple account';

  @override
  String get authGoogleAccount => 'Google account';

  @override
  String get authSignOut => 'Sign Out';

  @override
  String get editSubtitles => 'Edit subtitles';

  @override
  String get mergeWithNextSentence => 'Merge with next';

  @override
  String get deleteSentence => 'Delete sentence';

  @override
  String get editSentenceText => 'Edit Text';

  @override
  String get adjustTimestamp => 'Timestamp';

  @override
  String get editSentenceTitle => 'Edit sentence text';

  @override
  String get editSentenceLabel => 'Sentence text';

  @override
  String get timestampEditorTitle => 'Edit timestamp';

  @override
  String get timestampStart => 'Start';

  @override
  String get timestampEnd => 'End';

  @override
  String get timestampStep => 'Step';

  @override
  String get currentSentence => 'Current';

  @override
  String get sentenceDeleted => 'Sentence deleted';

  @override
  String get playSentence => 'Play sentence';

  @override
  String get stopPlayback => 'Stop playback';

  @override
  String get editWord => 'Edit word';

  @override
  String get splitSentenceHere => 'Split sentence here';

  @override
  String get wordEditAction => 'Edit';

  @override
  String get wordSplitBeforeAction => 'Split';

  @override
  String get saveSubtitleEdits => 'Save subtitle changes';

  @override
  String get subtitleStructureChangedWarning =>
      'This will clear learning progress and saved sentences of this audio.';

  @override
  String get subtitleEditsSaved => 'Subtitle changes saved.';

  @override
  String get discardSubtitleEditsTitle => 'Discard changes?';

  @override
  String get discardSubtitleEditsMessage =>
      'Your subtitle changes have not been saved.';

  @override
  String get discard => 'Discard';

  @override
  String get importAudio => 'Import Audio';

  @override
  String get importAudioFromFile => 'Import from File';

  @override
  String get importAudioFromFileDescription =>
      'Choose audio files from your device or cloud storage';

  @override
  String get importAudioFromUrl => 'Import from Link';

  @override
  String get importAudioFromUrlDescription =>
      'Paste a direct audio link and download it';

  @override
  String get importAudioFromCloudDrive => 'Import from Cloud Storage';

  @override
  String get importAudioFromBaiduNetdisk => 'Import from Baidu Netdisk';

  @override
  String get cloudDriveSourceShort => 'Cloud Storage';

  @override
  String get baiduNetdisk => 'Baidu Netdisk';

  @override
  String get baiduNetdiskAllFiles => 'All Files';

  @override
  String get baiduNetdiskWaitingAuthorization =>
      'Waiting for Baidu authorization...';

  @override
  String get baiduNetdiskLoadingFiles => 'Loading Baidu Netdisk files...';

  @override
  String get baiduNetdiskImportFailed => 'Baidu Netdisk import failed.';

  @override
  String get baiduNetdiskConnectTitle => 'Connect Baidu Netdisk';

  @override
  String get baiduNetdiskConnectDescription =>
      'Authorize Echo Loop to browse your Baidu Netdisk and import selected audio files.';

  @override
  String get baiduNetdiskConnectAction => 'Connect Baidu Netdisk';

  @override
  String get baiduNetdiskLogoutTooltip => 'Sign out of Baidu Netdisk';

  @override
  String get baiduNetdiskSelectAllAction => 'Select';

  @override
  String get baiduNetdiskClearSelectionAction => 'Clear';

  @override
  String get baiduNetdiskLogoutTitle => 'Sign out of Baidu Netdisk?';

  @override
  String get baiduNetdiskLogoutMessage =>
      'Echo Loop will clear the saved Baidu Netdisk authorization on this device.';

  @override
  String get baiduNetdiskLogoutConfirm => 'Sign Out';

  @override
  String get baiduNetdiskNoSupportedAudio =>
      'No supported audio files found in this folder.';

  @override
  String get importAudioShort => 'Import';

  @override
  String importAudioSelectedCount(int count) {
    return 'Import $count';
  }

  @override
  String importAudioAndSubtitleCount(int audioCount, int subtitleCount) {
    String _temp0 = intl.Intl.pluralLogic(
      audioCount,
      locale: localeName,
      other: '$audioCount audio files',
      one: '1 audio',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subtitleCount,
      locale: localeName,
      other: ', $subtitleCount subtitles',
      one: ', 1 subtitle',
      zero: '',
    );
    return 'Import ($_temp0$_temp1)';
  }

  @override
  String get baiduNetdiskImporting => 'Importing...';

  @override
  String baiduNetdiskImportingFile(String name) {
    return 'Importing $name...';
  }

  @override
  String baiduNetdiskImportedCount(int count) {
    return 'Imported $count from Baidu Netdisk';
  }

  @override
  String baiduNetdiskSkippedSummary(int duplicates, int failures) {
    return 'Skipped duplicates: $duplicates · Failed: $failures';
  }

  @override
  String get audioUrlLabel => 'Audio link';

  @override
  String get audioUrlHint => 'https://example.com/audio.mp3';

  @override
  String get pasteAudioLink => 'Paste Link';

  @override
  String get audioClipboardNoValidLink =>
      'Clipboard does not have a valid link';

  @override
  String get downloadAndImportAudio => 'Download and Import';

  @override
  String get audioUrlInvalid => 'Enter a valid audio link';

  @override
  String get audioUrlUnsupported => 'This link is not a supported audio format';

  @override
  String get audioUrlNotDirectAudio => 'This link is not a direct audio file';

  @override
  String get audioUrlDuplicate => 'An audio file with this name already exists';

  @override
  String get audioDownloadFailed => 'Failed to download audio';

  @override
  String get audioDownloadInProgress => 'Downloading audio';

  @override
  String get audioImportComplete => 'Import complete';

  @override
  String get audioImportCanceled => 'Audio import canceled';

  @override
  String get cancelDownload => 'Cancel Download';

  @override
  String get subscribePodcast => 'Subscribe Podcast';

  @override
  String get subscribePodcastOptionDescription =>
      'Add with Apple Podcasts or RSS';

  @override
  String get podcastUrlLabel => 'Apple Podcasts or RSS URL';

  @override
  String get podcastUrlHint =>
      'https://podcasts.apple.com/... or https://…/feed.xml';

  @override
  String get podcastSearchHint => 'Search podcasts or paste a link';

  @override
  String get podcastSearchEmpty => 'No podcasts found';

  @override
  String get podcastSearchFailed => 'Search failed, please try again';

  @override
  String get podcastSubscribeThisLink => 'Subscribe to this link';

  @override
  String get featuredPodcasts => 'Featured Podcasts';

  @override
  String get podcastSubscribing => 'Fetching podcast feed…';

  @override
  String podcastSubscribeFailed(String error) {
    return 'Failed to subscribe: $error';
  }

  @override
  String podcastRefreshFailed(String error) {
    return 'Failed to refresh: $error';
  }

  @override
  String podcastAlreadySubscribed(String name) {
    return 'Already subscribed — see Collection \"$name\"';
  }

  @override
  String get podcastRefreshFeed => 'Refresh Feed';

  @override
  String get podcastUnsubscribe => 'Unsubscribe';

  @override
  String podcastUnsubscribeConfirmTitle(String name) {
    return 'Unsubscribe from $name?';
  }

  @override
  String get podcastUnsubscribeConfirmMessage =>
      'All episodes and downloaded audio files in this collection will be deleted.';

  @override
  String get podcastFeedInfo => 'Feed Info';

  @override
  String get podcastDetails => 'Details';

  @override
  String get podcastEpisodeMeta => 'Episode Info';

  @override
  String get podcastShowMore => 'More';

  @override
  String get podcastShowLess => 'Less';

  @override
  String get podcastTitle => 'Title';

  @override
  String get podcastAuthor => 'Author';

  @override
  String get podcastDescription => 'Description';

  @override
  String get podcastFeedUrl => 'RSS URL';

  @override
  String get podcastAppleLink => 'Apple Podcasts';

  @override
  String get podcastOriginalLink => 'Link';

  @override
  String get podcastAudioType => 'Audio Type';

  @override
  String get podcastOpenLinkFailed => 'Could not open link';

  @override
  String podcastLastRefreshed(String time) {
    return 'Last refreshed: $time';
  }

  @override
  String get podcastEpisodeGuid => 'GUID';

  @override
  String get podcastEnclosureUrl => 'Audio URL';

  @override
  String get ttsSettings => 'Text-to-Speech';

  @override
  String get ttsSettingsDescription =>
      'Choose the speech engine and accent used when reading words and example sentences aloud.';

  @override
  String get ttsEngine => 'Speech Engine';

  @override
  String get ttsEnginePlatform => 'System Speech';

  @override
  String get ttsEnginePlatformApple => 'Apple AI';

  @override
  String get ttsEnginePlatformDescription =>
      'Built into your device. Fast, no download required, average quality.';

  @override
  String get ttsEngineEchoLoop => 'Echo Loop AI (Advanced)';

  @override
  String get ttsEngineComingSoon => 'Coming soon';

  @override
  String get ttsEngineEchoLoopDescription =>
      'Best sound quality. Needs a model download; recommended for high-performance devices.';

  @override
  String get ttsEnginePiper => 'Echo Loop AI (Balanced)';

  @override
  String get ttsEnginePiperDescription =>
      'Natural, smooth sound. Needs a model download; recommended for mid-range devices.';

  @override
  String get ttsModel => 'Model';

  @override
  String get ttsModelHighQuality => 'High quality';

  @override
  String get ttsModelHighQualityDescription =>
      'Best sound at acceptable speed. About 300 MB.';

  @override
  String get ttsModelLite => 'Lightweight';

  @override
  String get ttsModelLiteDescription =>
      'Small and memory-friendly for low-end devices, but slower. About 100 MB.';

  @override
  String get ttsModelRecommended => 'Recommended';

  @override
  String get ttsModelNotDownloaded => 'Not downloaded';

  @override
  String get ttsAccent => 'Accent';

  @override
  String get ttsAccentUs => 'American';

  @override
  String get ttsAccentUk => 'British';

  @override
  String get ttsAccentHint =>
      '(Some devices don\'t distinguish American from British)';

  @override
  String get ttsVoice => 'Voice';

  @override
  String get ttsVoiceFemale => 'Female';

  @override
  String get ttsVoiceMale => 'Male';

  @override
  String get ttsDeleteModel => 'Delete model';

  @override
  String get ttsDeleteModelConfirm =>
      'Delete the Echo Loop voice model? You can re-download it anytime.';

  @override
  String get ttsCancelDownload => 'Cancel';

  @override
  String get ttsDownloadedModelsTitle => 'Downloaded Echo Loop models';

  @override
  String ttsDownloadedModelsDesc(String size) {
    return 'Not in use · $size';
  }

  @override
  String get asrDeleteAllModelsConfirm =>
      'Delete all downloaded Echo Loop speech recognition models? You can re-download them anytime.';

  @override
  String get asrDownloadedModelsTitle => 'Downloaded speech recognition models';

  @override
  String asrDownloadedModelsDesc(String size) {
    return 'Not in use · $size';
  }

  @override
  String get dictionarySettings => 'Dictionary Settings';

  @override
  String get dictionaryDefault => 'Default Dictionary';

  @override
  String get dictionaryDefaultDescription =>
      'Dictionary shown by default when looking up a word';

  @override
  String get dictionarySources => 'Dictionary Sources';

  @override
  String get dictionarySourcesDescription =>
      'Disabled dictionaries won\'t appear in the lookup switcher';

  @override
  String get dictionaryWebAdsNotice =>
      'Online dictionary ads are not affiliated with Echo Loop.';

  @override
  String get dictSourceLocal => 'Local Dictionary';

  @override
  String get dictSourceAi => 'AI Dictionary';

  @override
  String get dictSourceCambridge => 'Cambridge';

  @override
  String get dictSourceAlwaysOn => 'Always on';

  @override
  String dictSourceCannotDisable(String name) {
    return '$name is a base source and can\'t be disabled';
  }

  @override
  String get dictDefaultBadge => 'Default';

  @override
  String dictSwitcherSemantics(String name) {
    return 'Switch dictionary, currently $name';
  }

  @override
  String get cambridgeNotFound => 'Not found in Cambridge';

  @override
  String get dictTryOtherSource => 'Try another dictionary';

  @override
  String get dictCambridgeOpenInBrowser => 'Open in browser';

  @override
  String get aiNoAnalysis => 'No AI analysis available';

  @override
  String get aiSignInRequired => 'Sign in to use the AI dictionary';

  @override
  String get dictPhraseTooLong =>
      'The phrase is too long. Select up to 8 words.';

  @override
  String get ttsPlayUk => 'Play UK pronunciation';

  @override
  String get ttsPlayUs => 'Play US pronunciation';

  @override
  String get dictAiSynonyms => 'Synonyms';

  @override
  String get dictAiAntonyms => 'Antonyms';

  @override
  String get dictAiExpressions => 'collocation ';

  @override
  String get dictAiWordFamily => 'Word Family';

  @override
  String get dictAiForms => 'Word Forms';

  @override
  String get dictAiEtymology => 'Etymology';

  @override
  String get dictAiTips => 'Learning Tips';

  @override
  String get dictAiMultiKeyPoints => 'Study Notes';

  @override
  String get dictAiMultiMeanings => 'Meanings & Examples';

  @override
  String get dictAiMultiNaturalness => 'Correction';

  @override
  String get dictAiMultiPronunciationTips => 'Pronunciation';

  @override
  String get dictAiMultiSimilarExpressions => 'Similar Expressions';

  @override
  String get dictAiMultiBackground => 'Background Knowledge';

  @override
  String get chatOpenTooltip => 'Ask AI';

  @override
  String get chatSentenceTitle => 'AI Tutor';

  @override
  String get chatInputPlaceholder => 'Ask anything…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatClear => 'Clear chat';

  @override
  String get chatNewChat => 'New chat';

  @override
  String get chatRegenerate => 'Regenerate';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatEditTitle => 'Edit message';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCopied => 'Copied';

  @override
  String chatContextLabel(String summary) {
    return 'Discussing: $summary';
  }

  @override
  String get chatEmptyGreeting => 'Ask me anything about this sentence.';

  @override
  String get chatErrorNetwork => 'Network unavailable. Tap to retry.';

  @override
  String get chatErrorGenerate => 'Generation failed. Tap to retry.';

  @override
  String get chatQuotaTitle => 'Free quota used up';

  @override
  String get chatUpgrade => 'Upgrade';

  @override
  String get chatSignInTitle => 'Sign in required';

  @override
  String get chatSignInMessage => 'Sign in to use the AI Assistant.';

  @override
  String get chatScrollToBottom => 'Scroll to bottom';

  @override
  String get chatThinking => 'Thinking…';

  @override
  String get chatFollowUp => 'Ask AI';

  @override
  String get chatFollowUpExplain => 'Explain';

  @override
  String get chatFollowUpTranslate => 'Translate';

  @override
  String get chatFollowUpExample => 'Example';

  @override
  String get chatFollowUpInstruction =>
      'Answer the question based strictly on the quoted text below.';

  @override
  String get chatQuoteRemove => 'Remove quote';

  @override
  String get retellAiReviewTooltip => 'AI review';

  @override
  String get retellAiReviewTitle => 'AI Retell Review';

  @override
  String get retellAiReviewKeyPoints => 'Key point coverage';

  @override
  String get retellAiReviewLabelOriginal => 'Original';

  @override
  String get retellAiReviewLabelYouSaid => 'You said';

  @override
  String get retellAiReviewLabelTip => 'Tip';

  @override
  String get retellAiReviewSuggestion => 'Suggestion';

  @override
  String get retellAiReviewStatusCovered => 'Covered';

  @override
  String get retellAiReviewStatusPartial => 'Partial';

  @override
  String get retellAiReviewStatusMissed => 'Missed';

  @override
  String get retellAiReviewStatusDistorted => 'Distorted';

  @override
  String get retellAiReviewStatusAdded => 'Added';

  @override
  String get retellAiReviewCorrections => 'Expression corrections';

  @override
  String get retellAiReviewCorrectionTypeGrammar => 'Grammar';

  @override
  String get retellAiReviewCorrectionTypeWordChoice => 'Word choice';

  @override
  String get retellAiReviewCorrectionTypeRedundancy => 'Wordy';

  @override
  String get retellAiReviewCorrectionTypePhrasing => 'Phrasing';

  @override
  String get retellAiReviewCorrectionTypeCohesion => 'Cohesion';

  @override
  String get retellAiReviewEvaluating => 'Evaluating…';

  @override
  String get retellAiReviewGenerating => 'Generating…';

  @override
  String get retellAiReviewRetry => 'Retry';

  @override
  String get retellAiReviewError =>
      'The AI review could not be completed. Please try again.';

  @override
  String get retellAiReviewAudioPreparationError =>
      'Couldn\'t prepare the recording for AI review.';

  @override
  String get retellAiReviewAudioTooLarge =>
      'The prepared recording exceeds the 2 MB limit.';

  @override
  String get retellAiReviewPlayRecording => 'Play recording';

  @override
  String get retellAiReviewStopRecording => 'Stop recording';
}
