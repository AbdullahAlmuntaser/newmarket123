// Ensure this file is imported as early as possible (first import in main.dart)
// to override the sqlite3 dynamic library used by the `sqlite3` package on
// Android. We prefer SQLCipher's library (libsqlcipher.so) where the app
// expects an encrypted SQLite build. To be resilient during development or
// when the expected .so is missing, try multiple candidate library names
// before failing.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/open.dart';

// Import ffi only on platforms that support it
import 'dart:ffi' if (dart.library.js) 'package:supermarket/dummy_ffi.dart';

/// Apply a platform-specific override for the sqlite3 dynamic library.
///
/// This function is safe to call early during app startup. It will attempt
/// to load a list of candidate .so names and register the first one that
/// succeeds with `open.overrideFor` for Android. If none are found it will
/// fall back to `DynamicLibrary.process()` as a last resort.
void applyNativeSqlOverride() {
  if (kIsWeb) return;

  final os = Platform.isAndroid ? OperatingSystem.android : (Platform.isLinux ? OperatingSystem.linux : null);
  if (os == null) return;

  open.overrideFor(os, () {
    DynamicLibrary? lib;
    final candidates = <String>[
      'libsqlcipher.so',
      'libsqlcipher.so.0',
      'libsqlite3.so',
      'libsqlite3.so.0',
    ];

    List<String> allAttempts = [...candidates];
    
    if (Platform.isAndroid) {
      const packageId = 'com.example.systemmarket';
      final fallbackPaths = candidates.map((name) => '/data/data/$packageId/lib/$name').toList();
      allAttempts.addAll(fallbackPaths);
    }

    for (final name in allAttempts) {
      try {
        debugPrint('native_sql_override: attempting to load $name');
        lib = DynamicLibrary.open(name);
        debugPrint('native_sql_override: loaded $name');
        break;
      } catch (e) {
        debugPrint('native_sql_override: failed to load $name: $e');
      }
    }

    if (lib != null) return lib;

    // Last-resort for non-Android: let sqlite3 package find it
    if (!Platform.isAndroid) {
       try {
         return DynamicLibrary.process();
       } catch (_) {}
    }

    debugPrint('native_sql_override: critical failure - no sqlite3/sqlcipher library found.');
    throw Exception('Failed to load SQLCipher native library. Encryption cannot be guaranteed.');
  });
}
