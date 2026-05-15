import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/backup_sync_service.dart';
import '../utils/gmail_backup_service.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen>
    with SingleTickerProviderStateMixin {
  GoogleSignInAccount? _driveAccount;
  GoogleSignInAccount? _gmailAccount;
  bool _loading = true;
  bool _restoring = false;
  List<GmailBackupInfo> _gmailBackups = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAccounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final driveAccount =
        await BackupSyncService.instance.restorePreviousSignIn();
    final gmailAccount = await GmailBackupService.instance.getGmailAccount();

    if (!mounted) return;

    setState(() {
      _driveAccount = driveAccount;
      _gmailAccount = gmailAccount;
      _loading = false;
    });

    // Load Gmail backups if account exists
    if (gmailAccount != null) {
      _loadGmailBackups();
    }
  }

  Future<void> _loadGmailBackups() async {
    final backups = await GmailBackupService.instance.listBackups();
    if (!mounted) return;

    setState(() {
      _gmailBackups = backups;
    });
  }

  // Restore from Google Drive
  Future<void> _restoreFromDrive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text(
            'This will overwrite all local data with the Google Drive backup.'),
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
      ),
    );

    if (confirm != true) return;

    setState(() => _restoring = true);

    try {
      var account = _driveAccount;
      account ??= await BackupSyncService.instance.signIn();

      if (account == null) {
        _showMessage('Google sign-in was cancelled.');
        return;
      }

      final restored = await BackupSyncService.instance.restoreBackup();
      if (!mounted) return;

      setState(() => _driveAccount = account);
      _showMessage(restored
          ? 'Backup restored successfully.'
          : 'No Google Drive backup was found.');
      if (restored) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Restore failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  // Restore from Gmail backup
  Future<void> _restoreFromGmailBackup(GmailBackupInfo backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Gmail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This will overwrite all local data with this Gmail backup:'),
            const SizedBox(height: 12),
            Text(
              backup.formattedDate,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Size: ${backup.sizeDisplay}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
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
      ),
    );

    if (confirm != true) return;

    setState(() => _restoring = true);

    try {
      final restored =
          await GmailBackupService.instance.restoreBackupFromGmail(
        backup.messageId,
      );

      if (!mounted) return;

      _showMessage(restored
          ? 'Backup restored successfully from Gmail!'
          : 'Failed to restore backup.');

      if (restored) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Restore failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Data'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Google Drive'),
            Tab(text: 'Gmail'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Google Drive Tab
                _buildDriveRestoreTab(),
                // Gmail Tab
                _buildGmailRestoreTab(),
              ],
            ),
    );
  }

  Widget _buildDriveRestoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: _driveAccount != null
                      ? [const Color(0xFF2A2A3F), const Color(0xFF1B1B2E)]
                      : [const Color(0xFF1B1B2E), const Color(0xFF161626)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _driveAccount != null
                              ? const Color(0xFF7A85FF)
                              : Colors.grey[700],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_outlined,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Drive',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _driveAccount?.email ?? 'Not connected',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_driveAccount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[900],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Connected',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sign in with the same Google account used for backup.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Restore Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_rounded, size: 20, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All local data will be replaced',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.restore, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transactions and settings will be restored',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _restoring ? null : _restoreFromDrive,
              icon: Icon(
                  _restoring ? Icons.hourglass_bottom : Icons.cloud_download),
              label: Text(_restoring
                  ? 'Restoring...'
                  : 'Restore from Google Drive'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF7A85FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGmailRestoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_gmailAccount == null)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B1B2E), Color(0xFF161626)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.mail_outline,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gmail',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Not connected',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await GmailBackupService.instance
                              .signInWithGmail();
                          _loadAccounts();
                        },
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Sign In with Gmail'),
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_gmailBackups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.mail_outline,
                        size: 64, color: Colors.white30),
                    const SizedBox(height: 16),
                    const Text(
                      'No Gmail backups found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a backup in the Backup tab first',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Backups',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _gmailBackups.length,
                  itemBuilder: (context, index) {
                    final backup = _gmailBackups[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3F),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.backup,
                                color: Colors.white, size: 20),
                          ),
                          title: Text(
                            backup.formattedDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(backup.sizeDisplay),
                          trailing: ElevatedButton.icon(
                            onPressed: _restoring
                                ? null
                                : () =>
                                    _restoreFromGmailBackup(backup),
                            icon: const Icon(
                              Icons.restore,
                              size: 16,
                            ),
                            label: const Text('Restore'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
