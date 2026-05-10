import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PrintPreviewDialog extends StatelessWidget {
  final Future<Uint8List> Function() onBuild;
  final String title;

  const PrintPreviewDialog({
    super.key,
    required this.onBuild,
    this.title = 'معاينة الطباعة',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (format) => onBuild(),
        canChangePageFormat: true,
        canChangeOrientation: true,
      ),
    );
  }
}
