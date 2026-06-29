import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ProductImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pickImage(
      {ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          'product_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
      final savedFile =
          await File(pickedFile.path).copy(p.join(imagesDir.path, fileName));

      return savedFile;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  static Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  static bool hasValidImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return false;
    return File(imagePath).existsSync();
  }
}
