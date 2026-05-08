import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supermarket/core/services/inventory_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';

class MockAppDatabase extends Mock implements AppDatabase {}
class MockAuditService extends Mock implements AuditService {}
class MockAppConfigService extends Mock implements AppConfigService {}

void main() {
  late MockAppDatabase mockDatabase;
  late MockAuditService mockAuditService;
  late MockAppConfigService mockConfigService;

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockAuditService = MockAuditService();
    mockConfigService = MockAppConfigService();
  });

  group('InventoryService Tests', () {
    test('service can be created', () {
      final inventoryService = InventoryService(
        mockDatabase,
        mockAuditService,
        mockConfigService,
      );
      expect(inventoryService, isNotNull);
    });
  });
}
