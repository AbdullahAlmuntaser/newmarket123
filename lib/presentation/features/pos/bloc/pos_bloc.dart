import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:uuid/uuid.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  final AppDatabase db;

  PosBloc(this.db) : super(const PosLoaded()) {
    on<LoadCategories>(_onLoadCategories);
    on<SelectCategory>(_onSelectCategory);
    on<AddProductBySku>(_onAddProduct);
    on<UpdateCartItemQuantity>(_onUpdateQuantity);
    on<RemoveCartItem>(_onRemoveItem);
    on<UpdateDiscount>((event, emit) {
      if (state is PosLoaded) {
        emit((state as PosLoaded).copyWith(discount: event.discount));
      }
    });
    on<UpdateTaxRate>((event, emit) {
      if (state is PosLoaded) {
        emit((state as PosLoaded).copyWith(taxRate: event.taxRate));
      }
    });
    on<ToggleWholesaleMode>(_onToggleWholesale);
    on<SearchProducts>(_onSearchProducts);
    on<CheckoutEvent>(_onCheckout);
    on<ClearCart>((event, emit) {
      if (state is PosLoaded) {
        final currentState = state as PosLoaded;
        emit(PosLoaded(
          categories: currentState.categories,
          selectedCategoryId: currentState.selectedCategoryId,
          filteredProducts: currentState.filteredProducts,
          taxRate: currentState.taxRate,
        ));
      } else {
        emit(const PosLoaded());
      }
    });

    // Load initial data
    add(LoadCategories());
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<PosState> emit,
  ) async {
    final categories = await (db.select(db.categories)).get();
    if (state is PosLoaded) {
      final currentState = state as PosLoaded;
      emit(currentState.copyWith(categories: categories));
      // Select first category by default if available
      if (categories.isNotEmpty && currentState.selectedCategoryId == null) {
        add(SelectCategory(categories.first.id));
      }
    } else {
      emit(PosLoaded(categories: categories));
    }
  }

  Future<void> _onSelectCategory(
    SelectCategory event,
    Emitter<PosState> emit,
  ) async {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;

    try {
      final products = await (db.select(db.products)
            ..where((t) => event.categoryId != null
                ? t.categoryId.equals(event.categoryId!)
                : const Constant(true)))
          .get();

      emit(currentState.copyWith(
        selectedCategoryId: event.categoryId,
        filteredProducts: products,
      ));
    } catch (e) {
      emit(PosError("Failed to filter products: $e"));
    }
  }

  Future<void> _onSearchProducts(
    SearchProducts event,
    Emitter<PosState> emit,
  ) async {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;

    if (event.query.isEmpty) {
      emit(currentState.copyWith(searchResults: []));
      return;
    }

    try {
      final results = await (db.select(db.products)
            ..where(
              (t) =>
                  t.name.like('%${event.query}%') |
                  t.sku.like('%${event.query}%'),
            )
            ..limit(10))
          .get();

      emit(currentState.copyWith(searchResults: results));
    } catch (e) {
      emit(PosError("Search failed: $e"));
      emit(currentState);
    }
  }

  Future<void> _onAddProduct(
    AddProductBySku event,
    Emitter<PosState> emit,
  ) async {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;

    try {
      final product = await (db.select(
        db.products,
      )..where((t) => t.sku.equals(event.sku))).getSingleOrNull();

      if (product == null) {
        emit(PosError("Product with SKU ${event.sku} not found"));
        emit(currentState);
        return;
      }

      final existingIndex = currentState.cart.indexWhere(
        (item) => item.product.id == product.id,
      );

      List<CartItem> newCart = List.from(currentState.cart);
      if (existingIndex >= 0) {
        newCart[existingIndex] = newCart[existingIndex].copyWith(
          quantity: newCart[existingIndex].quantity + 1,
        );
      } else {
        newCart.add(
          CartItem(product: product, isWholesale: currentState.isWholesaleMode),
        );
      }

      emit(currentState.copyWith(cart: newCart));
    } catch (e) {
      emit(PosError(e.toString()));
      emit(currentState);
    }
  }

  void _onUpdateQuantity(UpdateCartItemQuantity event, Emitter<PosState> emit) {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;
    final newCart = currentState.cart.map((item) {
      if (item.product.id == event.productId) {
        return item.copyWith(quantity: event.quantity);
      }
      return item;
    }).toList();
    emit(currentState.copyWith(cart: newCart));
  }

  void _onRemoveItem(RemoveCartItem event, Emitter<PosState> emit) {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;
    final newCart = currentState.cart
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(currentState.copyWith(cart: newCart));
  }

  void _onToggleWholesale(ToggleWholesaleMode event, Emitter<PosState> emit) {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;
    final newCart = currentState.cart
        .map((item) => item.copyWith(isWholesale: event.isWholesale))
        .toList();
    emit(
      currentState.copyWith(cart: newCart, isWholesaleMode: event.isWholesale),
    );
  }

  Future<void> _onCheckout(CheckoutEvent event, Emitter<PosState> emit) async {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;
    if (currentState.cart.isEmpty) return;

    try {
      final total = currentState.total;
      final discount = currentState.discount;
      final tax = currentState.taxAmount;

      emit(PosLoading());

      final saleId = const Uuid().v4();

      // 1. Prepare Companions
      final saleCompanion = SalesCompanion.insert(
        id: Value(saleId),
        customerId: Value(event.customerId),
        total: total,
        discount: Value(discount),
        tax: Value(tax),
        paymentMethod: event.paymentMethod,
        isCredit: Value(event.paymentMethod == 'credit'),
        syncStatus: const Value(1),
      );

      final itemsCompanions = currentState.cart.map((item) {
        return SaleItemsCompanion.insert(
          saleId: saleId,
          productId: item.product.id,
          quantity: item.quantity.toDouble(),
          price: item.unitPrice,
          syncStatus: const Value(1),
        );
      }).toList();

      // 2. Execute via DAO
      await db.salesDao.createSale(
        saleCompanion: saleCompanion,
        itemsCompanions: itemsCompanions,
        userId: event.userId,
      );

      // 3. Fetch final objects for success emission
      final saleObj = await (db.select(db.sales)..where((s) => s.id.equals(saleId))).getSingle();
      final saleItemsForAccounting = await (db.select(db.saleItems)..where((si) => si.saleId.equals(saleId))).get();

      emit(
        PosCheckoutSuccess(
          saleObj,
          saleItemsForAccounting,
          currentState.cart.map((i) => i.product).toList(),
        ),
      );
    } catch (e) {
      emit(PosError("Checkout failed: $e"));
      emit(currentState.copyWith());
    }
  }
}
