import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static const _dbKeyName = 'db_encryption_key';

  static Future<String> getDatabaseKey() async {
    String? key = await _storage.read(key: _dbKeyName);
    if (key == null) {
      key = _generateSecureKey();
      await _storage.write(key: _dbKeyName, value: key);
    }
    return key;
  }

  static String _generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
}
