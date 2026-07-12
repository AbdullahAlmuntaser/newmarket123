import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supermarket/core/services/credit_note_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class CreditNoteProvider with ChangeNotifier {
  final CreditNoteService _service;
  List<CreditNote> _creditNotes = [];
  bool _isLoading = false;
  String? _error;

  CreditNoteProvider(this._service);

  List<CreditNote> get creditNotes => _creditNotes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCreditNotes({String? customerId, String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _creditNotes = await _service.getCreditNotes(
        customerId: customerId,
        status: status,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CreditNoteWithItems?> getCreditNoteWithItems(
      String creditNoteId) async {
    try {
      return await _service.getCreditNoteWithItems(creditNoteId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> postCreditNote(String creditNoteId, {String? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.postCreditNote(creditNoteId, userId: userId);
      await loadCreditNotes();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelCreditNote(String creditNoteId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = _service.db;
      await (db.update(db.creditNotes)
            ..where((cn) => cn.id.equals(creditNoteId)))
          .write(const CreditNotesCompanion(
            status: Value('VOIDED'),
          ));
      await loadCreditNotes();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createCreditNote({
    required String customerId,
    required String saleId,
    required String reason,
    required List<CreditNoteItemData> items,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.createCreditNote(
        customerId: customerId,
        saleId: saleId,
        reason: reason,
        items: items,
      );
      await loadCreditNotes();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
