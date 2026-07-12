import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import '../models/quotation.dart';
import '../../domain/repositories/quotation_repository.dart';

class QuotationRepositoryImpl implements QuotationRepository {
  final AppDatabase database;

  QuotationRepositoryImpl({required this.database});

  @override
  Future<List<Quotation>> getAllQuotations() async {
    final maps = (await database.customSelect('SELECT * FROM quotations ORDER BY created_at DESC').get()).map((e) => e.data).toList();
    return maps.map((map) => Quotation.fromJson(map)).toList();
  }

  @override
  Future<Quotation?> getQuotationById(int id) async {
    final maps = (await database.customSelect('SELECT * FROM quotations WHERE id = ?', variables: [Variable(id)]).get()).map((e) => e.data).toList();
    if (maps.isNotEmpty) {
      return Quotation.fromJson(maps.first);
    }
    return null;
  }

  @override
  Future<Quotation?> getQuotationByNumber(String number) async {
    final maps = (await database.customSelect('SELECT * FROM quotations WHERE quotation_number = ?', variables: [Variable(number)]).get()).map((e) => e.data).toList();
    if (maps.isNotEmpty) {
      return Quotation.fromJson(maps.first);
    }
    return null;
  }

  @override
  Future<List<Quotation>> getQuotationsByCustomer(int customerId) async {
    final maps = (await database.customSelect('SELECT * FROM quotations WHERE customer_id = ? ORDER BY created_at DESC', variables: [Variable(customerId)]).get()).map((e) => e.data).toList();
    return maps.map((map) => Quotation.fromJson(map)).toList();
  }

  @override
  Future<List<Quotation>> getQuotationsByStatus(String status) async {
    final maps = (await database.customSelect('SELECT * FROM quotations WHERE status = ? ORDER BY created_at DESC', variables: [Variable(status)]).get()).map((e) => e.data).toList();
    return maps.map((map) => Quotation.fromJson(map)).toList();
  }

  @override
  Future<Quotation> createQuotation(Quotation quotation, List<QuotationItem> items) async {
    final json = quotation.toJson();
    final cols = json.keys.join(', ');
    final vals = json.keys.map((_) => '?').join(', ');
    final args = json.values.map((v) => Variable(v as Object)).toList();
    await database.customInsert('INSERT INTO quotations ($cols) VALUES ($vals)', variables: args);
    for (var item in items) {
      final ij = item.toJson();
      final ic = ij.keys.join(', ');
      final iv = ij.keys.map((_) => '?').join(', ');
      await database.customInsert('INSERT INTO quotation_items ($ic) VALUES ($iv)', variables: ij.values.map((v) => Variable(v as Object)).toList());
    }
    return quotation;
  }

  @override
  Future<Quotation> updateQuotation(Quotation quotation, List<QuotationItem> items) async {
    final json = quotation.toJson();
    final setClause = json.keys.map((k) => '$k = ?').join(', ');
    await database.customUpdate('UPDATE quotations SET $setClause WHERE id = ?',
        variables: [...json.values.map((v) => Variable(v as Object)), Variable(quotation.id as Object)]);
    await database.customUpdate('DELETE FROM quotation_items WHERE quotation_id = ?', variables: [Variable(quotation.id as Object)]);
    for (var item in items) {
      final ij = item.toJson();
      final ic = ij.keys.join(', ');
      final iv = ij.keys.map((_) => '?').join(', ');
      await database.customInsert('INSERT INTO quotation_items ($ic) VALUES ($iv)', variables: ij.values.map((v) => Variable(v as Object)).toList());
    }
    return quotation;
  }

  @override
  Future<void> deleteQuotation(int id) async {
    await database.customUpdate('DELETE FROM quotations WHERE id = ?', variables: [Variable(id)]);
  }

  @override
  Future<void> updateQuotationStatus(int id, String status) async {
    await database.customUpdate('UPDATE quotations SET status = ?, updated_at = ? WHERE id = ?',
        variables: [Variable(status), Variable(DateTime.now().toIso8601String()), Variable(id)]);
  }

  @override
  Future<List<QuotationItem>> getQuotationItems(int quotationId) async {
    final maps = (await database.customSelect('SELECT * FROM quotation_items WHERE quotation_id = ?', variables: [Variable(quotationId)]).get()).map((e) => e.data).toList();
    return maps.map((map) => QuotationItem.fromJson(map)).toList();
  }
}
