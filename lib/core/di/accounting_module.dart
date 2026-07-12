import 'package:get_it/get_it.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/accounting_period_service.dart';
import 'package:supermarket/core/services/budget_service.dart';
import 'package:supermarket/core/services/inventory_costing_service.dart';
import 'package:supermarket/core/services/notification_service.dart';
import 'package:supermarket/core/services/currency_conversion_service.dart';
import 'package:supermarket/core/services/app_settings_service.dart';
import 'package:supermarket/core/services/chart_of_accounts_service.dart';
import 'package:supermarket/core/services/currency_service.dart';
import 'package:supermarket/core/services/depreciation_service.dart';
import 'package:supermarket/core/services/financial_closing_service.dart';
import 'package:supermarket/core/services/financial_control_service.dart';
import 'package:supermarket/core/services/financial_report_service.dart';
import 'package:supermarket/core/services/journal_service.dart';
import 'package:supermarket/core/services/vat_service.dart';
import 'package:supermarket/core/services/fixed_assets_service.dart';
import 'package:supermarket/core/services/zakat_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

void registerAccountingModule(GetIt sl) {
  final db = sl<AppDatabase>();

  sl.registerLazySingleton<AccountingPeriodService>(
    () => AccountingPeriodService(db),
  );
  sl.registerLazySingleton<BudgetService>(() => BudgetService(db, sl<NotificationService>()));
  sl.registerLazySingleton<CurrencyService>(() => CurrencyService(sl<AppSettingsService>()));
  sl.registerLazySingleton<CurrencyConversionService>(
    () => CurrencyConversionService(db),
  );
  sl.registerLazySingleton<AccountingService>(
    () => AccountingService(db),
  );
  sl.registerLazySingleton<ChartOfAccountsService>(
    () => ChartOfAccountsService(db),
  );
  sl.registerLazySingleton<FinancialReportService>(
    () => FinancialReportService(db),
  );
  sl.registerLazySingleton<VatService>(() => VatService(db));
  sl.registerLazySingleton<DepreciationService>(() => DepreciationService(db));
  sl.registerLazySingleton<JournalService>(() => JournalService(db));
  sl.registerLazySingleton<FinancialClosingService>(
    () => FinancialClosingService(db, sl<FinancialReportService>()),
  );
  sl.registerLazySingleton<FinancialControlService>(
    () => FinancialControlService(
      db,
      costingService: sl<InventoryCostingService>(),
    ),
  );
  sl.registerLazySingleton<FixedAssetsService>(
    () => FixedAssetsService(db),
  );
  sl.registerLazySingleton<ZakatService>(() => ZakatService(db));
}
