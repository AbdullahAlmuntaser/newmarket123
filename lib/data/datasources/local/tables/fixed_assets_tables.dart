part of '../app_database.dart';

// جدول فئات الأصول الثابتة
class AccAssetCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 2, max: 100)();
  TextColumn get code => text().withLength(min: 2, max: 50)();
  TextColumn get defaultDepreciationRate =>
      text().map(const DecimalConverter()).withDefault(Constant(
          Decimal.zero.toString()))(); // نسبة الإهلاك السنوية الافتراضية
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول الأصول الثابتة
class FixedAssets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 2, max: 150)();
  TextColumn get serialNumber => text().nullable()();
  IntColumn get categoryId => integer().references(AccAssetCategories, #id)();
  TextColumn get cost => text().map(const DecimalConverter())(); // تكلفة الشراء
  DateTimeColumn get purchaseDate => dateTime()();
  DateTimeColumn get acquisitionDate => dateTime()(); // تاريخ البدء في الإهلاك
  TextColumn get salvageValue => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))(); // قيمة الخردة
  IntColumn get usefulLifeYears => integer()(); // العمر الإنتاجي بالسنوات
  TextColumn get depreciationMethod => text().withDefault(
      const Constant('straight_line'))(); // straight_line, declining
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // active, sold, scrapped
  TextColumn get accumulatedDepreciation => text()
      .map(const DecimalConverter())
      .withDefault(Constant(Decimal.zero.toString()))();
  // ملاحظة: currentBookValue يُحسب برمجياً
  DateTimeColumn get lastDepreciationDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول حركات إهلاك الأصول
class AccAssetDepreciationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(FixedAssets, #id)();
  TextColumn get depreciationAmount => text().map(const DecimalConverter())();
  DateTimeColumn get depreciationDate => dateTime()();
  TextColumn get journalEntryId => text()
      .nullable()(); // ربط بالقيد المحاسبي (UUID) - ارتباط منطقي وليس FK لسهولة الترحيل
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// جدول بيع أو خروج الأصول
class AccAssetDisposals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(FixedAssets, #id)();
  DateTimeColumn get disposalDate => dateTime()();
  TextColumn get salePrice => text().map(const DecimalConverter()).nullable()();
  TextColumn get disposalType => text()(); // sold, scrapped
  TextColumn get gainOrLoss =>
      text().map(const DecimalConverter()).nullable()(); // الربح أو الخسارة
  TextColumn get journalEntryId => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
