import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
        final settings = Hive.box('settings');
        final activeCurrency = settings.get(AppSettings.currencyKey, defaultValue: AppSettings.defaultCurrency) as String;
        final transactions = box.values.toList();
        final totalIncome = transactions
            .where((t) => t.type == 'income')
            .fold(0.0, (sum, t) => sum + t.amount);
        final totalExpense = transactions
            .where((t) => t.type == 'expense')
            .fold(0.0, (sum, t) => sum + t.amount);
        final balance = totalIncome - totalExpense;
        final recentTransactions = transactions.take(5).toList();

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
                    Text(
                      pendingDays <= 0 ? 'You’re all caught up for today' : 'You haven’t entered today’s expense',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Recent Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('VIEW HISTORY', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                ],
              ),
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
                ),
              ...recentTransactions.map((transaction) => _buildTransactionTile(transaction)).toList(),
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
                      signAmount(totalIncome - totalExpense),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: totalIncome - totalExpense < 0 ? Colors.redAccent : Colors.greenAccent,
                      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161626),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                  child: const Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RunningText(
                        transaction.category,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      RunningText(
                        '${transaction.date.toLocal().hour}:${transaction.date.toLocal().minute.toString().padLeft(2, '0')} - ${transaction.category.toUpperCase()}',
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
                : '+${AppSettings.currencySymbol(activeCurrency)}${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: transaction.type == 'expense' ? Colors.redAccent : Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
