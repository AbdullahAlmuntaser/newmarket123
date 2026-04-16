import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;

/// mixin يضيف pagination لأي صفحة تستخدم جداول Drift
mixin PaginatedListMixin<T extends drift.Table, D extends drift.DataClass>
    on State<StatefulWidget> {
  final int pageSize = 20;
  int _currentPage = 0;
  List<D> _allItems = [];
  @protected
  List<D> get pagedItems {
    final start = _currentPage * pageSize;
    final end = start + pageSize;
    if (start >= _allItems.length) return [];
    return _allItems.sublist(
      start,
      end > _allItems.length ? _allItems.length : end,
    );
  }

  bool get hasNextPage => (_currentPage + 1) * pageSize < _allItems.length;
  bool get hasPreviousPage => _currentPage > 0;
  int get totalPages => (_allItems.length / pageSize).ceil();
  int get displayedPage => _currentPage + 1;

  @protected
  Future<List<D>> fetchAllItems();

  @protected
  Future<void> loadItems() async {
    _allItems = await fetchAllItems();
    if (mounted) setState(() => _currentPage = 0);
  }

  @protected
  void nextPage() {
    if (hasNextPage && mounted) setState(() => _currentPage++);
  }

  @protected
  void previousPage() {
    if (hasPreviousPage && mounted) setState(() => _currentPage--);
  }

  @protected
  Widget buildPaginationControls() {
    if (_allItems.length <= pageSize) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('صفحة $displayedPage من $totalPages'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: hasPreviousPage ? previousPage : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: hasNextPage ? nextPage : null,
          ),
          const SizedBox(width: 16),
          Text('(${_allItems.length} عنصر)'),
        ],
      ),
    );
  }
}
