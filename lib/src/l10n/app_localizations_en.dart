// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHeute => 'Today';

  @override
  String get navBlocks => 'Blocks';

  @override
  String get navErnaehrung => 'Fuel';

  @override
  String get navCoach => 'Coach';

  @override
  String get navProgress => 'Progress';

  @override
  String get navSetup => 'Setup';

  @override
  String get tooltipHealthKit => 'Connect HealthKit';

  @override
  String get tooltipExport => 'Export snapshot';

  @override
  String get tooltipSettings => 'Settings';

  @override
  String get sectionUebungen => 'Exercises';

  @override
  String get btnStarten => 'Start';

  @override
  String get btnCodexPlanImportieren => 'Import Codex Plan';

  @override
  String get keinAktiverBlock => 'No active block';

  @override
  String get keinAktiverBlockSubtitle =>
      'Import your Codex Plan to get started.';

  @override
  String get labelCoach => 'COACH';

  @override
  String get labelProfil => 'Profile';

  @override
  String get nutritionHeaderTitle => 'Fuel + Recovery';

  @override
  String weekDay(int week, int day) {
    return 'W$week · D$day';
  }

  @override
  String woche(int week) {
    return 'Week $week';
  }

  @override
  String get signalGreenLight => 'GREEN LIGHT';

  @override
  String get signalGreenLightSub =>
      'Fuel and readiness aligned — full throttle today.';

  @override
  String get signalHold => 'HOLD';

  @override
  String get signalHoldSub => 'Signals neutral — keep intensity steady.';

  @override
  String get signalFuelFirst => 'FUEL FIRST';

  @override
  String get signalFuelFirstSub => 'Low intake — refuel before training.';

  @override
  String get signalDeloadBias => 'DELOAD BIAS';

  @override
  String get signalDeloadBiasSub => 'Weak fuel and recovery — reduce load.';

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
  String get btnSpeichern => 'Save';

  @override
  String get btnVerwerfen => 'Discard';

  @override
  String get btnAbbrechen => 'Cancel';

  @override
  String get btnMakrosAusblenden => 'Hide macros';

  @override
  String get btnDetails => 'Details';

  @override
  String get mahlzeitAnalysieren => 'Analyse meal';

  @override
  String get codexBewertetTrainingsauswirkung =>
      'Codex evaluates training impact';

  @override
  String get mahlzeit => 'Meal';

  @override
  String get coachPageTitle => 'Training';

  @override
  String uebungProgress(int idx, int total) {
    return 'EXERCISE $idx / $total';
  }

  @override
  String get statSaetze => 'Sets';

  @override
  String get statWdhl => 'Reps';

  @override
  String get statLast => 'Load';

  @override
  String get statRpe => 'RPE';

  @override
  String get statPause => 'Rest';

  @override
  String get sectionAlleUebungen => 'All Exercises';

  @override
  String get coachNotiz => 'Coach Note';

  @override
  String get sectionConditioning => 'Conditioning';

  @override
  String get fehlerVermeiden => 'Avoid mistakes';

  @override
  String get erklaervideo => 'Tutorial';

  @override
  String get coachEmptyState =>
      'No active workout. Select a block to start the Coach.';

  @override
  String get pendingMealTitle => 'Codex Meal Analysis pending';

  @override
  String get neuerCodexBlock => 'New Codex training block available';

  @override
  String get btnImport => 'Import';

  @override
  String dialogSetTitle(String exerciseName) {
    return 'Log $exerciseName';
  }

  @override
  String get dialogSetWeight => 'Weight kg';

  @override
  String get dialogSetReps => 'Reps';

  @override
  String get dialogSetRpe => 'RPE';

  @override
  String get dialogCompleteTitle => 'Complete workout';

  @override
  String dialogCompleteReadiness(int value) {
    return 'Readiness $value';
  }

  @override
  String dialogCompleteSoreness(int value) {
    return 'Soreness $value';
  }

  @override
  String get dialogCompleteNotes => 'Notes for Codex';

  @override
  String get btnFertig => 'Done';

  @override
  String get dialogMealAnalysisTitle => 'Analyse meal';

  @override
  String get dialogMealAnalysisWhat => 'What did you eat?';

  @override
  String get dialogMealAnalysisHint =>
      'e.g. bowl with rice, chicken, avocado, sauce';

  @override
  String get btnFoto => 'Photo';

  @override
  String get btnKamera => 'Camera';

  @override
  String get btnAnCodexSenden => 'Send to Codex';

  @override
  String get dialogMealResultTitle => 'Review Codex analysis';

  @override
  String get dialogMealResultKalorien => 'Calories';

  @override
  String get dialogMealResultProtein => 'Protein g';

  @override
  String get dialogMealResultCarbs => 'Carbs g';

  @override
  String get dialogMealResultFett => 'Fat g';

  @override
  String get dialogMealResultKoerpergewicht => 'Body weight kg';

  @override
  String get dialogMealResultKorrektur => 'Correction / Notes';

  @override
  String get dialogProfileTitle => 'Nutrition Profile';

  @override
  String get dialogProfileTrainingsziel => 'Training goal';

  @override
  String get dialogProfileGroesse => 'Height cm';

  @override
  String get dialogProfileGewicht => 'Weight kg';

  @override
  String get dialogProfileAlter => 'Age';

  @override
  String get dialogProfileSex => 'Sex';

  @override
  String get memoryWikiTitle => 'Memory Wiki';

  @override
  String memoryWikiAktiv(int count) {
    return '$count active';
  }

  @override
  String get memoryWikiSubtitle =>
      'Active memories are included in Codex snapshots and meal analyses.';

  @override
  String get memoryWikiEmpty => 'No memories saved yet.';

  @override
  String get tooltipMemoryHinzufuegen => 'Add memory';

  @override
  String get tooltipBearbeiten => 'Edit';

  @override
  String get tooltipLoeschen => 'Delete';

  @override
  String get dialogMemoryAddTitle => 'Add memory';

  @override
  String get dialogMemoryEditTitle => 'Edit memory';

  @override
  String get dialogMemoryKategorie => 'Category';

  @override
  String get dialogMemoryTitel => 'Title';

  @override
  String get dialogMemoryKurzMemory => 'Short memory';

  @override
  String get dialogMemoryMarkdown => 'Markdown details';

  @override
  String get dialogMemoryAktivFuerCodex => 'Active for Codex';

  @override
  String get blocksHeroTitle => '8-Week Training Blocks';

  @override
  String get blocksHeroSubtitle => 'Codex plans, the app executes';

  @override
  String get blocksHeroBody => 'Import the block Codex provides in iCloud.';

  @override
  String blocksCount(int count) {
    return '$count Blocks';
  }

  @override
  String get btnImportTrainingJson => 'Import training_block_plan.json';

  @override
  String blockCardWeeks(int weeks, String createdBy) {
    return '$weeks weeks · $createdBy';
  }

  @override
  String blockCardTargets(String targets) {
    return 'Targets: $targets';
  }

  @override
  String blockCardWorkouts(int count) {
    return '$count planned workouts';
  }

  @override
  String get progressHeroTitle => 'Progress';

  @override
  String get progressHeroBody =>
      'These metrics go into the next Codex snapshot.';

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
  String get settingsHeroSubtitle => 'Codex, Claude or other coach';

  @override
  String get settingsHeroBody =>
      'Everything a new agent needs: iCloud folder, start prompt, daily routine and write commands.';

  @override
  String get settingsHeroReady => 'Ready';

  @override
  String get settingsHeroLoading => 'Loading';

  @override
  String get settingsExchangeFolder => 'iCloud Exchange Folder';

  @override
  String get settingsBootstrapUrl => 'Agent Bootstrap URL';

  @override
  String get settingsStartprompt => 'Agent Start Prompt';

  @override
  String get settingsWriteCommands => 'Validated Write Commands';

  @override
  String get settingsChecklist => 'Daily Agent Checklist';

  @override
  String get tooltipKopieren => 'Copy';

  @override
  String get snackbarKopiert => 'Copied';

  @override
  String get exchangeFolderLoading => 'Loading exchange folder...';

  @override
  String get noGuidanceTitle => 'Waiting for fuel guidance from the coach';

  @override
  String get noGuidanceHintStale =>
      'Guidance is from a previous day — waiting for a fresh read from the coach.';

  @override
  String get noGuidanceHintMissing =>
      'Coach analysis hasn\'t arrived yet. Export today\'s context and wait for the response.';
}
