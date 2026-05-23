import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/app.dart';
import 'package:trainingsplan_app/src/data/local_store.dart';
import 'package:trainingsplan_app/src/l10n/app_localizations.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/local_bridge_service.dart';
import 'package:trainingsplan_app/src/state/fitness_controller.dart';
import 'package:trainingsplan_app/src/ui/dashboard.dart';

import 'helpers/sample_fitness_data.dart';

void main() {
  testWidgets('shows coached fitness app navigation', (tester) async {
    await tester.pumpWidget(const CodexCoachApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
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

    await tester.tap(find.text('Fuel'));
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

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Agent Setup'), findsOneWidget);
    expect(find.text('Self-Hosted T4L Server'), findsOneWidget);
    expect(find.text('Migrate Data'), findsOneWidget);
    expect(find.text('Push Context'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Complete Agent Handoff'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Complete Agent Handoff'), findsOneWidget);
    expect(find.textContaining('CodexFitnessExchange'), findsWidgets);
  });
}

class _WidgetStore extends LocalFitnessStore {
  LocalBridgeConfig bridgeConfig = const LocalBridgeConfig();

  @override
  Future<FitnessData> load() async => sampleFitnessData();

  @override
  Future<void> save(FitnessData data) async {}

  @override
  Future<LocalBridgeConfig> loadBridgeConfig() async => bridgeConfig;

  @override
  Future<void> saveBridgeConfig(LocalBridgeConfig config) async {
    bridgeConfig = config;
  }

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
