import 'package:flutter/material.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/customers_dao.dart';
import 'package:supermarket/injection_container.dart';
import 'dart:developer' as developer;

class CustomerStatementProvider with ChangeNotifier {
  final CustomersDao _customersDao = sl<AppDatabase>().customersDao;

  List<CustomerTransaction> _transactions = [];
  bool _isLoading = false;
  Customer? _customer;

  List<CustomerTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  Customer? get customer => _customer;

  Future<void> loadStatement(String customerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _customer = await _customersDao.getCustomerById(customerId);
      _transactions = await _customersDao.getCustomerStatement(customerId);
    } catch (e) {
      developer.log('Error loading customer statement', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double get totalDebit => _transactions.fold(0.0, (sum, t) => sum + t.debit);
  double get totalCredit => _transactions.fold(0.0, (sum, t) => sum + t.credit);
  double get balance => totalDebit - totalCredit;
}
