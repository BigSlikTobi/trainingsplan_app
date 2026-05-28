import 'dart:developer' as developer;

/// Lightweight structured logging for the app.
///
/// Routes through `dart:developer.log` so messages show up in the IDE and
/// DevTools with a consistent source name, severity level, and an attached
/// error + stack trace. This replaces the previous pattern of swallowing
/// exceptions into user-facing status strings with no developer-visible trace,
/// which made failures effectively invisible during debugging.
///
/// Levels follow the conventional `dart:developer` scale (see `package:logging`
/// `Level`): 800 = INFO, 900 = WARNING, 1000 = SEVERE.
abstract final class AppLog {
  static const _name = 't4l';

  static void info(String message) {
    developer.log(message, name: _name, level: 800);
  }

  static void warn(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _name,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
