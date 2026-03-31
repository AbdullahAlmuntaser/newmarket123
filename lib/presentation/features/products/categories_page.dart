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
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                subtitle: category.code != null
                    ? Text('${l10n.categoryCode}: ${category.code!}')
                    : null,
                trailing: isAdmin
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showAddEditDialog(context, db, category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () =>
                                _deleteCategory(context, db, category),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(context, db, null),
              tooltip: l10n.addCategory,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    AppDatabase db,
    Category? category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AddEditCategoryDialog(db: db, category: category),
    );
  }

  void _deleteCategory(
    BuildContext context,
    AppDatabase db,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            '${AppLocalizations.of(dialogContext)!.delete} ${category.name}',
          ),
          content: Text(
            'Are you sure you want to delete this category?',
          ), // Add to l10n
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(dialogContext)!.cancel),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(
                AppLocalizations.of(dialogContext)!.delete,
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                // Before deleting, check if any product is using this category
                final products = await (db.select(
                  db.products,
                )..where((p) => p.categoryId.equals(category.id))).get();
                if (!context.mounted) return;
                if (products.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cannot delete category, it is being used by some products.',
                      ),
                    ), // Add to l10n
                  );
                  Navigator.of(dialogContext).pop();
                  return;
                }
                await db.delete(db.categories).delete(category);
                if (!context.mounted) return;
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
