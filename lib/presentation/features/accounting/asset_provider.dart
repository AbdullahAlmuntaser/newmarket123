import 'package:flutter/material.dart';
import 'package:supermarket/core/services/asset_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class AssetProvider with ChangeNotifier {
  final AssetService _service;
  List<FixedAsset> _assets = [];
  bool _isLoading = false;

  AssetProvider(this._service);

  List<FixedAsset> get assets => _assets;
  bool get isLoading => _isLoading;

  Future<void> loadAssets() async {
    _isLoading = true;
    notifyListeners();
    _assets = await _service.getAllAssets();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addAsset(FixedAssetsCompanion asset) async {
    await _service.addAsset(asset);
    await loadAssets();
  }

  Future<void> runDepreciation() async {
    _isLoading = true;
    notifyListeners();
    await _service.processDepreciation();
    await loadAssets();
    _isLoading = false;
    notifyListeners();
  }
}
