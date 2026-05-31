// Ensure this file is imported as early as possible (first import in main.dart)
// to override the sqlite3 dynamic library used by the `sqlite3` package on
// Android. We prefer SQLCipher's library (libsqlcipher.so) where the app
// expects an encrypted SQLite build. To be resilient during development or
// when the expected .so is missing, try multiple candidate library names
// before failing.
import 'dart:io';
import 'dart:ffi';
import 'package:sqlite3/open.dart';
import 'package:flutter/foundation.dart';

/// Apply a platform-specific override for the sqlite3 dynamic library.
///
/// This function is safe to call early during app startup. It will attempt
/// to load a list of candidate .so names and register the first one that
/// succeeds with `open.overrideFor` for Android. If none are found it will
/// fall back to `DynamicLibrary.process()` as a last resort.
void applyNativeSqlOverride() {
  if (!Platform.isAndroid) return;

  open.overrideFor(OperatingSystem.android, () {
    DynamicLibrary? lib;
    final candidates = <String>[
      'libsqlcipher.so', // preferred (SQLCipher)
      'libsqlite3.so', // common name used by some builds
      'libsqlite.so', // fallback variant
    ];

    // Workaround for some Android versions where the library name alone
    // might not be enough to locate it.
    const packageId = 'com.example.systemmarket';
    final fallbackPaths = candidates.map((name) => '/data/data/$packageId/lib/$name').toList();

    final allAttempts = [...candidates, ...fallbackPaths];

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

    // Last-resort: If no candidate library could be loaded, fail.
    // We intentionally do NOT fall back to DynamicLibrary.process() here
    // because that would risk opening an unencrypted database if SQLCipher
    // is expected.
    debugPrint('native_sql_override: critical failure - no sqlite3/sqlcipher library found.');
    throw Exception('Failed to load SQLCipher native library. Encryption cannot be guaranteed.');
  });
}
