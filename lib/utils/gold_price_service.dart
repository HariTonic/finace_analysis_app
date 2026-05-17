import 'dart:convert';
import 'package:http/http.dart' as http;

class GoldPrice {
  final double pricePerGram;
  final double totalPrice;
  final String currency;
  final double grams;
  final DateTime timestamp;

  GoldPrice({
    required this.pricePerGram,
    required this.totalPrice,
    required this.currency,
    required this.grams,
    required this.timestamp,
  });

  factory GoldPrice.fromJson(Map<String, dynamic> json) {
    return GoldPrice(
      pricePerGram: (json['price_per_gram'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
      grams: (json['grams'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
    );
  }
}

class GoldPriceService {
  static const String _forexUrl = 'https://open.er-api.com/v6/latest/USD';
  static const String _goldUrl = 'https://api.gold-api.com/price/XAU';
  static const double _ounceToGrams = 31.1035;
  static const Duration _timeout = Duration(seconds: 10);

  static final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Safari/537.36',
  };

  final http.Client _httpClient;

  GoldPriceService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Fetches current gold price per gram for the specified currency
  /// 
  /// Returns null if the request fails
  Future<double?> fetchGoldPricePerGram({
    String currency = 'INR',
  }) async {
    try {
      final goldPrice = await _fetchGoldPriceUsdPerOunce();
      if (goldPrice == null) {
        return null;
      }

      final conversionRate = await _fetchConversionRate(currency);
      if (conversionRate == null) {
        return null;
      }

      final goldPriceCurrencyPerOunce = goldPrice * conversionRate;
      final pricePerGram = goldPriceCurrencyPerOunce / _ounceToGrams;

      return pricePerGram;
    } catch (_) {
      return null;
    }
  }

  /// Fetches complete gold price information
  /// 
  /// Returns GoldPrice object or null if request fails
  Future<GoldPrice?> fetchGoldPrice({
    String currency = 'INR',
    double grams = 1.0,
  }) async {
    try {
      final pricePerGram = await fetchGoldPricePerGram(currency: currency);
      if (pricePerGram == null) {
        return null;
      }

      final totalPrice = pricePerGram * grams;

      return GoldPrice(
        pricePerGram: pricePerGram,
        totalPrice: totalPrice,
        currency: currency,
        grams: grams,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches forex conversion rate for the specified currency
  /// 
  /// Returns the conversion rate (USD to specified currency) or null if request fails
  Future<double?> _fetchConversionRate(String currency) async {
    try {
      final uri = Uri.parse(_forexUrl);
      final response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final rates = data['rates'] as Map<String, dynamic>?;

      if (rates == null || !rates.containsKey(currency)) {
        return null;
      }

      final rate = rates[currency];
      if (rate is num) {
        return rate.toDouble();
      }

      return double.tryParse(rate.toString());
    } catch (_) {
      return null;
    }
  }

  /// Fetches gold price in USD per ounce
  /// 
  /// Returns the price per ounce or null if request fails
  Future<double?> _fetchGoldPriceUsdPerOunce() async {
    try {
      final uri = Uri.parse(_goldUrl);
      final response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final dynamic price = data['price'];

      if (price is num) {
        return price.toDouble();
      }

      if (price is String) {
        return double.tryParse(price.replaceAll(',', ''));
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
