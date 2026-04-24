import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/investment_holding.dart';
import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../utils/export_helper.dart';
import '../widgets/running_text.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Transaction>('transactions').listenable(),
      builder: (context, Box<Transaction> box, _) {
        return ValueListenableBuilder(
          valueListenable: Hive.box<InvestmentHolding>('investments').listenable(),
          builder: (context, Box<InvestmentHolding> investmentBox, _) {
            final settings = Hive.box('settings');
            final activeCurrency = settings.get(AppSettings.currencyKey, defaultValue: AppSettings.defaultCurrency) as String;
            final transactions = box.values.toList();
            final totalIncome = transactions
                .where((t) => t.type == 'income')
                .fold(0.0, (sum, t) => sum + t.amount);
            final totalExpense = transactions
                .where((t) => t.type == 'expense')
                .fold(0.0, (sum, t) => sum + t.amount);
            final totalInvestment = transactions
                .where((t) => t.type == 'investment')
                .fold(0.0, (sum, t) => sum + t.amount);
            final balance = totalIncome - totalExpense - totalInvestment;
            final recentTransactions = transactions.take(5).toList();
            final holdings = investmentBox.values.toList();
            final holdingsCurrentValue = holdings.fold<double>(0, (sum, item) => sum + item.currentValue);

            final installDate = AppSettings.getInstallDate();
            final latestEntryDate = transactions.isNotEmpty
                ? transactions.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b)
                : installDate;
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final latestEntryDay = DateTime(latestEntryDate.year, latestEntryDate.month, latestEntryDate.day);
            final pendingDays = today.difference(latestEntryDay).inDays;
            final pendingLabel = pendingDays <= 0
                ? 'All caught up'
                : '$pendingDays day${pendingDays == 1 ? '' : 's'} pending';
            final headerDate = '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';

            String formatAmount(double value) => AppSettings.formatCurrency(value, activeCurrency);
            String signAmount(double value) {
              final sign = value < 0 ? '-' : '+';
              return '$sign${AppSettings.currencySymbol(activeCurrency)}${value.abs().toStringAsFixed(2)}';
            }

            Future<void> _exportData() async {
              String csv = 'ID,Amount,Category,Date,Type,Notes\n';
              for (var t in transactions) {
                csv += '${t.id},${t.amount},${t.category},${t.date.toIso8601String()},${t.type},${t.notes}\n';
              }
              final path = await saveExportData(csv);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Data exported as CSV to $path')),
              );
            }

            return Container(
          color: const Color(0xFF0D1124),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 80.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wealth Vault', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(formatAmount(balance), style: const TextStyle(fontSize: 18, color: Colors.white70)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(headerDate, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A3F),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: SizedBox(
                                width: 110,
                                child: RunningText(
                                  pendingLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3F),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                      child: const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.transparent,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2E),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    const BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.18),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DAILY TRACKER', style: TextStyle(color: Colors.blueAccent, letterSpacing: 1.8, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    if (pendingDays <= 0)
                      const Text(
                        "You're all caught up for today",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_rounded, color: Colors.orangeAccent, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No entry for today! Update now.',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$pendingDays day${pendingDays == 1 ? '' : 's'} pending',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A85FF),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/add-expense');
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Expense Now', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildActionCard(context, Icons.wallet, 'Add Expense', '/add-expense')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildActionCard(context, Icons.attach_money, 'Add Income', '/add-income')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildActionCard(context, Icons.show_chart, 'Add Investment', '/add-investment')),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Recent Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (recentTransactions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161626),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('No recent transactions yet.', style: TextStyle(color: Colors.grey)),
                ) else
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161626),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: LimitedBox(
                    maxHeight: 400,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: recentTransactions.length > 5 ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                      itemCount: recentTransactions.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: Color(0xFF2A2A3F),
                      ),
                      itemBuilder: (context, index) => _buildTransactionTile(recentTransactions[index]),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2E),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DAILY TOTAL SUMMARY', style: TextStyle(color: Colors.grey, letterSpacing: 1.6)),
                    const SizedBox(height: 16),
                    Text(
                      signAmount(totalIncome - totalExpense - totalInvestment),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: totalIncome - totalExpense - totalInvestment < 0 ? Colors.redAccent : Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (holdings.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Current investment value: ${formatAmount(holdingsCurrentValue)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryStat('Income', formatAmount(totalIncome), Colors.greenAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryStat('Expense', formatAmount(totalExpense), Colors.redAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryStat('Invest', formatAmount(totalInvestment), Colors.lightBlueAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A3F),
                              disabledBackgroundColor: Colors.grey.shade700,
                              disabledForegroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: transactions.isEmpty ? null : _exportData,
                            icon: const Icon(Icons.upload, color: Colors.white),
                            label: const Text('Export', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A85FF),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/add-expense');
                            },
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Quick Entry', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
          },
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String label, String? route) {
    return GestureDetector(
      onTap: route == null ? null : () => Navigator.pushNamed(context, route),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161626),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    final activeCurrency = AppSettings.getCurrency();
    
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
                          '${transaction.date.toLocal().hour}:${transaction.date.toLocal().minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            transaction.type == 'expense'
                ? '-${AppSettings.currencySymbol(activeCurrency)}${transaction.amount.toStringAsFixed(2)}'
                : transaction.type == 'income'
                    ? '+${AppSettings.currencySymbol(activeCurrency)}${transaction.amount.toStringAsFixed(2)}'
                    : '-${AppSettings.currencySymbol(activeCurrency)}${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: transaction.type == 'expense'
                  ? Colors.redAccent
                  : transaction.type == 'income'
                      ? Colors.greenAccent
                      : Colors.lightBlueAccent,
              fontWeight: FontWeight.bold,
            ),
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

  Widget _summaryStat(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
