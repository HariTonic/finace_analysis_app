import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../utils/import_history.dart';
import '../utils/transaction_csv_service.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedCurrency = AppSettings.defaultCurrency;
  String _selectedGender = AppSettings.defaultGender;
  String _profileImageBase64 = '';
  DateTime? _selectedDob;
  bool _isProfileSaving = false;
  bool _isPreferencesSaving = false;
  bool _isImportingCsv = false;
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
    await AppSettings.setCurrency(_selectedCurrency);
    await AppSettings.setMonthlySpendingLimit(_monthlySpendingLimit);

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

  Future<void> _importCsvData() async {
    setState(() => _isImportingCsv = true);

    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'CSV',
            extensions: <String>['csv'],
          ),
        ],
      );

      if (file == null) {
        if (mounted) {
          setState(() => _isImportingCsv = false);
        }
        return;
      }

      final csv = await file.readAsString();
      final parsedTransactions = TransactionCsvService.parseTransactions(csv);

      if (parsedTransactions.isEmpty) {
        _showMessage('No valid transactions were found in that CSV file.');
        if (mounted) {
          setState(() => _isImportingCsv = false);
        }
        return;
      }

      final transactionBox = Hive.box<Transaction>('transactions');
      final existingIds = transactionBox.values.map((item) => item.id).toSet();

      var importedCount = 0;
      var skippedCount = 0;
      final importedIds = <String>[];

      for (final transaction in parsedTransactions) {
        if (existingIds.contains(transaction.id)) {
          skippedCount++;
          continue;
        }

        await transactionBox.add(transaction);
        existingIds.add(transaction.id);
        importedIds.add(transaction.id);
        importedCount++;
      }

      if (importedIds.isNotEmpty) {
        await ImportHistoryManager.addImportRecord(
          importedIds.length,
          'csv',
          importedIds,
          skippedCount,
        );
      }

      if (!mounted) {
        return;
      }

      final message = importedCount == 0
          ? 'All CSV transactions were already imported.'
          : 'Imported $importedCount transaction${importedCount == 1 ? '' : 's'} from CSV${skippedCount > 0 ? ' ($skippedCount duplicate${skippedCount == 1 ? '' : 's'} skipped)' : ''}.';
      _showMessage(message);
    } catch (_) {
      if (mounted) {
        _showMessage('CSV import failed. Please choose a valid export file.');
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingCsv = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1124),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildAccountHero(theme),
          const SizedBox(height: 16),
          _buildProfileSection(theme),
          const SizedBox(height: 16),
          _buildBackupSection(theme),
          const SizedBox(height: 16),
          _buildImportSection(theme),
          const SizedBox(height: 16),
          _buildPreferencesSection(theme),
        ],
      ),
    );
  }

  Widget _buildAccountHero(ThemeData theme) {
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
                  style: theme.textTheme.titleLarge?.copyWith(
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(ThemeData theme) {
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

  Widget _buildPreferencesSection(ThemeData theme) {
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
            initialValue: _monthlySpendingLimit == 0
                ? ''
                : _monthlySpendingLimit.toString(),
            decoration: const InputDecoration(
              labelText: 'Monthly Spending Limit',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
            ),
            keyboardType: TextInputType.number,
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

  Widget _buildImportSection(ThemeData theme) {
    return _SettingsCard(
      title: 'Data Import',
      subtitle:
          'Import transactions from a CSV file created by the app export.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CSV import adds transactions from the selected file and skips rows that were already imported with the same ID.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isImportingCsv ? null : _importCsvData,
              icon: _isImportingCsv
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_isImportingCsv ? 'Importing...' : 'Import CSV'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSection(ThemeData theme) {
    return _SettingsCard(
      title: 'Backup & Restore',
      subtitle: 'Secure your data with Gmail and Google Drive',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.backup_rounded),
            title: const Text('Back Up Data'),
            subtitle: const Text('Gmail and Google Drive backup'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pushNamed(context, '/backup');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: const Text('Restore Data'),
            subtitle: const Text('Restore from backup'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pushNamed(context, '/restore');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Backup Settings'),
            subtitle: const Text('Schedule automatic backups'),
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
