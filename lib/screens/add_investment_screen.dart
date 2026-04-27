import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/investment_holding.dart';
import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../utils/backup_sync_service.dart';

class AddInvestmentScreen extends StatefulWidget {
  const AddInvestmentScreen({super.key, this.transaction, this.holding});

  final Transaction? transaction;
  final InvestmentHolding? holding;

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final TextEditingController _stockNameController = TextEditingController();
  final TextEditingController _otherNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyPriceController = TextEditingController();
  final TextEditingController _currentPriceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  _InvestmentType _selectedType = _InvestmentType.stocks;
  DateTime _purchaseDate = DateTime.now();

  @override
  void dispose() {
    _stockNameController.dispose();
    _otherNameController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    _currentPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityController.text) ?? 0;
  double get _buyPrice => double.tryParse(_buyPriceController.text) ?? 0;
  double get _currentPrice =>
      double.tryParse(_currentPriceController.text) ?? _buyPrice;
  double get _investedAmount => _quantity * _buyPrice;
  double get _currentValue => _quantity * _currentPrice;
  double get _profitLoss => _currentValue - _investedAmount;

  bool get _canSave {
    if (_quantity <= 0 || _buyPrice <= 0) {
      return false;
    }
    return switch (_selectedType) {
      _InvestmentType.stocks => _stockNameController.text.trim().isNotEmpty,
      _InvestmentType.gold => true,
      _InvestmentType.other => _otherNameController.text.trim().isNotEmpty,
    };
  }

  bool get _isEditing => widget.transaction != null && widget.holding != null;

  @override
  void initState() {
    super.initState();
    _populateForEdit();
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode = AppSettings.getCurrency();
    String formatter(double value) =>
        AppSettings.formatCurrency(value, currencyCode);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1124),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Investment' : 'Track Investments'),
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable:
              Hive.box<InvestmentHolding>('investments').listenable(),
          builder: (context, Box<InvestmentHolding> box, _) {
            final holdings = box.values.toList()
              ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

            final totalInvested = holdings.fold<double>(
                0, (sum, item) => sum + item.investedAmount);
            final totalCurrent = holdings.fold<double>(
                0, (sum, item) => sum + item.currentValue);
            final totalPnL = totalCurrent - totalInvested;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildHero(formatter, totalInvested, totalCurrent, totalPnL),
                const SizedBox(height: 16),
                _buildTypeSelector(),
                const SizedBox(height: 16),
                _buildEntryCard(currencyCode, formatter),
                const SizedBox(height: 16),
                _buildHoldingsCard(holdings, formatter),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(
    String Function(double) formatter,
    double totalInvested,
    double totalCurrent,
    double totalPnL,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF10213E),
            Color(0xFF163563),
            Color(0xFF0E7490),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Investment Vault',
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track Stocks, Gold, and Other investments with invested amount, current value, and profit or loss.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(label: 'Invested', value: formatter(totalInvested)),
              _HeroMetric(
                  label: 'Current Value', value: formatter(totalCurrent)),
              _HeroMetric(
                label: 'P / L',
                value: '${totalPnL >= 0 ? '+' : ''}${formatter(totalPnL)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<_InvestmentType>(
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFF1D4ED8)
              : const Color(0xFF121A30);
        }),
        foregroundColor: WidgetStateProperty.all(Colors.white),
      ),
      segments: const [
        ButtonSegment(
          value: _InvestmentType.stocks,
          label: Text('Stocks'),
          icon: Icon(Icons.show_chart_rounded),
        ),
        ButtonSegment(
          value: _InvestmentType.gold,
          label: Text('Gold'),
          icon: Icon(Icons.workspace_premium_rounded),
        ),
        ButtonSegment(
          value: _InvestmentType.other,
          label: Text('Other'),
          icon: Icon(Icons.widgets_rounded),
        ),
      ],
      selected: <_InvestmentType>{_selectedType},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }

        setState(() {
          _selectedType = selection.first;
          if (_selectedType != _InvestmentType.stocks) {
            _stockNameController.clear();
          }
          if (_selectedType != _InvestmentType.other) {
            _otherNameController.clear();
          }
        });
      },
    );
  }

  Widget _buildEntryCard(
      String currencyCode, String Function(double) formatter) {
    final unitHint = switch (_selectedType) {
      _InvestmentType.stocks => 'Number of stocks',
      _InvestmentType.gold => 'Gold in grams',
      _InvestmentType.other => 'Units / quantity',
    };
    final buyHint = switch (_selectedType) {
      _InvestmentType.stocks => 'Cost per stock',
      _InvestmentType.gold => 'Cost per gram',
      _InvestmentType.other => 'Cost per unit',
    };
    final currentHint = switch (_selectedType) {
      _InvestmentType.stocks => 'Current price per stock',
      _InvestmentType.gold => 'Current price per gram',
      _InvestmentType.other => 'Current price per unit',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121A30),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Holding',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedType == _InvestmentType.stocks
                ? 'Enter the stock name and track your investments.'
                : _selectedType == _InvestmentType.gold
                    ? 'Track your gold grams with buy price and current price per gram.'
                    : 'Track any other investment with quantity and current unit value.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (_selectedType == _InvestmentType.stocks) _buildStockNameField(),
          if (_selectedType == _InvestmentType.other) _buildOtherNameField(),
          if (_selectedType != _InvestmentType.gold) const SizedBox(height: 14),
          _buildNumberField(
            controller: _quantityController,
            label: unitHint,
            prefixIcon: _selectedType == _InvestmentType.gold
                ? Icons.scale_rounded
                : Icons.confirmation_number_rounded,
          ),
          const SizedBox(height: 14),
          _buildNumberField(
            controller: _buyPriceController,
            label: buyHint,
            prefixIcon: Icons.payments_outlined,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: 14),
          _buildNumberField(
            controller: _currentPriceController,
            label: currentHint,
            prefixIcon: Icons.trending_up_rounded,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: 14),
          _buildDateField(),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1528),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryChip(
                    label: 'Invested', value: formatter(_investedAmount)),
                _SummaryChip(label: 'Current', value: formatter(_currentValue)),
                _SummaryChip(
                    label: 'P / L',
                    value:
                        '${_profitLoss >= 0 ? '+' : ''}${formatter(_profitLoss)}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canSave ? _saveHolding : null,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Update Investment' : 'Save Investment'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockNameField() {
    return TextField(
      controller: _stockNameController,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Stock name',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildOtherNameField() {
    return TextField(
      controller: _otherNameController,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Investment name',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    String? currencyCode,
  }) {
    final prefixText = currencyCode == null
        ? null
        : '${AppSettings.currencySymbol(currencyCode)} ';
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
      ],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon),
        prefixText: prefixText,
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickPurchaseDate,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Purchase date',
          prefixIcon: Icon(Icons.calendar_month_rounded),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(_purchaseDate),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHoldingsCard(
      List<InvestmentHolding> holdings, String Function(double) formatter) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121A30),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tracked Holdings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your manual current prices update the current value and profit/loss in real time.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (holdings.isEmpty)
            const _EmptyHoldingsState()
          else
            ...holdings.map((holding) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HoldingTile(
                    holding: holding,
                    formatter: formatter,
                    onDelete: () => _deleteHolding(holding),
                    onUpdatePrice: () => _showPriceUpdateDialog(holding),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _saveHolding() async {
    final currentUnitPrice =
        _currentPriceController.text.trim().isEmpty ? _buyPrice : _currentPrice;
    final name = switch (_selectedType) {
      _InvestmentType.stocks => _stockNameController.text.trim(),
      _InvestmentType.gold => 'Gold',
      _InvestmentType.other => _otherNameController.text.trim(),
    };
    final symbol = '';
    final exchange = '';
    final unitLabel = switch (_selectedType) {
      _InvestmentType.stocks => 'stocks',
      _InvestmentType.gold => 'grams',
      _InvestmentType.other => 'units',
    };

    final id =
        _isEditing ? widget.holding!.id : DateTime.now().toIso8601String();
    final notes = _notesController.text.trim();
    final holding = InvestmentHolding(
      id: id,
      type: _selectedType.name,
      name: name,
      quantity: _quantity,
      buyUnitPrice: _buyPrice,
      currentUnitPrice: currentUnitPrice,
      unitLabel: unitLabel,
      purchaseDate: _purchaseDate,
      notes: notes,
      symbol: symbol,
      exchange: exchange,
    );

    final investmentBox = Hive.box<InvestmentHolding>('investments');
    final transactionBox = Hive.box<Transaction>('transactions');

    if (_isEditing) {
      final existingHoldingIndex =
          investmentBox.values.toList().indexWhere((item) => item.id == id);
      if (existingHoldingIndex != -1) {
        await investmentBox.putAt(existingHoldingIndex, holding);
      }

      final transaction = widget.transaction!
        ..amount = holding.investedAmount
        ..category = '${_selectedType.label} - $name'
        ..date = _purchaseDate
        ..type = 'investment'
        ..notes = notes;
      await transaction.save();
    } else {
      await investmentBox.add(holding);

      final transaction = Transaction(
        id: id,
        amount: holding.investedAmount,
        category: '${_selectedType.label} - $name',
        date: _purchaseDate,
        type: 'investment',
        notes: notes,
      );
      await transactionBox.add(transaction);
    }
    await BackupSyncService.instance.backupIfEnabled();

    if (!mounted) {
      return;
    }

    if (_isEditing) {
      Navigator.pop(context);
      return;
    }

    _resetForm();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Investment saved successfully.')),
    );
  }

  void _resetForm() {
    setState(() {
      _stockNameController.clear();
      _otherNameController.clear();
      _quantityController.clear();
      _buyPriceController.clear();
      _currentPriceController.clear();
      _notesController.clear();
      _purchaseDate = DateTime.now();
    });
  }

  Future<void> _deleteHolding(InvestmentHolding holding) async {
    final box = Hive.box<InvestmentHolding>('investments');
    final transactionBox = Hive.box<Transaction>('transactions');
    final holdingKey =
        box.values.toList().indexWhere((item) => item.id == holding.id);
    if (holdingKey != -1) {
      await box.deleteAt(holdingKey);
    }

    final transactionKey = transactionBox.values
        .toList()
        .indexWhere((item) => item.id == holding.id);
    if (transactionKey != -1) {
      await transactionBox.deleteAt(transactionKey);
    }

    await BackupSyncService.instance.backupIfEnabled();
  }

  Future<void> _showPriceUpdateDialog(InvestmentHolding holding) async {
    final controller = TextEditingController(
        text: holding.currentUnitPrice.toStringAsFixed(2));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10182E),
          title: const Text('Update Current Price'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
            ],
            decoration: InputDecoration(
              labelText:
                  'Current price per ${holding.unitLabel == 'grams' ? 'gram' : 'unit'}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      return;
    }

    final value = double.tryParse(controller.text);
    if (value == null || value <= 0) {
      return;
    }

    final box = Hive.box<InvestmentHolding>('investments');
    final index =
        box.values.toList().indexWhere((item) => item.id == holding.id);
    if (index == -1) {
      return;
    }

    final updated = InvestmentHolding(
      id: holding.id,
      type: holding.type,
      name: holding.name,
      quantity: holding.quantity,
      buyUnitPrice: holding.buyUnitPrice,
      currentUnitPrice: value,
      unitLabel: holding.unitLabel,
      purchaseDate: holding.purchaseDate,
      notes: holding.notes,
      symbol: holding.symbol,
      exchange: holding.exchange,
    );

    await box.putAt(index, updated);
    await BackupSyncService.instance.backupIfEnabled();
  }

  void _populateForEdit() {
    final holding = widget.holding;
    final transaction = widget.transaction;
    if (holding == null || transaction == null) {
      return;
    }

    _selectedType = _InvestmentType.values.firstWhere(
      (item) => item.name == holding.type,
      orElse: () => _InvestmentType.other,
    );
    _purchaseDate = holding.purchaseDate;
    _quantityController.text = holding.quantity.toString();
    _buyPriceController.text = holding.buyUnitPrice.toString();
    _currentPriceController.text = holding.currentUnitPrice.toString();
    _notesController.text = transaction.notes;

    if (_selectedType == _InvestmentType.stocks) {
      _stockNameController.text = holding.name;
    } else if (_selectedType == _InvestmentType.other) {
      _otherNameController.text = holding.name;
    }
  }
}

enum _InvestmentType {
  stocks('Stocks Investment'),
  gold('Gold Investment'),
  other('Other Investment');

  const _InvestmentType(this.label);

  final String label;
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121E39),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({
    required this.holding,
    required this.formatter,
    required this.onDelete,
    required this.onUpdatePrice,
  });

  final InvestmentHolding holding;
  final String Function(double) formatter;
  final VoidCallback onDelete;
  final VoidCallback onUpdatePrice;

  @override
  Widget build(BuildContext context) {
    final isProfit = holding.profitLoss >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1528),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${holding.type.toUpperCase()} · ${holding.symbol.isNotEmpty ? '${holding.symbol} · ' : ''}${holding.quantity.toStringAsFixed(holding.unitLabel == 'grams' ? 2 : 0)} ${holding.unitLabel}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF18233F),
                onSelected: (value) {
                  if (value == 'update') {
                    onUpdatePrice();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'update',
                    child: Text('Update Current Price'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Holding'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniMetric(
                  label: 'Invested', value: formatter(holding.investedAmount)),
              _MiniMetric(
                  label: 'Current', value: formatter(holding.currentValue)),
              _MiniMetric(
                label: 'P / L',
                value: '${isProfit ? '+' : ''}${formatter(holding.profitLoss)}',
                valueColor: isProfit ? Colors.greenAccent : Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121E39),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyHoldingsState extends StatelessWidget {
  const _EmptyHoldingsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1528),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'No holdings tracked yet. Add your first stock, gold, or other investment above.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
