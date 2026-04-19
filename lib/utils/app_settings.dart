import 'package:hive_flutter/hive_flutter.dart';

class AppSettings {
  static const String currencyKey = 'currency';
  static const String installDateKey = 'installDate';
  static const String defaultCurrency = 'INR';

  static const Map<String, String> currencySymbols = {
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': '¥',
  };

  static String getCurrency() {
    final settings = Hive.box('settings');
    return settings.get(currencyKey, defaultValue: defaultCurrency) as String;
  }

  static void setCurrency(String currency) {
    final settings = Hive.box('settings');
    settings.put(currencyKey, currency);
  }

  static String currencySymbol(String currencyCode) {
    return currencySymbols[currencyCode] ?? currencyCode;
  }

  static String formatCurrency(double value, String currencyCode) {
    final symbol = currencySymbol(currencyCode);
    return '$symbol${value.toStringAsFixed(2)}';
  }

  static DateTime getInstallDate() {
    final settings = Hive.box('settings');
    final stored = settings.get(installDateKey);
    if (stored is DateTime) {
      return stored;
    }

    final now = DateTime.now();
    settings.put(installDateKey, now);
    return now;
  }
}
