import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../utils/app_settings.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Select Month: '),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedMonth,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedMonth = picked;
                    });
                  }
                },
                child: Text('${_selectedMonth.year}-${_selectedMonth.month}'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Transaction>('transactions').listenable(),
              builder: (context, Box<Transaction> box, _) {
                final activeCurrency = AppSettings.getCurrency();
                String formatAmount(double value) {
                  return AppSettings.formatCurrency(value, activeCurrency);
                }

                final transactions = box.values.where((t) => t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month).toList();
                final totalIncome = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
                final totalExpense = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
                final categoryBreakdown = <String, double>{};
                for (final t in transactions) {
                  categoryBreakdown[t.category] = (categoryBreakdown[t.category] ?? 0) + t.amount;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly Summary', style: Theme.of(context).textTheme.headlineMedium),
                    Text('Total Income: ${formatAmount(totalIncome)}'),
                    Text('Total Expense: ${formatAmount(totalExpense)}'),
                    Text('Net: ${formatAmount(totalIncome - totalExpense)}'),
                    const SizedBox(height: 20),
                    Text('Category-wise Breakdown', style: Theme.of(context).textTheme.headlineMedium),
                    Expanded(
                      child: ListView(
                        children: categoryBreakdown.entries.map((entry) {
                          return ListTile(
                            title: Text(entry.key),
                            trailing: Text(formatAmount(entry.value)),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}