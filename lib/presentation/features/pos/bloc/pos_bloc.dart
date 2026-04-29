import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import 'package:decimal/decimal.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/pricing_service.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:uuid/uuid.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  final AppDatabase db;
  final PricingService pricingService;
  final TransactionEngine transactionEngine;
  late StreamSubscription _productSubscription;

  PosBloc(this.db, this.pricingService, this.transactionEngine)
    : super(PosLoading()) {
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
    on<UpdateCartItemUnit>(_onUpdateUnit);
    on<ToggleWholesaleMode>(_onToggleWholesale);
    on<SearchProducts>(_onSearchProducts);
    on<SelectPriceList>(_onSelectPriceList);
    on<CheckoutEvent>(_onCheckout);
    on<RefreshPricesEvent>(_onRefreshPrices);
    on<ClearCart>((event, emit) {
      if (state is PosLoaded) {
        final currentState = state as PosLoaded;
        emit(
          PosLoaded(
            categories: currentState.categories,
            selectedCategoryId: currentState.selectedCategoryId,
            filteredProducts: currentState.filteredProducts,
            taxRate: currentState.taxRate,
          ),
        );
      } else {
        emit(PosLoaded());
      }
    });

    _productSubscription = db.productsDao.watchProducts().listen((_) {
      add(RefreshPricesEvent());
    });

    // Load initial data
    add(LoadCategories());
  }

  @override
  Future<void> close() {
    _productSubscription.cancel();
    return super.close();
  }

  Future<void> _onRefreshPrices(
    RefreshPricesEvent event,
    Emitter<PosState> emit,
  ) async {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;

    final updatedCart = await Future.wait(
      currentState.cart.map((item) async {
        final newPrice = await pricingService.calculatePrice(
          productId: item.product.id,
          priceListId: currentState.activePriceListId,
          quantity: item.quantity,
        );
        return item.copyWith(unitPrice: newPrice);
      }),
    );

    emit(currentState.copyWith(cart: updatedCart));
  }

  Future<void> _onSelectPriceList(
    SelectPriceList event,
    Emitter<PosState> emit,
  ) async {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;

    // تحديث القائمة السعرية وإعادة حساب الأسعار في السلة
    final updatedCart = <CartItem>[];
    for (final item in currentState.cart) {
      final finalPrice = await pricingService.calculatePrice(
        productId: item.product.id,
        priceListId: event.priceListId,
        quantity: item.quantity,
      );

      updatedCart.add(item.copyWith(unitPrice: finalPrice));
    }

    emit(
      currentState.copyWith(
        activePriceListId: event.priceListId,
        cart: updatedCart,
      ),
    );
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
      final products =
          await (db.select(db.products)..where(
                (t) => event.categoryId != null
                    ? t.categoryId.equals(event.categoryId!)
                    : const Constant(true),
              ))
              .get();

      emit(
        currentState.copyWith(
          selectedCategoryId: event.categoryId,
          filteredProducts: products,
        ),
      );
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
      final results =
          await (db.select(db.products)
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
      // 1. البحث في باركودات الوحدات أولاً (لأنه قد يكون باركود كرتون)
      final unitConv = await (db.select(
        db.unitConversions,
      )..where((t) => t.barcode.equals(event.sku))).getSingleOrNull();

      Product? product;
      String unitName = 'حبة';
      Decimal factor = Decimal.one;
      Decimal? specificPrice;

      if (unitConv != null) {
        product = await (db.select(
          db.products,
        )..where((t) => t.id.equals(unitConv.productId))).getSingle();
        unitName = unitConv.unitName;
        factor = Decimal.parse(unitConv.factor.toString());
        specificPrice = unitConv.sellPrice != null
            ? Decimal.parse(unitConv.sellPrice.toString())
            : null;
      } else {
        // 2. إذا لم يجد في الوحدات، يبحث في باركود المنتج الأساسي
        product = await (db.select(
          db.products,
        )..where((t) => t.sku.equals(event.sku))).getSingleOrNull();
        if (product != null) {
          unitName = product.unit;
        }
      }

      // Check if product was found
      if (product == null) {
        emit(const PosError("المنتج غير موجود"));
        return;
      }

      // جلب كافة الوحدات المتاحة لهذا المنتج
      final allUnits = await (db.select(
        db.unitConversions,
      )..where((t) => t.productId.equals(product!.id))).get();

      // جلب السعر الأدق عبر PricingService
      Decimal finalPrice = await pricingService.calculatePrice(
        productId: product.id,
        priceListId: currentState.activePriceListId,
        quantity: factor, // استخدام factor الوحدة للتحقق من السعر حسب الكمية
      );

      // إذا كانت الوحدة لها سعر محدد في جدول التحويلات، نستخدمه
      if (specificPrice != null) {
        finalPrice = specificPrice;
      } else {
        // إذا كان هناك عامل تحويل، نضرب السعر في المعامل
        finalPrice = finalPrice * factor;
      }

      final existingIndex = currentState.cart.indexWhere(
        (item) => item.product.id == product!.id && item.unitName == unitName,
      );

      List<CartItem> newCart = List.from(currentState.cart);
      if (existingIndex >= 0) {
        newCart[existingIndex] = newCart[existingIndex].copyWith(
          quantity: newCart[existingIndex].quantity + Decimal.one,
        );
      } else {
        newCart.add(
          CartItem(
            product: product,
            unitName: unitName,
            unitFactor: factor,
            unitPrice: finalPrice,
            isWholesale: currentState.isWholesaleMode,
            availableUnits: allUnits,
            quantity: Decimal.one,
          ),
        );
      }

      emit(currentState.copyWith(cart: newCart));
    } catch (e) {
      emit(PosError("خطأ عند إضافة المنتج: $e"));
      emit(currentState);
    }
  }

  Future<void> _onUpdateQuantity(
    UpdateCartItemQuantity event,
    Emitter<PosState> emit,
  ) async {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;

    final updatedCart = currentState.cart.map((item) {
      if (item.product.id == event.productId) {
        return item.copyWith(quantity: event.quantity);
      }
      return item;
    }).toList();
    emit(currentState.copyWith(cart: updatedCart));
  }

  Future<void> _onUpdateUnit(
    UpdateCartItemUnit event,
    Emitter<PosState> emit,
  ) async {
    if (state is! PosLoaded) return;
    final currentState = state as PosLoaded;

    final updatedCart = <CartItem>[];
    for (final item in currentState.cart) {
      if (item.product.id == event.productId) {
        // Find the selected unit
        UnitConversion? selectedUnit;
        if (event.unitName == item.product.unit) {
          // Base unit
          selectedUnit = null;
        } else {
          selectedUnit = item.availableUnits.cast<UnitConversion?>().firstWhere(
            (u) => u?.unitName == event.unitName,
            orElse: () => null,
          );
        }

        final unitName = event.unitName;
        final factor = selectedUnit != null
            ? Decimal.parse(selectedUnit.factor.toString())
            : Decimal.one;

        Decimal finalPrice;
        if (currentState.isWholesaleMode) {
          finalPrice =
              Decimal.parse(item.product.wholesalePrice.toString()) * factor;
        } else {
          finalPrice = selectedUnit?.sellPrice != null
              ? Decimal.parse(selectedUnit!.sellPrice.toString())
              : Decimal.parse(item.product.sellPrice.toString()) * factor;
        }

        updatedCart.add(
          item.copyWith(
            unitName: unitName,
            unitFactor: factor,
            unitPrice: finalPrice,
          ),
        );
      } else {
        updatedCart.add(item);
      }
    }
    emit(currentState.copyWith(cart: updatedCart));
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

    final newCart = currentState.cart.map((item) {
      Decimal newPrice;
      if (event.isWholesale) {
        newPrice =
            Decimal.parse(item.product.wholesalePrice.toString()) *
            item.unitFactor;
      } else {
        final unitInfo = item.availableUnits.cast<UnitConversion?>().firstWhere(
          (u) => u?.unitName == item.unitName,
          orElse: () => null,
        );
        newPrice = (unitInfo?.sellPrice != null)
            ? Decimal.parse(unitInfo!.sellPrice.toString())
            : Decimal.parse(item.product.sellPrice.toString()) *
                  item.unitFactor;
      }
      return item.copyWith(isWholesale: event.isWholesale, unitPrice: newPrice);
    }).toList();

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
      final tax = currentState.taxAmount;

      emit(PosLoading());

      final saleId = const Uuid().v4();

      // 1. Prepare Companions
      final currencyId = event.currencyId ?? 'USD';
      final exchangeRate = event.exchangeRate;

      // تجميع خصومات الأصناف
      final itemDiscountSum = currentState.cart.fold<Decimal>(
        Decimal.zero,
        (sum, item) => sum + (item.discount ?? Decimal.zero),
      );
      final totalDiscount = currentState.discount + itemDiscountSum;

      final saleCompanion = SalesCompanion.insert(
        id: Value(saleId),
        customerId: Value(event.customerId),
        total: total.toDouble(),
        discount: Value(totalDiscount.toDouble()),
        tax: Value(tax.toDouble()),
        paymentMethod: event.paymentMethod,
        isCredit: Value(event.paymentMethod == 'credit'),
        syncStatus: const Value(1),
        currencyId: Value(currencyId),
        exchangeRate: Value(exchangeRate.toDouble()),
      );

      final itemsCompanions = currentState.cart.map((item) {
        return SaleItemsCompanion.insert(
          saleId: saleId,
          productId: item.product.id,
          quantity: item.quantity
              .toDouble(), // Quantity is already in base units from CartItem
          price: item.unitPrice
              .toDouble(), // Unit price is already the price for the selected unit
          unitName: Value(item.unitName),
          unitFactor: Value(item.unitFactor.toDouble()),
          syncStatus: const Value(1),
        );
      }).toList();

      // 2. Execute via DAO (to create the base record)
      await db.salesDao.createSale(
        saleCompanion: saleCompanion,
        itemsCompanions: itemsCompanions,
        userId: event.userId,
      );

      // 3. Post via TransactionEngine for full processing
      await transactionEngine.postSale(saleId, userId: event.userId);

      // 4. Fetch final objects for success emission
      final saleObj = await (db.select(
        db.sales,
      )..where((s) => s.id.equals(saleId))).getSingle();
      final saleItemsForAccounting = await (db.select(
        db.saleItems,
      )..where((si) => si.saleId.equals(saleId))).get();

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
