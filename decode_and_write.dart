import 'dart:io';
import 'dart:convert';
void main() {
  var b64 = File('main.b64').readAsStringSync().trim();
  File('lib/main.dart').writeAsBytesSync(base64Decode(b64));
}
