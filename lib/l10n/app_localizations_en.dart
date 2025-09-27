// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SnackFlix';

  @override
  String get appTagline => 'A fun way to encourage healthy eating habits for kids by pausing videos and prompting for a bite.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get readPrivacy => 'Read Privacy';

  @override
  String get skip => 'Skip';

  @override
  String get privacyTitle => 'Privacy & Safety';

  @override
  String get privacyBody => '• On-device analysis only\n• Camera active briefly during checks\n• Manual Continue after 15s\n• Parent hidden exit (long-press 3s, top-left)';

  @override
  String get close => 'Close';

  @override
  String get featurePasteTitle => 'Paste Video URL';

  @override
  String get featurePasteDesc => 'Easily add your child’s favorite videos by pasting the URL into the app.';

  @override
  String get featureIntervalTitle => 'Set Bite Intervals';

  @override
  String get featureIntervalDesc => 'Customize how often SnackFlix pauses the video to prompt your child to take a bite.';

  @override
  String get featurePrivacyTitle => 'Private by Design';

  @override
  String get featurePrivacyDesc => 'All checks run on-device. Nothing is stored or sent to servers.';

  @override
  String get perm_cameraTitle => 'Camera Permission';

  @override
  String get perm_allowCameraTitle => 'Allow Camera Access';

  @override
  String get perm_explain => 'SnackFlix uses your camera briefly to verify that your child is eating before playing videos.';

  @override
  String get perm_pointTemporary => 'Only needed during verification. You can revoke access anytime in Settings.';

  @override
  String get perm_pointNoPreview => 'We never show the camera view to your child; this is a background check step.';

  @override
  String get perm_primaryButton => 'Allow Camera';

  @override
  String get perm_secondaryButton => 'Having trouble? Open Settings';

  @override
  String get perm_deniedSnack => 'Camera access is required to continue.';

  @override
  String get perm_settingsTitle => 'Open Settings';

  @override
  String get perm_settingsBody => 'Camera permission is permanently denied. Please enable it in Settings to continue.';

  @override
  String get cancel => 'Cancel';

  @override
  String get perm_settingsOpen => 'Open Settings';

  @override
  String get common_continue => 'Continue';

  @override
  String get parentSetupTitle => 'Parent Setup';

  @override
  String get help => 'Help';

  @override
  String get parentSetupHelpTitle => 'How SnackFlix Works';

  @override
  String get parentSetupHelpStep1 => 'Paste a video URL from YouTube, YouTube Kids, or another website.';

  @override
  String get parentSetupHelpStep2 => 'Set the Bite Interval to decide how often SnackFlix checks for eating.';

  @override
  String get parentSetupHelpStep3 => 'Smart Verification looks for a face, visible snack nearby, and chewing signals.';

  @override
  String get parentSetupHelpStep4 => 'Start the session. Playback will pause at each interval for verification.';

  @override
  String get gotIt => 'Got it';

  @override
  String get videoSourceHeader => 'Video Source';

  @override
  String get videoSourceHint => 'Paste URL (YouTube / YouTube Kids / web URL)';

  @override
  String get openYouTubeKids => 'Open YouTube Kids';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get pastedFromClipboardSnack => 'Pasted from clipboard';

  @override
  String get clipboardEmptySnack => 'Clipboard is empty';

  @override
  String get cantOpenYtKidsSnack => 'Could not open YouTube Kids';

  @override
  String get clear => 'Clear';

  @override
  String get biteIntervalHeader => 'Bite Interval';

  @override
  String get biteIntervalTip => 'Recommended: 90s for snacks, 120–150s for full meals.';

  @override
  String get smartVerificationHeader => 'Smart verification';

  @override
  String get smartVerificationSubtitle => 'Chewing + snack nearby';

  @override
  String get pinHeader => 'Parent PIN';

  @override
  String get pinSubtitle => 'Set a 4-digit PIN to override playback pauses.';

  @override
  String get pinHint => '4-digit PIN';

  @override
  String get startSessionCta => 'Start Session';

  @override
  String get invalidUrlSnack => 'Please enter a valid video URL.';

  @override
  String get preflightTitle => 'Pre-Flight Tips';

  @override
  String get preflightTipLighting => 'Good lighting';

  @override
  String get preflightTipFaceVisible => 'Face visible in camera';

  @override
  String get preflightTipSnackReady => 'Snack/utensil ready';

  @override
  String get deviceLockTitle => 'Lock Device (Recommended)';

  @override
  String get iosGuidedAccessHowTo => 'Enable Guided Access: Settings → Accessibility → Guided Access → On. Set a passcode.';

  @override
  String get iosGuidedAccessStart => 'Open SnackFlix, triple-click the side button, then tap Start.';

  @override
  String get iosGuidedAccessEnd => 'To end, triple-click and enter your passcode.';

  @override
  String get androidPinningEnable => 'Enable Screen pinning: Settings → Security → App pinning → On.';

  @override
  String get androidPinningStart => 'When prompted, tap Pin to lock SnackFlix on screen.';

  @override
  String get androidPinningUnpin => 'To unpin, hold Back + Overview (or follow the on-screen hint) and enter your PIN.';

  @override
  String get continueCta => 'Continue';

  @override
  String get invalidYoutubeUrl => 'Invalid YouTube URL.';

  @override
  String get playbackTitle => 'Now Playing';

  @override
  String get endSessionCta => 'End session';

  @override
  String get parentOverride => 'Parent Override';

  @override
  String get enterPinTitle => 'Enter PIN';

  @override
  String get incorrectPin => 'Incorrect PIN';

  @override
  String get submit => 'Submit';

  @override
  String get sessionSummaryTitle => 'Session Summary';

  @override
  String get sessionStatsHeader => 'Session Stats';

  @override
  String get statDurationWatched => 'Duration watched';

  @override
  String get statPromptsShown => 'Prompts shown';

  @override
  String get statAutoCleared => 'Auto-cleared';

  @override
  String get statManualOverrides => 'Manual overrides';

  @override
  String get feedbackHeader => 'Feedback';

  @override
  String get feedbackQuestion => 'Did SnackFlix help today?';

  @override
  String get yes => 'Yes';

  @override
  String get aLittle => 'A little';

  @override
  String get no => 'No';

  @override
  String get minAbbrev => 'min';

  @override
  String get timespanSession => 'This Session';

  @override
  String get timespanWeek => 'Week';

  @override
  String get timespanMonth => 'Month';

  @override
  String get timespanYear => 'Year';

  @override
  String get homeTab => 'Home';

  @override
  String get historyTab => 'History';

  @override
  String get settingsTab => 'Settings';

  @override
  String get done => 'Done';

  @override
  String get noHistoryMessage => 'No session history... yet!';

  @override
  String historyListItemSubtitle(int duration, int prompts) {
    return 'Watched for $duration min, $prompts prompts';
  }

  @override
  String get settingsThemeToggle => 'Dark Mode';

  @override
  String get settingsThemeLight => 'Using light theme';

  @override
  String get settingsThemeDark => 'Using dark theme';

  @override
  String get settingsBatterySaverToggle => 'Battery Saver';

  @override
  String get settingsBatterySaverEnabled => 'Enabled: Lower camera quality to save battery';

  @override
  String get settingsBatterySaverDisabled => 'Disabled: Highest camera quality';

  @override
  String get watchTimeHistoryTitle => 'Watch Time History';

  @override
  String get durationWatchedTitle => 'Duration Watched';

  @override
  String minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get pastSessionsTitle => 'Past Sessions';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get videoWatchedTitle => 'Video Watched';
}
