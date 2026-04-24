import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../utils/backup_sync_service.dart';
import '../widgets/running_text.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _category = 'Salary';
  DateTime _date = DateTime.now();

  final List<_IncomeCategory> _categories = const [
    _IncomeCategory('Salary', Icons.account_balance_wallet_rounded),
    _IncomeCategory('Freelance', Icons.laptop_chromebook_rounded),
    _IncomeCategory('Investment', Icons.trending_up_rounded),
    _IncomeCategory('Bonus', Icons.card_giftcard_rounded),
    _IncomeCategory('Other', Icons.widgets_rounded),
  ];

  double get _amountValue => double.tryParse(_amountController.text) ?? 0;

  bool get _canSave => _amountValue > 0;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCurrency = AppSettings.getCurrency();
    final currencySymbol = AppSettings.currencySymbol(activeCurrency);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1124),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 28),
                    _buildAmountSection(currencySymbol),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Select Category'),
                    const SizedBox(height: 12),
                    _buildCategorySelector(),
                    const SizedBox(height: 20),
                    _buildDateCard(),
                    const SizedBox(height: 16),
                    _buildNotesCard(),
                    const SizedBox(height: 18),
                    _buildSecurityBanner(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Add Income',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection(String currencySymbol) {
    return Column(
      children: [
        const Center(
          child: Text(
            'AMOUNT',
            style: TextStyle(
              color: Color(0xFF8FD8A6),
              fontSize: 18,
              letterSpacing: 3.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 112,
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  currencySymbol,
                  style: const TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      color: Color(0xFF474747),
                      fontSize: 62,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: const Color(0xFF474747).withValues(alpha: 0.22),
                        fontSize: 62,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.58),
        fontSize: 13,
        letterSpacing: 2.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category.label == _category;

          return GestureDetector(
            onTap: () => setState(() => _category = category.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 124,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4ADE80) : const Color(0xFF161626),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: isSelected ? 0.12 : 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(category.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        category.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateCard() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2E),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _buildLeadingIconTile(Icons.calendar_month_rounded),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Date'),
                  const SizedBox(height: 6),
                  RunningText(
                    _formattedDateLabel(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeadingIconTile(Icons.edit_note_rounded),
              const SizedBox(width: 18),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _buildSectionLabel('Notes (Optional)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Where did this income come from?',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.20),
                fontSize: 16,
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      width: double.infinity,
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D1124),
            Color(0xFF1B1B2E),
            Color(0xFF0D1124),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              left: -18,
              top: 0,
              bottom: 0,
              child: Transform.rotate(
                angle: -0.65,
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.00),
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.00),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 44,
              top: -20,
              child: Transform.rotate(
                angle: 0.72,
                child: Container(
                  width: 140,
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.00),
                        Colors.white.withValues(alpha: 0.26),
                        Colors.white.withValues(alpha: 0.00),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.70),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF4ADE80), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RunningText(
                    'Income Record Encryption Active',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: ElevatedButton(
        onPressed: _canSave ? _saveIncome : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4ADE80),
          disabledBackgroundColor: const Color(0xFF5C5C68),
          foregroundColor: Colors.black,
          disabledForegroundColor: Colors.white54,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Save Income',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIconTile(IconData icon) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: const Color(0xFF4ADE80), size: 24),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8FD8A6),
              surface: Color(0xFF1E1E1E),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1A1A1A)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  String _formattedDateLabel() {
    final now = DateTime.now();
    final isToday = now.year == _date.year && now.month == _date.month && now.day == _date.day;
    final suffix = DateFormat('d MMM').format(_date);
    if (isToday) {
      return 'Today, $suffix';
    }
    return '${DateFormat('EEE').format(_date)}, $suffix';
  }

  Future<void> _saveIncome() async {
    final amount = _amountValue;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }

    final transaction = Transaction(
      id: DateTime.now().toIso8601String(),
      amount: amount,
      category: _category,
      date: _date,
      type: 'income',
      notes: _notesController.text.trim(),
    );

    await Hive.box<Transaction>('transactions').add(transaction);
    await BackupSyncService.instance.backupIfEnabled();

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }
}

class _IncomeCategory {
  final String label;
  final IconData icon;

  const _IncomeCategory(this.label, this.icon);
}
