import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
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
    Locale('de'),
    Locale('en'),
  ];

  /// Bottom nav: today tab
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get navHeute;

  /// Bottom nav: blocks tab
  ///
  /// In de, this message translates to:
  /// **'Blocks'**
  String get navBlocks;

  /// Bottom nav: fuel/nutrition tab
  ///
  /// In de, this message translates to:
  /// **'Fuel'**
  String get navErnaehrung;

  /// Bottom nav: coach tab
  ///
  /// In de, this message translates to:
  /// **'Coach'**
  String get navCoach;

  /// Bottom nav: progress tab
  ///
  /// In de, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// Chat screen app bar title
  ///
  /// In de, this message translates to:
  /// **'Coach-Chat'**
  String get chatTitle;

  /// AppBar chat icon tooltip
  ///
  /// In de, this message translates to:
  /// **'Coach-Chat öffnen'**
  String get chatOpenTooltip;

  /// Chat composer text field hint
  ///
  /// In de, this message translates to:
  /// **'Schreib deinem Coach …'**
  String get chatInputHint;

  /// Chat send button tooltip
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get chatSend;

  /// Chat empty-state title
  ///
  /// In de, this message translates to:
  /// **'Sag Hallo 👋'**
  String get chatEmptyTitle;

  /// Chat empty-state body
  ///
  /// In de, this message translates to:
  /// **'Frag deinen Coach alles – mitten im Workout oder jederzeit.'**
  String get chatEmptyBody;

  /// Chat not-connected title
  ///
  /// In de, this message translates to:
  /// **'Kein Server verbunden'**
  String get chatNotConnectedTitle;

  /// Chat not-connected body
  ///
  /// In de, this message translates to:
  /// **'Verbinde in den Einstellungen einen T4L-Server, um zu chatten.'**
  String get chatNotConnectedBody;

  /// Failed outgoing message retry hint
  ///
  /// In de, this message translates to:
  /// **'Senden fehlgeschlagen. Tippen zum Wiederholen'**
  String get chatFailedRetry;

  /// Chat day divider: today
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get chatToday;

  /// Chat day divider: yesterday
  ///
  /// In de, this message translates to:
  /// **'Gestern'**
  String get chatYesterday;

  /// Coach tab chat entry card title
  ///
  /// In de, this message translates to:
  /// **'Chat mit deinem Coach'**
  String get chatCardTitle;

  /// Coach tab chat entry card subtitle
  ///
  /// In de, this message translates to:
  /// **'Fragen, Check-ins, Motivation'**
  String get chatCardSubtitle;

  /// Chat app bar: toggle reading replies aloud
  ///
  /// In de, this message translates to:
  /// **'Antworten vorlesen'**
  String get chatVoiceTooltip;

  /// Per-message speaker button tooltip
  ///
  /// In de, this message translates to:
  /// **'Vorlesen'**
  String get chatSpeak;

  /// Composer mic (speech-to-text) tooltip
  ///
  /// In de, this message translates to:
  /// **'Diktieren'**
  String get chatMicTooltip;

  /// Composer hint while dictating
  ///
  /// In de, this message translates to:
  /// **'Höre zu …'**
  String get chatListening;

  /// Snackbar shown when dictation cannot start
  ///
  /// In de, this message translates to:
  /// **'Spracheingabe nicht verfügbar. Erlaube Mikrofon und Spracherkennung in den Einstellungen.'**
  String get sttUnavailable;

  /// Bottom nav: setup tab
  ///
  /// In de, this message translates to:
  /// **'Setup'**
  String get navSetup;

  /// AppBar HealthKit icon tooltip
  ///
  /// In de, this message translates to:
  /// **'HealthKit verbinden'**
  String get tooltipHealthKit;

  /// AppBar export icon tooltip
  ///
  /// In de, this message translates to:
  /// **'Snapshot exportieren'**
  String get tooltipExport;

  /// AppBar settings/gear icon tooltip
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get tooltipSettings;

  /// Section label: exercises list
  ///
  /// In de, this message translates to:
  /// **'Übungen'**
  String get sectionUebungen;

  /// Start workout button label
  ///
  /// In de, this message translates to:
  /// **'Starten'**
  String get btnStarten;

  /// Import T4L Gym Bro plan button label
  ///
  /// In de, this message translates to:
  /// **'T4L Gym Bro Plan importieren'**
  String get btnCoachPlanImportieren;

  /// Empty state heading: no active block
  ///
  /// In de, this message translates to:
  /// **'Kein aktiver Block'**
  String get keinAktiverBlock;

  /// Empty state subtitle: no active block
  ///
  /// In de, this message translates to:
  /// **'Importiere deinen T4L Gym Bro Plan, um zu starten.'**
  String get keinAktiverBlockSubtitle;

  /// Coach note eyebrow label
  ///
  /// In de, this message translates to:
  /// **'COACH'**
  String get labelCoach;

  /// Nutrition header: profile link
  ///
  /// In de, this message translates to:
  /// **'Profil'**
  String get labelProfil;

  /// Nutrition page header title (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'Fuel + Recovery'**
  String get nutritionHeaderTitle;

  /// Week and day indicator, e.g. W3 · T2
  ///
  /// In de, this message translates to:
  /// **'W{week} · T{day}'**
  String weekDay(int week, int day);

  /// Pill label: current week number
  ///
  /// In de, this message translates to:
  /// **'Woche {week}'**
  String woche(int week);

  /// Nutrition signal badge: green
  ///
  /// In de, this message translates to:
  /// **'GREEN LIGHT'**
  String get signalGreenLight;

  /// Nutrition signal sub-line: green
  ///
  /// In de, this message translates to:
  /// **'Fuel und Readiness im Einklang — heute Vollgas.'**
  String get signalGreenLightSub;

  /// Nutrition signal badge: hold
  ///
  /// In de, this message translates to:
  /// **'HOLD'**
  String get signalHold;

  /// Nutrition signal sub-line: hold
  ///
  /// In de, this message translates to:
  /// **'Signale neutral — Intensität stabil halten.'**
  String get signalHoldSub;

  /// Nutrition signal badge: fuel first
  ///
  /// In de, this message translates to:
  /// **'FUEL FIRST'**
  String get signalFuelFirst;

  /// Nutrition signal sub-line: fuel first
  ///
  /// In de, this message translates to:
  /// **'Wenig gegessen — vor dem Training auffüllen.'**
  String get signalFuelFirstSub;

  /// Nutrition signal badge: deload
  ///
  /// In de, this message translates to:
  /// **'DELOAD BIAS'**
  String get signalDeloadBias;

  /// Nutrition signal sub-line: deload
  ///
  /// In de, this message translates to:
  /// **'Schwaches Fuel und Erholung — Last reduzieren.'**
  String get signalDeloadBiasSub;

  /// Yesterday signal chip: protein
  ///
  /// In de, this message translates to:
  /// **'PROTEIN'**
  String get chipProtein;

  /// Yesterday signal chip: carbs
  ///
  /// In de, this message translates to:
  /// **'CARBS'**
  String get chipCarbs;

  /// Yesterday signal chip: hydration
  ///
  /// In de, this message translates to:
  /// **'HYDRATION'**
  String get chipHydration;

  /// Level indicator: high
  ///
  /// In de, this message translates to:
  /// **'HIGH'**
  String get levelHigh;

  /// Level indicator: moderate
  ///
  /// In de, this message translates to:
  /// **'MODERATE'**
  String get levelModerate;

  /// Level indicator: low
  ///
  /// In de, this message translates to:
  /// **'LOW'**
  String get levelLow;

  /// Yesterday card section label (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'YESTERDAY\'S SIGNAL'**
  String get sectionYesterdaysSignal;

  /// Fuel advice card header label (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'TODAY\'S FUEL'**
  String get sectionTodaysFuel;

  /// Meal suggestion eyebrow inside fuel card (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'MEAL SUGGESTION'**
  String get sectionMealSuggestion;

  /// Section label: meal ideas (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'Meal Ideas'**
  String get sectionMealIdeas;

  /// Section label: meal analysis (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'Meal Analysis'**
  String get sectionMealAnalysis;

  /// Meal result card: training impact label (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'TRAINING IMPACT'**
  String get sectionTrainingImpact;

  /// Generic save button
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get btnSpeichern;

  /// Generic discard button
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get btnVerwerfen;

  /// Generic cancel button
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get btnAbbrechen;

  /// Collapse macros toggle label
  ///
  /// In de, this message translates to:
  /// **'Makros ausblenden'**
  String get btnMakrosAusblenden;

  /// Expand details toggle label (shown as part of macro summary line)
  ///
  /// In de, this message translates to:
  /// **'Details'**
  String get btnDetails;

  /// Meal analysis CTA: primary label
  ///
  /// In de, this message translates to:
  /// **'Mahlzeit analysieren'**
  String get mahlzeitAnalysieren;

  /// Meal analysis CTA: subtitle
  ///
  /// In de, this message translates to:
  /// **'T4L Gym Bro bewertet Trainingsauswirkung'**
  String get coachBewertetTrainingsauswirkung;

  /// Fallback meal description when empty
  ///
  /// In de, this message translates to:
  /// **'Mahlzeit'**
  String get mahlzeit;

  /// Coach page centered header title
  ///
  /// In de, this message translates to:
  /// **'Training'**
  String get coachPageTitle;

  /// Exercise counter label in focus card, e.g. ÜBUNG 2 / 5
  ///
  /// In de, this message translates to:
  /// **'ÜBUNG {idx} / {total}'**
  String uebungProgress(int idx, int total);

  /// Stat chip: sets
  ///
  /// In de, this message translates to:
  /// **'Sätze'**
  String get statSaetze;

  /// Stat chip: reps abbreviation
  ///
  /// In de, this message translates to:
  /// **'Wdhl.'**
  String get statWdhl;

  /// Stat chip: load
  ///
  /// In de, this message translates to:
  /// **'Last'**
  String get statLast;

  /// Stat chip: RPE
  ///
  /// In de, this message translates to:
  /// **'RPE'**
  String get statRpe;

  /// Stat chip: rest
  ///
  /// In de, this message translates to:
  /// **'Pause'**
  String get statPause;

  /// Section label: all exercises in coach page
  ///
  /// In de, this message translates to:
  /// **'Alle Übungen'**
  String get sectionAlleUebungen;

  /// Coach note eyebrow label on rationale block
  ///
  /// In de, this message translates to:
  /// **'Coach Notiz'**
  String get coachNotiz;

  /// Section label: conditioning block
  ///
  /// In de, this message translates to:
  /// **'Conditioning'**
  String get sectionConditioning;

  /// Toggle label to reveal common mistakes
  ///
  /// In de, this message translates to:
  /// **'Fehler vermeiden'**
  String get fehlerVermeiden;

  /// Video pill label
  ///
  /// In de, this message translates to:
  /// **'Erklärvideo'**
  String get erklaervideo;

  /// Coach empty state message
  ///
  /// In de, this message translates to:
  /// **'Kein aktives Workout. Wähle einen Block, um den Coach zu starten.'**
  String get coachEmptyState;

  /// Pending meal request card title
  ///
  /// In de, this message translates to:
  /// **'T4L Gym Bro Meal Analyse wartet'**
  String get pendingMealTitle;

  /// Banner: new T4L Gym Bro training block available
  ///
  /// In de, this message translates to:
  /// **'Neuer T4L Gym Bro Trainingsblock verfuegbar'**
  String get neuerCoachBlock;

  /// Banner import button label
  ///
  /// In de, this message translates to:
  /// **'Import'**
  String get btnImport;

  /// Set log dialog title
  ///
  /// In de, this message translates to:
  /// **'{exerciseName} loggen'**
  String dialogSetTitle(String exerciseName);

  /// Set log dialog: weight field label
  ///
  /// In de, this message translates to:
  /// **'Gewicht kg'**
  String get dialogSetWeight;

  /// Set log dialog: reps field label
  ///
  /// In de, this message translates to:
  /// **'Wiederholungen'**
  String get dialogSetReps;

  /// Set log dialog: RPE field label
  ///
  /// In de, this message translates to:
  /// **'RPE'**
  String get dialogSetRpe;

  /// Complete workout dialog title
  ///
  /// In de, this message translates to:
  /// **'Workout abschliessen'**
  String get dialogCompleteTitle;

  /// Readiness slider label
  ///
  /// In de, this message translates to:
  /// **'Readiness {value}'**
  String dialogCompleteReadiness(int value);

  /// Soreness slider label
  ///
  /// In de, this message translates to:
  /// **'Soreness {value}'**
  String dialogCompleteSoreness(int value);

  /// Complete dialog: notes field label
  ///
  /// In de, this message translates to:
  /// **'Notizen fuer T4L Gym Bro'**
  String get dialogCompleteNotes;

  /// Confirm / done button
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get btnFertig;

  /// Meal analysis dialog title
  ///
  /// In de, this message translates to:
  /// **'Meal analysieren'**
  String get dialogMealAnalysisTitle;

  /// Meal description text field label
  ///
  /// In de, this message translates to:
  /// **'Was hast du gegessen?'**
  String get dialogMealAnalysisWhat;

  /// Meal description text field hint
  ///
  /// In de, this message translates to:
  /// **'z.B. Bowl mit Reis, Huhn, Avocado, Sauce'**
  String get dialogMealAnalysisHint;

  /// Photo picker button label
  ///
  /// In de, this message translates to:
  /// **'Foto'**
  String get btnFoto;

  /// Camera button label
  ///
  /// In de, this message translates to:
  /// **'Kamera'**
  String get btnKamera;

  /// Send meal analysis to T4L Gym Bro button
  ///
  /// In de, this message translates to:
  /// **'An T4L Gym Bro senden'**
  String get btnAnCoachSenden;

  /// Meal result review dialog title
  ///
  /// In de, this message translates to:
  /// **'T4L Gym Bro Analyse pruefen'**
  String get dialogMealResultTitle;

  /// Meal result: calories field label
  ///
  /// In de, this message translates to:
  /// **'Kalorien'**
  String get dialogMealResultKalorien;

  /// Meal result: protein field label
  ///
  /// In de, this message translates to:
  /// **'Protein g'**
  String get dialogMealResultProtein;

  /// Meal result: carbs field label
  ///
  /// In de, this message translates to:
  /// **'Carbs g'**
  String get dialogMealResultCarbs;

  /// Meal result: fat field label
  ///
  /// In de, this message translates to:
  /// **'Fett g'**
  String get dialogMealResultFett;

  /// Meal result: body weight field label
  ///
  /// In de, this message translates to:
  /// **'Koerpergewicht kg'**
  String get dialogMealResultKoerpergewicht;

  /// Meal result: correction notes field label
  ///
  /// In de, this message translates to:
  /// **'Korrektur/Notizen'**
  String get dialogMealResultKorrektur;

  /// Athlete profile dialog title
  ///
  /// In de, this message translates to:
  /// **'Nutrition Profil'**
  String get dialogProfileTitle;

  /// Profile dialog: goal field label
  ///
  /// In de, this message translates to:
  /// **'Trainingsziel'**
  String get dialogProfileTrainingsziel;

  /// Profile dialog: height field label
  ///
  /// In de, this message translates to:
  /// **'Groesse cm'**
  String get dialogProfileGroesse;

  /// Profile dialog: weight field label
  ///
  /// In de, this message translates to:
  /// **'Gewicht kg'**
  String get dialogProfileGewicht;

  /// Profile dialog: age field label
  ///
  /// In de, this message translates to:
  /// **'Alter'**
  String get dialogProfileAlter;

  /// Profile dialog: sex field label
  ///
  /// In de, this message translates to:
  /// **'Sex'**
  String get dialogProfileSex;

  /// Memory wiki section title
  ///
  /// In de, this message translates to:
  /// **'Memory Wiki'**
  String get memoryWikiTitle;

  /// Memory wiki active count
  ///
  /// In de, this message translates to:
  /// **'{count} aktiv'**
  String memoryWikiAktiv(int count);

  /// Memory wiki subtitle
  ///
  /// In de, this message translates to:
  /// **'Aktive Memories gehen in T4L Gym Bro Kontext und Meal Analysen.'**
  String get memoryWikiSubtitle;

  /// Memory wiki empty state
  ///
  /// In de, this message translates to:
  /// **'Noch keine Memories gespeichert.'**
  String get memoryWikiEmpty;

  /// Add memory icon tooltip
  ///
  /// In de, this message translates to:
  /// **'Memory hinzufuegen'**
  String get tooltipMemoryHinzufuegen;

  /// Edit icon tooltip
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get tooltipBearbeiten;

  /// Delete icon tooltip
  ///
  /// In de, this message translates to:
  /// **'Loeschen'**
  String get tooltipLoeschen;

  /// Add memory dialog title
  ///
  /// In de, this message translates to:
  /// **'Memory hinzufuegen'**
  String get dialogMemoryAddTitle;

  /// Edit memory dialog title
  ///
  /// In de, this message translates to:
  /// **'Memory editieren'**
  String get dialogMemoryEditTitle;

  /// Memory dialog: category field label
  ///
  /// In de, this message translates to:
  /// **'Kategorie'**
  String get dialogMemoryKategorie;

  /// Memory dialog: title field label
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get dialogMemoryTitel;

  /// Memory dialog: summary field label
  ///
  /// In de, this message translates to:
  /// **'Kurz-Memory'**
  String get dialogMemoryKurzMemory;

  /// Memory dialog: markdown field label
  ///
  /// In de, this message translates to:
  /// **'Markdown Details'**
  String get dialogMemoryMarkdown;

  /// Memory dialog: active toggle label
  ///
  /// In de, this message translates to:
  /// **'Aktiv fuer T4L Gym Bro'**
  String get dialogMemoryAktivFuerCoach;

  /// Blocks page hero panel title (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'8-Week Training Blocks'**
  String get blocksHeroTitle;

  /// Blocks page hero panel subtitle
  ///
  /// In de, this message translates to:
  /// **'T4L Gym Bro plant, die App fuehrt aus'**
  String get blocksHeroSubtitle;

  /// Blocks page hero panel body
  ///
  /// In de, this message translates to:
  /// **'Importiere den Block, den T4L Gym Bro ueber deinen Server bereitstellt.'**
  String get blocksHeroBody;

  /// Blocks count trailing text
  ///
  /// In de, this message translates to:
  /// **'{count} Blocks'**
  String blocksCount(int count);

  /// Import training block JSON button label
  ///
  /// In de, this message translates to:
  /// **'Server-Trainingsblock importieren'**
  String get btnImportTrainingJson;

  /// Block card subtitle: weeks and creator
  ///
  /// In de, this message translates to:
  /// **'{weeks} Wochen · {createdBy}'**
  String blockCardWeeks(int weeks, String createdBy);

  /// Block card targets line
  ///
  /// In de, this message translates to:
  /// **'Targets: {targets}'**
  String blockCardTargets(String targets);

  /// Block card planned workouts count
  ///
  /// In de, this message translates to:
  /// **'{count} geplante Workouts'**
  String blockCardWorkouts(int count);

  /// Progress page hero title
  ///
  /// In de, this message translates to:
  /// **'Progress'**
  String get progressHeroTitle;

  /// Progress page hero body
  ///
  /// In de, this message translates to:
  /// **'Diese Kennzahlen gehen in den naechsten T4L Gym Bro Kontext-Push.'**
  String get progressHeroBody;

  /// Progress done count
  ///
  /// In de, this message translates to:
  /// **'{count} done'**
  String progressDone(int count);

  /// Progress log entry subtitle
  ///
  /// In de, this message translates to:
  /// **'{sets} Sets · {volume} kg · {status}'**
  String progressLogSets(int sets, String volume, String status);

  /// Settings page hero title
  ///
  /// In de, this message translates to:
  /// **'Agent Setup'**
  String get settingsHeroTitle;

  /// Settings page hero subtitle
  ///
  /// In de, this message translates to:
  /// **'T4L Gym Bro Server'**
  String get settingsHeroSubtitle;

  /// Settings page hero body
  ///
  /// In de, this message translates to:
  /// **'Alles fuer T4L Gym Bro: Server URL, API Key, Context Push und Result Checks.'**
  String get settingsHeroBody;

  /// Settings hero trailing: ready state
  ///
  /// In de, this message translates to:
  /// **'Ready'**
  String get settingsHeroReady;

  /// Settings hero trailing: loading state
  ///
  /// In de, this message translates to:
  /// **'Loading'**
  String get settingsHeroLoading;

  /// Settings server card title
  ///
  /// In de, this message translates to:
  /// **'T4L Server'**
  String get settingsExchangeFolder;

  /// Settings copy card: bootstrap URL title
  ///
  /// In de, this message translates to:
  /// **'Agent Bootstrap URL'**
  String get settingsBootstrapUrl;

  /// Settings copy card: start prompt title
  ///
  /// In de, this message translates to:
  /// **'Agent Startprompt'**
  String get settingsStartprompt;

  /// Settings copy card: write commands title
  ///
  /// In de, this message translates to:
  /// **'Validated Write Commands'**
  String get settingsWriteCommands;

  /// Settings checklist card title
  ///
  /// In de, this message translates to:
  /// **'Daily Agent Checklist'**
  String get settingsChecklist;

  /// Copy to clipboard tooltip
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get tooltipKopieren;

  /// Snackbar: copied to clipboard
  ///
  /// In de, this message translates to:
  /// **'Kopiert'**
  String get snackbarKopiert;

  /// Settings: server setup loading placeholder
  ///
  /// In de, this message translates to:
  /// **'Server Setup wird geladen...'**
  String get exchangeFolderLoading;

  /// Nutrition page: title of placeholder when no fuel guidance is available
  ///
  /// In de, this message translates to:
  /// **'Warte auf Fuel Guidance vom Coach'**
  String get noGuidanceTitle;

  /// Nutrition page: hint when guidance is from a previous day
  ///
  /// In de, this message translates to:
  /// **'Guidance vom letzten Tag — warte auf neue Einschätzung vom Coach.'**
  String get noGuidanceHintStale;

  /// Nutrition page: hint when no guidance has been received yet
  ///
  /// In de, this message translates to:
  /// **'Coach-Analyse noch nicht eingetroffen. Exportiere den Tageskontext und warte auf die Antwort.'**
  String get noGuidanceHintMissing;

  /// No description provided for @statusBereit.
  ///
  /// In de, this message translates to:
  /// **'● BEREIT'**
  String get statusBereit;

  /// No description provided for @statusAktiv.
  ///
  /// In de, this message translates to:
  /// **'● AKTIV'**
  String get statusAktiv;

  /// No description provided for @statusPause.
  ///
  /// In de, this message translates to:
  /// **'⏸ PAUSE'**
  String get statusPause;

  /// No description provided for @statusFertig.
  ///
  /// In de, this message translates to:
  /// **'✓ FERTIG'**
  String get statusFertig;

  /// No description provided for @statusAbgeschlossen.
  ///
  /// In de, this message translates to:
  /// **'✓ ABGESCHLOSSEN'**
  String get statusAbgeschlossen;

  /// No description provided for @statAktivLabel.
  ///
  /// In de, this message translates to:
  /// **'AKTIV'**
  String get statAktivLabel;

  /// No description provided for @statRpeAvg.
  ///
  /// In de, this message translates to:
  /// **'RPE ⌀'**
  String get statRpeAvg;

  /// No description provided for @statPlanzeit.
  ///
  /// In de, this message translates to:
  /// **'PLANZEIT'**
  String get statPlanzeit;

  /// No description provided for @statTagLabel.
  ///
  /// In de, this message translates to:
  /// **'TAG'**
  String get statTagLabel;

  /// No description provided for @btnTrainingStarten.
  ///
  /// In de, this message translates to:
  /// **'TRAINING STARTEN'**
  String get btnTrainingStarten;

  /// No description provided for @btnWorkoutAbschliessen.
  ///
  /// In de, this message translates to:
  /// **'WORKOUT ABSCHLIESSEN'**
  String get btnWorkoutAbschliessen;

  /// No description provided for @btnWeiter.
  ///
  /// In de, this message translates to:
  /// **'▶ WEITER'**
  String get btnWeiter;

  /// No description provided for @btnPauseLabel.
  ///
  /// In de, this message translates to:
  /// **'⏸ PAUSE'**
  String get btnPauseLabel;

  /// No description provided for @heroUebersicht.
  ///
  /// In de, this message translates to:
  /// **'← Übersicht'**
  String get heroUebersicht;

  /// No description provided for @heroSaetze.
  ///
  /// In de, this message translates to:
  /// **'SÄTZE'**
  String get heroSaetze;

  /// No description provided for @emptyKeinBlock.
  ///
  /// In de, this message translates to:
  /// **'○ KEIN AKTIVER BLOCK'**
  String get emptyKeinBlock;

  /// No description provided for @emptyNichtVerbunden.
  ///
  /// In de, this message translates to:
  /// **'○ NICHT VERBUNDEN'**
  String get emptyNichtVerbunden;

  /// No description provided for @emptyDein.
  ///
  /// In de, this message translates to:
  /// **'DEIN'**
  String get emptyDein;

  /// No description provided for @emptyErster.
  ///
  /// In de, this message translates to:
  /// **'ERSTER'**
  String get emptyErster;

  /// No description provided for @emptyTag.
  ///
  /// In de, this message translates to:
  /// **'TAG.'**
  String get emptyTag;

  /// No description provided for @btnTrainingsplanLaden.
  ///
  /// In de, this message translates to:
  /// **'TRAININGSPLAN LADEN'**
  String get btnTrainingsplanLaden;

  /// No description provided for @btnCoachVerbinden.
  ///
  /// In de, this message translates to:
  /// **'COACH VERBINDEN →'**
  String get btnCoachVerbinden;

  /// No description provided for @rpeLegendWarmup.
  ///
  /// In de, this message translates to:
  /// **'Warm-up'**
  String get rpeLegendWarmup;

  /// No description provided for @rpeLegendModerat.
  ///
  /// In de, this message translates to:
  /// **'Moderat'**
  String get rpeLegendModerat;

  /// No description provided for @rpeLegendHart.
  ///
  /// In de, this message translates to:
  /// **'Hart'**
  String get rpeLegendHart;

  /// No description provided for @btnSatzLoggen.
  ///
  /// In de, this message translates to:
  /// **'Satz loggen'**
  String get btnSatzLoggen;

  /// No description provided for @blockAbgeschlossen.
  ///
  /// In de, this message translates to:
  /// **'Block abgeschlossen'**
  String get blockAbgeschlossen;

  /// No description provided for @emptyAlleWorkoutsErledigt.
  ///
  /// In de, this message translates to:
  /// **'Alle Workouts in diesem Block sind erledigt'**
  String get emptyAlleWorkoutsErledigt;

  /// No description provided for @emptyPlanErscheintHier.
  ///
  /// In de, this message translates to:
  /// **'Dein Plan erscheint hier'**
  String get emptyPlanErscheintHier;

  /// No description provided for @fuelDiaryTitle.
  ///
  /// In de, this message translates to:
  /// **'FUEL DIARY'**
  String get fuelDiaryTitle;

  /// No description provided for @fuelDiarySentLabel.
  ///
  /// In de, this message translates to:
  /// **'SENT'**
  String get fuelDiarySentLabel;

  /// No description provided for @fuelQualityLevel.
  ///
  /// In de, this message translates to:
  /// **'Fuel Quality Level'**
  String get fuelQualityLevel;

  /// No description provided for @fuelScalePoor.
  ///
  /// In de, this message translates to:
  /// **'1 Schlecht'**
  String get fuelScalePoor;

  /// No description provided for @fuelScalePerfect.
  ///
  /// In de, this message translates to:
  /// **'10 Perfekt'**
  String get fuelScalePerfect;

  /// No description provided for @fuelDiaryHint.
  ///
  /// In de, this message translates to:
  /// **'Was hast du gegessen oder getrunken?'**
  String get fuelDiaryHint;

  /// No description provided for @fuelDiarySending.
  ///
  /// In de, this message translates to:
  /// **'Wird gesendet...'**
  String get fuelDiarySending;

  /// No description provided for @fuelDiaryUpdateCoach.
  ///
  /// In de, this message translates to:
  /// **'Update Coach'**
  String get fuelDiaryUpdateCoach;

  /// No description provided for @fuelDiarySendToCoach.
  ///
  /// In de, this message translates to:
  /// **'An Coach senden'**
  String get fuelDiarySendToCoach;

  /// No description provided for @fuelDiaryEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Logge was du gegessen hast, wie du dich fühlst, Supplements, Wasser — alles was Ernährung betrifft. Sende alles an deinen Coach wenn bereit.'**
  String get fuelDiaryEmptyHint;

  /// No description provided for @aktiverBlock.
  ///
  /// In de, this message translates to:
  /// **'AKTIVER BLOCK'**
  String get aktiverBlock;

  /// No description provided for @sessionsLabel.
  ///
  /// In de, this message translates to:
  /// **'SESSIONS'**
  String get sessionsLabel;

  /// No description provided for @coachSegmentPlan.
  ///
  /// In de, this message translates to:
  /// **'PLAN'**
  String get coachSegmentPlan;

  /// No description provided for @coachSegmentMemory.
  ///
  /// In de, this message translates to:
  /// **'MEMORY'**
  String get coachSegmentMemory;

  /// No description provided for @coachSegmentSync.
  ///
  /// In de, this message translates to:
  /// **'SYNC'**
  String get coachSegmentSync;

  /// No description provided for @verlauf.
  ///
  /// In de, this message translates to:
  /// **'VERLAUF'**
  String get verlauf;

  /// No description provided for @nochKeineSessions.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Sessions abgeschlossen.'**
  String get nochKeineSessions;

  /// No description provided for @naechsteSession.
  ///
  /// In de, this message translates to:
  /// **'NÄCHSTE SESSION'**
  String get naechsteSession;

  /// No description provided for @wirdHeuteAbendGeneriert.
  ///
  /// In de, this message translates to:
  /// **'Wird heute Abend generiert'**
  String get wirdHeuteAbendGeneriert;

  /// No description provided for @verfuegbarNach2100.
  ///
  /// In de, this message translates to:
  /// **'Verfügbar nach 21:00 Uhr'**
  String get verfuegbarNach2100;

  /// No description provided for @coachNotizLabel.
  ///
  /// In de, this message translates to:
  /// **'COACH NOTIZ'**
  String get coachNotizLabel;

  /// No description provided for @workoutStarten.
  ///
  /// In de, this message translates to:
  /// **'Workout starten'**
  String get workoutStarten;

  /// No description provided for @serverVerbunden.
  ///
  /// In de, this message translates to:
  /// **'Server verbunden'**
  String get serverVerbunden;

  /// No description provided for @keinServerKonfiguriert.
  ///
  /// In de, this message translates to:
  /// **'Kein Server konfiguriert'**
  String get keinServerKonfiguriert;

  /// No description provided for @syncEinstellungen.
  ///
  /// In de, this message translates to:
  /// **'⚙ Einstellungen'**
  String get syncEinstellungen;

  /// No description provided for @syncAktionen.
  ///
  /// In de, this message translates to:
  /// **'SYNC-AKTIONEN'**
  String get syncAktionen;

  /// No description provided for @contextPushen.
  ///
  /// In de, this message translates to:
  /// **'Context pushen'**
  String get contextPushen;

  /// No description provided for @contextPushenSub.
  ///
  /// In de, this message translates to:
  /// **'Athletenprofil, Block & Logs an Coach senden'**
  String get contextPushenSub;

  /// No description provided for @ergebnisseAbrufen.
  ///
  /// In de, this message translates to:
  /// **'Ergebnisse abrufen'**
  String get ergebnisseAbrufen;

  /// No description provided for @ergebnisseAbrufenSub.
  ///
  /// In de, this message translates to:
  /// **'Neuen Trainingsplan oder Coach-Feedback laden'**
  String get ergebnisseAbrufenSub;

  /// No description provided for @serverConfigHint.
  ///
  /// In de, this message translates to:
  /// **'Server-Konfiguration & Agent Handoff → Einstellungen'**
  String get serverConfigHint;

  /// No description provided for @syncErledigt.
  ///
  /// In de, this message translates to:
  /// **'Erledigt'**
  String get syncErledigt;

  /// No description provided for @memFilterAlle.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get memFilterAlle;

  /// No description provided for @memFilterMemories.
  ///
  /// In de, this message translates to:
  /// **'Memories'**
  String get memFilterMemories;

  /// No description provided for @memFilterConstraints.
  ///
  /// In de, this message translates to:
  /// **'Constraints'**
  String get memFilterConstraints;

  /// No description provided for @keineEintraege.
  ///
  /// In de, this message translates to:
  /// **'Keine Einträge'**
  String get keineEintraege;

  /// No description provided for @agentLabel.
  ///
  /// In de, this message translates to:
  /// **'AGENT'**
  String get agentLabel;

  /// No description provided for @ichLabel.
  ///
  /// In de, this message translates to:
  /// **'ICH'**
  String get ichLabel;

  /// No description provided for @vonDirLabel.
  ///
  /// In de, this message translates to:
  /// **'von dir'**
  String get vonDirLabel;

  /// No description provided for @coachEquals.
  ///
  /// In de, this message translates to:
  /// **'Coach'**
  String get coachEquals;

  /// No description provided for @memHinzufuegen.
  ///
  /// In de, this message translates to:
  /// **'+ Hinzufügen'**
  String get memHinzufuegen;

  /// No description provided for @constraintLabel.
  ///
  /// In de, this message translates to:
  /// **'CONSTRAINT'**
  String get constraintLabel;

  /// No description provided for @memoryLabel.
  ///
  /// In de, this message translates to:
  /// **'MEMORY'**
  String get memoryLabel;

  /// No description provided for @fortschrittStartetHier.
  ///
  /// In de, this message translates to:
  /// **'Dein Fortschritt startet hier'**
  String get fortschrittStartetHier;

  /// No description provided for @fortschrittStartetHierSub.
  ///
  /// In de, this message translates to:
  /// **'Schliesse dein erstes Workout ab und sieh wie sich deine Kraft, dein Volumen und deine Readiness entwickeln.'**
  String get fortschrittStartetHierSub;

  /// No description provided for @wasErwartetDich.
  ///
  /// In de, this message translates to:
  /// **'WAS DICH ERWARTET'**
  String get wasErwartetDich;

  /// No description provided for @volumenProWoche.
  ///
  /// In de, this message translates to:
  /// **'VOLUMEN / WOCHE'**
  String get volumenProWoche;

  /// No description provided for @volumePreviewSub.
  ///
  /// In de, this message translates to:
  /// **'Dein wöchentliches Trainingsvolumen als Balkendiagramm mit Trend und Zuwachs.'**
  String get volumePreviewSub;

  /// No description provided for @staerkePRsTitle.
  ///
  /// In de, this message translates to:
  /// **'Stärke-PRs'**
  String get staerkePRsTitle;

  /// No description provided for @staerkePRsSub.
  ///
  /// In de, this message translates to:
  /// **'Deine besten Gewichte pro Übung — mit Delta-Badge bei neuem Rekord.'**
  String get staerkePRsSub;

  /// No description provided for @bereitschaftErschoepfung.
  ///
  /// In de, this message translates to:
  /// **'Bereitschaft & Erschöpfung'**
  String get bereitschaftErschoepfung;

  /// No description provided for @bereitschaftErschoepfungSub.
  ///
  /// In de, this message translates to:
  /// **'Readiness- und Soreness-Verlauf der letzten Sessions als Sparkline.'**
  String get bereitschaftErschoepfungSub;

  /// No description provided for @volumeChartPlaceholder.
  ///
  /// In de, this message translates to:
  /// **'Hier erscheint dein Volumen-Chart'**
  String get volumeChartPlaceholder;

  /// No description provided for @nochKeineDaten.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Daten'**
  String get nochKeineDaten;

  /// No description provided for @dieseWoche.
  ///
  /// In de, this message translates to:
  /// **'Diese Woche'**
  String get dieseWoche;

  /// No description provided for @avgProWoche.
  ///
  /// In de, this message translates to:
  /// **'Ø / Woche'**
  String get avgProWoche;

  /// No description provided for @zuwachs.
  ///
  /// In de, this message translates to:
  /// **'Zuwachs'**
  String get zuwachs;

  /// No description provided for @staerkePRsLabel.
  ///
  /// In de, this message translates to:
  /// **'STÄRKE-PRS'**
  String get staerkePRsLabel;

  /// No description provided for @weniger.
  ///
  /// In de, this message translates to:
  /// **'Weniger'**
  String get weniger;

  /// No description provided for @prHinzufuegen.
  ///
  /// In de, this message translates to:
  /// **'+ PR hinzufügen'**
  String get prHinzufuegen;

  /// No description provided for @prHinzufuegenTitle.
  ///
  /// In de, this message translates to:
  /// **'PR hinzufügen'**
  String get prHinzufuegenTitle;

  /// No description provided for @prBearbeitenTitle.
  ///
  /// In de, this message translates to:
  /// **'PR bearbeiten'**
  String get prBearbeitenTitle;

  /// No description provided for @uebungLabel.
  ///
  /// In de, this message translates to:
  /// **'Übung'**
  String get uebungLabel;

  /// No description provided for @gewichtKgLabel.
  ///
  /// In de, this message translates to:
  /// **'Gewicht (kg)'**
  String get gewichtKgLabel;

  /// No description provided for @gewichtKgHint.
  ///
  /// In de, this message translates to:
  /// **'z.B. 100'**
  String get gewichtKgHint;

  /// No description provided for @vorherigesGewichtLabel.
  ///
  /// In de, this message translates to:
  /// **'Vorheriges Gewicht (kg)'**
  String get vorherigesGewichtLabel;

  /// No description provided for @optionalHint.
  ///
  /// In de, this message translates to:
  /// **'optional'**
  String get optionalHint;

  /// No description provided for @imCoachKontextSenden.
  ///
  /// In de, this message translates to:
  /// **'Im Coach-Kontext senden'**
  String get imCoachKontextSenden;

  /// No description provided for @imCoachKontextSendenSub.
  ///
  /// In de, this message translates to:
  /// **'Wird beim nächsten Sync an den Coach übermittelt'**
  String get imCoachKontextSendenSub;

  /// No description provided for @dauerLabel.
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get dauerLabel;

  /// No description provided for @heuteLabel.
  ///
  /// In de, this message translates to:
  /// **'HEUTE'**
  String get heuteLabel;

  /// No description provided for @zielLabel.
  ///
  /// In de, this message translates to:
  /// **'Ziel:'**
  String get zielLabel;

  /// No description provided for @workoutSummaryTitle.
  ///
  /// In de, this message translates to:
  /// **'Workout-Zusammenfassung'**
  String get workoutSummaryTitle;

  /// No description provided for @workoutNotFound.
  ///
  /// In de, this message translates to:
  /// **'Workout nicht gefunden'**
  String get workoutNotFound;

  /// No description provided for @uebungenUeberpruefen.
  ///
  /// In de, this message translates to:
  /// **'Übungen überprüfen'**
  String get uebungenUeberpruefen;

  /// No description provided for @keineUebungenAufgezeichnet.
  ///
  /// In de, this message translates to:
  /// **'Keine Übungen aufgezeichnet.'**
  String get keineUebungenAufgezeichnet;

  /// No description provided for @satzHinzufuegen.
  ///
  /// In de, this message translates to:
  /// **'Satz hinzufügen'**
  String get satzHinzufuegen;

  /// No description provided for @notizFuerCoach.
  ///
  /// In de, this message translates to:
  /// **'Notiz für den Coach…'**
  String get notizFuerCoach;

  /// No description provided for @nachbericht.
  ///
  /// In de, this message translates to:
  /// **'NACHBERICHT'**
  String get nachbericht;

  /// No description provided for @readinessLabel.
  ///
  /// In de, this message translates to:
  /// **'Readiness'**
  String get readinessLabel;

  /// No description provided for @sorenessLabel.
  ///
  /// In de, this message translates to:
  /// **'Soreness'**
  String get sorenessLabel;

  /// No description provided for @readinessSehrNiedrig.
  ///
  /// In de, this message translates to:
  /// **'Sehr niedrig'**
  String get readinessSehrNiedrig;

  /// No description provided for @readinessNiedrig.
  ///
  /// In de, this message translates to:
  /// **'Niedrig'**
  String get readinessNiedrig;

  /// No description provided for @readinessOk.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get readinessOk;

  /// No description provided for @readinessGut.
  ///
  /// In de, this message translates to:
  /// **'Gut'**
  String get readinessGut;

  /// No description provided for @readinessTop.
  ///
  /// In de, this message translates to:
  /// **'Top'**
  String get readinessTop;

  /// No description provided for @sorenessKeine.
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get sorenessKeine;

  /// No description provided for @sorenessLeicht.
  ///
  /// In de, this message translates to:
  /// **'Leicht'**
  String get sorenessLeicht;

  /// No description provided for @sorenessModerat.
  ///
  /// In de, this message translates to:
  /// **'Moderat'**
  String get sorenessModerat;

  /// No description provided for @sorenessStark.
  ///
  /// In de, this message translates to:
  /// **'Stark'**
  String get sorenessStark;

  /// No description provided for @sorenessSehrStark.
  ///
  /// In de, this message translates to:
  /// **'Sehr stark'**
  String get sorenessSehrStark;

  /// No description provided for @allgemeineNotizenHint.
  ///
  /// In de, this message translates to:
  /// **'Allgemeine Notizen für den Coach — Technik, Energie, Anpassungen…'**
  String get allgemeineNotizenHint;

  /// No description provided for @gesendetLabel.
  ///
  /// In de, this message translates to:
  /// **'GESENDET'**
  String get gesendetLabel;

  /// No description provided for @zumCoachSenden.
  ///
  /// In de, this message translates to:
  /// **'ZUM COACH SENDEN'**
  String get zumCoachSenden;

  /// No description provided for @conditioningLabel.
  ///
  /// In de, this message translates to:
  /// **'CONDITIONING'**
  String get conditioningLabel;

  /// No description provided for @selfHostedServer.
  ///
  /// In de, this message translates to:
  /// **'Self-Hosted T4L Server'**
  String get selfHostedServer;

  /// No description provided for @configuredLabel.
  ///
  /// In de, this message translates to:
  /// **'Konfiguriert'**
  String get configuredLabel;

  /// No description provided for @optionalLabel.
  ///
  /// In de, this message translates to:
  /// **'Optional'**
  String get optionalLabel;

  /// No description provided for @serverDescription.
  ///
  /// In de, this message translates to:
  /// **'Verbinde dich mit deinem eigenen T4L Server. Das Telefon bleibt die Quelle der Wahrheit, und neue Pläne erfordern deine Import-Bestätigung.'**
  String get serverDescription;

  /// No description provided for @noServerSyncYet.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Server-Sync'**
  String get noServerSyncYet;

  /// No description provided for @lastServerSync.
  ///
  /// In de, this message translates to:
  /// **'Letzter Server-Sync:'**
  String get lastServerSync;

  /// No description provided for @rpeDescription6.
  ///
  /// In de, this message translates to:
  /// **'Sehr komfortabel — 4 Wdhl. Reserve'**
  String get rpeDescription6;

  /// No description provided for @rpeDescription7.
  ///
  /// In de, this message translates to:
  /// **'Kontrolliert — 3 Wdhl. Reserve'**
  String get rpeDescription7;

  /// No description provided for @rpeDescription8.
  ///
  /// In de, this message translates to:
  /// **'Hartes Set — 2 Wdhl. Reserve'**
  String get rpeDescription8;

  /// No description provided for @rpeDescription9.
  ///
  /// In de, this message translates to:
  /// **'Sehr hart — 1 Wdhl. Reserve'**
  String get rpeDescription9;

  /// No description provided for @rpeDescription10.
  ///
  /// In de, this message translates to:
  /// **'Max Effort — alles gegeben'**
  String get rpeDescription10;

  /// No description provided for @gesamt.
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get gesamt;

  /// No description provided for @avgBereitschaft.
  ///
  /// In de, this message translates to:
  /// **'Ø Bereitschaft'**
  String get avgBereitschaft;

  /// No description provided for @avgErschoepfung.
  ///
  /// In de, this message translates to:
  /// **'Ø Erschöpfung'**
  String get avgErschoepfung;

  /// No description provided for @bereitschaftLabel.
  ///
  /// In de, this message translates to:
  /// **'Bereitschaft'**
  String get bereitschaftLabel;

  /// No description provided for @erschoepfungLabel.
  ///
  /// In de, this message translates to:
  /// **'Erschöpfung'**
  String get erschoepfungLabel;

  /// No description provided for @heroTag.
  ///
  /// In de, this message translates to:
  /// **'Tag {n}'**
  String heroTag(int n);

  /// No description provided for @blockAbgeschlossenInfo.
  ///
  /// In de, this message translates to:
  /// **'{count} Workouts im Block. Details bleiben in Blocks verfügbar.'**
  String blockAbgeschlossenInfo(int count);

  /// No description provided for @sessionsCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Sessions'**
  String sessionsCount(int count);

  /// No description provided for @alleSessions.
  ///
  /// In de, this message translates to:
  /// **'Alle {count} Sessions'**
  String alleSessions(int count);

  /// No description provided for @sessionNumber.
  ///
  /// In de, this message translates to:
  /// **'Session {n}'**
  String sessionNumber(int n);

  /// No description provided for @exerciseCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Übungen'**
  String exerciseCount(int count);

  /// No description provided for @imKontext.
  ///
  /// In de, this message translates to:
  /// **'{count} im Kontext'**
  String imKontext(int count);

  /// No description provided for @mehrAnzeigen.
  ///
  /// In de, this message translates to:
  /// **'+{count} mehr'**
  String mehrAnzeigen(int count);

  /// No description provided for @bereitschaftSessions.
  ///
  /// In de, this message translates to:
  /// **'BEREITSCHAFT ({count} SESSIONS)'**
  String bereitschaftSessions(int count);

  /// No description provided for @logSaetze.
  ///
  /// In de, this message translates to:
  /// **'{count} Sätze'**
  String logSaetze(int count);

  /// No description provided for @wdhlCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Wdhl.'**
  String wdhlCount(int count);

  /// No description provided for @satzVonTotal.
  ///
  /// In de, this message translates to:
  /// **'Satz {current} / {total}'**
  String satzVonTotal(int current, int total);

  /// No description provided for @viewWeekly.
  ///
  /// In de, this message translates to:
  /// **'Woche'**
  String get viewWeekly;

  /// No description provided for @viewDaily.
  ///
  /// In de, this message translates to:
  /// **'Tag'**
  String get viewDaily;

  /// No description provided for @volumenProTag.
  ///
  /// In de, this message translates to:
  /// **'VOLUMEN / TAG'**
  String get volumenProTag;

  /// No description provided for @heute.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get heute;

  /// No description provided for @avgProTag.
  ///
  /// In de, this message translates to:
  /// **'Ø / Tag'**
  String get avgProTag;

  /// No description provided for @dialogSetDuration.
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get dialogSetDuration;

  /// No description provided for @goalsLabel.
  ///
  /// In de, this message translates to:
  /// **'ZIELE'**
  String get goalsLabel;

  /// No description provided for @yesterdayLabel.
  ///
  /// In de, this message translates to:
  /// **'GESTERN'**
  String get yesterdayLabel;

  /// No description provided for @tipsLabel.
  ///
  /// In de, this message translates to:
  /// **'BEACHTEN'**
  String get tipsLabel;

  /// No description provided for @daysLeft.
  ///
  /// In de, this message translates to:
  /// **'{count} Tage übrig'**
  String daysLeft(int count);
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
