import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerService {
  MobileScannerController? _controller;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _isInitialized = true;
  }

  MobileScannerController get controller {
    if (_controller == null) {
      throw Exception('BarcodeScanner not initialized. Call initialize() first.');
    }
    return _controller!;
  }

  Future<void> toggleTorch() async {
    await controller.toggleTorch();
  }

  Future<void> switchCamera() async {
    await controller.switchCamera();
  }

  Future<void> startScanning() async {
    await controller.start();
  }

  Future<void> stopScanning() async {
    await controller.stop();
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  static Future<String?> scanFromCamera() async {
    return null;
  }

  static Future<String?> scanFromFile(String imagePath) async {
    return null;
  }

  static BarcodeFormat? detectFormat(String barcode) {
    if (barcode.isEmpty) return null;
    
    if (RegExp(r'^\d{8}$|^\d{13}$').hasMatch(barcode)) {
      return BarcodeFormat.ean13;
    }
    if (RegExp(r'^\d{12}$').hasMatch(barcode)) {
      return BarcodeFormat.ean8;
    }
    if (barcode.startsWith('01') && barcode.length >= 14) {
      return BarcodeFormat.code128;
    }
    
    return BarcodeFormat.qrCode;
  }

  static bool isValidBarcode(String barcode) {
    if (barcode.isEmpty) return false;
    if (barcode.length < 4 || barcode.length > 50) return false;
    
    final validChars = RegExp(r'^[a-zA-Z0-9\-_\.]+$');
    return validChars.hasMatch(barcode);
  }
}