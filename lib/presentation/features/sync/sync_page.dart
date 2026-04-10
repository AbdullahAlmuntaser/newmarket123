import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/backup_service.dart';
import '../../../data/datasources/local/app_database.dart';
import 'package:supermarket/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  bool _isBackingUp = false;
  late final BackupService _backupService;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(
      Provider.of<AppDatabase>(context, listen: false),
    );
  }

  Future<void> _handleLocalBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isBackingUp = true);
    try {
      final path = await _backupService.createLocalBackup();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backup created at: $path'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => _backupService.shareBackup(path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handlePickAndRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Database files might have .sqlite or other extensions
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        
        // Show confirmation dialog
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.confirmRestore),
            content: Text(l10n.restoreWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.restore),
              ),
            ],
          ),
        );

        if (confirm == true) {
          setState(() => _isBackingUp = true);
          await _backupService.restoreFromLocal(filePath);
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Restore successful. Please restart the app.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupAndSync)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isBackingUp) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            _buildSectionHeader(context, l10n.backupNow),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBackingUp ? null : _handleLocalBackup,
                icon: const Icon(Icons.sd_storage),
                label: Text(l10n.localBackup),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(context, l10n.restoreFromLocalFile),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isBackingUp ? null : _handlePickAndRestore,
                icon: const Icon(Icons.file_open),
                label: Text(l10n.pickBackupFile),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
