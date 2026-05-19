import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'add_investment_screen.dart';
import '../models/investment_holding.dart';
import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../utils/backup_sync_service.dart';
import '../utils/notification_service.dart';
import '../widgets/running_text.dart';
import '../widgets/scroll_shadow_wrapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Transaction>('transactions').listenable(),
      builder: (context, Box<Transaction> box, _) {
        return ValueListenableBuilder(
          valueListenable:
              Hive.box<InvestmentHolding>('investments').listenable(),
          builder: (context, Box<InvestmentHolding> investmentBox, _) {
            final settings = Hive.box('settings');
            final activeCurrency = settings.get(AppSettings.currencyKey,
                defaultValue: AppSettings.defaultCurrency) as String;
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

            final now = DateTime.now();
            // Current month calculations
            final currentMonth = DateTime(now.year, now.month);
            final currentMonthTransactions = transactions.where((t) {
              final tMonth = DateTime(t.date.year, t.date.month);
              return tMonth == currentMonth;
            }).toList();
            final monthlyExpense = currentMonthTransactions
                .where((t) => t.type == 'expense')
                .fold(0.0, (sum, t) => sum + t.amount);
            final monthlyLimit = AppSettings.getMonthlySpendingLimit();

            // Progress bar: shows remaining budget (decreases as spending increases)
            double progressValue = 0.0;
            if (monthlyLimit > 0) {
              progressValue = ((monthlyLimit - monthlyExpense) / monthlyLimit).clamp(0.0, 1.0);
            }

            final expenseLimitText = monthlyLimit > 0
                ? '${AppSettings.formatCurrency(monthlyExpense, activeCurrency)} / ${AppSettings.formatCurrency(monthlyLimit, activeCurrency)}'
                : 'Set a monthly expense limit in Settings';

            final progressGradientColors = progressValue > 0.5
                ? [Colors.green[400]!, Colors.green[700]!]
                : progressValue > 0.25
                    ? [Colors.amber[400]!, Colors.orange[600]!]
                    : [Colors.red[400]!, Colors.red[700]!];

            // Check for notifications
            if (monthlyLimit > 0) {
              final spentPercentage = (monthlyExpense / monthlyLimit) * 100;
              if (spentPercentage >= 25 && spentPercentage < 50) {
                // Notify at 25%
                NotificationService.showSpendingNotification(25);
              } else if (spentPercentage >= 50 && spentPercentage < 75) {
                NotificationService.showSpendingNotification(50);
              } else if (spentPercentage >= 75 && spentPercentage < 100) {
                NotificationService.showSpendingNotification(75);
              }
            }
            final recentTransactions = transactions.where((transaction) {
              return transaction.date.year == now.year &&
                  transaction.date.month == now.month &&
                  transaction.date.day == now.day;
            }).toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final holdings = investmentBox.values.toList();
            final holdingsCurrentValue = holdings.fold<double>(
                0, (sum, item) => sum + item.currentValue);

            final installDate = AppSettings.getInstallDate();
            final latestEntryDate = transactions.isNotEmpty
                ? transactions
                    .map((t) => t.date)
                    .reduce((a, b) => a.isAfter(b) ? a : b)
                : installDate;
            final today = DateTime(now.year, now.month, now.day);
            final latestEntryDay = DateTime(latestEntryDate.year,
                latestEntryDate.month, latestEntryDate.day);
            final pendingDays = today.difference(latestEntryDay).inDays;
            final pendingLabel = pendingDays <= 0
                ? 'All caught up'
                : '$pendingDays day${pendingDays == 1 ? '' : 's'} pending';
            final headerDate =
                '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';

            String formatAmount(double value) =>
                AppSettings.formatCurrency(value, activeCurrency);
            String signAmount(double value) {
              final sign = value < 0 ? '-' : '+';
              return '$sign${AppSettings.currencySymbol(activeCurrency)}${value.abs().toStringAsFixed(2)}';
            }



            return Container(
              color: const Color(0xFF0D1124),
              child: SafeArea(
                child: ScrollShadowWrapper(
                  builder: (controller) => SingleChildScrollView(
                    controller: controller,
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
                                const Text('MoneyFlow',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(formatAmount(balance),
                                    style: const TextStyle(
                                        fontSize: 18, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Expense limit',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            expenseLimitText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progressValue,
                              heightFactor: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: progressGradientColors,
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(headerDate,
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3F),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: SizedBox(
                              width: 110,
                              child: RunningText(
                                pendingLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    letterSpacing: 0.5),
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
                            const Text('DAILY TRACKER',
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    letterSpacing: 1.8,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            if (pendingDays <= 0)
                              const Text(
                                "You're all caught up for today",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_rounded,
                                          color: Colors.orangeAccent, size: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No entry for today! Update now.',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orangeAccent),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$pendingDays day${pendingDays == 1 ? '' : 's'} pending',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),

                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                              child: _buildActionCard(context, Icons.wallet,
                                  'Add Expense', '/add-expense')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildActionCard(
                                  context,
                                  Icons.attach_money,
                                  'Add Income',
                                  '/add-income')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildActionCard(context, Icons.show_chart,
                                  'Add Investment', '/add-investment')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A85FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/extract-sms',
                            );
                            if (result == true) {
                              // Refresh the home screen if transactions were imported
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.sms, color: Colors.white),
                          label: const Text(
                            'Import from Messages',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Recent Transactions',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (recentTransactions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161626),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('No transactions for today yet.',
                              style: TextStyle(color: Colors.grey)),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161626),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: LimitedBox(
                            maxHeight: 400,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: recentTransactions.length > 5
                                  ? const AlwaysScrollableScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              itemCount: recentTransactions.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                height: 1,
                                color: Color(0xFF2A2A3F),
                              ),
                              itemBuilder: (context, index) =>
                                  _buildTransactionTile(
                                      recentTransactions[index]),
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
                            const Text('DAILY TOTAL SUMMARY',
                                style: TextStyle(
                                    color: Colors.grey, letterSpacing: 1.6)),
                            const SizedBox(height: 16),
                            Text(
                              signAmount(
                                  totalIncome - totalExpense - totalInvestment),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: totalIncome -
                                            totalExpense -
                                            totalInvestment <
                                        0
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (holdings.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(
                                  'Current investment value: ${formatAmount(holdingsCurrentValue)}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: _summaryStat(
                                      'Income',
                                      formatAmount(totalIncome),
                                      Colors.greenAccent),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _summaryStat(
                                      'Expense',
                                      formatAmount(totalExpense),
                                      Colors.redAccent),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _summaryStat(
                                      'Invest',
                                      formatAmount(totalInvestment),
                                      Colors.lightBlueAccent),
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
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildActionCard(
      BuildContext context, IconData icon, String label, String? route) {
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
    final parentCategory =
        categoryParts.isNotEmpty ? categoryParts[0] : 'Unknown';
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
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      if (subCategory.isNotEmpty)
                        RunningText(
                          subCategory,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      else
                        RunningText(
                          '${transaction.date.toLocal().hour}:${transaction.date.toLocal().minute.toString().padLeft(2, '0')}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: '',
                color: const Color(0xFF1B1B2E),
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white70, size: 20),
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
          const SnackBar(
              content: Text('Linked investment record was not found.')),
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
      final investmentIndex = investmentBox.values
          .toList()
          .indexWhere((item) => item.id == transaction.id);
      if (investmentIndex != -1) {
        await investmentBox.deleteAt(investmentIndex);
      }
    }
    await transaction.delete();
    await BackupSyncService.instance.backupIfEnabled();
  }

  IconData _getCategoryIcon(String category) {
    // Investment categories (check first as they have prefixes)
    if (category.contains('Stocks Investment')) return Icons.show_chart_rounded;
    if (category.contains('Gold Investment')) return Icons.workspace_premium_rounded;
    if (category.contains('Other Investment')) return Icons.trending_up_rounded;

    // Expense categories
    if (category == 'Home') return Icons.home_rounded;
    if (category == 'Food') return Icons.restaurant;
    if (category == 'Transport') return Icons.directions_bus_rounded;
    if (category == 'Vehicle') return Icons.directions_car_filled_rounded;
    if (category == 'Personal & Shopping')
      return Icons.shopping_bag_rounded;
    if (category == 'Bills & Subscriptions') return Icons.receipt_long_rounded;
    if (category == 'Medical') return Icons.local_hospital_rounded;
    if (category == 'Education') return Icons.school_rounded;
    if (category == 'Entertainment') return Icons.movie_rounded;
    if (category == 'Family') return Icons.family_restroom_rounded;
    if (category == 'Debt') return Icons.account_balance_wallet_rounded;
    if (category == 'Others') return Icons.more_horiz_rounded;

    // Income categories
    if (category == 'Salary') return Icons.account_balance_wallet_rounded;
    if (category == 'Freelance') return Icons.laptop_chromebook_rounded;
    if (category == 'Investment') return Icons.trending_up_rounded;
    if (category == 'Bonus') return Icons.card_giftcard_rounded;
    if (category == 'Other') return Icons.widgets_rounded;

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
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                color: valueColor, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
