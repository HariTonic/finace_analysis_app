import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  Future<void> _restoreData(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final json = await file.readAsString();
      final data = jsonDecode(json) as List;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Restore'),
            content: const Text('This will overwrite all existing data. Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        final box = Hive.box<Transaction>('transactions');
        await box.clear();
        for (final item in data) {
          final transaction = Transaction(
            id: item['id'],
            amount: item['amount'],
            category: item['category'],
            date: DateTime.parse(item['date']),
            type: item['type'],
            notes: item['notes'],
          );
          await box.add(transaction);
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data restored successfully')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Warning: Restoring will overwrite all current data.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _restoreData(context),
              child: const Text('Select Backup File'),
            ),
          ],
        ),
      ),
    );
  }
}