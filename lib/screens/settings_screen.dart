import 'package:flutter/material.dart';
import '../utils/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _currencyOptions = ['USD', 'EUR', 'GBP', 'INR', 'JPY'];
  late String _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = AppSettings.getCurrency();
  }

  void _updateCurrency(String? currency) {
    if (currency == null) return;
    AppSettings.setCurrency(currency);
    setState(() {
      _selectedCurrency = currency;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('Backup Data'),
            onTap: () {
              Navigator.pushNamed(context, '/backup');
            },
          ),
          ListTile(
            title: const Text('Restore Data'),
            onTap: () {
              Navigator.pushNamed(context, '/restore');
            },
          ),
          ListTile(
            title: const Text('Manage Categories'),
            onTap: () {
              // TODO: Implement
            },
          ),
          const SizedBox(height: 24),
          const Text('Currency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCurrency,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _currencyOptions.map((String currency) {
              return DropdownMenuItem<String>(
                value: currency,
                child: Text('$currency (${AppSettings.currencySymbol(currency)})'),
              );
            }).toList(),
            onChanged: _updateCurrency,
          ),
        ],
      ),
    );
  }
}