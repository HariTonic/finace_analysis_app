import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../utils/app_settings.dart';
import '../utils/backup_sync_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  GoogleSignInAccount? _account;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final account = await BackupSyncService.instance.restorePreviousSignIn();
    if (!mounted) {
      return;
    }

    setState(() {
      _account = account;
      _loading = false;
    });
  }

  Future<void> _backupNow() async {
    setState(() => _syncing = true);

    try {
      var account = _account;
      account ??= await BackupSyncService.instance.signIn();

      if (account == null) {
        _showMessage('Google sign-in was cancelled.');
        return;
      }

      final success = await BackupSyncService.instance.uploadBackup();
      if (!mounted) {
        return;
      }

      setState(() => _account = account);
      _showMessage(success ? 'Backup uploaded to Google Drive.' : 'Backup could not be completed.');
    } catch (_) {
      if (mounted) {
        _showMessage('Backup failed. Please verify your Google configuration.');
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastSync = AppSettings.getBackupLastSyncedAt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Data'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_done_outlined),
                      title: Text(_account?.email ?? 'No Google account connected'),
                      subtitle: Text(
                        lastSync == null
                            ? 'No backup created yet'
                            : 'Last backup: ${DateFormat('dd MMM yyyy, hh:mm a').format(lastSync)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This screen creates an encrypted-style app backup in your Google Drive app data area.',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _syncing ? null : _backupNow,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(_syncing ? 'Backing up...' : 'Back Up to Google Drive'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
