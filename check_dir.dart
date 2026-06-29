import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

void main() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    developer.log('DOC_DIR: ${dir.path}');
  } catch (e) {
    developer.log('ERROR: $e');
  }
}
