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

  /// Bottom nav: nutrition tab
  ///
  /// In de, this message translates to:
  /// **'Ernaehrung'**
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

  /// Create block button label
  ///
  /// In de, this message translates to:
  /// **'+ Block erstellen'**
  String get btnBlockErstellen;

  /// Import Codex plan button label
  ///
  /// In de, this message translates to:
  /// **'Codex Plan importieren'**
  String get btnCodexPlanImportieren;

  /// Empty state heading: no active block
  ///
  /// In de, this message translates to:
  /// **'Kein aktiver Block'**
  String get keinAktiverBlock;

  /// Empty state subtitle: no active block
  ///
  /// In de, this message translates to:
  /// **'Starte mit einer Vorlage oder importiere deinen Codex Plan.'**
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
  /// **'Codex bewertet Trainingsauswirkung'**
  String get codexBewertetTrainingsauswirkung;

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
  /// **'Codex Meal Analyse wartet'**
  String get pendingMealTitle;

  /// Banner: new Codex training block available
  ///
  /// In de, this message translates to:
  /// **'Neuer Codex Trainingsblock verfuegbar'**
  String get neuerCodexBlock;

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
  /// **'Notizen fuer Codex'**
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

  /// Send meal analysis to Codex button
  ///
  /// In de, this message translates to:
  /// **'An Codex senden'**
  String get btnAnCodexSenden;

  /// Meal result review dialog title
  ///
  /// In de, this message translates to:
  /// **'Codex Analyse pruefen'**
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
  /// **'Aktive Memories gehen in Codex Snapshots und Meal Analysen.'**
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
  /// **'Aktiv fuer Codex'**
  String get dialogMemoryAktivFuerCodex;

  /// Blocks page hero panel title (brand voice: keep English)
  ///
  /// In de, this message translates to:
  /// **'8-Week Training Blocks'**
  String get blocksHeroTitle;

  /// Blocks page hero panel subtitle
  ///
  /// In de, this message translates to:
  /// **'Codex plant, die App fuehrt aus'**
  String get blocksHeroSubtitle;

  /// Blocks page hero panel body
  ///
  /// In de, this message translates to:
  /// **'Starte lokal mit einer Sport-Vorlage oder importiere den Block, den Codex in iCloud bereitstellt.'**
  String get blocksHeroBody;

  /// Blocks count trailing text
  ///
  /// In de, this message translates to:
  /// **'{count} Blocks'**
  String blocksCount(int count);

  /// Import training block JSON button label
  ///
  /// In de, this message translates to:
  /// **'training_block_plan.json importieren'**
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
  /// **'Diese Kennzahlen gehen in den naechsten Codex Snapshot.'**
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
  /// **'Codex, Claude oder anderer Coach'**
  String get settingsHeroSubtitle;

  /// Settings page hero body
  ///
  /// In de, this message translates to:
  /// **'Alle Infos, die ein neuer Agent braucht: iCloud Ordner, Startprompt, Tagesablauf und Schreibbefehle.'**
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

  /// Settings copy card: exchange folder title
  ///
  /// In de, this message translates to:
  /// **'iCloud Exchange Folder'**
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

  /// Settings: exchange folder loading placeholder
  ///
  /// In de, this message translates to:
  /// **'Exchange folder wird geladen...'**
  String get exchangeFolderLoading;
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
