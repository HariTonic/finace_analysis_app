import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../utils/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _currencyOptions = <String>[
    'USD',
    'EUR',
    'GBP',
    'INR',
    'JPY'
  ];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _monthlyLimitController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedCurrency = AppSettings.defaultCurrency;
  String _selectedGender = AppSettings.defaultGender;
  String _profileImageBase64 = '';
  DateTime? _selectedDob;
  bool _isProfileSaving = false;
  bool _isPreferencesSaving = false;
  double _monthlySpendingLimit = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _occupationController.dispose();
    _monthlyLimitController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    _selectedCurrency = AppSettings.getCurrency();
    _selectedGender = AppSettings.getProfileGender();
    _selectedDob = AppSettings.getProfileDob();
    _profileImageBase64 = AppSettings.getProfileImageBase64();
    _monthlySpendingLimit = AppSettings.getMonthlySpendingLimit();
    _nameController.text = AppSettings.getProfileName();
    _occupationController.text = AppSettings.getProfileOccupation();
    _monthlyLimitController.text =
        _monthlySpendingLimit == 0 ? '' : _monthlySpendingLimit.toStringAsFixed(0);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6AA8FF),
              surface: Color(0xFF121A33),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF10182E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() => _selectedDob = picked);
  }

  Future<void> _pickProfileImage() async {
    final selectedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );

    if (selectedFile == null) {
      return;
    }

    final bytes = await selectedFile.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _profileImageBase64 = base64Encode(bytes);
    });
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    setState(() => _isProfileSaving = true);
    await AppSettings.saveProfile(
      name: _nameController.text,
      dob: _selectedDob,
      gender: _selectedGender,
      occupation: _occupationController.text,
      profileImageBase64: _profileImageBase64,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isProfileSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile settings saved.')),
    );
  }

  Future<void> _savePreferences() async {
    FocusScope.of(context).unfocus();

    setState(() => _isPreferencesSaving = true);
    _monthlySpendingLimit = double.tryParse(_monthlyLimitController.text.trim()) ?? 0.0;
    await AppSettings.setCurrency(_selectedCurrency);
    await AppSettings.setMonthlySpendingLimit(_monthlySpendingLimit);

    if (!mounted) {
      return;
    }

    setState(() => _isPreferencesSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferences saved.')),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Uint8List? get _profileImageBytes {
    if (_profileImageBase64.isEmpty) {
      return null;
    }

    try {
      return base64Decode(_profileImageBase64);
    } catch (_) {
      return null;
    }
  }

  String _formattedDob() {
    if (_selectedDob == null) {
      return 'Not set';
    }
    return DateFormat('dd MMM yyyy').format(_selectedDob!);
  }

  String _backupStatusLabel() {
    final driveLast = AppSettings.getBackupLastSyncedAt();
    final gmailLast = AppSettings.getGmailBackupLastSyncedAt();
    final latest = [driveLast, gmailLast]
        .whereType<DateTime>()
        .fold<DateTime?>(null, (current, value) {
      if (current == null || value.isAfter(current)) {
        return value;
      }
      return current;
    });

    if (latest == null) {
      return 'No backup yet';
    }
    return 'Last backup ${DateFormat('dd MMM, hh:mm a').format(latest)}';
  }

  String _connectedBackupAccount() {
    final driveEmail = AppSettings.getBackupAccountEmail();
    if (driveEmail.isNotEmpty) {
      return driveEmail;
    }
    final gmailEmail = AppSettings.getGmailBackupEmail();
    if (gmailEmail.isNotEmpty) {
      return gmailEmail;
    }
    return 'No backup account connected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1124),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildAccountHero(),
          const SizedBox(height: 16),
          _buildProfileSection(),
          const SizedBox(height: 16),
          _buildPreferencesSection(),
          const SizedBox(height: 16),
          _buildBackupSection(),
        ],
      ),
    );
  }

  Widget _buildAccountHero() {
    final imageBytes = _profileImageBytes;
    ImageProvider<Object>? avatarImage;
    if (imageBytes != null) {
      avatarImage = MemoryImage(imageBytes);
    }
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Your Finance Vault';
    const subtitle = 'Add your profile details and manage your local data.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF17203A),
            Color(0xFF202C59),
            Color(0xFF131B33),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF6AA8FF),
              backgroundImage: avatarImage,
              child: imageBytes == null
                  ? Text(
                      displayName.isEmpty
                          ? 'U'
                          : displayName.characters.first.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickProfileImage,
                      icon: const Icon(Icons.photo_camera_back_outlined),
                      label: const Text('Profile photo'),
                    ),
                    if (imageBytes != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _profileImageBase64 = '';
                          });
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove photo'),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroInfoChip(
                      icon: Icons.currency_exchange_rounded,
                      label: 'Currency',
                      value: _selectedCurrency,
                    ),
                    _HeroInfoChip(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Budget',
                      value: _monthlySpendingLimit == 0
                          ? 'Not set'
                          : AppSettings.formatCurrency(
                              _monthlySpendingLimit,
                              _selectedCurrency,
                            ),
                    ),
                    _HeroInfoChip(
                      icon: Icons.backup_rounded,
                      label: 'Backup',
                      value: _backupStatusLabel(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return _SettingsCard(
      title: 'Profile',
      subtitle: 'Store the personal details you want to keep in the app.',
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'User name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _occupationController,
            decoration: const InputDecoration(
              labelText: 'Occupation',
              prefixIcon: Icon(Icons.work_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.wc_rounded),
            ),
            items: AppSettings.genderOptions.map((gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedGender = value);
            },
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDateOfBirth,
            borderRadius: BorderRadius.circular(18),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formattedDob()),
                  TextButton(
                    onPressed: _selectedDob == null
                        ? null
                        : () {
                            setState(() => _selectedDob = null);
                          },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isProfileSaving ? null : _saveProfile,
              icon: _isProfileSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isProfileSaving ? 'Saving...' : 'Save profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return _SettingsCard(
      title: 'Preferences',
      subtitle: 'Keep the app display choices aligned with your preferences.',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedCurrency,
            decoration: const InputDecoration(
              labelText: 'Currency',
              prefixIcon: Icon(Icons.currency_exchange_rounded),
            ),
            items: _currencyOptions.map((currency) {
              return DropdownMenuItem<String>(
                value: currency,
                child:
                    Text('$currency (${AppSettings.currencySymbol(currency)})'),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedCurrency = value);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _monthlyLimitController,
            decoration: const InputDecoration(
              labelText: 'Monthly Spending Limit',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
              helperText:
                  'Used for budget progress on Home and Reports.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              final limit = double.tryParse(value) ?? 0.0;
              setState(() => _monthlySpendingLimit = limit);
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isPreferencesSaving ? null : _savePreferences,
              icon: _isPreferencesSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label:
                  Text(_isPreferencesSaving ? 'Saving...' : 'Save preferences'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSection() {
    final driveLastSync = AppSettings.getBackupLastSyncedAt();
    final gmailLastSync = AppSettings.getGmailBackupLastSyncedAt();
    final driveAccount = AppSettings.getBackupAccountEmail();
    final gmailAccount = AppSettings.getGmailBackupEmail();

    return _SettingsCard(
      title: 'Backup & Restore',
      subtitle: 'Secure your data with Gmail and Google Drive',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.backup_rounded),
            title: const Text('Back Up Data'),
            subtitle: Text(
              driveLastSync == null && gmailLastSync == null
                  ? 'Gmail and Google Drive backup'
                  : 'Latest backup: ${_backupStatusLabel().replaceFirst('Last backup ', '')}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pushNamed(context, '/backup');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: const Text('Restore Data'),
            subtitle: Text(
              _connectedBackupAccount(),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pushNamed(context, '/restore');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Backup Settings'),
            subtitle: Text(
              driveAccount.isNotEmpty || gmailAccount.isNotEmpty
                  ? 'Manage schedule and connected accounts'
                  : 'Schedule automatic backups',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pushNamed(context, '/backup-settings');
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141C32),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
