import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/data/datasources/local/daos/products_dao.dart';
import 'package:supermarket/l10n/app_localizations.dart';
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

  bool get _hasMoreItems =>
      (_currentPage + 1) * _pageSize < _totalProducts;

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() {
      _currentPage++;
      _isLoadingMore = false;
    });
  }

  void _resetPagination() {
    setState(() {
      _currentPage = 0;
      _totalProducts = 0;
    });
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
        ),
        builder: (context, snapshot) {
          final allProducts = snapshot.data ?? [];
          
          if (_totalProducts == 0 && allProducts.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _totalProducts = allProducts.length);
            });
          }
          
          if (allProducts.isEmpty && _currentPage == 0) {
            return Center(child: Text(l10n.noProductsFound));
          }
          
          // Calculate pagination
          final start = _currentPage * _pageSize;
          final end = start + _pageSize;
          final displayedProducts = allProducts.sublist(
            start, 
            end > allProducts.length ? allProducts.length : end
          );

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: displayedProducts.length + 
                      (_hasMoreItems ? 1 : 0),
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
                    final categoryName = productWithCategory.category?.name ?? '';

                    return ListTile(
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

  void _showAddEditDialog(BuildContext context, Product? product) {
    showDialog(
      context: context,
      builder: (context) => AddEditProductDialog(product: product),
    );
  }
}