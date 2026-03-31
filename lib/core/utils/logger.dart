import 'dart:developer' as developer;

class AppLogger {
  static void log(
    String message, {
    String name = 'SupermarketApp',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(message, name: name, error: error, stackTrace: stackTrace);
  }

  static void info(String message) {
    log(message, name: 'INFO');
  }

  static void warning(String message, {Object? error}) {
    log(message, name: 'WARNING', error: error);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, name: 'ERROR', error: error, stackTrace: stackTrace);
  }
}
