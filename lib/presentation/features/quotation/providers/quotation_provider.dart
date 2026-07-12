import 'package:flutter/foundation.dart';
import '../../../../data/models/quotation.dart';
import '../../../../domain/repositories/quotation_repository.dart';
import '../../../../domain/usecases/create_quotation.dart';

class QuotationProvider extends ChangeNotifier {
  final CreateQuotation createQuotation;
  final QuotationRepository repository;

  List<Quotation> _quotations = [];
  bool _isLoading = false;
  String? _error;

  List<Quotation> get quotations => _quotations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  QuotationProvider(this.createQuotation, this.repository);

  Future<void> loadQuotations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _quotations = await repository.getAllQuotations();
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
      await repository.updateQuotationStatus(id, status);
      final index = _quotations.indexWhere((q) => q.id == id);
      if (index != -1) {
        _quotations[index] = Quotation(
          id: id,
          quotationNumber: _quotations[index].quotationNumber,
          customerId: _quotations[index].customerId,
          branchId: _quotations[index].branchId,
          warehouseId: _quotations[index].warehouseId,
          date: _quotations[index].date,
          expiryDate: _quotations[index].expiryDate,
          status: status,
          subtotal: _quotations[index].subtotal,
          discountTotal: _quotations[index].discountTotal,
          taxTotal: _quotations[index].taxTotal,
          totalAmount: _quotations[index].totalAmount,
          notes: _quotations[index].notes,
          createdBy: _quotations[index].createdBy,
          createdAt: _quotations[index].createdAt,
          updatedAt: _quotations[index].updatedAt,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
