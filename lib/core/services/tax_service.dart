import 'package:supermarket/core/services/app_settings_service.dart';

class TaxService {
  final AppSettingsService _settingsService;

  TaxService(this._settingsService);

  Future<double> getCurrentTaxRate() async {
    return await _settingsService.getTaxRate();
  }

  Future<double> getStandardRate() async {
    return await _settingsService.getTaxRate();
  }

  Future<double> getReducedRate() async {
    final rate = await _settingsService.getSetting('tax_reduced_rate');
    return rate != null ? double.parse(rate) : 0.05;
  }

  Future<void> setTaxRate(double rate) async {
    await _settingsService.setTaxRate(rate);
  }

  Future<void> setReducedRate(double rate) async {
    await _settingsService.setSetting('tax_reduced_rate', rate.toString());
  }

  double calculateTax(double amount, double rate) {
    return amount * rate;
  }

  double calculateTaxFromGross(double grossAmount, double rate) {
    return grossAmount - (grossAmount / (1 + rate));
  }

  double getNetFromGross(double grossAmount, double rate) {
    return grossAmount / (1 + rate);
  }

  double getGrossFromNet(double netAmount, double rate) {
    return netAmount * (1 + rate);
  }

  Map<String, double> calculateWithTax(double netAmount, double rate) {
    final tax = calculateTax(netAmount, rate);
    return {
      'net': netAmount,
      'tax': tax,
      'gross': netAmount + tax,
    };
  }
}