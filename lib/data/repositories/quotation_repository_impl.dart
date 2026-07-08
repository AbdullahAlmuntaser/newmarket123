import 'package:sqflite/sqflite.dart';
import 'package:erp_pos_app/data/models/quotation.dart';
import 'package:erp_pos_app/domain/repositories/quotation_repository.dart';

class QuotationRepositoryImpl implements QuotationRepository {
  final Database database;

  QuotationRepositoryImpl({required this.database});

  @override
  Future<List<Quotation>> getAllQuotations() async {
    final List<Map<String, dynamic>> maps = await database.query('quotations', orderBy: 'created_at DESC');
    return maps.map((map) => Quotation.fromJson(map)).toList();
  }

  @override
  Future<Quotation?> getQuotationById(int id) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'quotations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Quotation.fromJson(maps.first);
    }
    return null;
  }

  @override
  Future<Quotation?> getQuotationByNumber(String number) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'quotations',
      where: 'quotation_number = ?',
      whereArgs: [number],
    );
    if (maps.isNotEmpty) {
      return Quotation.fromJson(maps.first);
    }
    return null;
  }

  @override
  Future<List<Quotation>> getQuotationsByCustomer(int customerId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'quotations',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Quotation.fromJson(map)).toList();
  }

  @override
  Future<List<Quotation>> getQuotationsByStatus(String status) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'quotations',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Quotation.fromJson(map)).toList();
  }

  @override
  Future<Quotation> createQuotation(Quotation quotation, List<QuotationItem> items) async {
    await database.transaction((txn) async {
      final int id = await txn.insert('quotations', quotation.toJson());
      for (var item in items) {
        await txn.insert('quotation_items', {
          ...item.toJson(),
          'quotation_id': id,
        });
      }
    });
    return quotation;
  }

  @override
  Future<Quotation> updateQuotation(Quotation quotation, List<QuotationItem> items) async {
    await database.transaction((txn) async {
      await txn.update(
        'quotations',
        quotation.toJson(),
        where: 'id = ?',
        whereArgs: [quotation.id],
      );
      await txn.delete('quotation_items', where: 'quotation_id = ?', whereArgs: [quotation.id]);
      for (var item in items) {
        await txn.insert('quotation_items', {
          ...item.toJson(),
          'quotation_id': quotation.id,
        });
      }
    });
    return quotation;
  }

  @override
  Future<void> deleteQuotation(int id) async {
    await database.delete('quotations', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateQuotationStatus(int id, String status) async {
    await database.update(
      'quotations',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<QuotationItem>> getQuotationItems(int quotationId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'quotation_items',
      where: 'quotation_id = ?',
      whereArgs: [quotationId],
    );
    return maps.map((map) => QuotationItem.fromJson(map)).toList();
  }
}
