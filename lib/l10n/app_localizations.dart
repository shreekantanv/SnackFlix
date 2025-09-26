import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'SnackFlix'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'A fun way to encourage healthy eating habits for kids by pausing videos and prompting for a bite.'**
  String get appTagline;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @readPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Read Privacy'**
  String get readPrivacy;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Safety'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'• On-device analysis only\n• Camera active briefly during checks\n• Manual Continue after 15s\n• Parent hidden exit (long-press 3s, top-left)'**
  String get privacyBody;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @featurePasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste Video URL'**
  String get featurePasteTitle;

  /// No description provided for @featurePasteDesc.
  ///
  /// In en, this message translates to:
  /// **'Easily add your child’s favorite videos by pasting the URL into the app.'**
  String get featurePasteDesc;

  /// No description provided for @featureIntervalTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Bite Intervals'**
  String get featureIntervalTitle;

  /// No description provided for @featureIntervalDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize how often SnackFlix pauses the video to prompt your child to take a bite.'**
  String get featureIntervalDesc;

  /// No description provided for @featurePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Private by Design'**
  String get featurePrivacyTitle;

  /// No description provided for @featurePrivacyDesc.
  ///
  /// In en, this message translates to:
  /// **'All checks run on-device. Nothing is stored or sent to servers.'**
  String get featurePrivacyDesc;

  /// No description provided for @perm_cameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Permission'**
  String get perm_cameraTitle;

  /// No description provided for @perm_allowCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow Camera Access'**
  String get perm_allowCameraTitle;

  /// No description provided for @perm_explain.
  ///
  /// In en, this message translates to:
  /// **'SnackFlix uses your camera briefly to verify that your child is eating before playing videos.'**
  String get perm_explain;

  /// No description provided for @perm_pointTemporary.
  ///
  /// In en, this message translates to:
  /// **'Only needed during verification. You can revoke access anytime in Settings.'**
  String get perm_pointTemporary;

  /// No description provided for @perm_pointNoPreview.
  ///
  /// In en, this message translates to:
  /// **'We never show the camera view to your child; this is a background check step.'**
  String get perm_pointNoPreview;

  /// No description provided for @perm_primaryButton.
  ///
  /// In en, this message translates to:
  /// **'Allow Camera'**
  String get perm_primaryButton;

  /// No description provided for @perm_secondaryButton.
  ///
  /// In en, this message translates to:
  /// **'Having trouble? Open Settings'**
  String get perm_secondaryButton;

  /// No description provided for @perm_deniedSnack.
  ///
  /// In en, this message translates to:
  /// **'Camera access is required to continue.'**
  String get perm_deniedSnack;

  /// No description provided for @perm_settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get perm_settingsTitle;

  /// No description provided for @perm_settingsBody.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is permanently denied. Please enable it in Settings to continue.'**
  String get perm_settingsBody;

  /// No description provided for @perm_settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get perm_settingsCancel;

  /// No description provided for @perm_settingsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get perm_settingsOpen;

  /// No description provided for @common_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get common_continue;

  /// No description provided for @parentSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Setup'**
  String get parentSetupTitle;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @parentSetupHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'How SnackFlix Works'**
  String get parentSetupHelpTitle;

  /// No description provided for @parentSetupHelpStep1.
  ///
  /// In en, this message translates to:
  /// **'Paste a video URL from YouTube, YouTube Kids, or another website.'**
  String get parentSetupHelpStep1;

  /// No description provided for @parentSetupHelpStep2.
  ///
  /// In en, this message translates to:
  /// **'Set the Bite Interval to decide how often SnackFlix checks for eating.'**
  String get parentSetupHelpStep2;

  /// No description provided for @parentSetupHelpStep3.
  ///
  /// In en, this message translates to:
  /// **'Smart Verification looks for a face, visible snack nearby, and chewing signals.'**
  String get parentSetupHelpStep3;

  /// No description provided for @parentSetupHelpStep4.
  ///
  /// In en, this message translates to:
  /// **'Start the session. Playback will pause at each interval for verification.'**
  String get parentSetupHelpStep4;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @videoSourceHeader.
  ///
  /// In en, this message translates to:
  /// **'Video Source'**
  String get videoSourceHeader;

  /// No description provided for @videoSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Paste URL (YouTube / YouTube Kids / web URL)'**
  String get videoSourceHint;

  /// No description provided for @openYouTubeKids.
  ///
  /// In en, this message translates to:
  /// **'Open YouTube Kids'**
  String get openYouTubeKids;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// No description provided for @pastedFromClipboardSnack.
  ///
  /// In en, this message translates to:
  /// **'Pasted from clipboard'**
  String get pastedFromClipboardSnack;

  /// No description provided for @clipboardEmptySnack.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmptySnack;

  /// No description provided for @cantOpenYtKidsSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not open YouTube Kids'**
  String get cantOpenYtKidsSnack;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @biteIntervalHeader.
  ///
  /// In en, this message translates to:
  /// **'Bite Interval'**
  String get biteIntervalHeader;

  /// No description provided for @biteIntervalTip.
  ///
  /// In en, this message translates to:
  /// **'Recommended: 90s for snacks, 120–150s for full meals.'**
  String get biteIntervalTip;

  /// No description provided for @smartVerificationHeader.
  ///
  /// In en, this message translates to:
  /// **'Smart verification'**
  String get smartVerificationHeader;

  /// No description provided for @smartVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chewing + snack nearby'**
  String get smartVerificationSubtitle;

  /// No description provided for @startSessionCta.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get startSessionCta;

  /// No description provided for @invalidUrlSnack.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid video URL.'**
  String get invalidUrlSnack;

  /// No description provided for @preflightTitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-Flight Tips'**
  String get preflightTitle;

  /// No description provided for @preflightTipLighting.
  ///
  /// In en, this message translates to:
  /// **'Good lighting'**
  String get preflightTipLighting;

  /// No description provided for @preflightTipFaceVisible.
  ///
  /// In en, this message translates to:
  /// **'Face visible in camera'**
  String get preflightTipFaceVisible;

  /// No description provided for @preflightTipSnackReady.
  ///
  /// In en, this message translates to:
  /// **'Snack/utensil ready'**
  String get preflightTipSnackReady;

  /// No description provided for @deviceLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock Device (Recommended)'**
  String get deviceLockTitle;

  /// No description provided for @iosGuidedAccessHowTo.
  ///
  /// In en, this message translates to:
  /// **'Enable Guided Access: Settings → Accessibility → Guided Access → On. Set a passcode.'**
  String get iosGuidedAccessHowTo;

  /// No description provided for @iosGuidedAccessStart.
  ///
  /// In en, this message translates to:
  /// **'Open SnackFlix, triple-click the side button, then tap Start.'**
  String get iosGuidedAccessStart;

  /// No description provided for @iosGuidedAccessEnd.
  ///
  /// In en, this message translates to:
  /// **'To end, triple-click and enter your passcode.'**
  String get iosGuidedAccessEnd;

  /// No description provided for @androidPinningEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Screen pinning: Settings → Security → App pinning → On.'**
  String get androidPinningEnable;

  /// No description provided for @androidPinningStart.
  ///
  /// In en, this message translates to:
  /// **'When prompted, tap Pin to lock SnackFlix on screen.'**
  String get androidPinningStart;

  /// No description provided for @androidPinningUnpin.
  ///
  /// In en, this message translates to:
  /// **'To unpin, hold Back + Overview (or follow the on-screen hint) and enter your PIN.'**
  String get androidPinningUnpin;

  /// No description provided for @continueCta.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueCta;

  /// No description provided for @invalidYoutubeUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid YouTube URL.'**
  String get invalidYoutubeUrl;

  /// No description provided for @playbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get playbackTitle;

  /// No description provided for @endSessionCta.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get endSessionCta;

  /// No description provided for @sessionSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Summary'**
  String get sessionSummaryTitle;

  /// No description provided for @sessionStatsHeader.
  ///
  /// In en, this message translates to:
  /// **'Session Stats'**
  String get sessionStatsHeader;

  /// No description provided for @statDurationWatched.
  ///
  /// In en, this message translates to:
  /// **'Duration watched'**
  String get statDurationWatched;

  /// No description provided for @statPromptsShown.
  ///
  /// In en, this message translates to:
  /// **'Prompts shown'**
  String get statPromptsShown;

  /// No description provided for @statAutoCleared.
  ///
  /// In en, this message translates to:
  /// **'Auto-cleared'**
  String get statAutoCleared;

  /// No description provided for @statManualOverrides.
  ///
  /// In en, this message translates to:
  /// **'Manual overrides'**
  String get statManualOverrides;

  /// No description provided for @feedbackHeader.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackHeader;

  /// No description provided for @feedbackQuestion.
  ///
  /// In en, this message translates to:
  /// **'Did SnackFlix help today?'**
  String get feedbackQuestion;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @aLittle.
  ///
  /// In en, this message translates to:
  /// **'A little'**
  String get aLittle;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @minAbbrev.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minAbbrev;

  /// No description provided for @timespanSession.
  ///
  /// In en, this message translates to:
  /// **'This Session'**
  String get timespanSession;

  /// No description provided for @timespanWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get timespanWeek;

  /// No description provided for @timespanMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get timespanMonth;

  /// No description provided for @timespanYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get timespanYear;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @noHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'No session history... yet!'**
  String get noHistoryMessage;

  /// No description provided for @historyListItemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watched for {duration} min, {prompts} prompts'**
  String historyListItemSubtitle(int duration, int prompts);

  /// No description provided for @settingsThemeToggle.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsThemeToggle;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Using light theme'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Using dark theme'**
  String get settingsThemeDark;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
