import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('Debug FK should throw SqliteException', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final bId = const Uuid().v4();

    await db.into(db.branches).insert(
      BranchesCompanion.insert(
        id: Value(bId),
        name: 'Test Branch',
        code: 'BR1',
      ),
    );

    final entryId = const Uuid().v4();
    await db.into(db.gLEntries).insert(
      GLEntriesCompanion.insert(
        id: Value(entryId),
        description: 'Test Entry',
        branchId: Value(bId),
      ),
    );

    // Expecting a SqliteException because accountId 'NONE' does not exist
    // and violates the foreign key constraint.
    expect(
      () async => await db.into(db.gLLines).insert(
        GLLinesCompanion.insert(
          entryId: entryId,
          accountId: 'NONE', // This should fail!
          debit: const Value(100.0),
          branchId: Value(bId),
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
