import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/accounting_dao.dart';

class MockAppDatabase extends Mock implements AppDatabase {}
class MockEventBusService extends Mock implements EventBusService {}
class MockAccountingDao extends Mock implements AccountingDao {}
class MockAppConfigService extends Mock implements AppConfigService {}

class FakeGLAccountsCompanion extends Fake implements GLAccountsCompanion {}

void main() {
  late AccountingService accountingService;
  late MockAppDatabase mockDatabase;
  late MockEventBusService mockEventBus;
  late MockAccountingDao mockAccountingDao;
  late MockAppConfigService mockConfigService;

  setUpAll(() {
    registerFallbackValue(FakeGLAccountsCompanion());
  });

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockEventBus = MockEventBusService();
    mockAccountingDao = MockAccountingDao();
    mockConfigService = MockAppConfigService();

    when(() => mockEventBus.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockDatabase.accountingDao).thenReturn(mockAccountingDao);
    when(() => mockConfigService.getDefaultBranchId()).thenAnswer((_) async => 'branch-1');

    accountingService = AccountingService(mockDatabase, mockEventBus);
  });

  group('AccountingService Unit Tests', () {
    test('seedDefaultAccounts should create accounts if they do not exist', () async {
      when(() => mockDatabase.transaction(any()))
          .thenAnswer((inv) async {
        final callback = inv.positionalArguments[0] as Future<dynamic> Function();
        return await callback();
      });
      when(() => mockAccountingDao.getAccountByCode(any()))
          .thenAnswer((_) async => null);
      when(() => mockAccountingDao.createAccount(any()))
          .thenAnswer((_) async => 1);
      
      await accountingService.seedDefaultAccounts(branchId: '1');
      
      verify(() => mockAccountingDao.createAccount(any())).called(19);
    });
  });
}