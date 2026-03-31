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

final sl = GetIt.instance;

void init() {
  // Providers
  sl.registerLazySingleton(() => AuthProvider(sl()));
  sl.registerLazySingleton(() => ThemeProvider());

  // Blocs
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

  // Data sources
  sl.registerLazySingleton(() => AppDatabase());
}
