import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../utils/backup_sync_service.dart';
import '../widgets/running_text.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.transaction});

  final Transaction? transaction;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customSubCategoryController = TextEditingController();

  String _category = 'Food';
  String _subCategory = 'Groceries';
  DateTime _date = DateTime.now();

  final List<_ExpenseCategory> _categories = const [
    _ExpenseCategory('Housing', Icons.home_rounded),
    _ExpenseCategory('Utilities & Bills', Icons.receipt_long_rounded),
    _ExpenseCategory('Food', Icons.restaurant),
    _ExpenseCategory('Transportation', Icons.directions_car_filled_rounded),
    _ExpenseCategory('Healthcare', Icons.local_hospital_rounded),
    _ExpenseCategory('Debt & Financial', Icons.account_balance_wallet_rounded),
    _ExpenseCategory('Personal & Lifestyle', Icons.self_improvement_rounded),
    _ExpenseCategory('Entertainment', Icons.movie_rounded),
    _ExpenseCategory('Subscriptions & Services', Icons.subscriptions_rounded),
    _ExpenseCategory('Family & Education', Icons.school_rounded),
    _ExpenseCategory('Pets', Icons.pets_rounded),
    _ExpenseCategory('Travel', Icons.flight_takeoff_rounded),
    _ExpenseCategory('Giving & Obligations', Icons.volunteer_activism_rounded),
    _ExpenseCategory('Work-related', Icons.work_rounded),
    _ExpenseCategory('Others', Icons.more_horiz_rounded),
  ];

  final Map<String, List<String>> _subCategoriesByCategory = const {
    'Housing': [
      'Rent / Mortgage',
      'Property taxes',
      'Home maintenance & repairs',
      'Furniture & decor',
      'Other',
    ],
    'Utilities & Bills': [
      'Electricity',
      'Water',
      'Gas',
      'Internet',
      'Phone',
      'TV / Cable',
      'Other',
    ],
    'Food': [
      'Groceries',
      'Dining out / Takeout',
      'Coffee & snacks',
      'Other',
    ],
    'Transportation': [
      'Fuel',
      'Public transport',
      'Car payment',
      'Car maintenance & repairs',
      'Car insurance',
      'Parking & tolls',
      'Vehicle registration & inspections',
      'Other',
    ],
    'Healthcare': [
      'Health insurance',
      'Doctor visits',
      'Medication',
      'Dental care',
      'Vision care',
      'Pharmacy items',
      'Other',
    ],
    'Debt & Financial': [
      'Credit card payments',
      'Personal loans',
      'Bank fees',
      'Late fees / penalties',
      'Other',
    ],
    'Personal & Lifestyle': [
      'Clothing & shoes',
      'Laundry & dry cleaning',
      'Personal care',
      'Fitness',
      'Hobbies & sports',
      'Other',
    ],
    'Entertainment': [
      'Movies',
      'Concerts & events',
      'Games',
      'Other',
    ],
    'Subscriptions & Services': [
      'Streaming services',
      'Apps & software',
      'Memberships',
      'Other',
    ],
    'Family & Education': [
      'Childcare / babysitting',
      'School supplies',
      'Tuition / courses',
      'Books',
      'Other',
    ],
    'Pets': [
      'Pet food',
      'Vet visits',
      'Grooming',
      'Pet insurance',
      'Other',
    ],
    'Travel': [
      'Flights / transport',
      'Accommodation',
      'Activities',
      'Travel gear',
      'Other',
    ],
    'Giving & Obligations': [
      'Gifts',
      'Donations / charity',
      'Taxes',
      'Legal / professional fees',
      'Other',
    ],
    'Work-related': [
      'Work supplies',
      'Uniforms',
      'Extra commuting costs',
      'Other',
    ],
    'Others': [],
  };

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _populateForEdit();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _customSubCategoryController.dispose();
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amountController.text) ?? 0;

  bool get _isCustomSubCategory => _category == 'Others';

  bool get _canSave => _amountValue > 0 && (!_isCustomSubCategory || _customSubCategoryController.text.trim().isNotEmpty);

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
                    const SizedBox(height: 18),
                    _buildSectionLabel('Select Subtype'),
                    const SizedBox(height: 12),
                    _buildSubCategorySelector(),
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
        Expanded(
          child: Text(
            _isEditing ? 'Edit Expense' : 'Add Expense',
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
              color: Color(0xFF8790FF),
              fontSize: 18,
              letterSpacing: 3.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 126,
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  currencySymbol,
                  style: const TextStyle(
                    color: Color(0xFF7A85FF),
                    fontSize: 40,
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
                      color: Color(0xFF2E2E2E),
                      fontSize: 72,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: const Color(0xFF2E2E2E).withValues(alpha: 0.22),
                        fontSize: 72,
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
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category.label == _category;

          return GestureDetector(
            onTap: () {
              setState(() {
                _category = category.label;
                _subCategory = _availableSubCategories.isNotEmpty ? _availableSubCategories.first : '';
                if (!_isCustomSubCategory) {
                  _customSubCategoryController.clear();
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 124,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF7A85FF) : const Color(0xFF161626),
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
                    child: Icon(
                      category.icon,
                      color: Colors.white,
                      size: 26,
                    ),
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
                          color: Colors.white.withValues(alpha: isSelected ? 1 : 0.78),
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
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemCount: _categories.length,
      ),
    );
  }

  Widget _buildSubCategorySelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161626),
        borderRadius: BorderRadius.circular(22),
      ),
      child: _isCustomSubCategory
          ? TextField(
              controller: _customSubCategoryController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Enter sub category',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.edit_outlined, color: Color(0xFF7A85FF)),
              ),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableSubCategories.map((subCategory) {
                final isSelected = subCategory == _subCategory;
                return GestureDetector(
                  onTap: () => setState(() => _subCategory = subCategory),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF7A85FF) : const Color(0xFF1B1B2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF7A85FF) : Colors.white10,
                      ),
                    ),
                    child: RunningText(
                      subCategory,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: isSelected ? 1 : 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
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
          color: const Color(0xFF1E1E1E),
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
              hintText: 'What was this for?',
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
                        Colors.white.withValues(alpha: 0.28),
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
                        Colors.white.withValues(alpha: 0.35),
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
                      Colors.black.withValues(alpha: 0.72),
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
                  const Icon(Icons.shield_rounded, color: Color(0xFF7A85FF), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RunningText(
                    'Secure Vault Encryption Active',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
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
        onPressed: _canSave ? _saveExpense : null,
        style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7A85FF),
        disabledBackgroundColor: const Color(0xFF5C5C68),
        foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white54,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isEditing ? 'Update Expense' : 'Save Expense',
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
      child: Icon(icon, color: const Color(0xFF7A85FF), size: 24),
    );
  }

  List<String> get _availableSubCategories =>
      _subCategoriesByCategory[_category] ?? const ['Other'];

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
              primary: Color(0xFF8790FF),
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

  Future<void> _saveExpense() async {
    final amount = _amountValue;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }

    final resolvedSubCategory = _isCustomSubCategory ? _customSubCategoryController.text.trim() : _subCategory;
    if (resolvedSubCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a sub category before saving.')),
      );
      return;
    }

    final notes = _notesController.text.trim();

    if (_isEditing) {
      final transaction = widget.transaction!;
      transaction
        ..amount = amount
        ..category = '$_category - $resolvedSubCategory'
        ..date = _date
        ..type = 'expense'
        ..notes = notes;
      await transaction.save();
    } else {
      final transaction = Transaction(
        id: DateTime.now().toIso8601String(),
        amount: amount,
        category: '$_category - $resolvedSubCategory',
        date: _date,
        type: 'expense',
        notes: notes,
      );
      await Hive.box<Transaction>('transactions').add(transaction);
    }
    await BackupSyncService.instance.backupIfEnabled();

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  void _populateForEdit() {
    final transaction = widget.transaction;
    if (transaction == null) {
      return;
    }

    _amountController.text = transaction.amount.toStringAsFixed(2);
    _notesController.text = transaction.notes;
    _date = transaction.date;

    final parts = transaction.category.split(' - ');
    final category = parts.isNotEmpty ? parts.first : 'Food';
    final subCategory = parts.length > 1 ? parts.sublist(1).join(' - ') : 'Groceries';

    _category = _categories.any((item) => item.label == category) ? category : 'Others';
    if (_category == 'Others') {
      _customSubCategoryController.text = subCategory;
      _subCategory = '';
    } else {
      final available = _subCategoriesByCategory[_category] ?? const <String>[];
      _subCategory = available.contains(subCategory) ? subCategory : (available.isNotEmpty ? available.first : '');
      if (!available.contains(subCategory) && subCategory.isNotEmpty) {
        _category = 'Others';
        _customSubCategoryController.text = subCategory;
        _subCategory = '';
      }
    }
  }
}

class _ExpenseCategory {
  final String label;
  final IconData icon;

  const _ExpenseCategory(this.label, this.icon);
}
