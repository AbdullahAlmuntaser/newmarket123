import 'package:flutter/material.dart';
import 'package:supermarket/core/services/asset_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart';

class AssetProvider with ChangeNotifier {
  final AssetService _service;
  List<FixedAsset> _assets = [];
  bool _isLoading = false;
  String? _error;

  AssetProvider(this._service);

  List<FixedAsset> get assets => _assets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAssets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _assets = await _service.getAllAssets();
    } catch (e) {
      _error = 'فشل في تحميل الأصول: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addAsset(Insertable<FixedAsset> asset) async {
    _error = null;
    try {
      await _service.addAsset(asset);
      await loadAssets(); // Reload to get the updated list
      return true;
    } catch (e) {
      _error = 'فشل في إضافة الأصل: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAsset(Insertable<FixedAsset> asset) async {
    _error = null;
    try {
      await _service.updateAsset(asset);
      await loadAssets(); // Reload to get the updated list
      return true;
    } catch (e) {
      _error = 'فشل في تحديث الأصل: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> runDepreciation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.processDepreciation();
      await loadAssets();
      return true;
    } catch (e) {
      _error = 'فشل في حساب الإهلاك: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
