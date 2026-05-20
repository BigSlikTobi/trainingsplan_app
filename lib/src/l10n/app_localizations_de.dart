// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navHeute => 'Heute';

  @override
  String get navBlocks => 'Blocks';

  @override
  String get navErnaehrung => 'Ernaehrung';

  @override
  String get navCoach => 'Coach';

  @override
  String get navProgress => 'Progress';

  @override
  String get navSetup => 'Setup';

  @override
  String get tooltipHealthKit => 'HealthKit verbinden';

  @override
  String get tooltipExport => 'Snapshot exportieren';

  @override
  String get sectionUebungen => 'Übungen';

  @override
  String get btnStarten => 'Starten';

  @override
  String get btnBlockErstellen => '+ Block erstellen';

  @override
  String get btnCodexPlanImportieren => 'Codex Plan importieren';

  @override
  String get keinAktiverBlock => 'Kein aktiver Block';

  @override
  String get keinAktiverBlockSubtitle =>
      'Starte mit einer Vorlage oder importiere deinen Codex Plan.';

  @override
  String get labelCoach => 'COACH';

  @override
  String get labelProfil => 'Profil';

  @override
  String get nutritionHeaderTitle => 'Fuel + Recovery';

  @override
  String weekDay(int week, int day) {
    return 'W$week · T$day';
  }

  @override
  String woche(int week) {
    return 'Woche $week';
  }

  @override
  String get signalGreenLight => 'GREEN LIGHT';

  @override
  String get signalGreenLightSub =>
      'Fuel und Readiness im Einklang — heute Vollgas.';

  @override
  String get signalHold => 'HOLD';

  @override
  String get signalHoldSub => 'Signale neutral — Intensität stabil halten.';

  @override
  String get signalFuelFirst => 'FUEL FIRST';

  @override
  String get signalFuelFirstSub =>
      'Wenig gegessen — vor dem Training auffüllen.';

  @override
  String get signalDeloadBias => 'DELOAD BIAS';

  @override
  String get signalDeloadBiasSub =>
      'Schwaches Fuel und Erholung — Last reduzieren.';

  @override
  String get chipProtein => 'PROTEIN';

  @override
  String get chipCarbs => 'CARBS';

  @override
  String get chipHydration => 'HYDRATION';

  @override
  String get levelHigh => 'HIGH';

  @override
  String get levelModerate => 'MODERATE';

  @override
  String get levelLow => 'LOW';

  @override
  String get sectionYesterdaysSignal => 'YESTERDAY\'S SIGNAL';

  @override
  String get sectionTodaysFuel => 'TODAY\'S FUEL';

  @override
  String get sectionMealSuggestion => 'MEAL SUGGESTION';

  @override
  String get sectionMealIdeas => 'Meal Ideas';

  @override
  String get sectionMealAnalysis => 'Meal Analysis';

  @override
  String get sectionTrainingImpact => 'TRAINING IMPACT';

  @override
  String get btnSpeichern => 'Speichern';

  @override
  String get btnVerwerfen => 'Verwerfen';

  @override
  String get btnAbbrechen => 'Abbrechen';

  @override
  String get btnMakrosAusblenden => 'Makros ausblenden';

  @override
  String get btnDetails => 'Details';

  @override
  String get mahlzeitAnalysieren => 'Mahlzeit analysieren';

  @override
  String get codexBewertetTrainingsauswirkung =>
      'Codex bewertet Trainingsauswirkung';

  @override
  String get mahlzeit => 'Mahlzeit';

  @override
  String get coachPageTitle => 'Training';

  @override
  String uebungProgress(int idx, int total) {
    return 'ÜBUNG $idx / $total';
  }

  @override
  String get statSaetze => 'Sätze';

  @override
  String get statWdhl => 'Wdhl.';

  @override
  String get statLast => 'Last';

  @override
  String get statRpe => 'RPE';

  @override
  String get statPause => 'Pause';

  @override
  String get sectionAlleUebungen => 'Alle Übungen';

  @override
  String get erklaervideo => 'Erklärvideo';

  @override
  String get coachEmptyState =>
      'Kein aktives Workout. Wähle einen Block, um den Coach zu starten.';

  @override
  String get pendingMealTitle => 'Codex Meal Analyse wartet';

  @override
  String get neuerCodexBlock => 'Neuer Codex Trainingsblock verfuegbar';

  @override
  String get btnImport => 'Import';

  @override
  String dialogSetTitle(String exerciseName) {
    return '$exerciseName loggen';
  }

  @override
  String get dialogSetWeight => 'Gewicht kg';

  @override
  String get dialogSetReps => 'Wiederholungen';

  @override
  String get dialogSetRpe => 'RPE';

  @override
  String get dialogCompleteTitle => 'Workout abschliessen';

  @override
  String dialogCompleteReadiness(int value) {
    return 'Readiness $value';
  }

  @override
  String dialogCompleteSoreness(int value) {
    return 'Soreness $value';
  }

  @override
  String get dialogCompleteNotes => 'Notizen fuer Codex';

  @override
  String get btnFertig => 'Fertig';

  @override
  String get dialogMealAnalysisTitle => 'Meal analysieren';

  @override
  String get dialogMealAnalysisWhat => 'Was hast du gegessen?';

  @override
  String get dialogMealAnalysisHint =>
      'z.B. Bowl mit Reis, Huhn, Avocado, Sauce';

  @override
  String get btnFoto => 'Foto';

  @override
  String get btnKamera => 'Kamera';

  @override
  String get btnAnCodexSenden => 'An Codex senden';

  @override
  String get dialogMealResultTitle => 'Codex Analyse pruefen';

  @override
  String get dialogMealResultKalorien => 'Kalorien';

  @override
  String get dialogMealResultProtein => 'Protein g';

  @override
  String get dialogMealResultCarbs => 'Carbs g';

  @override
  String get dialogMealResultFett => 'Fett g';

  @override
  String get dialogMealResultKoerpergewicht => 'Koerpergewicht kg';

  @override
  String get dialogMealResultKorrektur => 'Korrektur/Notizen';

  @override
  String get dialogProfileTitle => 'Nutrition Profil';

  @override
  String get dialogProfileTrainingsziel => 'Trainingsziel';

  @override
  String get dialogProfileGroesse => 'Groesse cm';

  @override
  String get dialogProfileGewicht => 'Gewicht kg';

  @override
  String get dialogProfileAlter => 'Alter';

  @override
  String get dialogProfileSex => 'Sex';

  @override
  String get memoryWikiTitle => 'Memory Wiki';

  @override
  String memoryWikiAktiv(int count) {
    return '$count aktiv';
  }

  @override
  String get memoryWikiSubtitle =>
      'Aktive Memories gehen in Codex Snapshots und Meal Analysen.';

  @override
  String get memoryWikiEmpty => 'Noch keine Memories gespeichert.';

  @override
  String get tooltipMemoryHinzufuegen => 'Memory hinzufuegen';

  @override
  String get tooltipBearbeiten => 'Bearbeiten';

  @override
  String get tooltipLoeschen => 'Loeschen';

  @override
  String get dialogMemoryAddTitle => 'Memory hinzufuegen';

  @override
  String get dialogMemoryEditTitle => 'Memory editieren';

  @override
  String get dialogMemoryKategorie => 'Kategorie';

  @override
  String get dialogMemoryTitel => 'Titel';

  @override
  String get dialogMemoryKurzMemory => 'Kurz-Memory';

  @override
  String get dialogMemoryMarkdown => 'Markdown Details';

  @override
  String get dialogMemoryAktivFuerCodex => 'Aktiv fuer Codex';

  @override
  String get blocksHeroTitle => '8-Week Training Blocks';

  @override
  String get blocksHeroSubtitle => 'Codex plant, die App fuehrt aus';

  @override
  String get blocksHeroBody =>
      'Starte lokal mit einer Sport-Vorlage oder importiere den Block, den Codex in iCloud bereitstellt.';

  @override
  String blocksCount(int count) {
    return '$count Blocks';
  }

  @override
  String get btnImportTrainingJson => 'training_block_plan.json importieren';

  @override
  String blockCardWeeks(int weeks, String createdBy) {
    return '$weeks Wochen · $createdBy';
  }

  @override
  String blockCardTargets(String targets) {
    return 'Targets: $targets';
  }

  @override
  String blockCardWorkouts(int count) {
    return '$count geplante Workouts';
  }

  @override
  String get progressHeroTitle => 'Progress';

  @override
  String get progressHeroBody =>
      'Diese Kennzahlen gehen in den naechsten Codex Snapshot.';

  @override
  String progressDone(int count) {
    return '$count done';
  }

  @override
  String progressLogSets(int sets, String volume, String status) {
    return '$sets Sets · $volume kg · $status';
  }

  @override
  String get settingsHeroTitle => 'Agent Setup';

  @override
  String get settingsHeroSubtitle => 'Codex, Claude oder anderer Coach';

  @override
  String get settingsHeroBody =>
      'Alle Infos, die ein neuer Agent braucht: iCloud Ordner, Startprompt, Tagesablauf und Schreibbefehle.';

  @override
  String get settingsHeroReady => 'Ready';

  @override
  String get settingsHeroLoading => 'Loading';

  @override
  String get settingsExchangeFolder => 'iCloud Exchange Folder';

  @override
  String get settingsBootstrapUrl => 'Agent Bootstrap URL';

  @override
  String get settingsStartprompt => 'Agent Startprompt';

  @override
  String get settingsWriteCommands => 'Validated Write Commands';

  @override
  String get settingsChecklist => 'Daily Agent Checklist';

  @override
  String get tooltipKopieren => 'Kopieren';

  @override
  String get snackbarKopiert => 'Kopiert';

  @override
  String get exchangeFolderLoading => 'Exchange folder wird geladen...';

  @override
  String get noGuidanceTitle => 'Warte auf Fuel Guidance vom Coach';

  @override
  String get noGuidanceHintStale =>
      'Guidance vom letzten Tag — warte auf neue Einschätzung vom Coach.';

  @override
  String get noGuidanceHintMissing =>
      'Coach-Analyse noch nicht eingetroffen. Exportiere den Tageskontext und warte auf die Antwort.';
}
