import 'package:flutter/foundation.dart';
import 'package:erp_pos_app/data/models/quotation.dart';
import 'package:erp_pos_app/domain/usecases/create_quotation.dart';

class QuotationProvider extends ChangeNotifier {
  final CreateQuotation createQuotation;
  
  List<Quotation> _quotations = [];
  bool _isLoading = false;
  String? _error;

  List<Quotation> get quotations => _quotations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  QuotationProvider(this.createQuotation);

  Future<void> loadQuotations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement fetch from repository
      _quotations = [];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createNewQuotation(Quotation quotation, List<QuotationItem> items) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newQuotation = await createQuotation.execute(quotation, items);
      _quotations.insert(0, newQuotation);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateQuotationStatus(int id, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement update status in repository
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
