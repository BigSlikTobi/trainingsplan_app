import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/app.dart';
import 'package:trainingsplan_app/src/data/local_store.dart';
import 'package:trainingsplan_app/src/data/seed_data.dart';
import 'package:trainingsplan_app/src/l10n/app_localizations.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/state/fitness_controller.dart';
import 'package:trainingsplan_app/src/ui/dashboard.dart';

void main() {
  testWidgets('shows coached fitness app navigation', (tester) async {
    await tester.pumpWidget(const CodexCoachApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('T4L Trainer'), findsOneWidget);
  });

  testWidgets('nutrition page exposes Codex meal analysis flow', (
    tester,
  ) async {
    final controller = FitnessController(store: _WidgetStore());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Ernaehrung'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Mahlzeit analysieren'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Mahlzeit analysieren'), findsOneWidget);
  });

  testWidgets('setup page exposes agent handoff details', (tester) async {
    final controller = FitnessController(store: _WidgetStore());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();

    expect(find.text('Agent Setup'), findsOneWidget);
    expect(find.text('iCloud Exchange Folder'), findsOneWidget);
    expect(find.text('Agent Bootstrap URL'), findsOneWidget);
    expect(find.textContaining('CodexFitnessExchange'), findsWidgets);
  });
}

class _WidgetStore extends LocalFitnessStore {
  @override
  Future<FitnessData> load() async => createSeedFitnessData();

  @override
  Future<void> save(FitnessData data) async {}

  @override
  Future<File> writeExchangeJson(
    String fileName,
    Map<String, dynamic> payload,
  ) async {
    return File(fileName);
  }

  @override
  Future<bool> exchangeJsonExists(String fileName) async => false;

  @override
  Future<Directory> getExchangeDirectory() async {
    return Directory('/tmp/CodexFitnessExchange');
  }
}
