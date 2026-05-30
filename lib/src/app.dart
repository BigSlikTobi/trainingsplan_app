import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'design/design_tokens.dart';
import 'l10n/app_localizations.dart';
import 'state/fitness_controller.dart';
import 'ui/dashboard.dart';

class T4LTrainerApp extends StatefulWidget {
  const T4LTrainerApp({super.key});

  @override
  State<T4LTrainerApp> createState() => _T4LTrainerAppState();
}

class _T4LTrainerAppState extends State<T4LTrainerApp>
    with WidgetsBindingObserver {
  late final FitnessController controller;
  Timer? _serverPoller;
  bool _workoutWakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = FitnessController();
    controller.addListener(_syncWorkoutWakelock);
    unawaited(controller.load().then((_) => controller.syncWorkoutToWatch()));
    _serverPoller = Timer.periodic(const Duration(seconds: 30), (_) {
      if (controller.bridgeConfig.isConfigured) {
        unawaited(controller.checkForCoachUpdates());
      }
    });
  }

  @override
  void dispose() {
    _serverPoller?.cancel();
    controller.removeListener(_syncWorkoutWakelock);
    unawaited(WakelockPlus.disable());
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (controller.bridgeConfig.isConfigured) {
        unawaited(controller.checkForCoachUpdates());
      }
      unawaited(controller.syncWorkoutToWatch());
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
        if (locale == null) return const Locale('en');
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) return supported;
        }
        return const Locale('en');
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.sage,
          onPrimary: AppColors.white,
          secondary: AppColors.coral,
          tertiary: AppColors.gold,
          surface: AppColors.surface,
          onSurface: AppColors.paper,
          error: AppColors.error,
          outline: AppColors.paper.withValues(alpha: 0.10),
        ),
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: Typography.whiteCupertino.apply(
          bodyColor: AppColors.paper,
          displayColor: AppColors.paper,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.paper,
          surfaceTintColor: AppColors.transparent,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.bg.withValues(alpha: 0.96),
          surfaceTintColor: AppColors.transparent,
          indicatorColor: AppColors.sage.withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 10,
              color: states.contains(WidgetState.selected)
                  ? AppColors.sage
                  : AppColors.paper.withValues(alpha: 0.28),
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.sage
                  : AppColors.paper.withValues(alpha: 0.28),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          surfaceTintColor: AppColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            side: BorderSide(
              color: AppColors.paper.withValues(alpha: AppOpacity.hairline),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            borderSide: BorderSide(
              color: AppColors.paper.withValues(alpha: 0.10),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            borderSide: BorderSide(
              color: AppColors.paper.withValues(alpha: 0.10),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            borderSide: const BorderSide(color: AppColors.sage),
          ),
          filled: true,
          fillColor: AppColors.surface2,
          hintStyle: TextStyle(color: AppColors.paper.withValues(alpha: 0.28)),
        ),
        dividerColor: AppColors.paper.withValues(alpha: 0.06),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface2,
          selectedColor: AppColors.sage.withValues(alpha: 0.22),
          side: BorderSide(color: AppColors.paper.withValues(alpha: 0.10)),
          labelStyle: const TextStyle(color: AppColors.paper),
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
