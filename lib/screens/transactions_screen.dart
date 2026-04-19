import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../widgets/running_text.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filterType = 'all'; // all, income, expense
  DateTime? _filterDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _filterType,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterType = value!;
                  });
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    setState(() {
                      _filterDate = picked;
                    });
                  }
                },
                child: Text(_filterDate == null ? 'Select Date' : _filterDate!.toString().split(' ')[0]),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: Hive.box<Transaction>('transactions').listenable(),
            builder: (context, Box<Transaction> box, _) {
              var transactions = box.values.toList();
              if (_filterType != 'all') {
                transactions = transactions.where((t) => t.type == _filterType).toList();
              }
              if (_filterDate != null) {
                transactions = transactions.where((t) => t.date.year == _filterDate!.year && t.date.month == _filterDate!.month && t.date.day == _filterDate!.day).toList();
              }
              final activeCurrency = AppSettings.getCurrency();

            return ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final amountText = transaction.type == 'expense'
                      ? '-${AppSettings.currencySymbol(activeCurrency)}${transaction.amount.toStringAsFixed(2)}'
                      : '+${AppSettings.currencySymbol(activeCurrency)}${transaction.amount.toStringAsFixed(2)}';
                  return ListTile(
                    title: RunningText(
                      '${transaction.category} - $amountText',
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: RunningText(
                      transaction.date.toString(),
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    onTap: () {
                      // Show edit/delete modal
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Edit or Delete'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  // Edit - navigate to add screen with data
                                  Navigator.pop(context);
                                  // For simplicity, just delete for now
                                },
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () {
                                  transaction.delete();
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
