import 'package:hive/hive.dart';
import 'dart:math';
import '../models/transaction.dart';
import '../models/investment_holding.dart';

class DataSeeder {
  static String _generateId() {
    // Generate a simple UUID-like string
    const chars = 'abcdef0123456789';
    final random = Random();
    return '${DateTime.now().millisecondsSinceEpoch}'
        '${List.generate(8, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  /// Populates sample data into Hive if the boxes are empty
  static Future<void> seedSampleDataIfEmpty() async {
    final transactionBox = Hive.box<Transaction>('transactions');
    final investmentBox = Hive.box<InvestmentHolding>('investments');

    // Only seed if both boxes are empty
    if (transactionBox.isEmpty && investmentBox.isEmpty) {
      await seedSampleTransactions();
      await seedSampleInvestments();
    }
  }

  /// Seeds sample expense, income, and investment transactions
  static Future<void> seedSampleTransactions() async {
    final box = Hive.box<Transaction>('transactions');
    final now = DateTime.now();

    final sampleTransactions = [
      // Income transactions
      Transaction(
        id: _generateId(),
        amount: 50000,
        category: 'Salary - Monthly',
        date: now.subtract(const Duration(days: 5)),
        type: 'income',
        notes: 'Monthly salary',
      ),
      Transaction(
        id: _generateId(),
        amount: 5000,
        category: 'Freelance - Projects',
        date: now.subtract(const Duration(days: 2)),
        type: 'income',
        notes: 'Freelance project completion',
      ),

      // Expense transactions
      Transaction(
        id: _generateId(),
        amount: 500,
        category: 'Food - Groceries',
        date: now.subtract(const Duration(days: 4)),
        type: 'expense',
        notes: 'Weekly grocery shopping',
      ),
      Transaction(
        id: _generateId(),
        amount: 1200,
        category: 'Transport - Fuel',
        date: now.subtract(const Duration(days: 3)),
        type: 'expense',
        notes: 'Monthly fuel expenses',
      ),
      Transaction(
        id: _generateId(),
        amount: 2500,
        category: 'Utilities - Electricity',
        date: now.subtract(const Duration(days: 6)),
        type: 'expense',
        notes: 'Monthly electricity bill',
      ),
      Transaction(
        id: _generateId(),
        amount: 350,
        category: 'Entertainment - Movies',
        date: now.subtract(const Duration(days: 1)),
        type: 'expense',
        notes: 'Movie tickets and streaming',
      ),

      // Investment transactions
      Transaction(
        id: _generateId(),
        amount: 10000,
        category: 'Investment - Stocks',
        date: now.subtract(const Duration(days: 10)),
        type: 'investment',
        notes: 'Invested in tech stocks',
      ),
      Transaction(
        id: _generateId(),
        amount: 5000,
        category: 'Investment - Gold',
        date: now.subtract(const Duration(days: 7)),
        type: 'investment',
        notes: 'Gold investment purchase',
      ),
      Transaction(
        id: _generateId(),
        amount: 8000,
        category: 'Investment - Mutual Funds',
        date: now.subtract(const Duration(days: 12)),
        type: 'investment',
        notes: 'Index fund investment',
      ),
    ];

    for (final transaction in sampleTransactions) {
      await box.add(transaction);
    }
  }

  /// Seeds sample investment holdings
  static Future<void> seedSampleInvestments() async {
    final box = Hive.box<InvestmentHolding>('investments');
    final now = DateTime.now();

    final sampleInvestments = [
      InvestmentHolding(
        id: _generateId(),
        type: 'Stock',
        name: 'TCS Limited',
        quantity: 10,
        buyUnitPrice: 3500,
        currentUnitPrice: 3850,
        unitLabel: 'shares',
        purchaseDate: now.subtract(const Duration(days: 90)),
        notes: 'Tech stock holding',
        symbol: 'TCS',
        exchange: 'NSE',
      ),
      InvestmentHolding(
        id: _generateId(),
        type: 'Stock',
        name: 'Infosys Limited',
        quantity: 5,
        buyUnitPrice: 1800,
        currentUnitPrice: 1950,
        unitLabel: 'shares',
        purchaseDate: now.subtract(const Duration(days: 60)),
        notes: 'IT company stock',
        symbol: 'INFY',
        exchange: 'NSE',
      ),
      InvestmentHolding(
        id: _generateId(),
        type: 'Gold',
        name: 'Gold Bar 24K',
        quantity: 50,
        buyUnitPrice: 6200,
        currentUnitPrice: 6500,
        unitLabel: 'grams',
        purchaseDate: now.subtract(const Duration(days: 45)),
        notes: 'Pure gold investment',
        symbol: 'GOLD',
        exchange: 'Physical',
      ),
      InvestmentHolding(
        id: _generateId(),
        type: 'Mutual Fund',
        name: 'Nifty 50 Index Fund',
        quantity: 100,
        buyUnitPrice: 250,
        currentUnitPrice: 265,
        unitLabel: 'units',
        purchaseDate: now.subtract(const Duration(days: 30)),
        notes: 'Index fund investment',
      ),
    ];

    for (final investment in sampleInvestments) {
      await box.add(investment);
    }
  }

  /// Clears all sample data
  static Future<void> clearAllData() async {
    final transactionBox = Hive.box<Transaction>('transactions');
    final investmentBox = Hive.box<InvestmentHolding>('investments');

    await transactionBox.clear();
    await investmentBox.clear();
  }
}
