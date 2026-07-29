import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'log_sanitizer.dart';

class AppLogger {
  const AppLogger._();

  static void debug(String message, {String name = 'crmx'}) {
    if (kDebugMode) {
      developer.log(
        LogSanitizer.sanitize(message),
        name: name,
        level: 500,
      );
    }
  }

  static void info(String message, {String name = 'crmx'}) {
    developer.log(
      LogSanitizer.sanitize(message),
      name: name,
      level: 800,
    );
  }

  static void warning(String message, {String name = 'crmx'}) {
    developer.log(
      LogSanitizer.sanitize(message),
      name: name,
      level: 900,
    );
  }

  static void error(
    String message, {
    String name = 'crmx',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      LogSanitizer.sanitize(message),
      name: name,
      level: 1000,
      error: error == null ? null : LogSanitizer.sanitize(error),
      stackTrace: stackTrace,
    );
  }
}
