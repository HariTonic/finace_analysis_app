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
import '../widgets/scroll_shadow_wrapper.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.onNavigateHome});

  final VoidCallback? onNavigateHome;

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const int _recordsPerBatch = 50;
  
  String _filterType = 'all'; // all, income, expense, investment
  DateTime? _filterDate;
  late ScrollController _scrollController;
  bool _showScrollToTopButton = false;
  bool _selectionMode = false;
  final Set<String> _selectedTransactionIds = <String>{};
  
  List<Transaction> _displayedTransactions = [];
  List<Transaction> _allFilteredTransactions = [];
  int _currentBatchIndex = 0;
  bool _isLoadingMore = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShowTopButton = _scrollController.hasClients &&
        _scrollController.offset > 260;
    if (shouldShowTopButton != _showScrollToTopButton) {
      setState(() {
        _showScrollToTopButton = shouldShowTopButton;
      });
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreRecords();
    }
  }

  void _loadMoreRecords() {
    if (_isLoadingMore) return;
    
    final nextIndex = _currentBatchIndex + 1;
    final startIdx = nextIndex * _recordsPerBatch;
    
    // Only load if there are more records to fetch
    if (startIdx >= _allFilteredTransactions.length) {
      return; // No more records to load
    }
    
    setState(() {
      _isLoadingMore = true;
      _currentBatchIndex = nextIndex;
      final endIdx = (startIdx + _recordsPerBatch)
          .clamp(0, _allFilteredTransactions.length);
      _displayedTransactions.addAll(
        _allFilteredTransactions.sublist(startIdx, endIdx),
      );
      _isLoadingMore = false;
    });
  }

  void _resetAndLoadInitial(List<Transaction> transactions) {
    _allFilteredTransactions = transactions;
    _displayedTransactions = transactions
        .take(_recordsPerBatch)
        .toList();
    _currentBatchIndex = 0;
    _hasInitialized = true;
    final filteredIds = transactions.map((transaction) => transaction.id).toSet();
    _selectedTransactionIds.removeWhere((id) => !filteredIds.contains(id));
    if (_selectedTransactionIds.isEmpty) {
      _selectionMode = false;
    }
  }

  void _enterSelectionMode(Transaction transaction) {
    setState(() {
      _selectionMode = true;
      _selectedTransactionIds.add(transaction.id);
    });
  }

  void _toggleTransactionSelection(Transaction transaction) {
    setState(() {
      if (_selectedTransactionIds.contains(transaction.id)) {
        _selectedTransactionIds.remove(transaction.id);
      } else {
        _selectedTransactionIds.add(transaction.id);
      }
      if (_selectedTransactionIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _cancelSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedTransactionIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedTransactionIds.length == _allFilteredTransactions.length) {
        _selectedTransactionIds.clear();
        _selectionMode = false;
      } else {
        _selectionMode = true;
        _selectedTransactionIds
          ..clear()
          ..addAll(_allFilteredTransactions.map((transaction) => transaction.id));
      }
    });
  }

  Future<void> _deleteSelectedTransactions() async {
    if (_selectedTransactionIds.isEmpty) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        final count = _selectedTransactionIds.length;
        return AlertDialog(
          backgroundColor: const Color(0xFF161626),
          title: const Text(
            'Delete selected records?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'This will delete $count selected transaction${count == 1 ? '' : 's'}.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final transactionBox = Hive.box<Transaction>('transactions');
    final selectedTransactions = transactionBox.values
        .where((transaction) => _selectedTransactionIds.contains(transaction.id))
        .toList();

    for (final transaction in selectedTransactions) {
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
    }

    await BackupSyncService.instance.backupIfEnabled();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectionMode = false;
      _selectedTransactionIds.clear();
      _currentBatchIndex = 0;
      _displayedTransactions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1124),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
                            onPressed: _selectionMode
                                ? _cancelSelectionMode
                                : () {
                                    if (widget.onNavigateHome != null) {
                                      widget.onNavigateHome!.call();
                                      return;
                                    }
                                    Navigator.maybePop(context);
                                  },
                            icon: Icon(
                              _selectionMode
                                  ? Icons.close_rounded
                                  : Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectionMode
                                  ? '${_selectedTransactionIds.length} selected'
                                  : 'All Transactions',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_selectionMode) ...[
                            Checkbox(
                              value: _allFilteredTransactions.isNotEmpty &&
                                  _selectedTransactionIds.length ==
                                      _allFilteredTransactions.length,
                              tristate: true,
                              fillColor: WidgetStateProperty.resolveWith(
                                (_) => const Color(0xFF7A85FF),
                              ),
                              checkColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              onChanged: (_) => _toggleSelectAll(),
                            ),
                            IconButton(
                              onPressed: _selectedTransactionIds.isEmpty
                                  ? null
                                  : _deleteSelectedTransactions,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: _selectedTransactionIds.isEmpty
                                    ? Colors.white38
                                    : const Color(0xFFFF8A80),
                              ),
                              tooltip: 'Delete selected',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_selectionMode)
                        Row(
                          children: [
                            Text(
                              'Select all',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedTransactionIds.length}/${_allFilteredTransactions.length}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.56),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else
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
                                      _currentBatchIndex = 0;
                                      _displayedTransactions = [];
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
                                      _currentBatchIndex = 0;
                                      _displayedTransactions = [];
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
                                onPressed: () => setState(() {
                                  _filterDate = null;
                                  _currentBatchIndex = 0;
                                  _displayedTransactions = [];
                                }),
                                icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
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
                      
                      transactions.sort((a, b) => b.date.compareTo(a.date));
                      
                      if (!_hasInitialized || 
                          _allFilteredTransactions.length != transactions.length ||
                          (_allFilteredTransactions.isNotEmpty && transactions.isNotEmpty && 
                           _allFilteredTransactions.first.id != transactions.first.id)) {
                        _resetAndLoadInitial(transactions);
                      }
                      
                      final activeCurrency = AppSettings.getCurrency();

                      if (_displayedTransactions.isEmpty) {
                        return Center(
                          child: Text(
                            'No transactions found',
                            style: TextStyle(color: Colors.grey.withValues(alpha: 0.7), fontSize: 16),
                          ),
                        );
                      }

                      final hasMoreRecords = (_currentBatchIndex + 1) * _recordsPerBatch < _allFilteredTransactions.length;

                      return ScrollShadowWrapper(
                        showScrollToTopButton: false,
                        externalController: _scrollController,
                        builder: (controller) => Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161626),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Scrollbar(
                            controller: controller,
                            thickness: 4,
                            radius: const Radius.circular(2),
                            child: ListView.separated(
                              controller: controller,
                              padding: const EdgeInsets.only(bottom: 84),
                              shrinkWrap: false,
                              itemCount: _displayedTransactions.length + (hasMoreRecords && _isLoadingMore ? 1 : 0),
                              separatorBuilder: (context, index) => const Divider(
                                height: 1,
                                color: Color(0xFF2A2A3F),
                                indent: 16,
                                endIndent: 16,
                              ),
                              itemBuilder: (context, index) {
                                if (index == _displayedTransactions.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.grey[600]!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final transaction = _displayedTransactions[index];
                                return _buildTransactionTile(transaction, activeCurrency);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_showScrollToTopButton)
              Positioned(
                right: 24,
                bottom: 24,
                child: ElevatedButton(
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D6CFF),
                    elevation: 8,
                    shadowColor: Colors.black45,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.arrow_upward, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Top',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
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
    
    final isSelected = _selectedTransactionIds.contains(transaction.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: () => _enterSelectionMode(transaction),
        onTap: _selectionMode ? () => _toggleTransactionSelection(transaction) : null,
        child: Container(
          color: isSelected
              ? const Color(0xFF7A85FF).withValues(alpha: 0.12)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_selectionMode) ...[
                Checkbox(
                  value: isSelected,
                  fillColor: WidgetStateProperty.resolveWith(
                    (_) => const Color(0xFF7A85FF),
                  ),
                  checkColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  onChanged: (_) => _toggleTransactionSelection(transaction),
                ),
                const SizedBox(width: 4),
              ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
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
                  if (!_selectionMode)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: '',
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
        ),
      ),
    );
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
    if (category == 'Personal & Shopping') {
      return Icons.shopping_bag_rounded;
    }
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
