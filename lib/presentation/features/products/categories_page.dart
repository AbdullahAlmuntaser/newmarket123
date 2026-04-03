import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/presentation/features/products/widgets/add_edit_category_dialog.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/presentation/widgets/main_drawer.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = authProvider.currentUser?.role == 'admin';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      drawer: const MainDrawer(),
      body: StreamBuilder<List<Category>>(
        stream: db.select(db.categories).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return Center(child: Text(l10n.noCategoriesFound));
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final color = Colors.primaries[category.name.hashCode % Colors.primaries.length];
              
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: isAdmin ? () => _showAddEditDialog(context, db, category) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.7), color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.category, size: 40, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          category.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (category.code != null)
                          Text(
                            category.code!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        if (isAdmin)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                onPressed: () => _showAddEditDialog(context, db, category),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                onPressed: () => _deleteCategory(context, db, category),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditDialog(context, db, null),
              label: Text(l10n.addCategory),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddEditDialog(BuildContext context, AppDatabase db, Category? category) {
    showDialog(
      context: context,
      builder: (context) => AddEditCategoryDialog(db: db, category: category),
    );
  }

  void _deleteCategory(BuildContext context, AppDatabase db, Category category) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('${l10n.delete} ${category.name}'),
          content: const Text('هل أنت متأكد من حذف هذه الفئة؟ سيؤدي ذلك لمنع الوصول للمنتجات التابعة لها.'),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text(l10n.delete),
              onPressed: () async {
                final products = await (db.select(db.products)..where((p) => p.categoryId.equals(category.id))).get();
                if (!context.mounted) return;
                if (products.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يمكن حذف الفئة لأنها مرتبطة بمنتجات موجودة.')),
                  );
                  Navigator.of(dialogContext).pop();
                  return;
                }
                await db.delete(db.categories).delete(category);
                if (context.mounted) Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
