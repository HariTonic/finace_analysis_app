import '../models/transaction.dart';
import '../models/investment_holding.dart';

class TransactionParseResult {
  final double amount;
  final String type; // 'income' or 'expense'
  final String? category;
  final String? notes;
  final bool isValid;
  final String? error;

  TransactionParseResult({
    required this.amount,
    required this.type,
    this.category,
    this.notes,
    required this.isValid,
    this.error,
  });
}

class InvestmentTradeResult {
  final String symbol;
  final String name;
  final double quantity;
  final double rate;
  final String type; // 'buy' or 'sell'
  final double totalAmount;
  final String account;
  final DateTime date;
  final bool isValid;
  final String? error;

  InvestmentTradeResult({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.rate,
    required this.type,
    required this.totalAmount,
    required this.account,
    required this.date,
    required this.isValid,
    this.error,
  });
}

class TransactionParser {
  // Common SMS patterns for expenses and income
  static const Map<String, String> categoryPatterns = {
    // Food & Dining
    'food':
        r'(pizza|restaurant|cafe|coffee|burger|chicken|noodle|food|lunch|breakfast|dinner)',
    'groceries': r'(grocery|supermarket|mart|vegetables|milk|bread)',

    // Transport
    'transport': r'(uber|cab|taxi|auto|bus|petrol|fuel|gas|parking)',
    'travel': r'(flight|hotel|ticket|booking|holiday|trip)',

    // Shopping
    'shopping': r'(amazon|flipkart|mall|store|shop|clothes|shoes|dress)',
    'utilities': r'(electricity|water|internet|mobile|phone|bill)',

    // Entertainment
    'entertainment': r'(movie|theatre|cinema|gaming|game|concert|event)',

    // Healthcare
    'healthcare': r'(hospital|doctor|pharmacy|medical|medicine|clinic)',

    // Finance
    'investment': r'(stock|mutual|invest|trading|broker)',
    'interest': r'(interest|dividend)',
  };

  static const Map<String, String> typePatterns = {
    'expense':
        r'(debit|debited|spent|charged|paid|payment|withdraw|withdrawal|-)',
    'income':
        r'(credit|credited|received|deposit|salary|payment received|transfer)',
  };

  // Extract amount from SMS text
  static double? extractAmount(String text) {
    // Look for patterns like: Rs 500, ₹500, 500.00, $500
    final patterns = [
      r'(?:Rs\.?|₹|Rs)\s*(\d+(?:,\d{3})*(?:\.\d{2})?)',
      r'(^\d+(?:,\d{3})*(?:\.\d{2})?)\s*(?:Rs\.?|₹)',
      r'\b(\d+(?:,\d{3})*(?:\.\d{2})?)\b',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, multiLine: true, caseSensitive: false);
      final match = regex.firstMatch(text);

      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        try {
          return double.parse(amountStr);
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }

  // Determine transaction type (income or expense)
  static String determineType(String text) {
    final lowerText = text.toLowerCase();

    for (final type in typePatterns.entries) {
      if (RegExp(type.value, caseSensitive: false).hasMatch(lowerText)) {
        return type.key;
      }
    }

    // Default to expense if amount mentioned with debit-like words
    if (lowerText.contains('debit') || lowerText.contains('spent')) {
      return 'expense';
    }

    return 'expense'; // Default
  }

  // Determine category based on SMS content
  static String? determineCategory(String text) {
    final lowerText = text.toLowerCase();

    for (final category in categoryPatterns.entries) {
      if (RegExp(category.value, caseSensitive: false).hasMatch(lowerText)) {
        return category.key;
      }
    }

    return 'other';
  }

  // Parse SMS message into Transaction
  static TransactionParseResult parseSms(String smsText) {
    try {
      final amount = extractAmount(smsText);

      if (amount == null || amount <= 0) {
        return TransactionParseResult(
          amount: 0,
          type: 'expense',
          isValid: false,
          error: 'No valid amount found in message',
        );
      }

      final type = determineType(smsText);
      final category = determineCategory(smsText);

      return TransactionParseResult(
        amount: amount,
        type: type,
        category: category,
        notes: smsText,
        isValid: true,
      );
    } catch (e) {
      return TransactionParseResult(
        amount: 0,
        type: 'expense',
        isValid: false,
        error: 'Error parsing SMS: $e',
      );
    }
  }

  // Create Transaction object from parsed result
  static Transaction createTransaction(
    TransactionParseResult result,
    DateTime date,
  ) {
    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: result.amount,
      category: result.category ?? 'other',
      date: date,
      type: result.type,
      notes: result.notes ?? '',
    );
  }

  // Check if transaction is a duplicate based on amount, category, and date
  static bool isDuplicate(
    Transaction newTransaction,
    List<Transaction> existingTransactions,
  ) {
    for (final existing in existingTransactions) {
      // Check if amount, type, and category match
      final sameAmount = (existing.amount - newTransaction.amount).abs() < 0.01;
      final sameType = existing.type == newTransaction.type;
      final sameCategory = existing.category == newTransaction.category;

      // Check if date is within 1 hour
      final dateDiff =
          existing.date.difference(newTransaction.date).inMinutes.abs();
      final sameDate = dateDiff < 60;

      if (sameAmount && sameType && sameCategory && sameDate) {
        return true;
      }
    }

    return false;
  }

  // Extract date from various SMS formats
  static DateTime? extractDate(String text) {
    try {
      // Format: 25-04-26
      final ddMmYyRegex = RegExp(r'(\d{1,2})-(\d{1,2})-(\d{2,4})');
      final ddMmYyMatch = ddMmYyRegex.firstMatch(text);
      if (ddMmYyMatch != null) {
        int day = int.parse(ddMmYyMatch.group(1)!);
        int month = int.parse(ddMmYyMatch.group(2)!);
        int year = int.parse(ddMmYyMatch.group(3)!);

        // Handle 2-digit year
        if (year < 100) {
          year = year < 50 ? 2000 + year : 1900 + year;
        }
        return DateTime(year, month, day);
      }

      // Format: 19-MAR-2026
      final ddMMMyyyyRegex = RegExp(
          r'(\d{1,2})-(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)-(\d{4})',
          caseSensitive: false);
      final ddMMMyyyyMatch = ddMMMyyyyRegex.firstMatch(text);
      if (ddMMMyyyyMatch != null) {
        int day = int.parse(ddMMMyyyyMatch.group(1)!);
        Map<String, int> months = {
          'JAN': 1,
          'FEB': 2,
          'MAR': 3,
          'APR': 4,
          'MAY': 5,
          'JUN': 6,
          'JUL': 7,
          'AUG': 8,
          'SEP': 9,
          'OCT': 10,
          'NOV': 11,
          'DEC': 12,
        };
        int month = months[ddMMMyyyyMatch.group(2)!.toUpperCase()] ?? 1;
        int year = int.parse(ddMMMyyyyMatch.group(3)!);
        return DateTime(year, month, day);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if message is investment-related
  static bool isInvestmentMessage(String text) {
    final investmentKeywords = [
      'bought',
      'sold',
      'trade',
      'trade summary',
      'stock',
      'equity',
      'mutual',
      'nse',
      'bse',
      'broker',
      'trading',
      'securities'
    ];

    final lowerText = text.toLowerCase();
    return investmentKeywords.any((keyword) => lowerText.contains(keyword));
  }

  // Parse investment trade message
  static List<InvestmentTradeResult> parseInvestmentMessage(String text) {
    final trades = <InvestmentTradeResult>[];

    try {
      final normalizedText = text.replaceAll('\r', '');

      if (!RegExp(r'\b(BOUGHT|SOLD)\b', caseSensitive: false)
          .hasMatch(normalizedText)) {
        return [];
      }

      // Extract account number from formats like:
      // "Trd Acc-XXX3227", "A/c *7022", or "Account: 12345"
      final accountRegex = RegExp(
        r'(?:trd\s+acc|a/c|account)\s*[-:\s]*([A-Za-z0-9*]+)',
        caseSensitive: false,
        multiLine: true,
      );
      final accountMatch = accountRegex.firstMatch(normalizedText);
      final account = accountMatch?.group(1) ?? 'Unknown';

      // Extract date
      final date = extractDate(normalizedText) ?? DateTime.now();

      // Find trade entries like:
      // "BOUGHT 10 IDFCFIREQNR @ 62.71(NSE)"
      // "SOLD 5 ABC @ 100.00 (BSE)."
      final tradeRegex = RegExp(
        r'^\s*(BOUGHT|SOLD)\s+(\d+(?:\.\d+)?)\s+([A-Za-z0-9]+)\s*@\s*(\d+(?:\.\d+)?)\s*(?:\(([A-Za-z]+)\))?\.?\s*$',
        caseSensitive: false,
        multiLine: true,
      );

      final matches = tradeRegex.allMatches(normalizedText);

      for (final match in matches) {
        final tradeType = match.group(1)!.toUpperCase();
        final quantity = double.tryParse(match.group(2)!) ?? 0;
        final symbol = match.group(3)!.toUpperCase();
        final rate = double.tryParse(match.group(4)!) ?? 0;
        final exchange = (match.group(5) ?? 'NSE').toUpperCase();

        if (quantity > 0 && rate > 0) {
          final totalAmount = quantity * rate;

          trades.add(InvestmentTradeResult(
            symbol: symbol,
            name: symbol,
            quantity: quantity,
            rate: rate,
            type: tradeType.toLowerCase() == 'bought' ? 'buy' : 'sell',
            totalAmount: totalAmount,
            account: '$account|$exchange',
            date: date,
            isValid: true,
          ));
        }
      }

      return trades;
    } catch (e) {
      return [];
    }
  }

  // Create InvestmentHolding from trade result
  static InvestmentHolding createInvestmentFromTrade(
    InvestmentTradeResult trade,
  ) {
    final accountParts = trade.account.split('|');
    final account = accountParts.isNotEmpty ? accountParts.first : 'Unknown';
    final exchange = accountParts.length > 1 && accountParts[1].isNotEmpty
        ? accountParts[1]
        : 'NSE';

    return InvestmentHolding(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'stocks',
      symbol: trade.symbol,
      name: trade.name,
      quantity: trade.quantity,
      buyUnitPrice: trade.rate,
      currentUnitPrice: trade.rate,
      unitLabel: 'stocks',
      notes:
          'Imported from SMS - ${trade.type.toUpperCase()} ${trade.quantity} @ ${trade.rate} on ${trade.date} ($account)',
      purchaseDate: trade.date,
      exchange: exchange,
    );
  }
}
