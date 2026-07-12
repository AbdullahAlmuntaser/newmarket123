import 'package:get_it/get_it.dart';
import 'package:supermarket/core/services/sales_service.dart';
import 'package:supermarket/core/services/sales_order_service.dart';
import 'package:supermarket/core/services/delivery_notes_service.dart';
import 'package:supermarket/core/services/invoice_service.dart';
import 'package:supermarket/core/services/credit_note_service.dart';
import 'package:supermarket/core/services/proforma_service.dart';
import 'package:supermarket/core/services/return_service.dart';
import 'package:supermarket/core/services/quick_customer_service.dart';
import 'package:supermarket/core/services/statement_service.dart';
import 'package:supermarket/core/services/statement_printing_service.dart';
import 'package:supermarket/core/services/unified_statement_service.dart';
import 'package:supermarket/core/services/sales_commission_service.dart';
import 'package:supermarket/core/services/loyalty_service.dart';
import 'package:supermarket/core/services/pricing_service.dart';
import 'package:supermarket/core/services/posting_engine.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/core/services/app_settings_service.dart';
import 'package:supermarket/core/services/permission_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

void registerSalesModule(GetIt sl) {
  sl.registerLazySingleton<SalesService>(
    () => SalesService(
      sl<AppDatabase>(),
      sl<PostingEngine>(),
      sl<AppSettingsService>(),
      sl<PermissionService>(),
      sl<TransactionEngine>(),
    ),
  );
  sl.registerLazySingleton<SalesOrderService>(
    () => SalesOrderService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<DeliveryNotesService>(
    () => DeliveryNotesService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<InvoiceService>(() => InvoiceService(sl<AppDatabase>()));
  sl.registerLazySingleton<CreditNoteService>(
    () => CreditNoteService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<ProformaService>(
    () => ProformaService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<ReturnService>(() => ReturnService(sl<AppDatabase>()));
  sl.registerLazySingleton<QuickCustomerService>(
    () => QuickCustomerService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<StatementService>(
    () => StatementService(sl<PostingEngine>()),
  );
  sl.registerLazySingleton<StatementPrintingService>(
    () => StatementPrintingService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<UnifiedStatementService>(
    () => UnifiedStatementService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<SalesCommissionService>(
    () => SalesCommissionService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<LoyaltyService>(
    () => LoyaltyService(sl<AppConfigService>()),
  );
  sl.registerLazySingleton<PricingService>(
    () => PricingService(sl<AppDatabase>()),
  );
}
