import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  _BackupScreenState createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    // Load last backup date from somewhere, e.g., shared preferences
  }

  Future<void> _createBackup() async {
    final box = Hive.box<Transaction>('transactions');
    final transactions = box.values.toList();
    final data = transactions.map((t) => {
      'id': t.id,
      'amount': t.amount,
      'category': t.category,
      'date': t.date.toIso8601String(),
      'type': t.type,
      'notes': t.notes,
    }).toList();
    final json = jsonEncode(data);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/backup.json');
    await file.writeAsString(json);

    setState(() {
      _lastBackup = DateTime.now();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup created successfully')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Last Backup: ${_lastBackup?.toString() ?? 'None'}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createBackup,
              child: const Text('Create Backup'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement share
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share not implemented yet')));
              },
              child: const Text('Share Backup'),
            ),
          ],
        ),
      ),
    );
  }
}