import 'package:drift/drift.dart';

extension SafeGetSingle<T extends DataClass> on Selectable<T> {
  Future<T?> getFirstOrNull() async {
    final results = await get();
    if (results.isEmpty) return null;
    if (results.length > 1) {
      // ignore: avoid_print
      print('[DRIFT] WARNING: Query returned ${results.length} rows, expected at most 1');
    }
    return results.first;
  }
}
