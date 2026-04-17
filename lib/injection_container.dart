import 'package:get_it/get_it.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/core/theme/theme_provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/repositories/category_repository_impl.dart';
import 'package:supermarket/domain/repositories/category_repository.dart';
import 'package:supermarket/domain/usecases/add_category.dart';
import 'package:supermarket/domain/usecases/delete_category.dart';
import 'package:supermarket/domain/usecases/get_categories.dart';
import 'package:supermarket/domain/usecases/update_category.dart';
import 'package:supermarket/presentation/blocs/category/category_bloc.dart';
import 'package:supermarket/presentation/features/products/products_provider.dart';
import 'package:supermarket/core/services/accounting_service.dart';
import 'package:supermarket/core/services/event_bus_service.dart';
import 'package:supermarket/core/services/pricing_service.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:supermarket/core/services/inventory_service.dart';
import 'package:supermarket/core/services/purchase_service.dart';

import 'package:supermarket/presentation/features/pos/bloc/pos_bloc.dart';

final sl = GetIt.instance;

void init() {
  // Data sources
  final db = AppDatabase();
  sl.registerLazySingleton(() => db);

  // Services
  sl.registerLazySingleton(() => EventBusService());
  sl.registerLazySingleton(() => AccountingService(sl(), sl()));
  sl.registerLazySingleton(() => PricingService(sl()));
  sl.registerLazySingleton(() => TransactionEngine(sl(), sl()));
  sl.registerLazySingleton(() => InventoryService(sl()));
  sl.registerLazySingleton(() => PurchaseService(sl()));

  // Providers
  sl.registerLazySingleton(() => AuthProvider(sl()));
  sl.registerLazySingleton(() => ThemeProvider());
  sl.registerFactory(() => ProductsProvider(sl()));

  // Blocs
  sl.registerFactory(() => PosBloc(sl(), sl(), sl()));
  sl.registerFactory(
    () => CategoryBloc(
      getCategories: sl(),
      addCategory: sl(),
      updateCategory: sl(),
      deleteCategory: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetCategories(sl()));
  sl.registerLazySingleton(() => AddCategory(sl()));
  sl.registerLazySingleton(() => UpdateCategory(sl()));
  sl.registerLazySingleton(() => DeleteCategory(sl()));

  // Repositories
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(appDatabase: sl()),
  );
}
