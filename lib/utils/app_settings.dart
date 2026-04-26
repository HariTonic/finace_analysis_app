import 'package:hive_flutter/hive_flutter.dart';

class AppSettings {
  static const String currencyKey = 'currency';
  static const String installDateKey = 'installDate';
  static const String defaultCurrency = 'INR';

  static const String profileNameKey = 'profileName';
  static const String profileDobKey = 'profileDob';
  static const String profileGenderKey = 'profileGender';
  static const String profileOccupationKey = 'profileOccupation';
  static const String profileImageKey = 'profileImageBase64';

  static const String backupEnabledKey = 'backupEnabled';
  static const String backupLastSyncedAtKey = 'backupLastSyncedAt';
  static const String backupAccountEmailKey = 'backupAccountEmail';
  static const String backupAccountNameKey = 'backupAccountName';

  static const String monthlySpendingLimitKey = 'monthlySpendingLimit';

  static const String defaultGender = 'Prefer not to say';

  static const List<String> genderOptions = [
    defaultGender,
    'Male',
    'Female',
    'Non-binary',
    'Other',
  ];

  static const Map<String, String> currencySymbols = {
    'USD': r'$',
    'EUR': '\u20AC',
    'GBP': '\u00A3',
    'INR': '\u20B9',
    'JPY': '\u00A5',
  };

  static Box<dynamic> get _settingsBox => Hive.box('settings');

  static String getCurrency() {
    return _settingsBox.get(currencyKey, defaultValue: defaultCurrency)
        as String;
  }

  static Future<void> setCurrency(String currency) async {
    await _settingsBox.put(currencyKey, currency);
  }

  static String currencySymbol(String currencyCode) {
    return currencySymbols[currencyCode] ?? currencyCode;
  }

  static String formatCurrency(double value, String currencyCode) {
    final symbol = currencySymbol(currencyCode);
    return '$symbol${value.toStringAsFixed(2)}';
  }

  static DateTime getInstallDate() {
    final stored = _readDate(_settingsBox.get(installDateKey));
    if (stored != null) {
      return stored;
    }

    final now = DateTime.now();
    _settingsBox.put(installDateKey, now);
    return now;
  }

  static String getProfileName() {
    return _settingsBox.get(profileNameKey, defaultValue: '') as String;
  }

  static DateTime? getProfileDob() {
    return _readDate(_settingsBox.get(profileDobKey));
  }

  static String getProfileGender() {
    return _settingsBox.get(profileGenderKey, defaultValue: defaultGender)
        as String;
  }

  static String getProfileOccupation() {
    return _settingsBox.get(profileOccupationKey, defaultValue: '') as String;
  }

  static String getProfileImageBase64() {
    return _settingsBox.get(profileImageKey, defaultValue: '') as String;
  }

  static Future<void> saveProfile({
    required String name,
    DateTime? dob,
    required String gender,
    required String occupation,
    required String profileImageBase64,
  }) async {
    await _settingsBox.put(profileNameKey, name.trim());
    await _settingsBox.put(profileGenderKey, gender);
    await _settingsBox.put(profileOccupationKey, occupation.trim());
    await _settingsBox.put(profileImageKey, profileImageBase64);

    if (dob == null) {
      await _settingsBox.delete(profileDobKey);
    } else {
      await _settingsBox.put(profileDobKey, dob);
    }
  }

  static bool isBackupEnabled() {
    return _settingsBox.get(backupEnabledKey, defaultValue: false) as bool;
  }

  static Future<void> setBackupEnabled(bool enabled) async {
    await _settingsBox.put(backupEnabledKey, enabled);
  }

  static DateTime? getBackupLastSyncedAt() {
    return _readDate(_settingsBox.get(backupLastSyncedAtKey));
  }

  static Future<void> setBackupLastSyncedAt(DateTime? dateTime) async {
    if (dateTime == null) {
      await _settingsBox.delete(backupLastSyncedAtKey);
      return;
    }

    await _settingsBox.put(backupLastSyncedAtKey, dateTime);
  }

  static String getBackupAccountEmail() {
    return _settingsBox.get(backupAccountEmailKey, defaultValue: '') as String;
  }

  static String getBackupAccountName() {
    return _settingsBox.get(backupAccountNameKey, defaultValue: '') as String;
  }

  static Future<void> setBackupAccount({
    required String email,
    required String name,
  }) async {
    await _settingsBox.put(backupAccountEmailKey, email);
    await _settingsBox.put(backupAccountNameKey, name);
  }

  static Future<void> clearBackupAccount() async {
    await _settingsBox.delete(backupAccountEmailKey);
    await _settingsBox.delete(backupAccountNameKey);
  }

  static double getMonthlySpendingLimit() {
    return _settingsBox.get(monthlySpendingLimitKey, defaultValue: 0.0)
        as double;
  }

  static Future<void> setMonthlySpendingLimit(double limit) async {
    await _settingsBox.put(monthlySpendingLimitKey, limit);
  }

  static Map<String, dynamic> exportForBackup() {
    return {
      currencyKey: getCurrency(),
      installDateKey: getInstallDate().toIso8601String(),
      profileNameKey: getProfileName(),
      profileDobKey: getProfileDob()?.toIso8601String(),
      profileGenderKey: getProfileGender(),
      profileOccupationKey: getProfileOccupation(),
      profileImageKey: getProfileImageBase64(),
      backupEnabledKey: isBackupEnabled(),
      backupLastSyncedAtKey: getBackupLastSyncedAt()?.toIso8601String(),
      backupAccountEmailKey: getBackupAccountEmail(),
      backupAccountNameKey: getBackupAccountName(),
      monthlySpendingLimitKey: getMonthlySpendingLimit(),
    };
  }

  static Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    await setCurrency((data[currencyKey] as String?) ?? defaultCurrency);

    final installDate = _readDate(data[installDateKey]);
    if (installDate != null) {
      await _settingsBox.put(installDateKey, installDate);
    }

    await saveProfile(
      name: (data[profileNameKey] as String?) ?? '',
      dob: _readDate(data[profileDobKey]),
      gender: (data[profileGenderKey] as String?) ?? defaultGender,
      occupation: (data[profileOccupationKey] as String?) ?? '',
      profileImageBase64: (data[profileImageKey] as String?) ?? '',
    );

    await setBackupEnabled((data[backupEnabledKey] as bool?) ?? false);
    await setBackupLastSyncedAt(_readDate(data[backupLastSyncedAtKey]));
    await setBackupAccount(
      email: (data[backupAccountEmailKey] as String?) ?? '',
      name: (data[backupAccountNameKey] as String?) ?? '',
    );
    await setMonthlySpendingLimit(
        (data[monthlySpendingLimitKey] as num?)?.toDouble() ?? 0.0);
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
