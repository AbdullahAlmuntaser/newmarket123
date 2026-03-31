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
      if (!mounted) return;
      final db = Provider.of<AppDatabase>(context, listen: false);
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
      if (!mounted) return;
      final db = Provider.of<AppDatabase>(context, listen: false);
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        if (!mounted) return;
        setState(() => _isLoading = true);
        final db = Provider.of<AppDatabase>(context, listen: false);
        final backupService = BackupService(db);
        await backupService.restoreFromLocal(result.files.single.path!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استعادة البيانات بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في استعادة البيانات: $e')),
        );
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
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والاستعادة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.save, color: Colors.blue),
                    title: const Text('إنشاء نسخة احتياطية محلية'),
                    subtitle: const Text('حفظ جميع البيانات في ملف JSON على الجهاز'),
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
                    subtitle: const Text('اختر ملف نسخة احتياطية لاستعادة البيانات'),
                    onTap: _restoreBackup,
                  ),
                ),
                const Divider(height: 32),
                const Text(
                  'النسخ الاحتياطي السحابي (قريباً)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Card(
                  child: ListTile(
                    enabled: false,
                    leading: const Icon(Icons.cloud_upload, color: Colors.grey),
                    title: const Text('رفع إلى Firebase Storage'),
                    onTap: () {},
                  ),
                ),
              ],
            ),
    );
  }
}
