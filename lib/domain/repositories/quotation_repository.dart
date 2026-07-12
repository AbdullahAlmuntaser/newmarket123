import '../../data/models/quotation.dart';

abstract class QuotationRepository {
  Future<List<Quotation>> getAllQuotations();
  Future<Quotation?> getQuotationById(int id);
  Future<Quotation?> getQuotationByNumber(String number);
  Future<List<Quotation>> getQuotationsByCustomer(int customerId);
  Future<List<Quotation>> getQuotationsByStatus(String status);
  Future<Quotation> createQuotation(Quotation quotation, List<QuotationItem> items);
  Future<Quotation> updateQuotation(Quotation quotation, List<QuotationItem> items);
  Future<void> deleteQuotation(int id);
  Future<void> updateQuotationStatus(int id, String status);
  Future<List<QuotationItem>> getQuotationItems(int quotationId);
}
