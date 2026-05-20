import '../models/fitness_models.dart';

const curatedExerciseLibrary = <ExerciseDefinition>[
  ExerciseDefinition(
    id: 'goblet_squat',
    name: 'Goblet Squat',
    focus: 'Squat pattern, quads, trunk',
    equipment: Equipment.kettlebells,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=Squat+University+goblet+squat+tutorial',
      setup:
          'Kettlebell vor der Brust, Ellbogen leicht nach unten, Fuesse stabil verschrauben.',
      cues: [
        'Rippen unten halten',
        'Knie folgen den Zehen',
        'Unten kurz Spannung halten',
      ],
      commonMistakes: [
        'Runder Ruecken',
        'Fersen verlieren Druck',
        'Knie fallen nach innen',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'romanian_deadlift',
    name: 'Rumaenisches Kreuzheben',
    focus: 'Hip hinge, hamstrings, glutes',
    equipment: Equipment.barbell,
    media: ExerciseMedia(
      explainerUrl:
          'https://repfitness.com/blogs/training/deadlift-vs-romanian-deadlift',
      setup:
          'Langhantel aus dem Stand, weiche Knie, Huefte nach hinten schieben.',
      cues: [
        'Stange bleibt nah am Bein',
        'Ruecken neutral',
        'Hinge statt Squat',
      ],
      commonMistakes: [
        'Zu tiefe Ablage erzwingen',
        'Stange driftet weg',
        'Knie beugen zu stark',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'dumbbell_floor_press',
    name: 'Kurzhantel Floor Press',
    focus: 'Chest, triceps, shoulder control',
    equipment: Equipment.dumbbells,
    media: ExerciseMedia(
      explainerUrl:
          'https://support.runna.com/en/articles/6413209-floor-dumbbell-bench-press-exercise-tutorial',
      setup:
          'Ruecken am Boden, Fuesse aufgestellt, Oberarme kontrolliert bis zum Boden.',
      cues: [
        'Handgelenke gestapelt',
        'Ellbogen 30-45 Grad',
        'Oben aktiv auspressen',
      ],
      commonMistakes: [
        'Schultern hochziehen',
        'Hanteln kollidieren oben',
        'Unterer Ruecken ueberstreckt',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'one_arm_row',
    name: 'Einarmiges Rudern',
    focus: 'Lats, upper back, anti-rotation',
    equipment: Equipment.dumbbells,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=one+arm+dumbbell+row+tutorial+proper+form',
      setup:
          'Eine Hand abgestuetzt, Ruecken lang, Hantel unter Schulter starten.',
      cues: [
        'Schulterblatt zuerst',
        'Ellbogen zur Huefte',
        'Torso ruhig halten',
      ],
      commonMistakes: [
        'Rotieren statt rudern',
        'Nacken zieht mit',
        'Zu kurzer Bewegungsweg',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'military_press',
    name: 'Military Press',
    focus: 'Shoulders, triceps, trunk stiffness',
    equipment: Equipment.barbell,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=barbell+overhead+press+tutorial+Alan+Thrall',
      setup:
          'Stange auf Schulterhoehe, Gesäss und Bauch fest, Blick geradeaus.',
      cues: ['Kopf durch das Fenster', 'Rippen unten', 'Stange nah am Gesicht'],
      commonMistakes: [
        'Rueckenlage als Ersatz',
        'Stange wandert nach vorne',
        'Lockout halbherzig',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'curl_bar_curl',
    name: 'Curlstangen-Curls',
    focus: 'Biceps, elbow flexion',
    equipment: Equipment.curlBar,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=ez+bar+curl+proper+form',
      setup:
          'Aufrecht stehen, Ellbogen leicht vor dem Koerper, Handgelenke neutral.',
      cues: ['Oberarm ruhig', 'Oben kurz druecken', 'Langsam ablassen'],
      commonMistakes: [
        'Huefte schwingt',
        'Handgelenke knicken',
        'Nur halbe Wiederholungen',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'band_face_pull',
    name: 'Band Face Pull',
    focus: 'Rear delts, rotator cuff, posture',
    equipment: Equipment.bands,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=band+face+pull+tutorial',
      setup:
          'Band auf Gesichtshoehe fixieren, Daumen nach hinten, Brustbein ruhig.',
      cues: ['Zur Stirn ziehen', 'Ellbogen hoch', 'Schulterblaetter bewegen'],
      commonMistakes: [
        'Lendenwirbel ueberstrecken',
        'Zu schnell',
        'Haende ziehen nach unten',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'kettlebell_swing',
    name: 'Kettlebell Swing',
    focus: 'Power, posterior chain, conditioning',
    equipment: Equipment.kettlebells,
    media: ExerciseMedia(
      explainerUrl: 'https://repfitness.com/blogs/training/kettlebell-swings',
      setup: 'Kettlebell vor den Fuessen, hike pass, explosiver Hueftschub.',
      cues: ['Arme sind Haken', 'Snap aus der Huefte', 'Plank oben'],
      commonMistakes: [
        'Squat statt Hinge',
        'Hantel mit Armen heben',
        'Hyperextension oben',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'bulgarian_split_squat',
    name: 'Bulgarian Split Squat',
    focus: 'Single-leg strength, glutes, quads',
    equipment: Equipment.dumbbells,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=bulgarian+split+squat+tutorial+proper+form',
      setup: 'Hinterer Fuss erhoeht, Vorderfuss stabil, Hanteln seitlich.',
      cues: [
        'Langsam ablassen',
        'Vorderfuss bleibt voll belastet',
        'Hofte gerade',
      ],
      commonMistakes: [
        'Zu enger Stand',
        'Abstossen mit hinterem Bein',
        'Knie kollabiert innen',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'band_pallof_press',
    name: 'Band Pallof Press',
    focus: 'Anti-rotation core',
    equipment: Equipment.bands,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=band+pallof+press+tutorial',
      setup: 'Seitlich zum Bandanker, Band vor Brust, Fuesse fest.',
      cues: ['Arme gerade auspressen', 'Becken bleibt ruhig', 'Langsam atmen'],
      commonMistakes: [
        'Rotation zulassen',
        'Schultern hochziehen',
        'Zu leichter Bandzug',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'bosu_plank',
    name: 'BOSU Plank',
    focus: 'Trunk stability, shoulder control',
    equipment: Equipment.bosu,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=bosu+plank+tutorial',
      setup:
          'Unterarme oder Haende auf BOSU, Koerper als Linie, ruhige Atmung.',
      cues: ['Becken neutral', 'Boden wegdruecken', 'Rippen runter'],
      commonMistakes: [
        'Huefte haengt',
        'Kopf faellt',
        'Zu lange Sets mit Formverlust',
      ],
    ),
  ),
  ExerciseDefinition(
    id: 'turkish_get_up',
    name: 'Turkish Get-Up',
    focus: 'Full-body control, shoulder stability',
    equipment: Equipment.kettlebells,
    media: ExerciseMedia(
      explainerUrl:
          'https://www.youtube.com/results?search_query=turkish+get+up+tutorial+strongfirst',
      setup:
          'Kettlebell sicher zum Lockout bringen, jede Position bewusst aufbauen.',
      cues: ['Blick zur Glocke', 'Schulter gepackt', 'Jede Position pausieren'],
      commonMistakes: [
        'Zu schwer starten',
        'Schulter verliert Position',
        'Schritte ueberspringen',
      ],
    ),
  ),
];

ExerciseDefinition? exerciseById(String id) {
  for (final exercise in curatedExerciseLibrary) {
    if (exercise.id == id) return exercise;
  }
  return null;
}
