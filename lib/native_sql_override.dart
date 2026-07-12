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

/// Tracks which library was loaded: true = SQLCipher, false = standard SQLite
bool _sqlCipherLoaded = false;

/// Returns true if SQLCipher was successfully loaded by [applyNativeSqlOverride].
bool get isSqlCipherLoaded => _sqlCipherLoaded;

/// Apply a platform-specific override for the sqlite3 dynamic library.
///
/// This function is safe to call early during app startup. It will attempt
/// to load a list of candidate .so names and register the first one that
/// succeeds with `open.overrideFor` for Android. If none are found it will
/// fall back to `DynamicLibrary.process()` as a last resort.
///
/// After loading, set [_sqlCipherLoaded] based on the library name to track
/// whether SQLCipher or standard SQLite was loaded.
void applyNativeSqlOverride() {
  if (kIsWeb) return;

  final os = Platform.isAndroid
      ? OperatingSystem.android
      : (Platform.isLinux ? OperatingSystem.linux : null);
  if (os == null) return;

  open.overrideFor(os, () {
    DynamicLibrary? lib;

    // SQLCipher candidates first (ordered by likelihood)
    final sqlCipherCandidates = <String>[
      'libsqlcipher.so',       // Most common SQLCipher name
      'libsqlcipher.so.0',     // Versioned SQLCipher
    ];

    // Standard SQLite candidates (fallback only)
    final sqliteCandidates = <String>[
      'libsqlite3.so',         // Standard SQLite
      'libsqlite3.so.0',       // Versioned SQLite
    ];

    // Add Android-specific paths as fallback
    if (Platform.isAndroid) {
      const packageId = 'com.example.systemmarket';
      for (final name in List<String>.from(sqlCipherCandidates)) {
        sqlCipherCandidates.add('/data/data/$packageId/lib/$name');
      }
      for (final name in List<String>.from(sqliteCandidates)) {
        sqliteCandidates.add('/data/data/$packageId/lib/$name');
      }
    }

    // Try SQLCipher candidates FIRST
    for (final name in sqlCipherCandidates) {
      try {
        lib = DynamicLibrary.open(name);
        _sqlCipherLoaded = true;
        debugPrint('native_sql_override: loaded SQLCipher from $name');
        break;
      } catch (_) {
        // Silently try next candidate
      }
    }

    // Only try standard SQLite if SQLCipher failed
    if (lib == null) {
      debugPrint('native_sql_override: WARNING - SQLCipher not found, trying standard SQLite');
      for (final name in sqliteCandidates) {
        try {
          lib = DynamicLibrary.open(name);
          _sqlCipherLoaded = false;
          debugPrint('native_sql_override: loaded STANDARD SQLite from $name (encryption unavailable!)');
          break;
        } catch (_) {
          // Silently try next candidate
        }
      }
    }

    if (lib != null) return lib;

    // Last-resort for non-Android: let sqlite3 package find it
    if (!Platform.isAndroid) {
      try {
        _sqlCipherLoaded = false;
        return DynamicLibrary.process();
      } catch (_) {}
    }

    // Final fallback: try DynamicLibrary.process() on Android too
    // This works when the library is already loaded in the process
    try {
      _sqlCipherLoaded = false;
      return DynamicLibrary.process();
    } catch (_) {}

    // If nothing works, throw a clear error
    throw Exception(
        'NATIVE_LIBRARY_LOAD_FAILED: Cannot load SQLCipher or SQLite library. '
        'Ensure sqlcipher_flutter_libs is properly included in your Android build. '
        'Tried candidates: ${sqlCipherCandidates.join(", ")}, ${sqliteCandidates.join(", ")}');
  });
}
