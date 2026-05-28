import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/coach_payload_service.dart';

import 'helpers/sample_fitness_data.dart';

void main() {
  test('daily snapshot includes latest local context and memory wiki', () {
    final service = CoachPayloadService();

    final payload = service.buildDailySnapshot(sampleFitnessData());

    expect(payload['schema'], 'daily_snapshot.v1');
    expect(payload['profile'], isA<Map<String, dynamic>>());
    expect(payload['activeBlock'], isA<Map<String, dynamic>>());
    final memoryWiki = payload['memoryWiki'] as Map<String, dynamic>;
    expect(memoryWiki['schema'], 'memory_wiki.v1');
  });

  test('day context exports local-day activity sessions and logs', () {
    final service = CoachPayloadService();
    final payload = service.buildDayContext(
      data: sampleFitnessData(),
      activityReport: DayActivityReport(
        summary: const DayActivitySummary(
          readStatus: 'ok',
          missingPermissions: [],
          sampleCount: 4,
          steps: 12000,
          activeEnergyKcal: 650,
          exerciseMinutes: 45,
          walkingRunningDistanceMeters: 8000,
          flightsClimbed: 12,
        ),
        sessions: [
          DayActivitySession(
            id: 'run',
            activityType: 'RUNNING',
            startedAt: DateTime(2026, 5, 22, 7),
            endedAt: DateTime(2026, 5, 22, 7, 30),
            activeEnergyKcal: 320,
            distanceMeters: 5000,
            sourceName: 'Apple Watch',
          ),
        ],
      ),
      day: DateTime(2026, 5, 22),
    );

    expect(payload['schema'], 'day_context.v1');
    expect(payload['dayKey'], '2026-05-22');
    final sessions = payload['activitySessions'] as List<dynamic>;
    expect(sessions.single, containsPair('activityType', 'RUNNING'));
  });

  test('nutrition result validates positive calories', () {
    final service = CoachPayloadService();

    expect(
      () => service.parseNutritionAnalysisResult({
        'schema': 'nutrition_analysis_result.v1',
        'calories': 0,
        'protein': 20,
        'carbs': 30,
        'fat': 10,
        'bodyWeightKg': 82,
      }),
      throwsFormatException,
    );
  });

  test('next-day plan parser accepts nested server result payload', () {
    final service = CoachPayloadService();

    final workout = service.parseNextDayPlan({
      'schema': 'next_day_plan.v1',
      'plan': {
        'workout': {
          'id': 'daily_2026_05_25',
          'week': 1,
          'day': 3,
          'title': 'Tomorrow Strength',
          'focus': 'Upper body strength.',
          'rationale': 'Daily adjustment from fresh context.',
          'conditioning': '10 min easy walk',
          'exercises': [
            {
              'exerciseId': 'push_up',
              'name': 'Push-Up',
              'sets': 3,
              'reps': '8-12',
              'targetLoad': 'Bodyweight',
              'targetRpe': 7,
              'restSeconds': 75,
              'coachCue': 'Brace and move as one line.',
            },
          ],
        },
      },
    });

    expect(workout.id, 'daily_2026_05_25');
    expect(workout.exercises.single.name, 'Push-Up');
  });
}
