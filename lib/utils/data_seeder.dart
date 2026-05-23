import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/investment_holding.dart';
import '../models/transaction.dart';

class DataSeeder {
  static final Random _random = Random(42);

  static const Map<String, List<String>> _expenseSubCategoriesByCategory = {
    'Home': [
      'Rent',
      'Electricity',
      'Water Bill',
      'Gas',
      'Internet',
      'Groceries',
      'Maintenance',
      'Maid',
      'Furniture',
      'Home Repair',
      'Others',
    ],
    'Food': [
      'Restaurant',
      'Food Delivery',
      'Tea / Coffee',
      'Snacks',
      'Bakery',
      'Street Food',
      'Others',
    ],
    'Transport': [
      'Auto',
      'Cab',
      'Bus',
      'Train',
      'Metro',
      'Flight',
      'Parking',
      'Toll',
      'Others',
    ],
    'Vehicle': [
      'Fuel',
      'Bike Service',
      'Car Service',
      'Vehicle Insurance',
      'Repairs',
      'Accessories',
      'Others',
    ],
    'Personal & Shopping': [
      'Clothing',
      'Footwear',
      'Grooming',
      'Salon',
      'Cosmetics',
      'Accessories',
      'Online Shopping',
      'Household Items',
      'Gifts',
      'Gym',
      'Laundry',
      'Others',
    ],
    'Bills & Subscriptions': [
      'Mobile Recharge',
      'Credit Card Bill',
      'OTT',
      'Software Subscription',
      'Cloud Storage',
      'Bank Charges',
      'Others',
    ],
    'Medical': [
      'Doctor',
      'Medicines',
      'Tests',
      'Insurance',
      'Emergency',
      'Others',
    ],
    'Education': [
      'Courses',
      'Certifications',
      'Books',
      'Exam Fees',
      'Others',
    ],
    'Entertainment': [
      'Movies',
      'Games',
      'Outings',
      'Events',
      'Streaming',
      'Parties',
      'Others',
    ],
    'Family': [
      'Parents Support',
      'Kids',
      'Festivals',
      'Functions',
      'Child Education',
      'Others',
    ],
    'Debt': [
      'Personal Loan EMI',
      'Home Loan EMI',
      'Vehicle Loan EMI',
      'Credit Card Due',
      'Borrowed Money Return',
      'Interest Payment',
      'Friend/Family Repayment',
      'Bike EMI',
      'Car EMI',
      'Home EMI',
      'Others',
    ],
    'Others': ['Others'],
  };

  static const List<_InvestmentSeed> _investmentSeeds = [
    _InvestmentSeed(
      type: 'stocks',
      name: 'Reliance Industries',
      unitLabel: 'stocks',
      symbol: 'RELIANCE',
      quantity: 18,
      buyUnitPrice: 2450,
      currentUnitPrice: 2740,
    ),
    _InvestmentSeed(
      type: 'stocks',
      name: 'Infosys',
      unitLabel: 'stocks',
      symbol: 'INFY',
      quantity: 24,
      buyUnitPrice: 1490,
      currentUnitPrice: 1625,
    ),
    _InvestmentSeed(
      type: 'stocks',
      name: 'HDFC Bank',
      unitLabel: 'stocks',
      symbol: 'HDFCBANK',
      quantity: 14,
      buyUnitPrice: 1580,
      currentUnitPrice: 1710,
    ),
    _InvestmentSeed(
      type: 'gold',
      name: 'Gold',
      unitLabel: 'grams',
      quantity: 28,
      buyUnitPrice: 6120,
      currentUnitPrice: 6765,
    ),
    _InvestmentSeed(
      type: 'gold',
      name: 'Gold',
      unitLabel: 'grams',
      quantity: 16,
      buyUnitPrice: 6285,
      currentUnitPrice: 6890,
    ),
    _InvestmentSeed(
      type: 'other',
      name: 'Nifty 50 Index Fund',
      unitLabel: 'units',
      quantity: 220,
      buyUnitPrice: 248,
      currentUnitPrice: 276,
    ),
    _InvestmentSeed(
      type: 'other',
      name: 'Emergency Debt Fund',
      unitLabel: 'units',
      quantity: 410,
      buyUnitPrice: 112,
      currentUnitPrice: 119,
    ),
    _InvestmentSeed(
      type: 'other',
      name: 'Retirement SIP Basket',
      unitLabel: 'units',
      quantity: 320,
      buyUnitPrice: 185,
      currentUnitPrice: 202,
    ),
  ];

  static String _generateId() {
    const chars = 'abcdef0123456789';
    return '${DateTime.now().microsecondsSinceEpoch}'
        '${List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join()}';
  }

  static Future<void> seedSampleDataIfEmpty() async {
    if (!kDebugMode) {
      return;
    }

    final transactionBox = Hive.box<Transaction>('transactions');
    final investmentBox = Hive.box<InvestmentHolding>('investments');

    if (transactionBox.isEmpty && investmentBox.isEmpty) {
      await seedYearOfTransactions();
      await seedYearOfInvestments();
    }
  }

  static Future<void> replaceWithYearOfData() async {
    if (!kDebugMode) {
      return;
    }

    await clearAllData();
    await seedYearOfTransactions();
    await seedYearOfInvestments();
  }

  static Future<void> seedYearOfTransactions() async {
    final box = Hive.box<Transaction>('transactions');
    if (box.isNotEmpty) {
      return;
    }

    final now = DateTime.now();
    final startDate = DateTime(now.year - 1, now.month, now.day);
    final transactions = <Transaction>[];

    transactions.addAll(_buildExpenseCoverageTransactions(startDate));
    transactions.addAll(_buildMonthlyIncomeTransactions(now));
    transactions.addAll(_buildRecurringExpenseTransactions(startDate, now));
    transactions.addAll(_buildAdditionalExpenseTransactions(startDate, now));
    transactions.addAll(_buildInvestmentTransactions(now));

    transactions.sort((a, b) => a.date.compareTo(b.date));

    for (final transaction in transactions) {
      await box.add(transaction);
    }
  }

  static Future<void> seedYearOfInvestments() async {
    final box = Hive.box<InvestmentHolding>('investments');
    if (box.isNotEmpty) {
      return;
    }

    final now = DateTime.now();
    final holdings = <InvestmentHolding>[];

    for (var index = 0; index < _investmentSeeds.length; index++) {
      final seed = _investmentSeeds[index];
      final purchaseDate = DateTime(
        now.year,
        now.month - min(index + 1, 10),
        5 + ((index * 3) % 20),
        11,
        15,
      );
      final id = _investmentIdForIndex(index);
      holdings.add(
        InvestmentHolding(
          id: id,
          type: seed.type,
          name: seed.name,
          quantity: seed.quantity,
          buyUnitPrice: seed.buyUnitPrice,
          currentUnitPrice: seed.currentUnitPrice,
          unitLabel: seed.unitLabel,
          purchaseDate: purchaseDate,
          notes: 'Seeded ${seed.type} holding for dashboard and reports testing.',
          symbol: seed.symbol,
          exchange: seed.type == 'stocks' ? 'NSE' : 'Portfolio',
        ),
      );
    }

    for (final holding in holdings) {
      await box.add(holding);
    }
  }

  static List<Transaction> _buildExpenseCoverageTransactions(DateTime startDate) {
    final transactions = <Transaction>[];
    var dayOffset = 0;

    _expenseSubCategoriesByCategory.forEach((category, subCategories) {
      for (final subCategory in subCategories) {
        final date = startDate.add(Duration(days: dayOffset));
        transactions.add(
          Transaction(
            id: _generateId(),
            amount: _expenseAmount(category, subCategory, multiplier: 0.9),
            category: '$category - $subCategory',
            date: DateTime(date.year, date.month, date.day, 19, dayOffset % 50),
            type: 'expense',
            notes: 'Seeded $category expense for $subCategory coverage.',
          ),
        );
        dayOffset += 2;
      }
    });

    return transactions;
  }

  static List<Transaction> _buildMonthlyIncomeTransactions(DateTime now) {
    final transactions = <Transaction>[];

    for (var monthsAgo = 11; monthsAgo >= 0; monthsAgo--) {
      final monthDate = DateTime(now.year, now.month - monthsAgo, 1);
      transactions.addAll([
        Transaction(
          id: _generateId(),
          amount: 52000 + ((11 - monthsAgo) * 650).toDouble(),
          category: 'Salary',
          date: DateTime(monthDate.year, monthDate.month, 1, 10, 0),
          type: 'income',
          notes: 'Monthly salary credited.',
        ),
        Transaction(
          id: _generateId(),
          amount: 6000 + ((monthsAgo % 4) * 1500).toDouble(),
          category: 'Freelance',
          date: DateTime(monthDate.year, monthDate.month, 9, 18, 20),
          type: 'income',
          notes: 'Freelance payment received.',
        ),
        Transaction(
          id: _generateId(),
          amount: 1800 + ((monthsAgo % 3) * 450).toDouble(),
          category: 'Investment',
          date: DateTime(monthDate.year, monthDate.month, 18, 13, 10),
          type: 'income',
          notes: 'Investment return booked.',
        ),
        Transaction(
          id: _generateId(),
          amount: 2500 + ((monthsAgo % 5) * 500).toDouble(),
          category: 'Other',
          date: DateTime(monthDate.year, monthDate.month, 24, 17, 45),
          type: 'income',
          notes: 'Miscellaneous income entry.',
        ),
      ]);

      if (monthsAgo % 3 == 0) {
        transactions.add(
          Transaction(
            id: _generateId(),
            amount: 9000 + ((monthsAgo % 2) * 3000).toDouble(),
            category: 'Bonus',
            date: DateTime(monthDate.year, monthDate.month, 28, 16, 30),
            type: 'income',
            notes: 'Quarterly bonus credited.',
          ),
        );
      }
    }

    return transactions;
  }

  static List<Transaction> _buildRecurringExpenseTransactions(
    DateTime startDate,
    DateTime now,
  ) {
    final transactions = <Transaction>[];

    for (var monthIndex = 0; monthIndex < 12; monthIndex++) {
      final monthDate = DateTime(startDate.year, startDate.month + monthIndex, 1);
      final offset = monthIndex.toDouble();

      transactions.addAll([
        _expenseTransaction(
          'Home',
          'Rent',
          14500 + (offset * 250),
          DateTime(monthDate.year, monthDate.month, 2, 8, 30),
          'Monthly house rent.',
        ),
        _expenseTransaction(
          'Home',
          'Electricity',
          2100 + ((monthIndex % 4) * 180).toDouble(),
          DateTime(monthDate.year, monthDate.month, 5, 21, 10),
          'Electricity bill payment.',
        ),
        _expenseTransaction(
          'Food',
          'Groceries',
          3200 + ((monthIndex % 5) * 240).toDouble(),
          DateTime(monthDate.year, monthDate.month, 6, 20, 15),
          'Monthly grocery restock.',
        ),
        _expenseTransaction(
          'Transport',
          'Metro',
          950 + ((monthIndex % 3) * 110).toDouble(),
          DateTime(monthDate.year, monthDate.month, 8, 9, 5),
          'Metro commute recharge.',
        ),
        _expenseTransaction(
          'Vehicle',
          'Fuel',
          2600 + ((monthIndex % 4) * 210).toDouble(),
          DateTime(monthDate.year, monthDate.month, 10, 19, 0),
          'Fuel top-up.',
        ),
        _expenseTransaction(
          'Bills & Subscriptions',
          'Mobile Recharge',
          399,
          DateTime(monthDate.year, monthDate.month, 12, 14, 0),
          'Mobile recharge payment.',
        ),
        _expenseTransaction(
          'Bills & Subscriptions',
          'OTT',
          499,
          DateTime(monthDate.year, monthDate.month, 14, 22, 10),
          'Streaming subscription renewal.',
        ),
        _expenseTransaction(
          'Personal & Shopping',
          'Household Items',
          1100 + ((monthIndex % 3) * 175).toDouble(),
          DateTime(monthDate.year, monthDate.month, 16, 18, 35),
          'Household shopping.',
        ),
        _expenseTransaction(
          'Debt',
          'Credit Card Due',
          4500 + ((monthIndex % 6) * 350).toDouble(),
          DateTime(monthDate.year, monthDate.month, 20, 11, 40),
          'Credit card bill payment.',
        ),
        _expenseTransaction(
          'Family',
          'Parents Support',
          5000 + ((monthIndex % 4) * 300).toDouble(),
          DateTime(monthDate.year, monthDate.month, 22, 10, 20),
          'Monthly support transfer to family.',
        ),
      ]);
    }

    transactions.removeWhere((transaction) => transaction.date.isAfter(now));
    return transactions;
  }

  static List<Transaction> _buildAdditionalExpenseTransactions(
    DateTime startDate,
    DateTime now,
  ) {
    final transactions = <Transaction>[];
    var cursor = startDate.add(const Duration(days: 18));
    var loopIndex = 0;
    final categoryEntries = _expenseSubCategoriesByCategory.entries.toList();

    while (!cursor.isAfter(now)) {
      final entry = categoryEntries[loopIndex % categoryEntries.length];
      final subCategories = entry.value;
      final subCategory = subCategories[loopIndex % subCategories.length];

      transactions.add(
        _expenseTransaction(
          entry.key,
          subCategory,
          _expenseAmount(entry.key, subCategory),
          DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            12 + (loopIndex % 8),
            (loopIndex * 7) % 60,
          ),
          'Seeded ${entry.key.toLowerCase()} expense for $subCategory.',
        ),
      );

      if (loopIndex % 3 == 0) {
        final extraSubCategory = subCategories[(loopIndex + 1) % subCategories.length];
        transactions.add(
          _expenseTransaction(
            entry.key,
            extraSubCategory,
            _expenseAmount(entry.key, extraSubCategory, multiplier: 0.75),
            DateTime(
              cursor.year,
              cursor.month,
              cursor.day,
              20,
              (loopIndex * 11) % 60,
            ),
            'Evening ${entry.key.toLowerCase()} expense.',
          ),
        );
      }

      cursor = cursor.add(Duration(days: 3 + (loopIndex % 4)));
      loopIndex++;
    }

    return transactions;
  }

  static List<Transaction> _buildInvestmentTransactions(DateTime now) {
    final transactions = <Transaction>[];

    for (var index = 0; index < _investmentSeeds.length; index++) {
      final seed = _investmentSeeds[index];
      final purchaseDate = DateTime(
        now.year,
        now.month - min(index + 1, 10),
        5 + ((index * 3) % 20),
        11,
        15,
      );
      final label = switch (seed.type) {
        'stocks' => 'Stocks Investment',
        'gold' => 'Gold Investment',
        _ => 'Other Investment',
      };

      transactions.add(
        Transaction(
          id: _investmentIdForIndex(index),
          amount: seed.quantity * seed.buyUnitPrice,
          category: '$label - ${seed.name}',
          date: purchaseDate,
          type: 'investment',
          notes: 'Seeded ${seed.name} purchase.',
        ),
      );
    }

    return transactions;
  }

  static Transaction _expenseTransaction(
    String category,
    String subCategory,
    double amount,
    DateTime date,
    String notes,
  ) {
    return Transaction(
      id: _generateId(),
      amount: amount,
      category: '$category - $subCategory',
      date: date,
      type: 'expense',
      notes: notes,
    );
  }

  static double _expenseAmount(
    String category,
    String subCategory, {
    double multiplier = 1,
  }) {
    final base = switch (category) {
      'Home' => 2500,
      'Food' => 320,
      'Transport' => 220,
      'Vehicle' => 1400,
      'Personal & Shopping' => 950,
      'Bills & Subscriptions' => 700,
      'Medical' => 850,
      'Education' => 1200,
      'Entertainment' => 650,
      'Family' => 1800,
      'Debt' => 2600,
      _ => 400,
    };

    final modifier = (subCategory.length * 37) % 550;
    return ((base + modifier) * multiplier).roundToDouble();
  }

  static String _investmentIdForIndex(int index) => 'seed-investment-$index';

  static Future<void> clearAllData() async {
    final transactionBox = Hive.box<Transaction>('transactions');
    final investmentBox = Hive.box<InvestmentHolding>('investments');

    await transactionBox.clear();
    await investmentBox.clear();
  }
}

class _InvestmentSeed {
  const _InvestmentSeed({
    required this.type,
    required this.name,
    required this.unitLabel,
    required this.quantity,
    required this.buyUnitPrice,
    required this.currentUnitPrice,
    this.symbol = '',
  });

  final String type;
  final String name;
  final String unitLabel;
  final double quantity;
  final double buyUnitPrice;
  final double currentUnitPrice;
  final String symbol;
}
