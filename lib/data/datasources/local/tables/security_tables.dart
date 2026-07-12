part of '../app_database.dart';

class UserSessions extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get token => text().unique()();
  DateTimeColumn get loginAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class LoginAttempts extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().references(Users, #id)();
  DateTimeColumn get attemptedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get success => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
