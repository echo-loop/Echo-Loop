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
  String get waveformZoom => 'Zoom';

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
  String get nativeLanguageDescription =>
      'Language for translations and analysis';

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
  String audioUnsupportedFormat(String ext) {
    return 'Unsupported audio format: $ext. Only MP3, WAV, M4A, AAC, FLAC are supported.';
  }

  @override
  String get audioErrorUnsupportedTitle => 'Unsupported audio format';

  @override
  String get audioErrorGenericTitle => 'Failed to add audio';

  @override
  String get pickTranscriptFileFailed => 'Failed to select transcript file';

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
  String get sortByDateAsc => 'Oldest First';

  @override
  String get sortByDateDesc => 'Newest First';

  @override
  String get sortDefault => 'Default';

  @override
  String get sortByOriginalDateAsc => 'Oldest Published';

  @override
  String get sortByOriginalDateDesc => 'Latest Published';

  @override
  String publishedOn(String date) {
    return 'Published $date';
  }

  @override
  String get discoverEntryTitleA => 'Discover Curated Collections';

  @override
  String get discoverEntrySubtitleA => 'TOEFL · IELTS · TEM · VOA…';

  @override
  String get officialCollectionEmpty => 'This collection has no audios yet';

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
  String get favorites => 'Bookmarks';

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
  String get firstStudy => 'Initial Learning';

  @override
  String get review => 'Review';

  @override
  String stepProgress(int completed, int total) {
    return '$completed/$total completed';
  }

  @override
  String get stepBlindListening => 'Blind Listening';

  @override
  String get stepBlindListeningDesc =>
      'Blind listen to get the overall difficulty and gist';

  @override
  String get stepIntensiveListening => 'Intensive Listening';

  @override
  String get stepIntensiveListeningDesc =>
      'Listen sentence by sentence, understand and mark difficult ones';

  @override
  String get stepShadowing => 'Listen & Repeat';

  @override
  String get stepShadowingDesc => 'Repeat weak sentences over and over';

  @override
  String get stepRetelling => 'Paragraph Retelling';

  @override
  String get stepRetellingDesc =>
      'Retell the gist of each paragraph in English';

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
  String get blindListenBriefingTitle => 'Blind Listening';

  @override
  String get blindListenBriefingSubtitle =>
      'Initial Learning - Blind Listening';

  @override
  String blindListenBriefingReviewSubtitle(int round) {
    return 'Review $round - Blind Listening';
  }

  @override
  String get blindListenBriefingTip =>
      'Listen without subtitles, try to get the gist';

  @override
  String get startPractice => 'Start Practice';

  @override
  String get blindListenAppBarTitle => 'Blind Listening';

  @override
  String blindListenPassLabel(int count) {
    return 'Pass $count';
  }

  @override
  String get blindListenComplete => 'Blind Listen Complete';

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
    return 'Are you sure you want to delete \"$name\"? The audio file will be permanently deleted.';
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
  String get noTranscriptWarning => 'This audio has no transcript yet';

  @override
  String get intensiveListenAppBarTitle => 'Intensive Listening';

  @override
  String intensiveListenProgress(int current, int total) {
    return 'Sentence $current/$total';
  }

  @override
  String intensiveListenPlayCount(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String get intensiveListenPeek => 'Peek';

  @override
  String get intensiveListenHideSubtitle => 'Hide';

  @override
  String get intensiveListenCantUnderstand => 'Unclear';

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
  String get aiListening => 'Listening';

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
    return 'You\'ve completed intensive listening for all $total sentences.\n$difficult sentence(s) marked as difficult.';
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
  String get intensiveListenBriefingTip =>
      'Listen sentence by sentence. Tap \'Unclear\' to reveal text and explanations.';

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
  String get intensiveListenPauseSmart => 'Auto';

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
    return 'Difficulty: $difficulty';
  }

  @override
  String continueToStep(String step) {
    return 'Continue: $step';
  }

  @override
  String get completeFirstStudy => 'Complete Initial Learning';

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
  String get listenAndRepeatListenHint => 'Listen then repeat';

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
      'Confirming final transcript...';

  @override
  String get listenAndRepeatYourTakeLabel => 'Your Take';

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
      'No English speech detected';

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
  String listenAndRepeatCompleteMessage(int total) {
    return 'You\'ve completed listen & repeat for all $total difficult sentences.';
  }

  @override
  String get listenAndRepeatNoDifficultSentences =>
      'No difficult sentences, no listen & repeat needed';

  @override
  String get exitListenAndRepeatTitle => 'Exit Listen & Repeat?';

  @override
  String get exitListenAndRepeatMessage =>
      'Your progress will be saved. You can continue from where you left off.';

  @override
  String get listenAndRepeatBriefingTitle => 'Listen & Repeat';

  @override
  String get listenAndRepeatBriefingTip =>
      'Listen first, then repeat during the pause.';

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
  String get listenAndRepeatControlModeLabel => 'Control Mode';

  @override
  String get listenAndRepeatControlModeAuto => 'Auto';

  @override
  String get listenAndRepeatControlModeManual => 'Manual';

  @override
  String get listenAndRepeatControlModeAutoDesc =>
      'Auto-record, auto-stop, auto-advance';

  @override
  String get listenAndRepeatControlModeManualDesc =>
      'Tap to record, tap to stop, tap next';

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
    return 'Practiced ${count}x';
  }

  @override
  String shadowingPassInfo(int count) {
    return 'Practiced ${count}x';
  }

  @override
  String get retellBriefingTitle => 'Paragraph Retelling';

  @override
  String get retellBriefingSubtitle =>
      'Listen to a paragraph, then retell in your own words. Keywords help you recall the content.';

  @override
  String get retellBriefingTargetDuration => 'Paragraph duration';

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
    return '${duration}s';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String get retellPreListenHint => 'Listen first, then retell';

  @override
  String get retellListeningPhase => 'Listening...';

  @override
  String get retellPromptToRetell => 'Retell it in your own words';

  @override
  String retellRetellingCountdown(int seconds) {
    return 'Retell ${seconds}s';
  }

  @override
  String retellRepeatInfo(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String get retellCompleteFirstStudy => 'Complete Initial Learning';

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
  String get retellAutoPlayRecordingSessionToggle =>
      'Auto-play retell recording';

  @override
  String get retellAutoPlaybackPromptTitle =>
      'Auto-play your recording after retelling?';

  @override
  String get retellAutoPlaybackPromptMessage =>
      'When enabled, your recording plays automatically after each retell so you can fix your pronunciation right away. You can change this anytime in settings.';

  @override
  String get retellAutoPlaybackKeepOff => 'Not Now';

  @override
  String get retellAutoPlaybackEnable => 'Enable';

  @override
  String get retellRepeatCount => 'Repeat per paragraph';

  @override
  String get retellPauseMode => 'Pause between paragraphs';

  @override
  String retellPassInfo(int count) {
    return 'Practiced ${count}x';
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
  String get reviewDifficultPracticeTitle => 'Difficult Sentence Practice';

  @override
  String reviewDifficultPracticeProgress(int current, int total) {
    return 'Sentence $current/$total';
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
      'No difficult sentences to practice. Auto-completed.';

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
      'When enabled, speech recognition automatically evaluates your pronunciation during repeat and retell practice.';

  @override
  String get asrBackendPlatform => 'Apple Speech';

  @override
  String get asrBackendPlatformDescription =>
      'Uses the built-in system speech recognition, no download needed';

  @override
  String get asrBackendOffline => 'Echo Loop AI';

  @override
  String get asrBackendOfflineDescription =>
      'Uses the app\'s AI model, works offline, requires download';

  @override
  String asrModelTier(String tier) {
    return 'Model: $tier (auto-selected for your device)';
  }

  @override
  String get localSpeechRecognition => 'Local Speech Recognition';

  @override
  String speechModelSize(String size) {
    return 'Model size: ~$size';
  }

  @override
  String speechModelReady(String size) {
    return 'Ready · $size';
  }

  @override
  String speechModelDownloading(String progress) {
    return 'Downloading... $progress';
  }

  @override
  String get speechModelDownloadFailed => 'Download failed. Tap to retry.';

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
      'Speech practice scoring will be unavailable.';

  @override
  String get alsoDeleteModel => 'Also delete downloaded model';

  @override
  String get disableAction => 'Disable';

  @override
  String get speechRecognitionRequiredTitle =>
      'Speech Recognition Model Required';

  @override
  String get speechRecognitionRequiredMessage =>
      'Speech recognition is used to automatically evaluate your read-along and retelling. A model download is required. You can disable this in Settings.';

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
  String get timeMachineUseSystemTime => 'Using system time';

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
      'Are you sure you want to delete the subtitle?';

  @override
  String get deleteSubtitleWarning =>
      'Deleting the subtitle will also clear all bookmarked sentences and learning progress for this audio.';

  @override
  String get languageAutoDetect => 'Auto Detect';

  @override
  String get mixedLanguageNotSupported =>
      'Mixed language audio is not supported yet';

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
    return 'Initial Learning ($count)';
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
    return 'Initial Learning - $subStage';
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
      'Mark difficult sentences during intensive listening or shadowing';

  @override
  String get favoritesNoVocabulary => 'No saved vocabulary yet';

  @override
  String get favoritesNoVocabularyHint =>
      'Tap a word during learning to look it up and save it';

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
  String get bookmarkReviewTitle => 'Bookmark Review';

  @override
  String get bookmarkReviewStart => 'Start Review';

  @override
  String bookmarkReviewStartCount(int count) {
    return 'Start Review ($count)';
  }

  @override
  String get bookmarkReviewComplete => 'Review Complete';

  @override
  String bookmarkReviewCompleteMessage(int count) {
    return 'You\'ve reviewed all $count bookmarked sentences.';
  }

  @override
  String get bookmarkReviewAgain => 'Review Again';

  @override
  String get bookmarkReviewAudioSkipped =>
      'Audio unavailable, skipping this sentence';

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
  String get difficultPracticeBlindListenRepeat => 'Blind listen repeats';

  @override
  String get difficultPracticeShadowReadingRepeat => 'Shadow reading repeats';

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
      'No learned words yet. Finish some listening first.';

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
  String get flashcardSettingsTitle => 'Card Settings';

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
  String get flashcardTimerMode => 'Card Advance Timer';

  @override
  String get flashcardTimerSmart => 'Auto';

  @override
  String get flashcardTimerSmartDesc =>
      'Adjusts based on word difficulty and practice count';

  @override
  String get flashcardTimerFixed => 'Fixed';

  @override
  String get flashcardTimerFixedDesc => 'Set fixed duration for front and back';

  @override
  String get flashcardTimerFrontDuration => 'Front';

  @override
  String get flashcardTimerBackDuration => 'Back';

  @override
  String get flashcardSortMode => 'Word Sort Order';

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
  String get flashcardSortAlphaAscDesc => 'Sort alphabetically A to Z';

  @override
  String get flashcardSortAlphaDescDesc => 'Sort alphabetically Z to A';

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
  String get freePlay => 'Free Play';

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
      'This will clear all cached data such as AI translations and analyses. They will be re-fetched when needed. Continue?';

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
  String get autoCompletedNoDifficultReview => '0 difficult sentences, skipped';

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
  String get demoModeSubtitle =>
      'Use demo data for screenshots and presentations';

  @override
  String get practiceRemoveMark => 'Unmark';

  @override
  String get practiceAddMark => 'Re-mark';

  @override
  String blindListenSegmentProgress(int current, int total) {
    return 'Paragraph $current/$total';
  }

  @override
  String blindListenSegmentDuration(int duration) {
    return '${duration}s';
  }

  @override
  String get blindListenListeningHint => 'Listen carefully...';

  @override
  String get blindListenPreListenHint => 'Listen first, then recall';

  @override
  String blindListenRepeatInfo(int current, int total) {
    return 'Round $current/$total';
  }

  @override
  String get blindListenSettingsTitle => 'Listening Settings';

  @override
  String get blindListenPauseBetween => 'Pause between paragraphs';

  @override
  String get blindListenTargetDuration => 'Paragraph duration';

  @override
  String get blindListenDisplayHideAll => 'Hide Subtitles';

  @override
  String get blindListenDisplayShowAll => 'Show Subtitles';

  @override
  String get blindListenRecallHint => 'Try to recall what you just heard';

  @override
  String get blindListenControlModeAutoDesc =>
      'Auto-repeat, auto-pause, auto-next';

  @override
  String get blindListenControlModeManualDesc => 'Tap to replay, tap next';

  @override
  String get blindListenNoParagraph => 'No split';

  @override
  String blindListenParagraphCount(int count) {
    return '$count paragraphs';
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
  String get stageBlindListen => 'Blind Listen';

  @override
  String get stageIntensiveListen => 'Intensive Listen';

  @override
  String get stageListenAndRepeat => 'Shadowing';

  @override
  String get stageRetell => 'Retelling';

  @override
  String get stageReviewDifficultPractice => 'Difficult Drill';

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
  String get savedReviewReminderSection => 'Saved Review Reminder';

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
  String get exportAudio => 'Export';

  @override
  String get exportAudioFile => 'Audio';

  @override
  String get exportSubtitleFile => 'Subtitle';

  @override
  String get exportSelectFiles => 'Select files to export';

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
      'This will replace all current data including learning progress, favorites, and audio files. This action cannot be undone.';

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
  String get activityCalendar => 'Activity Calendar';

  @override
  String get noActivityThisMonth => 'No learning activity this month';

  @override
  String monthlySummaryTitle(String month) {
    return '$month Stats';
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
  String get senseGroupSplit => 'Split into Groups';

  @override
  String get senseGroupLoading => 'Splitting...';

  @override
  String get senseGroupSingleGroup => 'This sentence is a single group';

  @override
  String get senseGroupSave => 'Save';

  @override
  String get senseGroupSaved => 'Saved';

  @override
  String get annotationBtnSenseGroup => 'Groups';

  @override
  String get annotationBtnSenseGroupMedium => 'Larger Groups';

  @override
  String get annotationBtnSenseGroupFine => 'Smaller Groups';

  @override
  String get annotationBtnTranslation => 'Translate';

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
  String filesSelected(int count) {
    return '$count files selected';
  }

  @override
  String processingFileOf(int current, int total) {
    return 'Processing $current of $total...';
  }

  @override
  String multipleAudioAdded(int count) {
    return '$count audio files added';
  }

  @override
  String duplicatesSkipped(int count) {
    return 'Skipped $count duplicates';
  }

  @override
  String get duplicatesSkippedDetail =>
      'The following audio files already exist in the library and were skipped:';

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
  String get download => 'Download';

  @override
  String get retry => 'Retry';

  @override
  String get guideNext => 'Next';

  @override
  String get guideDone => 'Done';

  @override
  String get guideLibraryCollectionListDescription =>
      'This is your collection list. Collections let you categorize audio by topic — tap any collection to see the audio inside.';

  @override
  String get guideLibraryCollectionMenuDescription =>
      'Tap here to pin, rename, or delete this collection.';

  @override
  String get guideLibraryCreateCollectionDescription =>
      'Tap here to create a new collection.';

  @override
  String get guideCollectionAudioListDescription =>
      'Tap any audio to view its learning plan and current progress.';

  @override
  String get guideCollectionAudioMenuDescription =>
      'Tap here to manage this audio\'s subtitles, collection, tags, and more.';

  @override
  String get guideCollectionUploadDescription =>
      'Tap here to upload your own audio.';

  @override
  String get guidePlanAddSubtitleTitle => 'Add subtitles';

  @override
  String get guidePlanAddSubtitleDescription =>
      'Generate subtitles with AI in one tap, or upload a local subtitle file. You can start learning this audio right after.';

  @override
  String get guidePlanAiTranscriptionTitle => 'Use AI transcription';

  @override
  String get guidePlanAiTranscriptionDescription =>
      'If you do not have a subtitle file, AI transcription is the fastest way.';

  @override
  String get guidePlanStartTranscriptionDescription =>
      'Tap here to let AI generate subtitles for this audio.';

  @override
  String get guidePlanFreePlayTitle => 'Free Practice';

  @override
  String get guidePlanFreePlayDescription =>
      'A flexible, all-in-one audio player for free practice. Learn at your own pace.';

  @override
  String get guidePlanStartLearningTitle => 'Follow the plan';

  @override
  String get guidePlanStartLearningDescription =>
      'Tap here to follow the learning plan step by step. Echo Loop will guide you and remind you to review at the right time.';

  @override
  String get guidePlanPauseLearningTitle => 'Pause learning';

  @override
  String get guidePlanPauseLearningDescription =>
      'If you no longer want to study this audio, tap here to pause anytime. Review reminders will stop, and you can resume with one tap later.';

  @override
  String get guideRetellSkipTitle => 'Skip this retell';

  @override
  String get guideRetellSkipDescription =>
      'Retelling builds speaking fast; if you want to focus on listening for now, tap here to skip this retell.';

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
      'This area includes new audio to learn, due reviews, completed tasks, and more. Echo Loop will pace your learning for you.';

  @override
  String get guideStudyStatsHeaderTitle => 'Today at a glance';

  @override
  String get guideStudyStatsHeaderDescription =>
      'Your listening time, speaking practice time, and new vocabulary for today are all summarized here. Tap a card or bar for a more detailed breakdown.';

  @override
  String get guideStudyStreakDescription =>
      'Tap here to open your activity calendar. Check in every day and build a steady learning habit.';

  @override
  String guideFavoritesSentencesListDescription(String dumbbellIcon) {
    return 'Your saved sentences, grouped by source audio. Tap $dumbbellIcon to review every saved sentence from that audio at once.';
  }

  @override
  String get guideFavoritesSentencesReviewDescription =>
      'Tap here to review every saved sentence at once.';

  @override
  String get guideFavoritesVocabularyListDescription =>
      'Your saved words and phrases. Expand a card to see definitions and hear how they sound in the original sentences.';

  @override
  String get guideFavoritesFlashcardDescription =>
      'Tap here to enter flashcard mode and review every saved word. Seeing the word and hearing it in context makes memory stick.';

  @override
  String get guideIntensiveListenCantUnderstandDescription =>
      'Tap here when a sentence is hard to follow. It will be auto-marked as difficult and you\'ll enter single-sentence analysis mode.';

  @override
  String get guideIntensiveListenAnnotationContinueDescription =>
      'Once you understand this sentence, tap Continue to move on to the next one.';

  @override
  String get guideIntensiveListenAnnotationPlayDescription =>
      'Tap the play button to play the current sentence.';

  @override
  String get guideSentenceTileNumberDescription =>
      'Tap the number to play from this sentence.';

  @override
  String get guideSentenceTileBodyDescription =>
      'Tap the sentence to view the explanation.';

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
      'Sign in to add curated collections to My Collections and keep your learning content in sync.';

  @override
  String get goLearn => 'Go Learn';

  @override
  String get removeFromMyCollections => 'Remove from My Collections';

  @override
  String get enrollNeededTitle => 'Add Collection First';

  @override
  String get enrollNeededMessage =>
      'Add this collection to your library, then you can start learning.';

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
      'All audios, subtitles, and learning records in this collection will be deleted. This cannot be undone.';

  @override
  String get removeOfficialConfirmConfirm => 'Remove';

  @override
  String get officialCollectionDeprecated =>
      'This collection has been removed by the publisher. Your local copy remains available.';

  @override
  String get preparingLearningMaterial => 'Preparing Learning Material';

  @override
  String get downloadingAudioAndSubtitle => 'Downloading audio and subtitle...';

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
  String get updateOfficialSubtitle => 'Update Subtitle';

  @override
  String get updateOfficialSubtitleConfirm => 'Update subtitle?';

  @override
  String get updateOfficialSubtitleWarning =>
      'Updating the subtitle will replace the local subtitle and clear all bookmarked sentences and learning progress for this audio.';

  @override
  String get officialSubtitleUpdated => 'Subtitle updated';

  @override
  String get officialSubtitleUpdateFailed =>
      'Subtitle update failed, please retry';

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
  String get onboardingExamGaokao => 'Gaokao';

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
      'Improving listening & speaking\nisn\'t about hearing more,\nit\'s about practicing deeper.';

  @override
  String get onboardingSummaryPoint1 =>
      'Drill on audio that matches your level';

  @override
  String get onboardingSummaryPoint2 =>
      'Read in sense groups, learn words in context';

  @override
  String get onboardingSummaryPoint3 =>
      'Build input and intuition through intensive listening and shadowing';

  @override
  String get onboardingSummaryPoint4 =>
      'Practice speaking through retelling, turning comprehension into output';

  @override
  String get onboardingStart => 'Start learning';

  @override
  String get onboardingQ1Prompt =>
      'What\'s your main goal for English listening & speaking practice?';

  @override
  String get onboardingQ1OptionExam => 'For an exam';

  @override
  String get onboardingQ1OptionDaily => 'Everyday conversation';

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
  String get onboardingQ3OptionFriend => 'Friend or family';

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
  String get learningSettings => 'Study Plan';

  @override
  String get speakingPracticeSection => 'Speaking practice';

  @override
  String get autoSkipRetellToggle => 'Auto-skip speaking practice';

  @override
  String get autoSkipRetellSubtitle =>
      'Auto-skip speaking tasks in your learning plan';

  @override
  String get autoSkipRetellDescription =>
      'When enabled, speaking practice tasks are auto-marked as skipped; you can complete them anytime in free practice.';

  @override
  String get autoExpandCachedAnnotationToggle => 'Auto-expand Analysis';

  @override
  String get autoExpandCachedAnnotationSubtitle =>
      'Auto-show cached translation, analysis and sense groups';

  @override
  String get autoPlayRetellRecordingToggle => 'Auto-play retell recording';

  @override
  String get autoPlayRetellRecordingSubtitle =>
      'After retelling, automatically play your recording for pronunciation review';

  @override
  String get retellSkip => 'Skip';

  @override
  String get retellSkippedSuffix => 'Skipped';

  @override
  String get skipSilenceTitle => 'Auto-skip Silence';

  @override
  String get skipSilenceDescription =>
      'Skip long silent gaps between sentences';

  @override
  String get silenceThreshold => 'Silence Threshold';

  @override
  String silenceThresholdValue(int seconds) {
    return '${seconds}s';
  }

  @override
  String silenceSkipped(int seconds) {
    return 'Skipped ${seconds}s of silence part';
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
      'Record your speech for pronunciation scoring';

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
      'You previously denied access. Please enable it in System Settings.';

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
  String get authChooseMethod => 'Choose how you want to continue.';

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
      'This will clear learning progress and bookmarked sentences for this audio.';

  @override
  String get subtitleEditsSaved => 'Subtitle changes saved.';

  @override
  String get discardSubtitleEditsTitle => 'Discard changes?';

  @override
  String get discardSubtitleEditsMessage =>
      'Your subtitle changes have not been saved.';

  @override
  String get discard => 'Discard';
}
