import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supermarket/core/utils/usecase.dart';
import 'package:supermarket/domain/usecases/add_category.dart';
import 'package:supermarket/domain/usecases/delete_category.dart';
import 'package:supermarket/domain/usecases/get_categories.dart';
import 'package:supermarket/domain/usecases/update_category.dart';
import 'package:supermarket/presentation/blocs/category/category_event.dart';
import 'package:supermarket/presentation/blocs/category/category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final GetCategories getCategories;
  final AddCategory addCategory;
  final UpdateCategory updateCategory;
  final DeleteCategory deleteCategory;

  CategoryBloc({
    required this.getCategories,
    required this.addCategory,
    required this.updateCategory,
    required this.deleteCategory,
  }) : super(CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategoryEvent>(_onAddCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
  }

  void _onLoadCategories(LoadCategories event, Emitter<CategoryState> emit) async {
    emit(CategoryLoading());
    final failureOrCategories = await getCategories(NoParams());
    failureOrCategories.fold(
      (failure) => emit(const CategoryError(message: 'Failed to load categories')),
      (categories) => emit(CategoryLoaded(categories: categories)),
    );
  }

  void _onAddCategory(
      AddCategoryEvent event, Emitter<CategoryState> emit) async {
    final failureOrUnit = await addCategory(event.category);
    failureOrUnit.fold(
      (failure) => emit(const CategoryError(message: 'Failed to add category')),
      (_) => add(LoadCategories()),
    );
  }

  void _onUpdateCategory(
      UpdateCategoryEvent event, Emitter<CategoryState> emit) async {
    final failureOrUnit = await updateCategory(event.category);
    failureOrUnit.fold(
      (failure) => emit(const CategoryError(message: 'Failed to update category')),
      (_) => add(LoadCategories()),
    );
  }

  void _onDeleteCategory(
      DeleteCategoryEvent event, Emitter<CategoryState> emit) async {
    final failureOrUnit = await deleteCategory(event.id);
    failureOrUnit.fold(
      (failure) => emit(const CategoryError(message: 'Failed to delete category')),
      (_) => add(LoadCategories()),
    );
  }
}
