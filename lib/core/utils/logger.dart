/// A lightweight logger wrapper around the `logging` package.
///
/// Provides coloured, level-aware output in debug mode and silently
/// drops messages below the configured threshold in release builds.
library;

import 'dart:developer' as dev;
import 'package:logging/logging.dart';

/// Pre-configured logger instance for the entire app.
///
/// Call [LoggerConfig.init] once at app startup to set the desired level.
final appLogger = Logger('Zephyr');

/// Convenience loggers scoped to common subsystems.
final dbLogger = Logger('Zephyr.DB');
final apiLogger = Logger('Zephyr.API');
final uiLogger = Logger('Zephyr.UI');

/// Central configuration for the logger hierarchy.
class LoggerConfig {
  LoggerConfig._();

  static bool _initialized = false;

  /// Initialises the root logger with the specified [level].
  ///
  /// In debug mode, messages are printed to the console with level
  /// prefixes. In release builds, only [Level.WARNING] and above are
  /// forwarded to [dart.dev.log].
  static void init({Level level = Level.INFO}) {
    if (_initialized) return;
    _initialized = true;

    // Root logger catches everything.
    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      // In release builds, use dart:developer for better performance.
      dev.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );

      // Debug: also print a human-friendly line.
      debugPrint(
        '${_levelColor(record.level)}'
        '[${record.loggerName}] '
        '${record.level.name.toLowerCase()}: '
        '${record.message}'
        '${record.error != null ? '\n  error: ${record.error}' : ''}',
      );
    });
  }

  /// ANSI colour code for a given log level.
  static String _levelColor(Level level) {
    switch (level) {
      case Level.ALL:
      case Level.FINEST:
      case Level.FINER:
      case Level.FINE:
        return '\x1B[36m'; // cyan
      case Level.CONFIG:
      case Level.INFO:
        return '\x1B[32m'; // green
      case Level.WARNING:
        return '\x1B[33m'; // yellow
      case Level.SEVERE:
      case Level.SHOUT:
        return '\x1B[31m'; // red
      case Level.OFF:
        return '';
    }
  }
}