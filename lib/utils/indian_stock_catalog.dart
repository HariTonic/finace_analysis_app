class IndianStockOption {
  const IndianStockOption({
    required this.name,
    required this.symbol,
    required this.exchange,
  });

  final String name;
  final String symbol;
  final String exchange;

  String get label => '$name ($symbol · $exchange)';
}

class IndianStockCatalog {
  static const List<IndianStockOption> options = [
    IndianStockOption(name: 'Reliance Industries', symbol: 'RELIANCE', exchange: 'NSE'),
    IndianStockOption(name: 'Tata Consultancy Services', symbol: 'TCS', exchange: 'NSE'),
    IndianStockOption(name: 'Infosys', symbol: 'INFY', exchange: 'NSE'),
    IndianStockOption(name: 'HDFC Bank', symbol: 'HDFCBANK', exchange: 'NSE'),
    IndianStockOption(name: 'ICICI Bank', symbol: 'ICICIBANK', exchange: 'NSE'),
    IndianStockOption(name: 'State Bank of India', symbol: 'SBIN', exchange: 'NSE'),
    IndianStockOption(name: 'Bharti Airtel', symbol: 'BHARTIARTL', exchange: 'NSE'),
    IndianStockOption(name: 'Larsen & Toubro', symbol: 'LT', exchange: 'NSE'),
    IndianStockOption(name: 'ITC', symbol: 'ITC', exchange: 'NSE'),
    IndianStockOption(name: 'Axis Bank', symbol: 'AXISBANK', exchange: 'NSE'),
    IndianStockOption(name: 'Hindustan Unilever', symbol: 'HINDUNILVR', exchange: 'NSE'),
    IndianStockOption(name: 'Sun Pharmaceutical', symbol: 'SUNPHARMA', exchange: 'NSE'),
    IndianStockOption(name: 'Mahindra & Mahindra', symbol: 'M&M', exchange: 'NSE'),
    IndianStockOption(name: 'Bajaj Finance', symbol: 'BAJFINANCE', exchange: 'NSE'),
    IndianStockOption(name: 'Maruti Suzuki India', symbol: 'MARUTI', exchange: 'NSE'),
    IndianStockOption(name: 'Titan Company', symbol: 'TITAN', exchange: 'NSE'),
    IndianStockOption(name: 'Wipro', symbol: 'WIPRO', exchange: 'NSE'),
    IndianStockOption(name: 'Asian Paints', symbol: 'ASIANPAINT', exchange: 'NSE'),
    IndianStockOption(name: 'Nestle India', symbol: 'NESTLEIND', exchange: 'NSE'),
    IndianStockOption(name: 'UltraTech Cement', symbol: 'ULTRACEMCO', exchange: 'NSE'),
    IndianStockOption(name: 'Adani Enterprises', symbol: 'ADANIENT', exchange: 'NSE'),
    IndianStockOption(name: 'Zomato', symbol: 'ZOMATO', exchange: 'NSE'),
  ];

  static List<IndianStockOption> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return options.take(8).toList();
    }

    return options.where((option) {
      return option.name.toLowerCase().contains(normalized) ||
          option.symbol.toLowerCase().contains(normalized) ||
          option.exchange.toLowerCase().contains(normalized);
    }).take(12).toList();
  }
}
