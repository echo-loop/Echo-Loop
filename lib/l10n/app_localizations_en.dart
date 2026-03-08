// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fluency';

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
  String get transcript => 'Transcript';

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

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get hotkeyReplay => 'R: Replay';

  @override
  String get hotkeyPlayPause => 'Space: Play/Pause';

  @override
  String get hotkeyToggleTranscript => '↑: Show/Hide Transcript';

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
  String get pickTranscriptFileFailed => 'Failed to select transcript file';

  @override
  String get fileExists => 'File Exists';

  @override
  String fileExistsMessage(String name) {
    return 'An audio file named \"$name\" already exists. Please delete the original audio first.';
  }

  @override
  String get ok => 'OK';

  @override
  String addedOn(String date) {
    return 'Added: $date';
  }

  @override
  String get collections => 'Collections';

  @override
  String get collection => 'Collection';

  @override
  String get createCollection => 'Create Collection';

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
    return 'Are you sure you want to delete \"$name\"? Audio files in this collection will not be deleted.';
  }

  @override
  String get renameCollection => 'Rename';

  @override
  String get starCollection => 'Star';

  @override
  String get unstarCollection => 'Unstar';

  @override
  String get starAudio => 'Star';

  @override
  String get unstarAudio => 'Unstar';

  @override
  String get sortByNameAsc => 'Name (A-Z)';

  @override
  String get sortByNameDesc => 'Name (Z-A)';

  @override
  String get sortByDateAsc => 'Oldest First';

  @override
  String get sortByDateDesc => 'Newest First';

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
  String get favorites => 'Favorites';

  @override
  String get profile => 'Profile';

  @override
  String get studyComingSoon => 'Study feature coming soon';

  @override
  String get favoritesComingSoon => 'Favorites feature coming soon';

  @override
  String get learningPlanProgress => 'Learning Progress';

  @override
  String get learningPlanNotStarted => 'Not started';

  @override
  String get firstStudy => 'First Study';

  @override
  String get review => 'Review';

  @override
  String stepProgress(int completed, int total) {
    return '$completed/$total completed';
  }

  @override
  String get stepBlindListening => 'Blind Listening';

  @override
  String get stepBlindListeningDesc => 'Listen 1-2 times without subtitles';

  @override
  String get stepIntensiveListening => 'Intensive Listening';

  @override
  String get stepIntensiveListeningDesc =>
      'Listen sentence by sentence, mark difficult ones';

  @override
  String get stepShadowing => 'Listen & Repeat';

  @override
  String get stepShadowingDesc => 'Repeat difficult sentences with subtitles';

  @override
  String get stepRetelling => 'Retelling';

  @override
  String get stepRetellingDesc => 'Retell paragraphs in your own words';

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
  String get reviewIntervalNow => 'After 6 hours';

  @override
  String get reviewInterval1d => 'After 1 day';

  @override
  String get reviewInterval2d => 'After 2 days';

  @override
  String get reviewInterval4d => 'After 4 days';

  @override
  String get reviewInterval7d => 'After 7 days';

  @override
  String get reviewInterval14d => 'After 14 days';

  @override
  String get reviewInterval28d => 'After 28 days';

  @override
  String get startLearning => 'Start Learning';

  @override
  String get continueLearning => 'Continue Learning';

  @override
  String get learningInProgress => 'In Progress';

  @override
  String get learningCompleted => 'Completed';

  @override
  String get reviewReady => 'Ready to review';

  @override
  String reviewCountdown(int days) {
    return 'Available in $days days';
  }

  @override
  String reviewCountdownHours(int hours) {
    return 'Available in $hours hours';
  }

  @override
  String get blindListenBriefingTitle => 'Full Listening';

  @override
  String get blindListenBriefingSubtitle => 'First Study - Full Listening';

  @override
  String blindListenBriefingReviewSubtitle(int round) {
    return 'Review $round - Full Listening';
  }

  @override
  String get blindListenBriefingTip =>
      'Listen without subtitles, try to get the gist';

  @override
  String get startPractice => 'Start Practice';

  @override
  String get blindListenAppBarTitle => 'Full Listening';

  @override
  String blindListenPassLabel(int count) {
    return 'Pass $count';
  }

  @override
  String get blindListenComplete => 'Listening Complete';

  @override
  String blindListenPassInfo(int count) {
    return 'Listened $count time(s)';
  }

  @override
  String get selectDifficulty => 'How did it feel?';

  @override
  String get selectDifficultyRequired =>
      'Please select a difficulty to continue';

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
  String get difficultyMedium => 'Okay';

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
  String get noAudioItemsHint => 'Import audio files to start learning';

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
    return 'Are you sure you want to delete \"$name\"? This audio will be removed from all collections.';
  }

  @override
  String get uploadTranscript => 'Upload Transcript';

  @override
  String get replaceTranscriptTitle => 'Replace Transcript';

  @override
  String get replaceTranscriptMessage =>
      'A transcript already exists. Do you want to replace it?';

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
  String get noTranscriptWarning =>
      'No transcript uploaded. A transcript is required to start the learning flow.';

  @override
  String get intensiveListenAppBarTitle => 'Intensive Listening';

  @override
  String intensiveListenProgress(int current, int total) {
    return 'Intensive $current/$total';
  }

  @override
  String intensiveListenPlayCount(int current, int total) {
    return 'Play $current/$total';
  }

  @override
  String get intensiveListenPeek => 'Peek';

  @override
  String get intensiveListenHideSubtitle => 'Hide';

  @override
  String get intensiveListenCantUnderstand => 'Can\'t understand';

  @override
  String get intensiveListenAutoMarkedDifficult =>
      'Auto-marked difficult, tap to undo';

  @override
  String get intensiveListenMarkedDifficult => 'Marked difficult, tap to undo';

  @override
  String get intensiveListenNotDifficult => 'Tap to mark as difficult';

  @override
  String get aiTranslation => 'Translation';

  @override
  String get aiAnalysis => 'Analysis';

  @override
  String get aiLoadFailed => 'Failed to load, tap to retry';

  @override
  String get aiRetry => 'Retry';

  @override
  String get aiGrammar => 'Grammar';

  @override
  String get aiVocabulary => 'Vocabulary';

  @override
  String get aiUsage => 'Usage';

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
  String get intensiveListenCompleteTitle => 'Intensive Listening Complete';

  @override
  String intensiveListenCompleteMessage(int total, int difficult) {
    return 'You\'ve completed intensive listening for all $total sentences. $difficult sentence(s) marked as difficult.';
  }

  @override
  String get intensiveListenCompleteNext => 'Next Step';

  @override
  String get exitIntensiveListenTitle => 'Exit Intensive Listening?';

  @override
  String get exitIntensiveListenMessage =>
      'Your progress will be saved. You can continue from where you left off.';

  @override
  String get intensiveListenBriefingTitle => 'Intensive Listening';

  @override
  String get intensiveListenBriefingSubtitle =>
      'First Study - Intensive Listening';

  @override
  String get intensiveListenBriefingTip =>
      'Listen sentence by sentence. Tap \'Can\'t understand\' to reveal text and mark difficult sentences.';

  @override
  String intensiveListenBriefingSentenceCount(int count) {
    return '$count sentences';
  }

  @override
  String get intensiveListenNoSubtitle => 'No Subtitle Available';

  @override
  String get intensiveListenNoSubtitleMessage =>
      'This audio has no subtitle. Please upload a subtitle file first.';

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
  String get intensiveListenPauseSmart => 'Smart';

  @override
  String get intensiveListenPauseFixed => 'Fixed';

  @override
  String get intensiveListenPauseMultiplierMode => 'Multiplier';

  @override
  String get intensiveListenSettingsTemporaryHint =>
      'Settings apply to this session only';

  @override
  String get intensiveListenPauseSmartDesc =>
      'Auto-adjusted based on difficulty, sentence length, and learning stage';

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
    return 'Difficulty: $difficulty';
  }

  @override
  String get backToPlan => 'Back to Plan';

  @override
  String continueToStep(String step) {
    return 'Continue: $step';
  }

  @override
  String get completeFirstStudy => 'Complete First Study';

  @override
  String get completeReview => 'Complete Review';

  @override
  String stepProgressLabel(int current, int total, String stage) {
    return 'Step $current/$total ($stage)';
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
    return 'Are you sure you want to delete \"$name\"? It will be removed from all audio.';
  }

  @override
  String get listenAndRepeatAppBarTitle => 'Listen & Repeat';

  @override
  String listenAndRepeatProgress(int current, int total) {
    return 'Repeat $current/$total';
  }

  @override
  String listenAndRepeatPlayCount(int current, int total) {
    return 'Play $current/$total';
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
  String get listenAndRepeatListenHint => 'Listen first, then repeat';

  @override
  String get listenAndRepeatYourTurnHint => 'Your turn — repeat out loud!';

  @override
  String get listenAndRepeatCompleteTitle => 'Listen & Repeat Complete';

  @override
  String listenAndRepeatCompleteMessage(int total) {
    return 'You\'ve completed listen & repeat for all $total difficult sentences.';
  }

  @override
  String get listenAndRepeatNoDifficultSentences =>
      'No difficult sentences marked. Skipping listen & repeat.';

  @override
  String get exitListenAndRepeatTitle => 'Exit Listen & Repeat?';

  @override
  String get exitListenAndRepeatMessage =>
      'Your progress will be saved. You can continue from where you left off.';

  @override
  String get listenAndRepeatBriefingTitle => 'Listen & Repeat';

  @override
  String get listenAndRepeatBriefingSubtitle => 'First Study - Listen & Repeat';

  @override
  String get listenAndRepeatBriefingTip =>
      'Listen to each sentence, then repeat it aloud during the pause.';

  @override
  String listenAndRepeatBriefingDifficultCount(int count) {
    return '$count difficult sentences';
  }

  @override
  String listenAndRepeatBriefingPlayCount(int count) {
    return '$count plays per sentence';
  }

  @override
  String get listenAndRepeatRemoveDifficult =>
      'Marked difficult, tap to remove';

  @override
  String get listenAndRepeatSettings => 'Repeat Settings';

  @override
  String get listenAndRepeatSettingsTemporaryHint =>
      'Settings apply to this session only';

  @override
  String get listenAndRepeatPauseSmartDesc =>
      'Auto-adjusted based on difficulty, sentence length, and learning stage';

  @override
  String sentenceDuration(String duration) {
    return '${duration}s';
  }

  @override
  String difficultSentenceCount(int count) {
    return '$count difficult sentences';
  }

  @override
  String intensiveListenPassInfo(int count) {
    return 'Intensive listen ${count}x';
  }

  @override
  String shadowingPassInfo(int count) {
    return 'Shadowing ${count}x';
  }

  @override
  String get retellBriefingTitle => 'Paragraph Retelling';

  @override
  String get retellBriefingSubtitle =>
      'Listen to a paragraph, then retell in your own words. Keywords help you recall the content.';

  @override
  String get retellBriefingTargetDuration => 'Target paragraph duration';

  @override
  String retellBriefingParagraphCount(int count) {
    return 'Will be divided into $count paragraphs';
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
  String get retellTitle => 'Paragraph Retelling';

  @override
  String retellParagraphProgress(int current, int total) {
    return 'Paragraph $current/$total';
  }

  @override
  String retellParagraphDuration(String duration) {
    return 'Duration $duration';
  }

  @override
  String get retellListeningPhase => 'Listening...';

  @override
  String retellRetellingCountdown(int seconds) {
    return 'Retell ${seconds}s';
  }

  @override
  String retellRepeatInfo(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String get retellCompleteFirstStudy => 'Complete First Study';

  @override
  String get retellCompleteReview => 'Complete Review';

  @override
  String get retellCompleteFreePlay => 'Practice Complete';

  @override
  String get retellCompleteTitle => 'Retelling Complete';

  @override
  String get retellPracticeAgain => 'Practice Again';

  @override
  String retellCompleteMessage(int count) {
    return '$count paragraphs retold';
  }

  @override
  String get retellExitConfirmTitle => 'Exit Retelling?';

  @override
  String get retellExitConfirmMessage =>
      'Current paragraph progress will be saved.';

  @override
  String get retellDisplayKeywordsOnly => 'Visible Only';

  @override
  String get retellDisplayShowAll => 'Show All';

  @override
  String get retellDisplayHideAll => 'Hide All';

  @override
  String get retellSettingsTitle => 'Retell Settings';

  @override
  String get retellRepeatCount => 'Repeat per paragraph';

  @override
  String get retellPauseMode => 'Retell pause';

  @override
  String retellPassInfo(int count) {
    return 'Retell ${count}x';
  }

  @override
  String get retellNoDifficultSentences =>
      'No sentences to retell. Complete intensive listening first.';

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
  String get retellKeywordRatio => 'Visible ratio';

  @override
  String get pauseModeSmart => 'Smart';

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
  String get reviewDifficultPracticeTitle => 'Difficult Sentence Practice';

  @override
  String reviewDifficultPracticeProgress(int current, int total) {
    return '$current/$total sentences';
  }

  @override
  String get reviewDifficultPracticeBlindListen => 'Listening...';

  @override
  String get reviewDifficultPracticeCompleteTitle =>
      'Difficult Practice Complete';

  @override
  String reviewDifficultPracticeCompleteMessage(int total) {
    return 'You\'ve practiced all $total difficult sentences.';
  }

  @override
  String get reviewDifficultPracticeNone =>
      'No difficult sentences to practice.';

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
  String get developer => 'Developer';

  @override
  String get unlockAllReviews => 'Unlock All Reviews';

  @override
  String get unlockAllReviewsDescription =>
      'Skip review time locks for testing';

  @override
  String get manageSubtitles => 'Manage Subtitles';

  @override
  String get localUpload => 'Local Upload';

  @override
  String get aiTranscription => 'AI Transcription';

  @override
  String get deleteSubtitle => 'Delete Subtitle';

  @override
  String get startTranscription => 'Start Transcription';

  @override
  String get alreadyTranscribedWithOption =>
      'Already transcribed with this option';

  @override
  String get transcriptionUploading => 'Uploading...';

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
  String get transcriptionErrorServer => 'Server error, please retry later';

  @override
  String get transcriptionErrorUnknown => 'Something went wrong';

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
      'Are you sure you want to delete the subtitle?';

  @override
  String get deleteSubtitleWarning =>
      'Deleting the subtitle will affect learning progress.';

  @override
  String get languageMulti => 'Mixed Languages';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get overwriteExistingSubtitle => 'Overwrite existing subtitle?';

  @override
  String get overwriteExistingSubtitleMessage =>
      'This will replace the current subtitle. Continue?';

  @override
  String get overwrite => 'Overwrite';

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
  String get reviewButton => 'Review';

  @override
  String streakDays(int count) {
    return '${count}d streak';
  }

  @override
  String get todayStudyTimeShort => 'Today';

  @override
  String get weekStudyTimeShort => 'Week';

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
    return 'First Study ($count)';
  }

  @override
  String completedSection(int count) {
    return 'Completed ($count)';
  }

  @override
  String get noStudyTasks => 'No study tasks yet';

  @override
  String get noStudyTasksHint => 'Import audio files to start learning.';

  @override
  String get goToLibrary => 'Go to Library';

  @override
  String get allDoneTitle => 'All done for now!';

  @override
  String get allDoneHint => 'Great work today. Come back later for reviews.';

  @override
  String overdueDays(int count) {
    return 'Overdue ${count}d';
  }

  @override
  String overdueHours(int count) {
    return 'Overdue ${count}h';
  }

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
    return 'First Study - $subStage';
  }

  @override
  String subStageLabelReview(String reviewName, String subStage) {
    return '$reviewName - $subStage';
  }
}
