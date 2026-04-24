import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../utils/app_settings.dart';
import '../utils/backup_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _currencyOptions = <String>['USD', 'EUR', 'GBP', 'INR', 'JPY'];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedCurrency = AppSettings.defaultCurrency;
  String _selectedGender = AppSettings.defaultGender;
  String _profileImageBase64 = '';
  DateTime? _selectedDob;
  bool _backupEnabled = false;
  bool _isInitializing = true;
  bool _isProfileSaving = false;
  bool _isSyncing = false;
  GoogleSignInAccount? _googleAccount;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeGoogleAccount();
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
    _backupEnabled = AppSettings.isBackupEnabled();
    _nameController.text = AppSettings.getProfileName();
    _occupationController.text = AppSettings.getProfileOccupation();
  }

  Future<void> _initializeGoogleAccount() async {
    final account = await BackupSyncService.instance.restorePreviousSignIn();
    if (!mounted) {
      return;
    }

    setState(() {
      _googleAccount = account;
      _isInitializing = false;
    });
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
    await BackupSyncService.instance.backupIfEnabled();

    if (!mounted) {
      return;
    }

    setState(() => _isProfileSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile settings saved.')),
    );
  }

  Future<void> _signInToGoogle() async {
    if (!BackupSyncService.instance.isSupportedPlatform) {
      _showMessage('Google Drive backup is available on Android, iOS, and macOS.');
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final account = await BackupSyncService.instance.signIn();
      if (!mounted) {
        return;
      }

      if (account == null) {
        _showMessage('Google sign-in was cancelled.');
        setState(() => _isSyncing = false);
        return;
      }

      final shouldPrefillName = _nameController.text.trim().isEmpty && (account.displayName?.trim().isNotEmpty ?? false);
      if (shouldPrefillName) {
        _nameController.text = account.displayName!.trim();
      }

      setState(() {
        _googleAccount = account;
      });

      final hasRemoteBackup = await BackupSyncService.instance.hasRemoteBackup();
      if (!mounted) {
        return;
      }

      if (hasRemoteBackup) {
        final shouldRestore = await _showRestoreDialog(
          title: 'Restore your Drive backup?',
          message: 'We found a backup for ${account.email}. Restoring will replace the current data on this device.',
        );
        if (shouldRestore && mounted) {
          await _restoreFromDrive();
        }
      } else if (_backupEnabled) {
        await BackupSyncService.instance.uploadBackup();
        if (mounted) {
          _showMessage('Initial Google Drive backup completed.');
        }
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Google sign-in failed. Check your Google configuration and try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _signOutFromGoogle() async {
    setState(() => _isSyncing = true);
    await BackupSyncService.instance.signOut();
    await AppSettings.setBackupEnabled(false);

    if (!mounted) {
      return;
    }

    setState(() {
      _googleAccount = null;
      _backupEnabled = false;
      _isSyncing = false;
    });
    _showMessage('Google Drive backup has been disconnected.');
  }

  Future<void> _toggleBackup(bool enabled) async {
    if (enabled && _googleAccount == null) {
      await _signInToGoogle();
      if (_googleAccount == null) {
        return;
      }
    }

    setState(() => _isSyncing = true);
    await AppSettings.setBackupEnabled(enabled);

    if (enabled) {
      final hasRemoteBackup = await BackupSyncService.instance.hasRemoteBackup();
      if (!mounted) {
        return;
      }

      if (hasRemoteBackup) {
        final shouldRestore = await _showRestoreDialog(
          title: 'Use existing backup?',
          message: 'A Drive backup already exists for this Google account. Restore that backup now, or keep your current data and upload it instead.',
          confirmLabel: 'Restore',
        );

        if (shouldRestore) {
          await _restoreFromDrive(showSuccessMessage: true);
        } else {
          await BackupSyncService.instance.uploadBackup();
          if (mounted) {
            _showMessage('Current data backed up to Google Drive.');
          }
        }
      } else {
        await BackupSyncService.instance.uploadBackup();
        if (mounted) {
          _showMessage('Google Drive backup is now enabled.');
        }
      }
    } else {
      _showMessage('Automatic backup disabled.');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _backupEnabled = enabled;
      _isSyncing = false;
    });
  }

  Future<void> _backupNow() async {
    if (_googleAccount == null) {
      await _signInToGoogle();
      if (_googleAccount == null) {
        return;
      }
    }

    setState(() => _isSyncing = true);
    final success = await BackupSyncService.instance.uploadBackup();
    if (!mounted) {
      return;
    }

    setState(() => _isSyncing = false);
    _showMessage(success ? 'Backup uploaded to Google Drive.' : 'Unable to create backup right now.');
  }

  Future<void> _restoreFromDrive({bool showSuccessMessage = false}) async {
    setState(() => _isSyncing = true);

    try {
      final restored = await BackupSyncService.instance.restoreBackup();
      if (!mounted) {
        return;
      }

      if (restored) {
        _loadSettings();
        setState(() {});
        if (showSuccessMessage) {
          _showMessage('Backup restored from Google Drive.');
        }
      } else {
        _showMessage('No backup was found on Google Drive.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Backup restore failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<bool> _showRestoreDialog({
    required String title,
    required String message,
    String confirmLabel = 'Restore',
  }) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10182E),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return decision ?? false;
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

  String _lastBackupLabel() {
    final lastSync = AppSettings.getBackupLastSyncedAt();
    if (lastSync == null) {
      return 'No cloud backup yet';
    }
    return 'Last backup: ${DateFormat('dd MMM yyyy, hh:mm a').format(lastSync)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDriveSupported = BackupSyncService.instance.isSupportedPlatform;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1124),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildAccountHero(theme),
                const SizedBox(height: 16),
                _buildProfileSection(theme),
                const SizedBox(height: 16),
                _buildBackupSection(theme, isDriveSupported),
                const SizedBox(height: 16),
                _buildPreferencesSection(theme),
              ],
            ),
    );
  }

  Widget _buildAccountHero(ThemeData theme) {
    final imageBytes = _profileImageBytes;
    final googlePhoto = _googleAccount?.photoUrl;
    ImageProvider<Object>? avatarImage;
    if (imageBytes != null) {
      avatarImage = MemoryImage(imageBytes);
    } else if (googlePhoto != null && googlePhoto.isNotEmpty) {
      avatarImage = NetworkImage(googlePhoto);
    }
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_googleAccount?.displayName ?? 'Your Finance Vault');
    final subtitle = _googleAccount?.email.isNotEmpty == true
        ? _googleAccount!.email
        : 'Add your profile details and connect Google Drive backup';

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
              child: imageBytes == null && (googlePhoto == null || googlePhoto.isEmpty)
                  ? Text(
                      displayName.isEmpty ? 'U' : displayName.characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    FilledButton.icon(
                      onPressed: _isSyncing ? null : _signInToGoogle,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(_googleAccount == null ? 'Login with Google' : 'Switch account'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSyncing ? null : _pickProfileImage,
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
      subtitle: 'Store the personal details that should travel with your backup.',
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

  Widget _buildBackupSection(ThemeData theme, bool isDriveSupported) {
    final connectedEmail = _googleAccount?.email.isNotEmpty == true
        ? _googleAccount!.email
        : AppSettings.getBackupAccountEmail();

    return _SettingsCard(
      title: 'Cloud Backup',
      subtitle: 'Optional Google Drive sync that behaves like a personal vault backup.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _backupEnabled,
            onChanged: _isSyncing || !isDriveSupported ? null : _toggleBackup,
            title: const Text('Enable Google Drive backup'),
            subtitle: Text(
              isDriveSupported
                  ? 'When enabled, your latest transactions and profile can be backed up and restored.'
                  : 'This device cannot use Google Drive backup.',
            ),
          ),
          const Divider(color: Colors.white12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_done_outlined),
            title: Text(connectedEmail.isEmpty ? 'Not connected' : connectedEmail),
            subtitle: Text(_lastBackupLabel()),
            trailing: connectedEmail.isNotEmpty
                ? TextButton(
                    onPressed: _isSyncing ? null : _signOutFromGoogle,
                    child: const Text('Logout'),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _isSyncing || !isDriveSupported ? null : _backupNow,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(_isSyncing ? 'Working...' : 'Back up now'),
              ),
              OutlinedButton.icon(
                onPressed: _isSyncing || !isDriveSupported || _googleAccount == null
                    ? null
                    : () => _restoreFromDrive(showSuccessMessage: true),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Restore backup'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(ThemeData theme) {
    return _SettingsCard(
      title: 'Preferences',
      subtitle: 'Keep the app display choices aligned with your profile backup.',
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCurrency,
        decoration: const InputDecoration(
          labelText: 'Currency',
          prefixIcon: Icon(Icons.currency_exchange_rounded),
        ),
        items: _currencyOptions.map((currency) {
          return DropdownMenuItem<String>(
            value: currency,
            child: Text('$currency (${AppSettings.currencySymbol(currency)})'),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() => _selectedCurrency = value);
        },
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
