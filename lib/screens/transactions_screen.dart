import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'add_investment_screen.dart';
import '../models/investment_holding.dart';
import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../utils/backup_sync_service.dart';
import '../widgets/running_text.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.onNavigateHome});

  final VoidCallback? onNavigateHome;

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filterType = 'all'; // all, income, expense, investment
  DateTime? _filterDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1124),
      body: SafeArea(
        child: Column(
          children: [
            // Header and filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (widget.onNavigateHome != null) {
                            widget.onNavigateHome!.call();
                            return;
                          }
                          Navigator.maybePop(context);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'All Transactions',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filter row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B2E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _filterType,
                            style: const TextStyle(color: Colors.white),
                            dropdownColor: const Color(0xFF1B1B2E),
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'income', child: Text('Income', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'expense', child: Text('Expense', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'investment', child: Text('Investment', style: TextStyle(color: Colors.white))),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _filterType = value!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
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
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1B2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _filterDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(_filterDate!),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_filterDate != null)
                        IconButton(
                          onPressed: () => setState(() => _filterDate = null),
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Transactions list
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
                  
                  transactions.sort((a, b) => b.date.compareTo(a.date));
                  
                  final activeCurrency = AppSettings.getCurrency();

                  if (transactions.isEmpty) {
                    return Center(
                      child: Text(
                        'No transactions found',
                        style: TextStyle(color: Colors.grey.withValues(alpha: 0.7), fontSize: 16),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161626),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListView.separated(
                      shrinkWrap: false,
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: Color(0xFF2A2A3F),
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        return _buildTransactionTile(transaction, activeCurrency);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction, String activeCurrency) {
    // Parse category to extract parent and sub-category
    final categoryParts = transaction.category.split(' - ');
    final parentCategory = categoryParts.isNotEmpty ? categoryParts[0] : 'Unknown';
    final subCategory = categoryParts.length > 1 ? categoryParts[1] : '';
    
    final icon = _getCategoryIcon(parentCategory);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RunningText(
                        parentCategory,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      if (subCategory.isNotEmpty)
                        RunningText(
                          subCategory,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      else
                        RunningText(
                          '${transaction.date.toLocal().hour}:${transaction.date.toLocal().minute.toString().padLeft(2, '0')} - ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.type == 'income'
                    ? '+${AppSettings.currencySymbol(activeCurrency)}${transaction.amount.toStringAsFixed(2)}'
                    : '-${AppSettings.currencySymbol(activeCurrency)}${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: transaction.type == 'income'
                      ? Colors.greenAccent
                      : (transaction.type == 'investment' ? Colors.lightBlueAccent : Colors.redAccent),
                  fontWeight: FontWeight.bold,
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                color: const Color(0xFF1B1B2E),
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _editTransaction(transaction);
                    return;
                  }
                  if (value == 'delete') {
                    await _deleteTransaction(transaction);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    // Expense categories
    if (category == 'Housing') return Icons.home_rounded;
    if (category == 'Utilities & Bills') return Icons.receipt_long_rounded;
    if (category == 'Food') return Icons.restaurant;
    if (category == 'Transportation') return Icons.directions_car_filled_rounded;
    if (category == 'Healthcare') return Icons.local_hospital_rounded;
    if (category == 'Debt & Financial') return Icons.account_balance_wallet_rounded;
    if (category == 'Personal & Lifestyle') return Icons.self_improvement_rounded;
    if (category == 'Entertainment') return Icons.movie_rounded;
    if (category == 'Subscriptions & Services') return Icons.subscriptions_rounded;
    if (category == 'Family & Education') return Icons.school_rounded;
    if (category == 'Pets') return Icons.pets_rounded;
    if (category == 'Travel') return Icons.flight_takeoff_rounded;
    if (category == 'Giving & Obligations') return Icons.volunteer_activism_rounded;
    if (category == 'Work-related') return Icons.work_rounded;
    
    // Income categories
    if (category == 'Salary') return Icons.account_balance_wallet_rounded;
    if (category == 'Freelance') return Icons.laptop_chromebook_rounded;
    if (category == 'Investment') return Icons.trending_up_rounded;
    if (category == 'Bonus') return Icons.card_giftcard_rounded;
    
    // Investment categories
    if (category == 'Stocks') return Icons.show_chart;
    if (category == 'Stocks Investment' || category == 'Stocks') return Icons.show_chart;
    if (category == 'Gold Investment' || category == 'Gold') return Icons.workspace_premium_rounded;
    if (category == 'Other Investment') return Icons.widgets_rounded;
    
    return Icons.category;
  }

  Future<void> _editTransaction(Transaction transaction) async {
    if (transaction.type == 'expense') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(transaction: transaction),
        ),
      );
      return;
    }

    if (transaction.type == 'income') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddIncomeScreen(transaction: transaction),
        ),
      );
      return;
    }

    if (transaction.type == 'investment') {
      final holdingBox = Hive.box<InvestmentHolding>('investments');
      final holding = holdingBox.values.cast<InvestmentHolding?>().firstWhere(
        (item) => item?.id == transaction.id,
        orElse: () => null,
      );

      if (holding == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Linked investment record was not found.')),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddInvestmentScreen(
            transaction: transaction,
            holding: holding,
          ),
        ),
      );
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    if (transaction.type == 'investment') {
      final investmentBox = Hive.box<InvestmentHolding>('investments');
      final investmentIndex = investmentBox.values.toList().indexWhere((item) => item.id == transaction.id);
      if (investmentIndex != -1) {
        await investmentBox.deleteAt(investmentIndex);
      }
    }
    await transaction.delete();
    await BackupSyncService.instance.backupIfEnabled();
  }
}
