import 'dart:convert';
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
            final monthlyIncome = currentMonthTransactions
                .where((t) => t.type == 'income')
                .fold(0.0, (sum, t) => sum + t.amount);
            final monthlyInvestment = currentMonthTransactions
                .where((t) => t.type == 'investment')
                .fold(0.0, (sum, t) => sum + t.amount);
            final monthlyInHand =
                monthlyIncome - monthlyExpense - monthlyInvestment;
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
            final todayExpense = recentTransactions
                .where((t) => t.type == 'expense')
                .fold(0.0, (sum, t) => sum + t.amount);
            final todayIncome = recentTransactions
                .where((t) => t.type == 'income')
                .fold(0.0, (sum, t) => sum + t.amount);
            final todayInvestment = recentTransactions
                .where((t) => t.type == 'investment')
                .fold(0.0, (sum, t) => sum + t.amount);
            final todayNet = todayIncome - todayExpense - todayInvestment;
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
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1A223A),
                              const Color(0xFF121A2F),
                              todayNet >= 0 ? const Color(0xFF132B25) : const Color(0xFF311A23),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (todayNet >= 0 ? Colors.greenAccent : Colors.redAccent)
                                  .withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    "Today's Summary",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _statusPill(
                                  label: recentTransactions.isEmpty
                                      ? 'No activity'
                                      : pendingDays <= 0
                                          ? 'Updated today'
                                          : '$pendingDays day${pendingDays == 1 ? '' : 's'} pending',
                                  color: recentTransactions.isEmpty
                                      ? Colors.blueGrey
                                      : pendingDays <= 0
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              recentTransactions.isEmpty
                                  ? 'No transactions recorded yet for today.'
                                  : 'Your live snapshot for ${DateFormat('dd MMM').format(now)}.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              signAmount(todayNet),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: todayNet >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Net today',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _todayMiniStat(
                                    'Expense',
                                    formatAmount(todayExpense),
                                    const Color(0xFFEF4444),
                                    Icons.receipt_long_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _todayMiniStat(
                                    'Entries',
                                    recentTransactions.length.toString(),
                                    const Color(0xFF38BDF8),
                                    Icons.format_list_bulleted_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _todayMiniStat(
                                    'Pending',
                                    pendingDays <= 0 ? 'None' : pendingLabel,
                                    const Color(0xFFF59E0B),
                                    Icons.schedule_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  recentTransactions.isEmpty ? '/add-expense' : '/add-income',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7A85FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: Icon(
                                  recentTransactions.isEmpty ? Icons.add_card_rounded : Icons.add_rounded,
                                ),
                                label: Text(
                                  recentTransactions.isEmpty ? 'Add today\'s first entry' : 'Add another entry',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildQuickActionsRow(context),
                      const SizedBox(height: 16),
                      _buildToolsCard(context),
                      const SizedBox(height: 24),
                      _buildMonthlyOverviewCard(
                        income: monthlyIncome,
                        invested: monthlyInvestment,
                        inHand: monthlyInHand,
                        formatAmount: formatAmount,
                      ),
                      const SizedBox(height: 24),
                      const Text('Today\'s Transactions',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildRecentTransactionsSection(recentTransactions),
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
      BuildContext context,
      IconData icon,
      String label,
      String? route,
      Color accent,
    ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: route == null ? null : () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 108,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.95),
                accent.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.26),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            Icons.remove_circle_outline_rounded,
            'Add Expense',
            '/add-expense',
            const Color(0xFFE35D5B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context,
            Icons.add_card_rounded,
            'Add Income',
            '/add-income',
            const Color(0xFF1FA971),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context,
            Icons.trending_up_rounded,
            'Add Investment',
            '/add-investment',
            const Color(0xFF3E7BFA),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161626),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3F),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sms_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tools',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Import transactions from your messages when you need a quick bulk update.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context,
                '/extract-sms',
              );
              if (result == true) {
                setState(() {});
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF7A85FF).withValues(alpha: 0.14),
              foregroundColor: const Color(0xFFB7BEFF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Import SMS',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyOverviewCard({
    required double income,
    required double invested,
    required double inHand,
    required String Function(double value) formatAmount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161626),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Month',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Track your monthly income, invested amount, and in-hand balance.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _todayMiniStat(
                  'Income',
                  formatAmount(income),
                  const Color(0xFF10B981),
                  Icons.add_card_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _todayMiniStat(
                  'Invested',
                  formatAmount(invested),
                  const Color(0xFF3B82F6),
                  Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _todayMiniStat(
                  'In Hand',
                  formatAmount(inHand),
                  inHand >= 0
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFEF4444),
                  Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection(List<Transaction> recentTransactions) {
    if (recentTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161626),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No transactions for today yet.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
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
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            color: Color(0xFF2A2A3F),
          ),
          itemBuilder: (context, index) =>
              _buildTransactionTile(recentTransactions[index]),
        ),
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _todayMiniStat(String label, String value, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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

}
