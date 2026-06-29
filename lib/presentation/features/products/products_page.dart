import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/core/services/audit_service.dart';
import 'package:supermarket/injection_container.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';
import 'package:supermarket/presentation/features/products/widgets/add_edit_product_dialog.dart';
import 'package:supermarket/presentation/features/products/widgets/smart_stock_widget.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _searchQuery = '';
  String? _selectedCategoryId;
  int _currentPage = 0;
  int _totalProducts = 0;
  bool _isLoadingMore = false;
  final int _pageSize = 30;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTotalCount());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreItems) {
        _loadMore();
      }
    }
  }

  bool get _hasMoreItems => (_currentPage + 1) * _pageSize < _totalProducts;

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() {
      _currentPage++;
      _isLoadingMore = true;
    });
    await _updateTotalCount();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _resetPagination() {
    setState(() {
      _currentPage = 0;
      _totalProducts = 0;
    });
    _updateTotalCount();
  }

  Future<void> _updateTotalCount() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final count = await db.productsDao.countProducts(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      categoryId: _selectedCategoryId,
    );
    if (mounted) {
      setState(() => _totalProducts = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _resetPagination();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: l10n.searchProducts,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: StreamBuilder<List<Category>>(
                  stream: db.select(db.categories).watch(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    return SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildCategoryChip(context, null, l10n.all);
                          }
                          final category = categories[index - 1];
                          return _buildCategoryChip(
                            context,
                            category,
                            category.name,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: const MainDrawer(),
      body: StreamBuilder<List<ProductWithCategory>>(
        stream: db.productsDao.watchProducts(
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          categoryId: _selectedCategoryId,
          limit: (_currentPage + 1) * _pageSize,
          offset: 0,
        ),
        builder: (context, snapshot) {
          final displayedProducts = snapshot.data ?? [];

          if (displayedProducts.isEmpty && _currentPage == 0) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(l10n.noProductsFound));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: displayedProducts.length + (_hasMoreItems ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayedProducts.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final productWithCategory = displayedProducts[index];
                    final product = productWithCategory.product;
                    final categoryName =
                        productWithCategory.category?.name ?? '';

                    return ListTile(
                      leading: _buildProductImage(product),
                      title: Text(product.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SKU: ${product.sku} | ${l10n.category}: $categoryName',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Row(
                            children: [
                              Text(
                                '${l10n.stock}: ',
                                style: const TextStyle(fontSize: 12),
                              ),
                              SmartStockWidget(product: product),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${l10n.price}: ${product.sellPrice}'),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showAddEditDialog(context, product);
                              } else if (value == 'units') {
                                context.push(
                                  '/products/unit-conversion/${product.id}',
                                  extra: product.name,
                                );
                              } else if (value == 'delete') {
                                _deleteProduct(context, product);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('تعديل المنتج'),
                              ),
                              const PopupMenuItem(
                                value: 'units',
                                child: Text('تحويل الوحدات'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف المنتج'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _showAddEditDialog(context, product),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'عرض ${displayedProducts.length} من $_totalProducts منتج',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context, null),
        tooltip: l10n.addProduct,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    Category? category,
    String label,
  ) {
    final categoryId = category?.id;
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategoryId = selected ? categoryId : null;
            _resetPagination();
          });
        },
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      final file = File(product.imagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultImageIcon(),
          ),
        );
      }
    }
    return _defaultImageIcon();
  }

  Widget _defaultImageIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.inventory_2, color: Colors.grey[500], size: 24),
    );
  }

  void _showAddEditDialog(BuildContext context, Product? product) {
    showDialog(
      context: context,
      builder: (context) => AddEditProductDialog(product: product),
    );
  }

  Future<void> _deleteProduct(BuildContext context, Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text(l10n.deleteProductConfirmation(product.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await sl<AppDatabase>().productsDao.deleteProduct(product);
        if (context.mounted) {
          await sl<AuditService>().logDelete(
            'Product',
            product.id,
            details: 'Product deleted: ${product.name}, SKU: ${product.sku}',
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المنتج')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.failedToDeleteProduct}: $e')),
          );
        }
      }
    }
  }
}
