import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/backup_sync_service.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  GoogleSignInAccount? _account;
  bool _loading = true;
  bool _restoring = false;

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

  Future<void> _restoreBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Restore'),
          content: const Text('This will overwrite all local data with the Google Drive backup.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() => _restoring = true);

    try {
      var account = _account;
      account ??= await BackupSyncService.instance.signIn();

      if (account == null) {
        _showMessage('Google sign-in was cancelled.');
        return;
      }

      final restored = await BackupSyncService.instance.restoreBackup();
      if (!mounted) {
        return;
      }

      setState(() => _account = account);
      _showMessage(restored ? 'Backup restored successfully.' : 'No Google Drive backup was found.');
      if (restored) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Restore failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Data'),
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
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(_account?.email ?? 'No Google account connected'),
                      subtitle: const Text('Sign in with the same Google account used for backup.'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Restoring will replace your current transactions and saved profile details.'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _restoring ? null : _restoreBackup,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(_restoring ? 'Restoring...' : 'Restore from Google Drive'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
