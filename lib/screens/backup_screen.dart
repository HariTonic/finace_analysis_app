import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../utils/app_settings.dart';
import '../utils/backup_sync_service.dart';
import '../utils/gmail_backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen>
    with SingleTickerProviderStateMixin {
  GoogleSignInAccount? _driveAccount;
  GoogleSignInAccount? _gmailAccount;
  bool _loading = true;
  bool _syncing = false;
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
  }

  // Google Drive Backup
  Future<void> _backupToDrive() async {
    setState(() => _syncing = true);

    try {
      var account = _driveAccount;
      account ??= await BackupSyncService.instance.signIn();

      if (account == null) {
        _showMessage('Google sign-in was cancelled.');
        return;
      }

      final success = await BackupSyncService.instance.uploadBackup();
      if (!mounted) return;

      setState(() => _driveAccount = account);
      _showMessage(
        success
            ? 'Backup uploaded to Google Drive.'
            : 'Backup could not be completed.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Backup failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  // Gmail Backup (WhatsApp-like)
  Future<void> _backupToGmail() async {
    setState(() => _syncing = true);

    try {
      var account = _gmailAccount;
      account ??= await GmailBackupService.instance.signInWithGmail();

      if (account == null) {
        _showMessage('Gmail sign-in was cancelled.');
        return;
      }

      final success = await GmailBackupService.instance.sendBackupToGmail();
      if (!mounted) return;

      setState(() => _gmailAccount = account);
      _showMessage(
        success
            ? 'Backup sent to Gmail successfully!'
            : 'Failed to send backup to Gmail.',
      );
      _loadAccounts(); // Refresh account info
    } catch (e) {
      if (mounted) {
        _showMessage('Gmail backup failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  // Sign out from Gmail
  Future<void> _signOutFromGmail() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out from Gmail'),
        content: const Text(
            'You will need to sign in again to access Gmail backups.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await GmailBackupService.instance.signOutFromGmail();
    if (!mounted) return;

    setState(() => _gmailAccount = null);
    _showMessage('Signed out from Gmail');
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
    final lastDriveSync = AppSettings.getBackupLastSyncedAt();
    final lastGmailSync = AppSettings.getGmailBackupLastSyncedAt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Backup'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Google Drive'),
            Tab(text: 'Gmail (WhatsApp)'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Google Drive Tab
                _buildDriveBackupTab(lastDriveSync),
                // Gmail Tab
                _buildGmailBackupTab(lastGmailSync),
              ],
            ),
    );
  }

  Widget _buildDriveBackupTab(DateTime? lastSync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildAccountCard(
            icon: Icons.cloud_outlined,
            title: 'Google Drive',
            email: _driveAccount?.email ?? 'Not connected',
            lastSync: lastSync,
            isConnected: _driveAccount != null,
          ),
          const SizedBox(height: 24),
          const Text(
            'Secure Backup to Google Drive',
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
                    Icon(Icons.lock_outline, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Encrypted backup stored in your private Google Drive',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Automatic backups available with settings',
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
              onPressed: _syncing ? null : _backupToDrive,
              icon: Icon(_syncing ? Icons.hourglass_bottom : Icons.backup),
              label: Text(_syncing ? 'Backing up...' : 'Back Up Now'),
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

  Widget _buildGmailBackupTab(DateTime? lastSync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildAccountCard(
            icon: Icons.mail_outline,
            title: 'Gmail',
            email: _gmailAccount?.email ?? 'Not connected',
            lastSync: lastSync,
            isConnected: _gmailAccount != null,
          ),
          const SizedBox(height: 24),
          const Text(
            'WhatsApp-Style Gmail Backup',
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
                    Icon(Icons.email_outlined, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Backups sent to your Gmail with attachments',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.restore, size: 20, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Easy restore from any Gmail-connected device',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: Colors.cyan),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Schedule automatic daily backups',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_gmailAccount != null)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _syncing ? null : _backupToGmail,
                    icon: Icon(
                        _syncing ? Icons.hourglass_bottom : Icons.mail_outline),
                    label: Text(_syncing
                        ? 'Sending backup...'
                        : 'Send Backup to Gmail'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.red[700],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _gmailAccount != null ? _signOutFromGmail : null,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _syncing ? null : _backupToGmail,
                icon: Icon(_syncing ? Icons.hourglass_bottom : Icons.mail_outline),
                label: Text(_syncing ? 'Signing in...' : 'Sign In with Gmail'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.red[700],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountCard({
    required IconData icon,
    required String title,
    required String email,
    required DateTime? lastSync,
    required bool isConnected,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isConnected
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
                    color: isConnected
                        ? const Color(0xFF7A85FF)
                        : Colors.grey[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
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
                if (isConnected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            if (lastSync != null)
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last backup: ${DateFormat('MMM dd, yyyy • hh:mm a').format(lastSync)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 16, color: Colors.white54),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No backup created yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
