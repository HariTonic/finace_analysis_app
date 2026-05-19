import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/investment_holding.dart';
import '../utils/transaction_parser.dart';
import '../utils/import_history.dart';
import '../utils/app_settings.dart';
import '../widgets/scroll_shadow_wrapper.dart';

class SmsExtractionScreen extends StatefulWidget {
  const SmsExtractionScreen({super.key});

  @override
  State<SmsExtractionScreen> createState() => _SmsExtractionScreenState();
}

class _SmsExtractionScreenState extends State<SmsExtractionScreen> {
  static const Color _primaryActionColor = Color(0xFF7A85FF);

  List<TransactionParseResult> parsedTransactions = [];
  List<InvestmentTradeResult> parsedInvestments = [];
  List<bool> selectedTransactions = [];
  List<bool> selectedInvestments = [];
  bool isLoading = false;
  int duplicatesFound = 0;
  final TextEditingController _smsTextController = TextEditingController();

  @override
  void dispose() {
    _smsTextController.dispose();
    super.dispose();
  }

  void _parseAndLoadTransactions() async {
    setState(() {
      isLoading = true;
      parsedTransactions = [];
      parsedInvestments = [];
      selectedTransactions = [];
      selectedInvestments = [];
      duplicatesFound = 0;
    });

    try {
      final rawText = _smsTextController.text;
      if (rawText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please paste your messages')),
        );
        setState(() => isLoading = false);
        return;
      }

      final normalizedText = rawText.replaceAll('\r', '');
      final messageBlocks = normalizedText.contains(RegExp(r'\n\s*\n'))
          ? normalizedText.split(RegExp(r'\n\s*\n+'))
          : normalizedText.split('\n');

      final transactionBox = Hive.box<Transaction>('transactions');

      List<TransactionParseResult> allParsedTx = [];
      List<InvestmentTradeResult> allParsedInv = [];
      int duplicateCount = 0;

      for (final block in messageBlocks) {
        final trimmedBlock = block.trim();
        if (trimmedBlock.isEmpty) continue;

        // Check if this is an investment message
        if (TransactionParser.isInvestmentMessage(trimmedBlock)) {
          final trades = TransactionParser.parseInvestmentMessage(trimmedBlock);
          for (final trade in trades) {
            if (trade.isValid) {
              allParsedInv.add(trade);
            }
          }
        } else {
          // Regular transaction
          final parseResult = TransactionParser.parseSms(trimmedBlock);

          if (parseResult.isValid) {
            // Check for duplicates
            final newTransaction = TransactionParser.createTransaction(
              parseResult,
              TransactionParser.extractDate(trimmedBlock) ?? DateTime.now(),
            );

            if (TransactionParser.isDuplicate(
                newTransaction, transactionBox.values.toList())) {
              duplicateCount++;
              continue; // Skip duplicates
            }

            allParsedTx.add(parseResult);
          }
        }
      }

      setState(() {
        parsedTransactions = allParsedTx;
        parsedInvestments = allParsedInv;
        selectedTransactions = List.filled(allParsedTx.length, true);
        selectedInvestments = List.filled(allParsedInv.length, true);
        duplicatesFound = duplicateCount;
        isLoading = false;
      });

      if (allParsedTx.isEmpty && allParsedInv.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              duplicateCount > 0
                  ? '$duplicateCount duplicate records were skipped'
                  : 'No valid transactions found in the pasted messages',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing messages: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  void _importSelectedItems() async {
    final selectedTx = selectedTransactions.where((s) => s).length;
    final selectedInv = selectedInvestments.where((s) => s).length;

    if (selectedTx == 0 && selectedInv == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final transactionBox = Hive.box<Transaction>('transactions');
      final investmentBox = Hive.box<InvestmentHolding>('investments');
      final importedIds = <String>[];

      // Import transactions
      for (int i = 0; i < parsedTransactions.length; i++) {
        if (selectedTransactions[i]) {
          final parseResult = parsedTransactions[i];
          final transaction = TransactionParser.createTransaction(
            parseResult,
            DateTime.now(),
          );
          await transactionBox.add(transaction);
          importedIds.add(transaction.id);
        }
      }

      // Import investments
      for (int i = 0; i < parsedInvestments.length; i++) {
        if (selectedInvestments[i]) {
          final tradeResult = parsedInvestments[i];
          final investment =
              TransactionParser.createInvestmentFromTrade(tradeResult);
          await investmentBox.add(investment);
          await transactionBox.add(
            Transaction(
              id: investment.id,
              amount: investment.investedAmount,
              category: 'Stocks Investment - ${investment.name}',
              date: investment.purchaseDate,
              type: 'investment',
              notes: investment.notes,
            ),
          );
          importedIds.add(investment.id);
        }
      }

      // Record import history
      await ImportHistoryManager.addImportRecord(
        importedIds.length,
        'sms',
        importedIds,
        duplicatesFound,
      );

      setState(() => isLoading = false);

      final totalCount = selectedTx + selectedInv;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $totalCount item${totalCount == 1 ? '' : 's'}${selectedTx > 0 ? ' ($selectedTx transaction${selectedTx == 1 ? '' : 's'}' : ''}${selectedInv > 0 ? '${selectedTx > 0 ? ', ' : ''}$selectedInv investment${selectedInv == 1 ? '' : 's'}' : ''}${selectedTx > 0 || selectedInv > 0 ? ')' : ''}',
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context, true);
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Hive.box('settings');
    final currency = settings.get(AppSettings.currencyKey,
        defaultValue: AppSettings.defaultCurrency) as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Messages'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ScrollShadowWrapper(
              builder: (controller) => SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Text(
                    'Paste Messages',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste bank messages, trading notifications, investment alerts, and similar text.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _smsTextController,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText:
                          'Paste Multiple Messages Here...\n\nExample:\n\n"Your account was debited with \$50.00 on 2024-06-01. Available balance: \$950.00."\n\n"Bought 10 shares of AAPL at \$150.00 each on 2024-06-02."',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF161626),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _parseAndLoadTransactions,
                      icon: const Icon(Icons.search, color: Colors.white),
                      label: const Text(
                        'Parse Messages',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryActionColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (duplicatesFound > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$duplicatesFound duplicate${duplicatesFound == 1 ? '' : 's'} skipped',
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Transactions Section
                  if (parsedTransactions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transactions',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${parsedTransactions.length} found',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161626),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: parsedTransactions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = parsedTransactions[index];
                          return CheckboxListTile(
                            value: selectedTransactions[index],
                            onChanged: (value) {
                              setState(() {
                                selectedTransactions[index] = value ?? false;
                              });
                            },
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.category ?? 'Other',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tx.type.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: tx.type == 'income'
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${AppSettings.currencySymbol(currency)}${tx.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  // Investments Section
                  if (parsedInvestments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Investments',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${parsedInvestments.length} found',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161626),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: parsedInvestments.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final inv = parsedInvestments[index];
                          return CheckboxListTile(
                            value: selectedInvestments[index],
                            onChanged: (value) {
                              setState(() {
                                selectedInvestments[index] = value ?? false;
                              });
                            },
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inv.symbol,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${inv.quantity} @ ${AppSettings.currencySymbol(currency)}${inv.rate.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${AppSettings.currencySymbol(currency)}${inv.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: inv.type == 'buy'
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        inv.type.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: inv.type == 'buy'
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (parsedTransactions.isNotEmpty ||
                      parsedInvestments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _importSelectedItems,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryActionColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Import Selected',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }
}
