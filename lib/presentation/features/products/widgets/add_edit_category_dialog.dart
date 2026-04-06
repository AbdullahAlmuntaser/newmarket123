import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:drift/drift.dart' hide Column;

class AddEditCategoryDialog extends StatefulWidget {
  final AppDatabase db;
  final Category? category;

  const AddEditCategoryDialog({super.key, required this.db, this.category});

  @override
  State<AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<AddEditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String? _code;

  @override
  void initState() {
    super.initState();
    _name = widget.category?.name ?? '';
    _code = widget.category?.code;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.category == null ? l10n.addCategory : l10n.editCategory,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              decoration: InputDecoration(labelText: l10n.categoryName),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.enterNameError;
                }
                return null;
              },
              onSaved: (value) => _name = value!,
            ),
            TextFormField(
              initialValue: _code,
              decoration: InputDecoration(labelText: l10n.categoryCode),
              onSaved: (value) => _code = value,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _saveCategory, child: Text(l10n.save)),
      ],
    );
  }

  void _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final l10n = AppLocalizations.of(context)!;

      try {
        if (widget.category == null) {
          // Add new category
          await widget.db
              .into(widget.db.categories)
              .insert(
                CategoriesCompanion.insert(name: _name, code: Value(_code)),
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.categoryAdded),
              ),
            );
          }
        } else {
          // Update existing category
          await (widget.db.update(widget.db.categories)
                ..where((c) => c.id.equals(widget.category!.id)))
              .write(CategoriesCompanion(name: Value(_name), code: Value(_code)));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.categoryUpdated),
              ),
            );
          }
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e, s) {
        developer.log(
          'Failed to save category',
          name: 'add_edit_category_dialog',
          error: e,
          stackTrace: s,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.failedToSaveCategory}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
