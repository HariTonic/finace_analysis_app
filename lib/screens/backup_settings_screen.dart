import 'package:flutter/material.dart';
import '../utils/app_settings.dart';
import '../utils/gmail_backup_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  late BackupFrequency _selectedFrequency;
  late bool _autoBackupEnabled;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final frequencyValue = AppSettings.getGmailBackupFrequency();
    _selectedFrequency = BackupFrequency.fromString(frequencyValue);
  }

  Future<void> _setBackupFrequency(BackupFrequency frequency) async {
    setState(() {
      _selectedFrequency = frequency;
    });

    await AppSettings.setGmailBackupFrequency(frequency.value);
    _showMessage('Backup frequency set to ${frequency.displayName}');
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
        title: const Text('Backup Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Google Drive Settings
            _buildSectionHeader('Google Drive Backup'),
            _buildSettingCard(
              icon: Icons.cloud_outlined,
              title: 'Google Drive',
              description: 'Secure backup to your Google Drive',
              trailing: Switch(
                value: AppSettings.isBackupEnabled(),
                onChanged: (value) async {
                  await AppSettings.setBackupEnabled(value);
                  setState(() {});
                  _showMessage(
                    value ? 'Google Drive backup enabled' : 'Google Drive backup disabled',
                  );
                },
              ),
            ),
            if (AppSettings.isBackupEnabled())
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppSettings.getBackupAccountEmail().isEmpty
                            ? 'No account connected'
                            : AppSettings.getBackupAccountEmail(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Gmail Backup Settings
            _buildSectionHeader('Gmail Backup (WhatsApp Style)'),
            _buildSettingCard(
              icon: Icons.mail_outline,
              title: 'Email Backups',
              description: 'Send backups to your Gmail account',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Backup Schedule',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildFrequencyOption(
              BackupFrequency.never,
              'Never',
              'No automatic backups',
            ),
            _buildFrequencyOption(
              BackupFrequency.daily,
              'Daily',
              'Automatic backup every day at 2:00 AM',
            ),
            _buildFrequencyOption(
              BackupFrequency.weekly,
              'Weekly',
              'Automatic backup every Sunday at 2:00 AM',
            ),
            _buildFrequencyOption(
              BackupFrequency.monthly,
              'Monthly',
              'Automatic backup on the 1st of each month',
            ),
            const SizedBox(height: 24),

            // Backup Information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What Gets Backed Up',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        BackupItem('Transactions', Icons.receipt_long_rounded),
                        SizedBox(height: 10),
                        BackupItem(
                            'Investment Holdings', Icons.show_chart_rounded),
                        SizedBox(height: 10),
                        BackupItem('Profile Information', Icons.person_outline),
                        SizedBox(height: 10),
                        BackupItem('App Settings', Icons.settings_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Storage & Security
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Storage & Security',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 18, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Backups are stored in your secure Google account',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.cloud_done_outlined,
                                size: 18, color: Colors.blue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Google Drive and Gmail encrypt your data',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String description,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF7A85FF), size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          trailing: trailing,
        ),
      ),
    );
  }

  Widget _buildFrequencyOption(
    BackupFrequency frequency,
    String label,
    String description,
  ) {
    final isSelected = _selectedFrequency == frequency;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _setBackupFrequency(frequency),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2A2A3F) : const Color(0xFF161626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF7A85FF) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF7A85FF)
                        : Colors.white30,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Color(0xFF7A85FF))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackupItem extends StatelessWidget {
  final String label;
  final IconData icon;

  const BackupItem(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7A85FF)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
