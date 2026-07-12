// Dummy file to allow conditional import of dart:ffi on web.
// On web, DynamicLibrary is never actually used (applyNativeSqlOverride
// returns early when kIsWeb is true), but the import must resolve.

class DynamicLibrary {
  DynamicLibrary._();
  static DynamicLibrary open(String path) => throw UnsupportedError('DynamicLibrary.open is not supported on web');
  static DynamicLibrary process() => throw UnsupportedError('DynamicLibrary.process is not supported on web');
}
