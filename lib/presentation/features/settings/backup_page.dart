import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supermarket/core/utils/backup_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:provider/provider.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isLoading = false;
  String? _lastBackupPath;

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      final db = context.read<AppDatabase>();
      final backupService = BackupService(db);
      final path = await backupService.createLocalBackup();
      if (mounted) {
        setState(() => _lastBackupPath = path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إنشاء النسخة الاحتياطية بنجاح في: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء النسخة الاحتياطية: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareBackup() async {
    if (_lastBackupPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إنشاء نسخة احتياطية أولاً')),
        );
      }
      return;
    }
    try {
      final db = context.read<AppDatabase>();
      final backupService = BackupService(db);
      await backupService.shareBackup(_lastBackupPath!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في مشاركة النسخة الاحتياطية: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sqlite'],
      );

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تحذير'),
          content: const Text(
            'استعادة النسخة الاحتياطية ستقوم بحذف البيانات الحالية. هل أنت متأكد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );

      if (confirmed != true || result == null) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      setState(() => _isLoading = true);
      if (!mounted) return;
      final db = context.read<AppDatabase>();
      final backupService = BackupService(db);
      await backupService.restoreFromLocal(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم استعادة البيانات بنجاح، سيتم إعادة تشغيل التطبيق.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في استعادة البيانات: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.save, color: Colors.blue),
                    title: const Text('إنشاء نسخة احتياطية محلية'),
                    subtitle: const Text('حفظ جميع البيانات في ملف على الجهاز'),
                    onTap: _createBackup,
                  ),
                ),
                if (_lastBackupPath != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.share, color: Colors.green),
                      title: const Text('مشاركة النسخة الاحتياطية'),
                      subtitle: Text(_lastBackupPath!.split('/').last),
                      onTap: _shareBackup,
                    ),
                  ),
                const Divider(height: 32),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restore, color: Colors.orange),
                    title: const Text('استعادة من ملف محلي'),
                    subtitle: const Text(
                      'اختر ملف نسخة احتياطية لاستعادة البيانات',
                    ),
                    onTap: _restoreBackup,
                  ),
                ),
              ],
            ),
    );
  }
}
