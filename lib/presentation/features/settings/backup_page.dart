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
  List<LocalBackupInfo> _backups = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBackups());
  }

  BackupService _backupService() {
    return BackupService(context.read<AppDatabase>());
  }

  Future<void> _loadBackups() async {
    try {
      final backups = await _backupService().listLocalBackups();
      if (mounted) {
        setState(() => _backups = backups);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل النسخ الاحتياطية: $e')),
        );
      }
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      final path = await _backupService().createLocalBackup();
      await _loadBackups();
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

  Future<void> _shareBackup([String? path]) async {
    final backupPath = path ?? _lastBackupPath;
    if (backupPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إنشاء نسخة احتياطية أولاً')),
        );
      }
      return;
    }
    try {
      await _backupService().shareBackup(backupPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في مشاركة النسخة الاحتياطية: $e')),
        );
      }
    }
  }

  Future<void> _deleteBackup(LocalBackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف نسخة احتياطية'),
        content: Text('هل تريد حذف النسخة ${backup.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _backupService().deleteLocalBackup(backup.path);
      if (_lastBackupPath == backup.path) {
        _lastBackupPath = null;
      }
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف النسخة الاحتياطية')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حذف النسخة الاحتياطية: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sqlite'],
      );

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تحذير'),
          content: const Text(
            'استعادة النسخة الاحتياطية ستقوم بحذف البيانات الحالية. سيتم إنشاء نسخة أمان قبل الاستعادة. هل أنت متأكد؟',
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
      final safetyBackupPath = await _backupService().restoreFromLocal(
        filePath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استعادة البيانات بنجاح. نسخة الأمان: $safetyBackupPath. أعد تشغيل التطبيق.',
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  Widget _buildBackupList() {
    if (_backups.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد نسخ احتياطية محلية حتى الآن'),
        ),
      );
    }

    return Column(
      children: _backups
          .map(
            (backup) => Card(
              child: ListTile(
                leading: const Icon(Icons.backup, color: Colors.indigo),
                title: Text(backup.name),
                subtitle: Text(
                  '${_formatDate(backup.createdAt)} • ${backup.formattedSize}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'share') {
                      _shareBackup(backup.path);
                    } else if (value == 'delete') {
                      _deleteBackup(backup);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'share',
                      child: Text('مشاركة'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف'),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والاستعادة'),
        actions: [
          IconButton(
            tooltip: 'تحديث القائمة',
            onPressed: _isLoading ? null : _loadBackups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBackups,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.save, color: Colors.blue),
                      title: const Text('إنشاء نسخة احتياطية محلية'),
                      subtitle:
                          const Text('حفظ جميع البيانات في ملف على الجهاز'),
                      onTap: _createBackup,
                    ),
                  ),
                  if (_lastBackupPath != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.share, color: Colors.green),
                        title: const Text('مشاركة آخر نسخة احتياطية'),
                        subtitle: Text(_lastBackupPath!.split('/').last),
                        onTap: () => _shareBackup(),
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
                  const SizedBox(height: 16),
                  Text(
                    'النسخ المحلية',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildBackupList(),
                ],
              ),
            ),
    );
  }
}
