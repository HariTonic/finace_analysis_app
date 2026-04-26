import 'dart:convert';
import 'package:http/http.dart' as http;

class YahooFinanceService {
  // Get free API key from https://eodhistoricaldata.com
  static const String _apiKey = '69ec80bed91bf3.20582062';
  static const String _baseUrl = 'https://eodhd.com/api';

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
  };

  /// Fetch current price of a stock using its symbol
  /// Returns null - users will enter price manually
  static Future<double?> getCurrentPrice(String symbol) async {
    // API calls disabled - users enter price manually
    return null;
  }

  /// Fetch prices for multiple stocks at once
  /// Returns empty map - users enter prices manually
  static Future<Map<String, double>> getPrices(List<String> symbols) async {
    // API calls disabled - users enter prices manually
    return {};
  }

  /// Search for stocks by query term (name or symbol)
  /// Returns a list of stock search results
  static Future<List<StockSearchResult>> searchStocks(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final lowerQuery = query.toLowerCase();
      final results = <StockSearchResult>[];

      // Major Indian stocks list for local search
      final indianStocks = _getIndianStocksList();

      for (final stock in indianStocks) {
        if (stock.symbol.toLowerCase().contains(lowerQuery) ||
            stock.name.toLowerCase().contains(lowerQuery)) {
          results.add(stock);

          // Limit to first 10 results
          if (results.length >= 10) break;
        }
      }

      return results;
    } catch (e) {
      print('Error searching stocks: $e');
    }
    return [];
  }

  /// Get list of major Indian stocks for local search
  static List<StockSearchResult> _getIndianStocksList() {
    return [
      StockSearchResult(
          symbol: 'RELIANCE', name: 'Reliance Industries', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'TCS', name: 'Tata Consultancy Services', exchange: 'NSE'),
      StockSearchResult(symbol: 'INFY', name: 'Infosys', exchange: 'NSE'),
      StockSearchResult(symbol: 'WIPRO', name: 'Wipro', exchange: 'NSE'),
      StockSearchResult(symbol: 'HDFC', name: 'HDFC Bank', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'ICICIBANK', name: 'ICICI Bank', exchange: 'NSE'),
      StockSearchResult(symbol: 'AXISBANK', name: 'Axis Bank', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'MARUTI', name: 'Maruti Suzuki', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'DRREDDY', name: 'Dr. Reddy\'s', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'SUNPHARMA', name: 'Sun Pharma', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'SBIN', name: 'State Bank of India', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'BAJAJFINSV', name: 'Bajaj Finserv', exchange: 'NSE'),
      StockSearchResult(symbol: 'ITC', name: 'ITC', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'TITAN', name: 'Titan Company', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'NESTLEIND', name: 'Nestle India', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'BRITANNIA', name: 'Britannia', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'POWERGRID', name: 'Power Grid', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'HCLTECH', name: 'HCL Technologies', exchange: 'NSE'),
      StockSearchResult(
          symbol: 'HINDUNILVR', name: 'Hindustan Unilever', exchange: 'NSE'),
      StockSearchResult(symbol: 'LT', name: 'Larsen & Toubro', exchange: 'NSE'),
    ];
  }

  /// Format symbol for API (e.g., DRREDDY -> DRREDDY.NSE)
  static String _formatSymbol(String symbol) {
    // If symbol already has exchange suffix, return as is
    if (symbol.contains('.')) {
      return symbol;
    }

    // Add NSE for Indian stocks
    return '$symbol.NSE';
  }

  /// Normalize exchange names to Indian format
  static String _normalizeExchange(String exchange) {
    if (exchange.contains('NSE') || exchange.contains('NSX')) {
      return 'NSE';
    }
    if (exchange.contains('BSE')) {
      return 'BSE';
    }
    return exchange;
  }
}

class StockSearchResult {
  final String symbol;
  final String name;
  final String exchange;

  StockSearchResult({
    required this.symbol,
    required this.name,
    required this.exchange,
  });
}
