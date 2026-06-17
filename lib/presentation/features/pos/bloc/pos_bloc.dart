import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/pricing_service.dart';
import 'package:supermarket/core/services/packaging_engine.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_event.dart';
import 'package:supermarket/presentation/features/pos/bloc/pos_state.dart';
import 'package:supermarket/core/services/transaction_engine.dart';
import 'package:uuid/uuid.dart';
import 'package:supermarket/core/constants/app_enums.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  final AppDatabase db;
  final PricingService pricingService;
  final TransactionEngine transactionEngine;
  final PackagingEngine packagingEngine;
  late StreamSubscription<List<ProductWithCategory>> _productSubscription;

  PosBloc(this.db, this.pricingService, this.transactionEngine, this.packagingEngine,
      {bool skipInit = false})
      : super(PosLoading()) {
    on<LoadCategories>(_onLoadCategories);
    on<SelectCategory>(_onSelectCategory);
    on<AddProductBySku>(_onAddProduct);
    on<UpdateCartItemQuantity>(_onUpdateQuantity);
    on<RemoveCartItem>(_onRemoveItem);
    on<UpdateDiscount>((event, emit) async {
      if (state is PosLoaded) {
        final configService = AppConfigService(db);
        final maxStr = await configService.getString('max_discount_percent');
        final maxDiscount = Decimal.tryParse(maxStr ?? '') ?? Decimal.fromInt(20);
        if (event.discount > maxDiscount) {
          emit(PosError('الخصم يتجاوز الحد المسموح به (${maxDiscount.toStringAsFixed(0)}%)'));
          return;
        }
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
            cart: const [],
            discount: Decimal.zero,
            isWholesaleMode: false,
          ),
        );
      } else {
        emit(PosLoaded());
      }
    });

    // ==================== RETURN MODE HANDLERS ====================

    void onToggleReturnMode(ToggleReturnMode event, Emitter<PosState> emit) {
      if (state is! PosLoaded) return;
      emit((state as PosLoaded).copyWith(
        isReturnMode: event.isReturnMode,
        returnItems: const [],
        clearOriginalSale: true,
      ));
    }

    Future<void> onLookupOriginalSale(
      LookupOriginalSale event,
      Emitter<PosState> emit,
    ) async {
      if (state is! PosLoaded) return;
      emit(PosLoading());

      try {
        final sale = await (db.select(db.sales)
              ..where((s) => s.id.like('${event.saleReference}%'))
              ..where((s) => s.status.equals(DocumentStatus.posted.index)))
            .getSingleOrNull();

        if (sale == null) {
          emit(const PosError('الفاتورة الأصلية غير موجودة'));
          emit(state);
          return;
        }

        final items = await (db.select(db.saleItems)
              ..where((si) => si.saleId.equals(sale.id)))
            .get();

        final products = <Product>[];
        for (final item in items) {
          final product = await (db.select(db.products)
                ..where((p) => p.id.equals(item.productId)))
              .getSingleOrNull();
          if (product != null) products.add(product);
        }

        final returnItems = items.map((item) => ReturnItem(
              productId: item.productId,
              quantity: Decimal.zero,
              unitPrice: item.price,
              reason: '',
            )).toList();

        emit((PosLoaded(
          categories: const [],
          taxRate: Decimal.zero,
        )).copyWith(
          isReturnMode: true,
          originalSale: sale,
          cart: const [],
          returnItems: returnItems,
        ));
      } catch (e) {
        emit(PosError('خطأ في البحث عن الفاتورة: $e'));
      }
    }

    Future<void> onAddReturnItem(
      AddReturnItem event,
      Emitter<PosState> emit,
    ) async {
      if (state is! PosLoaded) return;
      final currentState = state as PosLoaded;

      final existingIndex =
          currentState.returnItems.indexWhere((i) => i.productId == event.productId);
      final updated = List<ReturnItem>.from(currentState.returnItems);

      if (existingIndex >= 0) {
        updated[existingIndex] = updated[existingIndex].copyWith(
          quantity: event.quantity,
          reason: event.reason,
        );
      } else {
        updated.add(ReturnItem(
          productId: event.productId,
          batchId: event.batchId,
          quantity: event.quantity,
          unitPrice: event.unitPrice,
          reason: event.reason,
        ));
      }

      emit(currentState.copyWith(returnItems: updated));
    }

    Future<void> onProcessReturn(
      ProcessReturn event,
      Emitter<PosState> emit,
    ) async {
      if (state is! PosLoaded) return;
      final currentState = state as PosLoaded;
      if (currentState.returnItems.isEmpty) return;

      final itemsToReturn =
          currentState.returnItems.where((i) => i.quantity > Decimal.zero).toList();
      if (itemsToReturn.isEmpty) {
        emit(const PosError('لم يتم تحديد أي أصناف للمرتجع'));
        return;
      }

      emit((state as PosLoaded).copyWith(isProcessingCheckout: true));

      try {
        final returnId = const Uuid().v4();
        final totalRefund =
            itemsToReturn.fold(Decimal.zero, (s, i) => s + i.total);

        await db.into(db.salesReturns).insert(
              SalesReturnsCompanion.insert(
                id: Value(returnId),
                saleId: event.originalSaleId,
                amountReturned: Value(totalRefund),
                createdAt: Value(DateTime.now()),
              ),
            );

        for (final item in itemsToReturn) {
          await db.into(db.salesReturnItems).insert(
                SalesReturnItemsCompanion.insert(
                  salesReturnId: returnId,
                  productId: item.productId,
                  batchId: Value(item.batchId),
                  quantity: item.quantity,
                  price: item.unitPrice,
                ),
              );
        }

        await transactionEngine.postSaleReturn(returnId);

        final originalSale = await (db.select(db.sales)
              ..where((s) => s.id.equals(event.originalSaleId)))
            .getSingle();

        emit(PosReturnSuccess(returnId, originalSale, totalRefund));
      } catch (e) {
        emit(PosError('خطأ في معالجة المرتجع: $e'));
        emit(currentState.copyWith(isProcessingCheckout: false));
      }
    }

    // Return mode events
    on<ToggleReturnMode>(onToggleReturnMode);
    on<LookupOriginalSale>(onLookupOriginalSale);
    on<AddReturnItem>(onAddReturnItem);
    on<RemoveReturnItem>((event, emit) {
      if (state is! PosLoaded) return;
      final currentState = state as PosLoaded;
      emit(currentState.copyWith(
        returnItems: currentState.returnItems
            .where((i) => i.productId != event.productId)
            .toList(),
      ));
    });
    on<ProcessReturn>(onProcessReturn);
    on<ClearReturn>((event, emit) {
      if (state is! PosLoaded) return;
      emit((state as PosLoaded).copyWith(
        isReturnMode: false,
        returnItems: const [],
        clearOriginalSale: true,
      ));
    });

    if (!skipInit) {
      _productSubscription = db.productsDao
          .watchProducts()
          .handleError((e) => developer.log("PosBloc Error: $e"))
          .listen((products) {
        if (state is PosLoaded && (state as PosLoaded).cart.isNotEmpty) {
          final cartProductIds = (state as PosLoaded).cart.map((i) => i.product.id).toSet();
          final changedProducts = products.where((p) => cartProductIds.contains(p.product.id)).toList();
          if (changedProducts.isNotEmpty) {
            add(RefreshPricesEvent());
          }
        }
      });
      add(LoadCategories());
    } else {
      _productSubscription = const Stream<List<ProductWithCategory>>.empty().listen((_) {});
    }
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
          isWholesale: currentState.isWholesaleMode,
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

    final updatedCart = <CartItem>[];
    for (final item in currentState.cart) {
      final finalPrice = await pricingService.calculatePrice(
        productId: item.product.id,
        priceListId: event.priceListId,
        quantity: item.quantity,
        isWholesale: currentState.isWholesaleMode,
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
            ..where(
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
      final productUnit = await (db.select(
        db.productUnits,
      )..where((t) => t.barcode.equals(event.sku)))
          .getSingleOrNull();

      Product? product;
      String unitName = 'حبة';
      Decimal factor = Decimal.one;
      Decimal? specificPrice;

      if (productUnit != null) {
        product = await (db.select(
          db.products,
        )..where((t) => t.id.equals(productUnit.productId)))
            .getSingle();
        unitName = productUnit.unitName;
        factor = productUnit.unitFactor;
        specificPrice = productUnit.sellPrice;
      } else {
        product = await (db.select(
          db.products,
        )..where((t) => t.sku.equals(event.sku) | t.barcode.equals(event.sku)))
            .getSingleOrNull();
        if (product != null) {
          unitName = product.unit;
        }
      }

      if (product == null) {
        emit(const PosError("المنتج غير موجود"));
        return;
      }

      final allUnits = await packagingEngine.getPackagingHierarchy(product.id);

       Decimal finalPrice = await pricingService.calculatePrice(
         productId: product.id,
         priceListId: currentState.activePriceListId,
         quantity: factor,
         isWholesale: currentState.isWholesaleMode,
       );

      if (specificPrice != null) {
        finalPrice = specificPrice;
      } else {
        finalPrice = finalPrice * factor;
      }

      final existingIndex = currentState.cart.indexWhere(
        (item) => item.product.id == product!.id && item.unitName == unitName,
      );

      List<CartItem> newCart = List.from(currentState.cart);
      if (existingIndex >= 0) {
        final updatedQty = newCart[existingIndex].quantity + Decimal.one;
        newCart[existingIndex] = newCart[existingIndex].copyWith(
          quantity: updatedQty,
        );
        
        final suggestion = await packagingEngine.getBestPackagingSuggestion(product.id, updatedQty * factor);
        if (suggestion != null && suggestion.unitName != unitName) {
           developer.log('Suggestion: Consider selling in ${suggestion.unitName} for better pricing/handling');
        }
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
        ProductUnit? selectedUnit;
        if (event.unitName == item.product.unit) {
          selectedUnit = null;
        } else {
          selectedUnit = item.availableUnits.cast<ProductUnit?>().firstWhere(
                (u) => u?.unitName == event.unitName,
                orElse: () => null,
              );
        }

        final unitName = event.unitName;
        final factor = selectedUnit != null
            ? selectedUnit.unitFactor
            : Decimal.one;

        Decimal finalPrice;
        if (currentState.isWholesaleMode) {
          finalPrice =
              Decimal.parse(item.product.wholesalePrice.toString()) * factor;
        } else {
          finalPrice = selectedUnit?.sellPrice != null
              ? selectedUnit!.sellPrice!
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
        newPrice = Decimal.parse(item.product.wholesalePrice.toString()) *
            item.unitFactor;
      } else {
        final unitInfo = item.availableUnits.cast<ProductUnit?>().firstWhere(
              (u) => u?.unitName == item.unitName,
              orElse: () => null,
            );
        newPrice = (unitInfo?.sellPrice != null)
            ? unitInfo!.sellPrice!
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
    if (currentState.isProcessingCheckout) return;

    // Shift validation for cash sales
    if (event.paymentMethod == 'cash' && event.userId != null) {
      final activeShift = await (db.select(db.shifts)
            ..where((s) => s.userId.equals(event.userId!) & s.isOpen.equals(true)))
          .getSingleOrNull();
      if (activeShift == null) {
        emit(const PosError('يجب فتح وردية عمل قبل إجراء عملية بيع نقدي'));
        return;
      }
    }

    // Credit limit check for credit sales
    if (event.paymentMethod == 'credit' && event.customerId != null) {
      final customer = await db.customersDao.getCustomerById(event.customerId!);
      if (customer != null && customer.creditLimit > Decimal.zero) {
        final newBalance = customer.balance + currentState.total;
        if (newBalance > customer.creditLimit) {
          emit(const PosError('العميل تجاوز الحد الائتماني المسموح به'));
          return;
        }
      }
    }

    emit(currentState.copyWith(isProcessingCheckout: true));

    try {
      final total = currentState.total;
      final tax = currentState.taxAmount;

      emit(PosLoading());

      final saleId = const Uuid().v4();
      developer.log(
        'Creating new POS sale draft: saleId=$saleId, payment=${event.paymentMethod}',
        name: 'pos.lifecycle',
      );

      final currencyId = event.currencyId ?? 'USD';
      final exchangeRate = event.exchangeRate;

      final itemDiscountSum = currentState.cart.fold<Decimal>(
        Decimal.zero,
        (sum, item) => sum + (item.discount ?? Decimal.zero),
      );
      final totalDiscount = currentState.discount + itemDiscountSum;

      PaymentMethod method = PaymentMethod.cash;
      if (event.paymentMethod == 'bank') {
        method = PaymentMethod.bank;
      } else if (event.paymentMethod == 'check') {
        method = PaymentMethod.check;
      }

      final saleCompanion = SalesCompanion.insert(
        id: Value(saleId),
        customerId: Value(event.customerId),
        total: Decimal.parse(total.toString()),
        discount: Value(Decimal.parse(totalDiscount.toString())),
        tax: Value(Decimal.parse(tax.toString())),
        paymentMethod: method,
        isCredit: Value(event.paymentMethod == 'credit'),
        syncStatus: const Value(1),
        currencyId: Value(currencyId),
        exchangeRate: Value(Decimal.parse(exchangeRate.toString())),
        status: const Value(DocumentStatus.draft),
      );

      final itemsCompanions = currentState.cart.map((item) {
        return SaleItemsCompanion.insert(
          saleId: saleId,
          productId: item.product.id,
          quantity: item.quantity,
          price: item.unitPrice,
          unitName: Value(item.unitName),
          unitFactor: Value(item.unitFactor),
          syncStatus: const Value(1),
        );
      }).toList();

      await db.salesDao.createSale(
        saleCompanion: saleCompanion,
        itemsCompanions: itemsCompanions,
        userId: event.userId,
      );

      developer.log('Posting POS sale draft: saleId=$saleId', name: 'pos.lifecycle');
      try {
        await transactionEngine.postSale(saleId, userId: event.userId);
      } catch (postError) {
        // Clean up orphaned draft on posting failure
        await (db.delete(db.sales)..where((s) => s.id.equals(saleId))).go();
        rethrow;
      }
      developer.log('Posted POS sale successfully: saleId=$saleId', name: 'pos.lifecycle');

      final saleObj = await (db.select(
        db.sales,
      )..where((s) => s.id.equals(saleId)))
          .getSingle();
      final saleItemsForAccounting = await (db.select(
        db.saleItems,
      )..where((si) => si.saleId.equals(saleId)))
          .get();

      emit(
        PosCheckoutSuccess(
          saleObj,
          saleItemsForAccounting,
          currentState.cart.map((i) => i.product).toList(),
        ),
      );
    } catch (e) {
      developer.log('Checkout error: $e', name: 'pos_bloc');
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      emit(PosError(errorMessage));
      emit(currentState.copyWith(isProcessingCheckout: false));
    }
  }
}
