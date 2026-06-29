import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/injection_container.dart' as di;
import 'package:supermarket/core/services/barcode_generation_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BarcodePrintingPage extends StatefulWidget {
  const BarcodePrintingPage({super.key});

  @override
  State<BarcodePrintingPage> createState() => _BarcodePrintingPageState();
}

class _BarcodePrintingPageState extends State<BarcodePrintingPage> {
  List<Product> _products = [];
  List<Product> _selectedProducts = [];
  BarcodeType _barcodeType = BarcodeType.code128;
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _selectedSupplierId;
  int _labelQuantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final db = di.sl<AppDatabase>();
      _products = await (db.select(db.products)
            ..where((p) => p.isActive.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Product> get _filteredProducts {
    return _products.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
      final matchesCategory =
          _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      final matchesSupplier =
          _selectedSupplierId == null || p.supplierId == _selectedSupplierId;
      return matchesSearch && matchesCategory && matchesSupplier;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طباعة الباركود والملصقات'),
        actions: [
          if (_selectedProducts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printSelectedLabels,
              tooltip: 'طباعة المحدد',
            ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: _batchGenerateBarcodes,
            tooltip: 'توليد باركود للمنتجات بدون باركود',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildBarcodeTypeSelector(),
          _buildLabelQuantitySelector(),
          _buildSelectedCountBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildProductsList(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedProducts.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generateBarcodeSheet,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('ورقة باركود'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _printSelectedLabels,
                      icon: const Icon(Icons.print),
                      label: const Text('طباعة مباشرة'),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'بحث بالاسم أو الكود أو الباركود...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<Category>>(
                  stream: di
                      .sl<AppDatabase>()
                      .select(di.sl<AppDatabase>().categories)
                      .watch(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'التصنيف',
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('الكل')),
                        ...categories.map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedCategoryId = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<List<Supplier>>(
                  stream: di
                      .sl<AppDatabase>()
                      .select(di.sl<AppDatabase>().suppliers)
                      .watch(),
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _selectedSupplierId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'المورد',
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('الكل')),
                        ...suppliers.map((s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedSupplierId = val),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Text('نوع الباركود: ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: SegmentedButton<BarcodeType>(
              segments: const [
                ButtonSegment(
                    value: BarcodeType.code128, label: Text('Code128')),
                ButtonSegment(value: BarcodeType.ean13, label: Text('EAN13')),
                ButtonSegment(value: BarcodeType.qrCode, label: Text('QR')),
              ],
              selected: {_barcodeType},
              onSelectionChanged: (val) =>
                  setState(() => _barcodeType = val.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelQuantitySelector() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Text('عدد الملصقات: ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: _labelQuantity.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                final qty = int.tryParse(val) ?? 1;
                setState(() => _labelQuantity = qty.clamp(1, 100));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCountBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'محدد: ${_selectedProducts.length} من ${_filteredProducts.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(
                    () => _selectedProducts = List.from(_filteredProducts)),
                child: const Text('تحديد الكل'),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedProducts.clear()),
                child: const Text('إلغاء التحديد'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    if (_filteredProducts.isEmpty) {
      return const Center(child: Text('لا توجد منتجات'));
    }

    return ListView.builder(
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final isSelected = _selectedProducts.any((p) => p.id == product.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedProducts.add(product);
              } else {
                _selectedProducts.removeWhere((p) => p.id == product.id);
              }
            });
          },
          title: Text(product.name),
          subtitle: Text(
            'SKU: ${product.sku} | الباركود: ${product.barcode ?? 'غير محدد'}',
            style: const TextStyle(fontSize: 12),
          ),
          secondary: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: product.imagePath != null && product.imagePath!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(File(product.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.inventory_2)),
                  )
                : const Icon(Icons.inventory_2),
          ),
        );
      },
    );
  }

  Future<void> _printSelectedLabels() async {
    if (_selectedProducts.isEmpty) return;

    final labels = _selectedProducts
        .map((p) => BarcodeLabel(
              productName: p.name,
              sku: p.sku,
              barcode: p.barcode ??
                  BarcodeGenerationService.autoGenerateBarcode(
                      type: _barcodeType),
              type: _barcodeType,
              price: double.tryParse(p.sellPrice.toString()),
              quantity: _labelQuantity,
            ))
        .toList();

    await Printing.layoutPdf(
      onLayout: (format) => _generateBarcodePdf(labels, format),
      name: 'barcode_labels',
    );
  }

  Future<void> _generateBarcodeSheet() async {
    if (_selectedProducts.isEmpty) return;

    final labels = _selectedProducts
        .map((p) => BarcodeLabel(
              productName: p.name,
              sku: p.sku,
              barcode: p.barcode ??
                  BarcodeGenerationService.autoGenerateBarcode(
                      type: _barcodeType),
              type: _barcodeType,
              price: double.tryParse(p.sellPrice.toString()),
              quantity: _labelQuantity,
            ))
        .toList();

    await Printing.layoutPdf(
      onLayout: (format) => _generateBarcodeSheetPdf(labels, format),
      name: 'barcode_sheet',
    );
  }

  Future<void> _batchGenerateBarcodes() async {
    final db = di.sl<AppDatabase>();
    final productsWithoutBarcode = _products
        .where((p) => p.barcode == null || p.barcode!.isEmpty)
        .toList();

    if (productsWithoutBarcode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جميع المنتجات لها باركود بالفعل')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('توليد باركود جماعي'),
        content: Text(
            'سيتم توليد باركود لـ ${productsWithoutBarcode.length} منتج بدون باركود. هل تريد المتابعة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('توليد')),
        ],
      ),
    );

    if (confirmed == true) {
      int count = 0;
      for (final product in productsWithoutBarcode) {
        final newBarcode =
            BarcodeGenerationService.autoGenerateBarcode(type: _barcodeType);
        await (db.update(db.products)..where((p) => p.id.equals(product.id)))
            .write(
          ProductsCompanion(barcode: Value(newBarcode)),
        );
        count++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم توليد باركود لـ $count منتج')),
        );
        _loadProducts();
      }
    }
  }

  Future<Uint8List> _generateBarcodePdf(
      List<BarcodeLabel> labels, PdfPageFormat format) async {
    final doc = pw.Document();

    for (final label in labels) {
      for (int i = 0; i < label.quantity; i++) {
        doc.addPage(
          pw.Page(
            pageFormat: format,
            build: (context) => _buildLabelWidget(label),
          ),
        );
      }
    }

    return doc.save();
  }

  Future<Uint8List> _generateBarcodeSheetPdf(
      List<BarcodeLabel> labels, PdfPageFormat format) async {
    final doc = pw.Document();
    const labelsPerPage = 20;

    for (int i = 0; i < labels.length; i += labelsPerPage) {
      final pageLabels = labels.skip(i).take(labelsPerPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) => pw.GridView(
            crossAxisCount: 4,
            childAspectRatio: 0.5,
            children: pageLabels
                .expand((label) => List.generate(
                    label.quantity, (_) => _buildLabelWidget(label)))
                .toList(),
          ),
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildLabelWidget(BarcodeLabel label) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label.productName,
              style: const pw.TextStyle(fontSize: 8), maxLines: 1),
          pw.Text('SKU: ${label.sku}', style: const pw.TextStyle(fontSize: 6)),
          pw.SizedBox(height: 4),
          pw.BarcodeWidget(
            barcode: label.type == BarcodeType.qrCode
                ? pw.Barcode.qrCode()
                : label.type == BarcodeType.ean13
                    ? pw.Barcode.ean13()
                    : pw.Barcode.code128(),
            data: label.barcode,
            width: 120,
            height: 40,
          ),
          pw.Text(label.barcode, style: const pw.TextStyle(fontSize: 6)),
          if (label.price != null)
            pw.Text('${label.price!.toStringAsFixed(2)} ر.س',
                style:
                    pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
