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
  String get navErnaehrung => 'Fuel';

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
  String get tooltipSettings => 'Einstellungen';

  @override
  String get sectionUebungen => 'Übungen';

  @override
  String get btnStarten => 'Starten';

  @override
  String get btnCoachPlanImportieren => 'T4L Gym Bro Plan importieren';

  @override
  String get keinAktiverBlock => 'Kein aktiver Block';

  @override
  String get keinAktiverBlockSubtitle =>
      'Importiere deinen T4L Gym Bro Plan, um zu starten.';

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
  String get coachBewertetTrainingsauswirkung =>
      'T4L Gym Bro bewertet Trainingsauswirkung';

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
  String get coachNotiz => 'Coach Notiz';

  @override
  String get sectionConditioning => 'Conditioning';

  @override
  String get fehlerVermeiden => 'Fehler vermeiden';

  @override
  String get erklaervideo => 'Erklärvideo';

  @override
  String get coachEmptyState =>
      'Kein aktives Workout. Wähle einen Block, um den Coach zu starten.';

  @override
  String get pendingMealTitle => 'T4L Gym Bro Meal Analyse wartet';

  @override
  String get neuerCoachBlock => 'Neuer T4L Gym Bro Trainingsblock verfuegbar';

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
  String get dialogCompleteNotes => 'Notizen fuer T4L Gym Bro';

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
  String get btnAnCoachSenden => 'An T4L Gym Bro senden';

  @override
  String get dialogMealResultTitle => 'T4L Gym Bro Analyse pruefen';

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
      'Aktive Memories gehen in T4L Gym Bro Kontext und Meal Analysen.';

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
  String get dialogMemoryAktivFuerCoach => 'Aktiv fuer T4L Gym Bro';

  @override
  String get blocksHeroTitle => '8-Week Training Blocks';

  @override
  String get blocksHeroSubtitle => 'T4L Gym Bro plant, die App fuehrt aus';

  @override
  String get blocksHeroBody =>
      'Importiere den Block, den T4L Gym Bro ueber deinen Server bereitstellt.';

  @override
  String blocksCount(int count) {
    return '$count Blocks';
  }

  @override
  String get btnImportTrainingJson => 'Server-Trainingsblock importieren';

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
      'Diese Kennzahlen gehen in den naechsten T4L Gym Bro Kontext-Push.';

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
  String get settingsHeroSubtitle => 'T4L Gym Bro Server';

  @override
  String get settingsHeroBody =>
      'Alles fuer T4L Gym Bro: Server URL, API Key, Context Push und Result Checks.';

  @override
  String get settingsHeroReady => 'Ready';

  @override
  String get settingsHeroLoading => 'Loading';

  @override
  String get settingsExchangeFolder => 'T4L Server';

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
  String get exchangeFolderLoading => 'Server Setup wird geladen...';

  @override
  String get noGuidanceTitle => 'Warte auf Fuel Guidance vom Coach';

  @override
  String get noGuidanceHintStale =>
      'Guidance vom letzten Tag — warte auf neue Einschätzung vom Coach.';

  @override
  String get noGuidanceHintMissing =>
      'Coach-Analyse noch nicht eingetroffen. Exportiere den Tageskontext und warte auf die Antwort.';

  @override
  String get statusBereit => '● BEREIT';

  @override
  String get statusAktiv => '● AKTIV';

  @override
  String get statusPause => '⏸ PAUSE';

  @override
  String get statusFertig => '✓ FERTIG';

  @override
  String get statusAbgeschlossen => '✓ ABGESCHLOSSEN';

  @override
  String get statAktivLabel => 'AKTIV';

  @override
  String get statRpeAvg => 'RPE ⌀';

  @override
  String get statPlanzeit => 'PLANZEIT';

  @override
  String get statTagLabel => 'TAG';

  @override
  String get btnTrainingStarten => 'TRAINING STARTEN';

  @override
  String get btnWorkoutAbschliessen => 'WORKOUT ABSCHLIESSEN';

  @override
  String get btnWeiter => '▶ WEITER';

  @override
  String get btnPauseLabel => '⏸ PAUSE';

  @override
  String get heroUebersicht => '← Übersicht';

  @override
  String get heroSaetze => 'SÄTZE';

  @override
  String get emptyKeinBlock => '○ KEIN AKTIVER BLOCK';

  @override
  String get emptyNichtVerbunden => '○ NICHT VERBUNDEN';

  @override
  String get emptyDein => 'DEIN';

  @override
  String get emptyErster => 'ERSTER';

  @override
  String get emptyTag => 'TAG.';

  @override
  String get btnTrainingsplanLaden => 'TRAININGSPLAN LADEN';

  @override
  String get btnCoachVerbinden => 'COACH VERBINDEN →';

  @override
  String get rpeLegendWarmup => 'Warm-up';

  @override
  String get rpeLegendModerat => 'Moderat';

  @override
  String get rpeLegendHart => 'Hart';

  @override
  String get btnSatzLoggen => 'Satz loggen';

  @override
  String get blockAbgeschlossen => 'Block abgeschlossen';

  @override
  String get emptyAlleWorkoutsErledigt =>
      'Alle Workouts in diesem Block sind erledigt';

  @override
  String get emptyPlanErscheintHier => 'Dein Plan erscheint hier';

  @override
  String get fuelDiaryTitle => 'FUEL DIARY';

  @override
  String get fuelDiarySentLabel => 'SENT';

  @override
  String get fuelQualityLevel => 'Fuel Quality Level';

  @override
  String get fuelScalePoor => '1 Schlecht';

  @override
  String get fuelScalePerfect => '10 Perfekt';

  @override
  String get fuelDiaryHint => 'Was hast du gegessen oder getrunken?';

  @override
  String get fuelDiarySending => 'Wird gesendet...';

  @override
  String get fuelDiaryUpdateCoach => 'Update Coach';

  @override
  String get fuelDiarySendToCoach => 'An Coach senden';

  @override
  String get fuelDiaryEmptyHint =>
      'Logge was du gegessen hast, wie du dich fühlst, Supplements, Wasser — alles was Ernährung betrifft. Sende alles an deinen Coach wenn bereit.';

  @override
  String get aktiverBlock => 'AKTIVER BLOCK';

  @override
  String get sessionsLabel => 'SESSIONS';

  @override
  String get coachSegmentPlan => 'PLAN';

  @override
  String get coachSegmentMemory => 'MEMORY';

  @override
  String get coachSegmentSync => 'SYNC';

  @override
  String get verlauf => 'VERLAUF';

  @override
  String get nochKeineSessions => 'Noch keine Sessions abgeschlossen.';

  @override
  String get naechsteSession => 'NÄCHSTE SESSION';

  @override
  String get wirdHeuteAbendGeneriert => 'Wird heute Abend generiert';

  @override
  String get verfuegbarNach2100 => 'Verfügbar nach 21:00 Uhr';

  @override
  String get coachNotizLabel => 'COACH NOTIZ';

  @override
  String get workoutStarten => 'Workout starten';

  @override
  String get serverVerbunden => 'Server verbunden';

  @override
  String get keinServerKonfiguriert => 'Kein Server konfiguriert';

  @override
  String get syncEinstellungen => '⚙ Einstellungen';

  @override
  String get syncAktionen => 'SYNC-AKTIONEN';

  @override
  String get contextPushen => 'Context pushen';

  @override
  String get contextPushenSub => 'Athletenprofil, Block & Logs an Coach senden';

  @override
  String get ergebnisseAbrufen => 'Ergebnisse abrufen';

  @override
  String get ergebnisseAbrufenSub =>
      'Neuen Trainingsplan oder Coach-Feedback laden';

  @override
  String get serverConfigHint =>
      'Server-Konfiguration & Agent Handoff → Einstellungen';

  @override
  String get syncErledigt => 'Erledigt';

  @override
  String get memFilterAlle => 'Alle';

  @override
  String get memFilterMemories => 'Memories';

  @override
  String get memFilterConstraints => 'Constraints';

  @override
  String get keineEintraege => 'Keine Einträge';

  @override
  String get agentLabel => 'AGENT';

  @override
  String get ichLabel => 'ICH';

  @override
  String get vonDirLabel => 'von dir';

  @override
  String get coachEquals => 'Coach';

  @override
  String get memHinzufuegen => '+ Hinzufügen';

  @override
  String get constraintLabel => 'CONSTRAINT';

  @override
  String get memoryLabel => 'MEMORY';

  @override
  String get fortschrittStartetHier => 'Dein Fortschritt startet hier';

  @override
  String get fortschrittStartetHierSub =>
      'Schliesse dein erstes Workout ab und sieh wie sich deine Kraft, dein Volumen und deine Readiness entwickeln.';

  @override
  String get wasErwartetDich => 'WAS DICH ERWARTET';

  @override
  String get volumenProWoche => 'VOLUMEN / WOCHE';

  @override
  String get volumePreviewSub =>
      'Dein wöchentliches Trainingsvolumen als Balkendiagramm mit Trend und Zuwachs.';

  @override
  String get staerkePRsTitle => 'Stärke-PRs';

  @override
  String get staerkePRsSub =>
      'Deine besten Gewichte pro Übung — mit Delta-Badge bei neuem Rekord.';

  @override
  String get bereitschaftErschoepfung => 'Bereitschaft & Erschöpfung';

  @override
  String get bereitschaftErschoepfungSub =>
      'Readiness- und Soreness-Verlauf der letzten Sessions als Sparkline.';

  @override
  String get volumeChartPlaceholder => 'Hier erscheint dein Volumen-Chart';

  @override
  String get nochKeineDaten => 'Noch keine Daten';

  @override
  String get dieseWoche => 'Diese Woche';

  @override
  String get avgProWoche => 'Ø / Woche';

  @override
  String get zuwachs => 'Zuwachs';

  @override
  String get staerkePRsLabel => 'STÄRKE-PRS';

  @override
  String get weniger => 'Weniger';

  @override
  String get prHinzufuegen => '+ PR hinzufügen';

  @override
  String get prHinzufuegenTitle => 'PR hinzufügen';

  @override
  String get prBearbeitenTitle => 'PR bearbeiten';

  @override
  String get uebungLabel => 'Übung';

  @override
  String get gewichtKgLabel => 'Gewicht (kg)';

  @override
  String get gewichtKgHint => 'z.B. 100';

  @override
  String get vorherigesGewichtLabel => 'Vorheriges Gewicht (kg)';

  @override
  String get optionalHint => 'optional';

  @override
  String get imCoachKontextSenden => 'Im Coach-Kontext senden';

  @override
  String get imCoachKontextSendenSub =>
      'Wird beim nächsten Sync an den Coach übermittelt';

  @override
  String get dauerLabel => 'Dauer';

  @override
  String get heuteLabel => 'HEUTE';

  @override
  String get zielLabel => 'Ziel:';

  @override
  String get workoutSummaryTitle => 'Workout-Zusammenfassung';

  @override
  String get workoutNotFound => 'Workout nicht gefunden';

  @override
  String get uebungenUeberpruefen => 'Übungen überprüfen';

  @override
  String get keineUebungenAufgezeichnet => 'Keine Übungen aufgezeichnet.';

  @override
  String get satzHinzufuegen => 'Satz hinzufügen';

  @override
  String get notizFuerCoach => 'Notiz für den Coach…';

  @override
  String get nachbericht => 'NACHBERICHT';

  @override
  String get readinessLabel => 'Readiness';

  @override
  String get sorenessLabel => 'Soreness';

  @override
  String get readinessSehrNiedrig => 'Sehr niedrig';

  @override
  String get readinessNiedrig => 'Niedrig';

  @override
  String get readinessOk => 'OK';

  @override
  String get readinessGut => 'Gut';

  @override
  String get readinessTop => 'Top';

  @override
  String get sorenessKeine => 'Keine';

  @override
  String get sorenessLeicht => 'Leicht';

  @override
  String get sorenessModerat => 'Moderat';

  @override
  String get sorenessStark => 'Stark';

  @override
  String get sorenessSehrStark => 'Sehr stark';

  @override
  String get allgemeineNotizenHint =>
      'Allgemeine Notizen für den Coach — Technik, Energie, Anpassungen…';

  @override
  String get gesendetLabel => 'GESENDET';

  @override
  String get zumCoachSenden => 'ZUM COACH SENDEN';

  @override
  String get conditioningLabel => 'CONDITIONING';

  @override
  String get selfHostedServer => 'Self-Hosted T4L Server';

  @override
  String get configuredLabel => 'Konfiguriert';

  @override
  String get optionalLabel => 'Optional';

  @override
  String get serverDescription =>
      'Verbinde dich mit deinem eigenen T4L Server. Das Telefon bleibt die Quelle der Wahrheit, und neue Pläne erfordern deine Import-Bestätigung.';

  @override
  String get noServerSyncYet => 'Noch kein Server-Sync';

  @override
  String get lastServerSync => 'Letzter Server-Sync:';

  @override
  String get rpeDescription6 => 'Sehr komfortabel — 4 Wdhl. Reserve';

  @override
  String get rpeDescription7 => 'Kontrolliert — 3 Wdhl. Reserve';

  @override
  String get rpeDescription8 => 'Hartes Set — 2 Wdhl. Reserve';

  @override
  String get rpeDescription9 => 'Sehr hart — 1 Wdhl. Reserve';

  @override
  String get rpeDescription10 => 'Max Effort — alles gegeben';

  @override
  String get gesamt => 'Gesamt';

  @override
  String get avgBereitschaft => 'Ø Bereitschaft';

  @override
  String get avgErschoepfung => 'Ø Erschöpfung';

  @override
  String get bereitschaftLabel => 'Bereitschaft';

  @override
  String get erschoepfungLabel => 'Erschöpfung';

  @override
  String heroTag(int n) {
    return 'Tag $n';
  }

  @override
  String blockAbgeschlossenInfo(int count) {
    return '$count Workouts im Block. Details bleiben in Blocks verfügbar.';
  }

  @override
  String sessionsCount(int count) {
    return '$count Sessions';
  }

  @override
  String alleSessions(int count) {
    return 'Alle $count Sessions';
  }

  @override
  String sessionNumber(int n) {
    return 'Session $n';
  }

  @override
  String exerciseCount(int count) {
    return '$count Übungen';
  }

  @override
  String imKontext(int count) {
    return '$count im Kontext';
  }

  @override
  String mehrAnzeigen(int count) {
    return '+$count mehr';
  }

  @override
  String bereitschaftSessions(int count) {
    return 'BEREITSCHAFT ($count SESSIONS)';
  }

  @override
  String logSaetze(int count) {
    return '$count Sätze';
  }

  @override
  String wdhlCount(int count) {
    return '$count Wdhl.';
  }

  @override
  String satzVonTotal(int current, int total) {
    return 'Satz $current / $total';
  }

  @override
  String get viewWeekly => 'Woche';

  @override
  String get viewDaily => 'Tag';

  @override
  String get volumenProTag => 'VOLUMEN / TAG';

  @override
  String get heute => 'Heute';

  @override
  String get avgProTag => 'Ø / Tag';

  @override
  String get dialogSetDuration => 'Dauer';

  @override
  String get goalsLabel => 'ZIELE';

  @override
  String get yesterdayLabel => 'GESTERN';

  @override
  String get tipsLabel => 'BEACHTEN';

  @override
  String daysLeft(int count) {
    return '$count Tage übrig';
  }
}
