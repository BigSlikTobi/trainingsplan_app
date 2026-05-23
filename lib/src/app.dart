import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'design/design_tokens.dart';
import 'l10n/app_localizations.dart';
import 'state/fitness_controller.dart';
import 'ui/dashboard.dart';

class CodexCoachApp extends StatefulWidget {
  const CodexCoachApp({super.key});

  @override
  State<CodexCoachApp> createState() => _CodexCoachAppState();
}

class _CodexCoachAppState extends State<CodexCoachApp>
    with WidgetsBindingObserver {
  late final FitnessController controller;
  Timer? _exchangePoller;
  bool _workoutWakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = FitnessController();
    controller.addListener(_syncWorkoutWakelock);
    unawaited(controller.load().then((_) => controller.syncWorkoutToWatch()));
    _exchangePoller = Timer.periodic(
      const Duration(seconds: 30),
      (_) => controller.checkForCodexUpdates(),
    );
  }

  @override
  void dispose() {
    _exchangePoller?.cancel();
    controller.removeListener(_syncWorkoutWakelock);
    unawaited(WakelockPlus.disable());
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.checkForCodexUpdates();
      controller.syncWorkoutToWatch();
      _syncWorkoutWakelock(force: true);
    }
  }

  void _syncWorkoutWakelock({bool force = false}) {
    final shouldEnable = controller.hasActiveWorkout;
    if (!force && _workoutWakelockEnabled == shouldEnable) return;
    _workoutWakelockEnabled = shouldEnable;
    unawaited(WakelockPlus.toggle(enable: shouldEnable));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppTokens.appName,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return const Locale('de');
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) return supported;
        }
        return const Locale('de');
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.ink,
          onPrimary: AppColors.paper,
          secondary: AppColors.coral,
          onSecondary: AppColors.ink,
          tertiary: AppColors.sage,
          surface: AppColors.paper,
          onSurface: AppColors.ink,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: Typography.blackCupertino.apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.ink,
          surfaceTintColor: AppColors.transparent,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.paper,
          indicatorColor: AppColors.sage.withValues(
            alpha: AppOpacity.selectedFill,
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AppColors.ink
                  : AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.ink
                  : AppColors.ink.withValues(alpha: AppOpacity.mutedIcon),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.white,
          surfaceTintColor: AppColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            side: BorderSide(
              color: AppColors.ink.withValues(alpha: AppOpacity.subtle),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          filled: true,
          fillColor: AppColors.white,
        ),
      ),
      home: FitnessScope(controller: controller, child: const CoachDashboard()),
    );
  }
}

class FitnessScope extends InheritedNotifier<FitnessController> {
  const FitnessScope({
    required FitnessController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static FitnessController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FitnessScope>();
    assert(scope != null, 'FitnessScope missing');
    return scope!.notifier!;
  }
}
