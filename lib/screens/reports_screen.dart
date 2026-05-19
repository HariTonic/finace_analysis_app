import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/investment_holding.dart';
import '../models/transaction.dart';
import '../utils/app_settings.dart';
import '../utils/gold_price_service.dart';
import '../widgets/scroll_shadow_wrapper.dart';

const List<Color> _chartPalette = [
  Color(0xFF7B61FF),
  Color(0xFF00D1FF),
  Color(0xFFFF4D8D),
  Color(0xFFFFB84D),
  Color(0xFFFF0080),
  Color(0xFF7928CA),
  Color(0xFF00F5FF),
  Color(0xFFFCEE09),
  Color(0xFF005AA7),
  Color(0xFF00C6FF),
  Color(0xFF7FDBFF),
  Color(0xFFB2FEFA),
  Color(0xFFFF512F),
  Color(0xFFF09819),
  Color(0xFFFF9966),
  Color(0xFFFFD194),
  Color(0xFF00C853),
  Color(0xFF69F0AE),
  Color(0xFF1DE9B6),
  Color(0xFF00BFA5),
  Color(0xFFB388FF),
  Color(0xFF7C4DFF),
  Color(0xFFE1BEE7),
  Color(0xFFCE93D8),
  Color(0xFFFF9A9E),
  Color(0xFFFAD0C4),
  Color(0xFFFFD3B6),
  Color(0xFFFFAAA5),
  Color(0xFF1F1C2C),
  Color(0xFF928DAB),
];

LinearGradient _chartGradientAt(int index) {
  final start = _chartPalette[index % _chartPalette.length];
  final end = _chartPalette[(index + 1) % _chartPalette.length];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [start, end],
  );
}

Color _chartColorAt(int index) => _chartPalette[index % _chartPalette.length];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportTimeframe _selectedTimeframe = _ReportTimeframe.currentMonth;
  _ReportSection _selectedSection = _ReportSection.balanceMix;
  String? _selectedExpenseParentCategory;
  DateTime? _customRangeStart;
  DateTime? _customRangeEnd;

  late _DateRange _expenseCompareA;
  late _DateRange _expenseCompareB;
  late _DateRange _investmentCompareA;
  late _DateRange _investmentCompareB;

  final http.Client _httpClient = http.Client();
  late final GoldPriceService _goldPriceService;
  final Map<String, String> _nseHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.nseindia.com/',
    'Connection': 'keep-alive',
  };
  final Map<String, String> _nseCookies = {};
  bool _nseSessionReady = false;

  @override
  void initState() {
    super.initState();
    _goldPriceService = GoldPriceService(httpClient: _httpClient);
    final now = DateTime.now();
    _expenseCompareA = _DateRange.forTimeframe(_ReportTimeframe.currentMonth, now);
    _expenseCompareB = _DateRange.forTimeframe(_ReportTimeframe.quarter, now);
    _investmentCompareA = _DateRange.forTimeframe(_ReportTimeframe.currentMonth, now);
    _investmentCompareB = _DateRange.forTimeframe(_ReportTimeframe.halfYear, now);
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<InvestmentHolding>('investments').listenable(),
      builder: (context, Box<InvestmentHolding> investmentBox, _) {
        return ValueListenableBuilder(
          valueListenable: Hive.box<Transaction>('transactions').listenable(),
          builder: (context, Box<Transaction> box, _) {
            final transactions = box.values.toList()..sort((a, b) => a.date.compareTo(b.date));
            final holdings = investmentBox.values.toList();
            final currencyCode = AppSettings.getCurrency();
            String formatter(double value) => AppSettings.formatCurrency(value, currencyCode);

            return ScrollShadowWrapper(
              builder: (controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _buildHeader(),
                const SizedBox(height: 18),
                _buildSectionSelector(),
                const SizedBox(height: 18),
                _buildTimeframeSelector(),
                const SizedBox(height: 18),
                ..._buildSectionContent(transactions, holdings, formatter),
              ],
            ),
          );
        },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151F3B),
            Color(0xFF1D336A),
            Color(0xFF112143),
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finance Intelligence',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Compare expenses, investments, and in-hand balance with gradient-powered charts and date-range analytics.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return _ReportCard(
      title: 'Analysis Range',
      subtitle: 'Select timeframe for charts.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ReportTimeframe.values.map((timeframe) {
                final isSelected = timeframe == _selectedTimeframe;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(
                    timeframe.label,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selectedColor: const Color(0xFF7A85FF),
                  backgroundColor: const Color(0xFF11182E),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onSelected: (_) => setState(() {
                    _selectedTimeframe = timeframe;
                    if (timeframe == _ReportTimeframe.custom) {
                      _customRangeStart ??= DateTime.now().subtract(const Duration(days: 30));
                      _customRangeEnd ??= DateTime.now();
                    } else {
                      _customRangeStart = null;
                      _customRangeEnd = null;
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          if (_selectedTimeframe == _ReportTimeframe.custom) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    title: 'From',
                    value: _customRangeStart != null
                        ? _DateRange._formatDate(_customRangeStart!)
                        : 'Select date',
                    onTap: () async {
                      final picked = await _pickCustomDate(context, true);
                      if (picked != null) {
                        setState(() {
                          _customRangeStart = picked;
                          if (_customRangeEnd != null && _customRangeEnd!.isBefore(picked)) {
                            _customRangeEnd = picked;
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    title: 'To',
                    value: _customRangeEnd != null
                        ? _DateRange._formatDate(_customRangeEnd!)
                        : 'Select date',
                    onTap: () async {
                      final picked = await _pickCustomDate(context, false);
                      if (picked != null) {
                        setState(() {
                          _customRangeEnd = picked;
                          if (_customRangeStart != null && picked.isBefore(_customRangeStart!)) {
                            _customRangeStart = picked;
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_customRangeStart != null && _customRangeEnd != null) ...[
              const SizedBox(height: 14),
              Text(
                'Custom range: ${_DateRange(start: _customRangeStart!, end: _customRangeEnd!).label}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<DateTime?> _pickCustomDate(BuildContext context, bool isStart) async {
    final initialDate = isStart
        ? _customRangeStart ?? DateTime.now().subtract(const Duration(days: 30))
        : _customRangeEnd ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7A85FF),
              surface: Color(0xFF10182E),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF10182E)),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }

  _DateRange get _activeRange {
    if (_customRangeStart != null && _customRangeEnd != null) {
      return _DateRange(start: _customRangeStart!, end: _customRangeEnd!);
    }
    return _DateRange.forTimeframe(_selectedTimeframe, DateTime.now());
  }

  Widget _buildSectionSelector() {
    return _ReportCard(
      title: 'Report View',
      subtitle: 'Switch between report areas.',
      child: SegmentedButton<_ReportSection>(
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? const Color(0xFF2C417A) : const Color(0xFF0E1528);
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          alignment: Alignment.center,
        ),
        segments: _ReportSection.values.map((section) {
          return ButtonSegment<_ReportSection>(
            value: section,
            label: Center(
              child: Text(
                section.label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList(),
        selected: <_ReportSection>{_selectedSection},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            final newSection = selection.first;
            setState(() {
              _selectedSection = newSection;
            });
            if (newSection == _ReportSection.investmentAnalysis) {
              _refreshInvestmentPrices();
              _refreshGoldPrices();
            }
          }
        },
      ),
    );
  }

  List<Widget> _buildSectionContent(
    List<Transaction> transactions,
    List<InvestmentHolding> holdings,
    String Function(double) formatter,
  ) {
    switch (_selectedSection) {
      case _ReportSection.balanceMix:
        return [
          _buildBalanceCharts(transactions, formatter),
        ];
      case _ReportSection.expenseAnalysis:
        return [
          _buildExpenseCategorySection(transactions, formatter),
        ];
      case _ReportSection.investmentAnalysis:
        return [
          _buildInvestmentAnalysis(holdings, formatter),
        ];
    }
  }

  Future<void> _refreshInvestmentPrices() async {
    final investmentBox = Hive.box<InvestmentHolding>('investments');
    final holdings = investmentBox.values.toList();
    final symbols = holdings
        .map((holding) => holding.symbol.trim().toUpperCase())
        .where((symbol) => symbol.isNotEmpty)
        .toSet();

    if (symbols.isEmpty) {
      return;
    }

    for (final symbol in symbols) {
      final price = await _fetchNseStockPrice(symbol);
      if (price == null) {
        continue;
      }

      for (var index = 0; index < holdings.length; index++) {
        final holding = holdings[index];
        if (holding.symbol.trim().toUpperCase() != symbol) {
          continue;
        }
        final updated = InvestmentHolding(
          id: holding.id,
          type: holding.type,
          name: holding.name,
          quantity: holding.quantity,
          buyUnitPrice: holding.buyUnitPrice,
          currentUnitPrice: price,
          unitLabel: holding.unitLabel,
          purchaseDate: holding.purchaseDate,
          notes: holding.notes,
          symbol: holding.symbol,
          exchange: holding.exchange,
        );
        await investmentBox.putAt(index, updated);
      }
    }
  }

  Future<double?> _fetchNseStockPrice(String symbol) async {
    try {
      if (!_nseSessionReady) {
        await _initNseSession();
      }
      final uri = Uri.parse('https://www.nseindia.com/api/quote-equity?symbol=${Uri.encodeComponent(symbol)}');
      final headers = Map<String, String>.from(_nseHeaders);
      final cookieValue = _cookieHeaderValue();
      if (cookieValue.isNotEmpty) {
        headers['Cookie'] = cookieValue;
      }
      final resp = await _httpClient.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      _updateCookiesFromResponse(resp);
      if (resp.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic> data = jsonDecode(resp.body);
      final priceInfo = data['priceInfo'] ?? {};
      final dynamic lastPrice = priceInfo['lastPrice'] ?? priceInfo['last_price'] ?? priceInfo['last'];
      if (lastPrice is num) {
        return lastPrice.toDouble();
      }
      if (lastPrice is String) {
        return double.tryParse(lastPrice.replaceAll(',', ''));
      }
    } catch (_) {
      // ignore network errors
    }
    return null;
  }

  Future<void> _initNseSession() async {
    try {
      final resp = await _httpClient.get(Uri.parse('https://www.nseindia.com'), headers: _nseHeaders).timeout(const Duration(seconds: 8));
      _updateCookiesFromResponse(resp);
      await Future.delayed(const Duration(milliseconds: 400));
      _nseSessionReady = true;
    } catch (_) {
      _nseSessionReady = false;
    }
  }

  void _updateCookiesFromResponse(http.Response resp) {
    final setCookie = resp.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) {
      return;
    }
    final cookieParts = setCookie.split(RegExp(r',\s*(?=[^;]+=)'));
    for (final part in cookieParts) {
      final cookiePair = part.split(';').firstWhere((item) => item.contains('='), orElse: () => '');
      if (cookiePair.isEmpty) {
        continue;
      }
      final kv = cookiePair.split('=');
      if (kv.length < 2) {
        continue;
      }
      _nseCookies[kv[0].trim()] = kv.sublist(1).join('=');
    }
  }

  String _cookieHeaderValue() {
    return _nseCookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  Future<void> _refreshGoldPrices() async {
    final investmentBox = Hive.box<InvestmentHolding>('investments');
    final holdings = investmentBox.values.toList();
    
    // Find gold holdings
    final goldHoldings = holdings
        .where((holding) {
          final type = holding.type.toLowerCase();
          return type.contains('gold') || type == 'precious metal';
        })
        .toList();

    if (goldHoldings.isEmpty) {
      return;
    }

    // Get current gold price from the service
    final goldPrice = await _goldPriceService.fetchGoldPricePerGram(
      currency: AppSettings.getCurrency(),
    );

    if (goldPrice == null) {
      return;
    }

    // Update all gold holdings with the new price
    for (var index = 0; index < holdings.length; index++) {
      final holding = holdings[index];
      final type = holding.type.toLowerCase();
      
      if (!type.contains('gold') && type != 'precious metal') {
        continue;
      }

      final updated = InvestmentHolding(
        id: holding.id,
        type: holding.type,
        name: holding.name,
        quantity: holding.quantity,
        buyUnitPrice: holding.buyUnitPrice,
        currentUnitPrice: goldPrice,
        unitLabel: holding.unitLabel,
        purchaseDate: holding.purchaseDate,
        notes: holding.notes,
        symbol: holding.symbol,
        exchange: holding.exchange,
      );
      await investmentBox.putAt(index, updated);
    }
  }

  Widget _buildInvestmentAnalysis(
    List<InvestmentHolding> holdings,
    String Function(double) formatter,
  ) {
    final stocks = _aggregateInvestmentHoldings(holdings, excludeGold: true);
    final goldHoldings = _aggregateGoldHoldings(holdings);

    if (stocks.isEmpty && goldHoldings.isEmpty) {
      return _ReportCard(
        title: 'Investment Analysis',
        subtitle: 'Compare all tracked investments using buy and current price pairs.',
        child: const _EmptyChart(message: 'No investments available.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stocks.isNotEmpty)
          _buildStockAnalysisCard(stocks, formatter),
        if (stocks.isNotEmpty && goldHoldings.isNotEmpty)
          const SizedBox(height: 24),
        if (goldHoldings.isNotEmpty)
          _buildGoldAnalysisCard(goldHoldings, formatter),
      ],
    );
  }

  Widget _buildStockAnalysisCard(
    List<_AggregatedHolding> stocks,
    String Function(double) formatter,
  ) {
    final maxPrice = stocks.fold<double>(0, (currentMax, item) {
      return math.max(currentMax, math.max(item.avgBuyPrice, item.avgCurrentPrice));
    });
    final totalInvested = stocks.fold<double>(0, (sum, item) => sum + item.totalInvestedAmount);
    final totalCurrent = stocks.fold<double>(0, (sum, item) => sum + item.totalCurrentValue);
    final totalProfitLoss = totalCurrent - totalInvested;

    return _ReportCard(
      title: 'Stock Analysis',
      subtitle: 'Compare buy price and current price for each stock holding.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(label: 'Total Invested', value: formatter(totalInvested)),
              _MetricChip(
                label: 'Total P/L',
                value: '${totalProfitLoss >= 0 ? '+' : ''}${formatter(totalProfitLoss)}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Horizontal stock bar graph (two bars per stock).',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: math.min(720, stocks.length * 112.0),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: stocks.length,
              physics: const ClampingScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final item = stocks[index];
                return _buildStockBarGroup(item, maxPrice, formatter, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldAnalysisCard(
    List<_AggregatedHolding> goldHoldings,
    String Function(double) formatter,
  ) {
    final maxPrice = goldHoldings.fold<double>(0, (currentMax, item) {
      return math.max(currentMax, math.max(item.avgBuyPrice, item.avgCurrentPrice));
    });
    final totalInvested = goldHoldings.fold<double>(0, (sum, item) => sum + item.totalInvestedAmount);
    final totalCurrent = goldHoldings.fold<double>(0, (sum, item) => sum + item.totalCurrentValue);
    final totalProfitLoss = totalCurrent - totalInvested;

    return _ReportCard(
      title: 'Gold Analysis',
      subtitle: 'Compare buy price and current price for each gold holding.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(label: 'Total Invested', value: formatter(totalInvested)),
              _MetricChip(
                label: 'Total P/L',
                value: '${totalProfitLoss >= 0 ? '+' : ''}${formatter(totalProfitLoss)}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Horizontal gold bar graph (two bars per gold item).',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: math.min(720, goldHoldings.length * 112.0),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: goldHoldings.length,
              physics: const ClampingScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final item = goldHoldings[index];
                return _buildGoldBarGroup(item, maxPrice, formatter, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockBarGroup(
    _AggregatedHolding stock,
    double maxPrice,
    String Function(double) formatter,
    int index,
  ) {
    const buyGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF00D1FF), Color(0xFF007BFF)],
    );
    final currentGradient = stock.profitLoss >= 0
        ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
          )
        : const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF512F), Color(0xFFFF9A9E)],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stock.symbol} · ${stock.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Qty ${stock.totalQuantity.toStringAsFixed(2)} · P/L ${formatter(stock.profitLoss)} (${stock.profitLossPercent.toStringAsFixed(1)}%)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: stock.profitLoss >= 0 ? const Color(0xFF0A4F2D) : const Color(0xFF4F0A1A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                stock.profitLoss >= 0 ? '+${stock.profitLossPercent.toStringAsFixed(1)}%' : '${stock.profitLossPercent.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildHorizontalBar('Buy', stock.avgBuyPrice, maxPrice, buyGradient, formatter),
        const SizedBox(height: 12),
        _buildHorizontalBar('Current', stock.avgCurrentPrice, maxPrice, currentGradient, formatter),
      ],
    );
  }

  Widget _buildHorizontalBar(
    String label,
    double value,
    double maxValue,
    LinearGradient gradient,
    String Function(double) formatter,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            Text(formatter(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = maxValue <= 0 ? 0.0 : constraints.maxWidth * (value / maxValue).clamp(0.0, 1.0);
            return Container(
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: barWidth,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGoldBarGroup(
    _AggregatedHolding gold,
    double maxPrice,
    String Function(double) formatter,
    int index,
  ) {
    const buyGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    );
    final currentGradient = gold.profitLoss >= 0
        ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
          )
        : const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF512F), Color(0xFFFF9A9E)],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${gold.symbol} · ${gold.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Qty ${gold.totalQuantity.toStringAsFixed(2)} ${gold.unitLabel} · P/L ${formatter(gold.profitLoss)} (${gold.profitLossPercent.toStringAsFixed(1)}%)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: gold.profitLoss >= 0 ? const Color(0xFF0A4F2D) : const Color(0xFF4F0A1A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                gold.profitLoss >= 0 ? '+${gold.profitLossPercent.toStringAsFixed(1)}%' : '${gold.profitLossPercent.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildHorizontalBar('Buy', gold.avgBuyPrice, maxPrice, buyGradient, formatter),
        const SizedBox(height: 12),
        _buildHorizontalBar('Current', gold.avgCurrentPrice, maxPrice, currentGradient, formatter),
      ],
    );
  }

  List<_AggregatedHolding> _aggregateInvestmentHoldings(List<InvestmentHolding> holdings, {bool excludeGold = false}) {
    final grouped = <String, _AggregatedHolding>{};
    for (final holding in holdings) {
      final holdingType = holding.type.toLowerCase();
      
      if (excludeGold && (holdingType.contains('gold') || holdingType == 'precious metal')) {
        continue;
      }
      
      final symbol = holding.symbol.trim().toUpperCase();
      if (symbol.isEmpty && holdingType != 'stocks') {
        continue;
      }
      final key = symbol.isNotEmpty ? symbol : holding.name.trim();
      if (key.isEmpty) {
        continue;
      }

      final existing = grouped[key];
      final invested = holding.quantity * holding.buyUnitPrice;
      final currentValue = holding.quantity * holding.currentUnitPrice;
      if (existing == null) {
        grouped[key] = _AggregatedHolding(
          symbol: symbol.isNotEmpty ? symbol : holding.name,
          name: holding.name,
          totalQuantity: holding.quantity,
          totalInvestedAmount: invested,
          totalCurrentValue: currentValue,
          unitLabel: holding.unitLabel,
        );
      } else {
        grouped[key] = existing.copyWith(
          addQuantity: holding.quantity,
          addInvestedAmount: invested,
          addCurrentValue: currentValue,
        );
      }
    }

    final items = grouped.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
    return items;
  }

  List<_AggregatedHolding> _aggregateGoldHoldings(List<InvestmentHolding> holdings) {
    final grouped = <String, _AggregatedHolding>{};
    for (final holding in holdings) {
      final holdingType = holding.type.toLowerCase();
      
      if (!holdingType.contains('gold') && holdingType != 'precious metal') {
        continue;
      }
      
      final key = holding.name.trim();
      if (key.isEmpty) {
        continue;
      }

      final existing = grouped[key];
      final invested = holding.quantity * holding.buyUnitPrice;
      final currentValue = holding.quantity * holding.currentUnitPrice;
      if (existing == null) {
        grouped[key] = _AggregatedHolding(
          symbol: 'XAU',
          name: holding.name,
          totalQuantity: holding.quantity,
          totalInvestedAmount: invested,
          totalCurrentValue: currentValue,
          unitLabel: holding.unitLabel,
        );
      } else {
        grouped[key] = existing.copyWith(
          addQuantity: holding.quantity,
          addInvestedAmount: invested,
          addCurrentValue: currentValue,
        );
      }
    }

    final items = grouped.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Widget _buildBalanceCharts(
    List<Transaction> transactions,
    String Function(double) formatter,
  ) {
    final range = _activeRange;
    final rangeTransactions = range.apply(transactions);
    final summary = _BalanceSummary.fromTransactions(rangeTransactions);
    final chartItems = summary.toChartItems();
    final totalTracked = summary.totalTracked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text(
          'Balance Mix',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_selectedTimeframe.label} · Expense vs investment vs in-hand amount',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.3,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 860;
            final expenseBreakdown = _buildExpenseBreakdown(rangeTransactions);
            final totalExpenses = expenseBreakdown.fold<double>(0, (sum, item) => sum + item.amount);

            final chartWidget = SizedBox(
              height: 416,
              child: totalExpenses <= 0
                  ? const _EmptyChart(message: 'No expense data available for this timeframe.')
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _RoundedPieChart(
                            items: expenseBreakdown,
                            total: totalExpenses,
                            size: 416,
                            innerRadius: 129,
                            thicknessScale: 1.05,
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppSettings.formatCurrency(totalExpenses, AppSettings.getCurrency()),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total Spending',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            );

            final legendWidget = Column(
              children: chartItems.map((item) {
                final percentage = totalTracked == 0 ? 0.0 : (item.amount / totalTracked) * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LegendTile(
                    label: item.label,
                    amount: formatter(item.amount),
                    percentage: '${percentage.toStringAsFixed(1)}%',
                    colors: item.gradient.colors,
                  ),
                );
              }).toList(),
            );

            if (stacked) {
              return Column(
                children: [
                  chartWidget,
                  const SizedBox(height: 24),
                  legendWidget,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: constraints.maxWidth * 0.5,
                  child: Center(child: chartWidget),
                ),
                const SizedBox(width: 18),
                Expanded(child: legendWidget),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricChip(label: 'Income', value: formatter(summary.income)),
            _MetricChip(label: 'Tracked Total', value: formatter(summary.totalTracked)),
            _MetricChip(label: 'Range', value: range.label),
          ],
        ),
      ],
    );
  }

  Widget _buildExpenseCategorySection(
    List<Transaction> transactions,
    String Function(double) formatter,
  ) {
    final range = _activeRange;
    final rangeTransactions = range.apply(transactions);
    final parentCategories = _buildExpenseParentCategories(rangeTransactions);
    final selectedCategory = parentCategories.contains(_selectedExpenseParentCategory)
        ? _selectedExpenseParentCategory
        : null;
    final expenseBreakdown = _buildExpenseBreakdown(rangeTransactions);
    final totalExpenses = expenseBreakdown.fold<double>(0, (sum, item) => sum + item.amount);

    return _ReportCard(
      title: 'Expense Category Analysis',
      subtitle: '${_selectedTimeframe.label} · Parent-category classification with money and percentage',
      child: rangeTransactions.where((t) => t.type == 'expense').isEmpty
          ? const _EmptyChart(message: 'No expense data available in this timeframe.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExpenseCategoryFilter(parentCategories),
                const SizedBox(height: 26),
                if (selectedCategory == null) ...[
                  SizedBox(
                    height: 416, // increased by ~30%
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _RoundedPieChart(
                          items: expenseBreakdown,
                          total: totalExpenses,
                          size: 416,
                          innerRadius: 129,
                          thicknessScale: 1.05,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Total Spending',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatter(totalExpenses),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...expenseBreakdown.map((item) {
                    final percentage = totalExpenses == 0 ? 0.0 : (item.amount / totalExpenses) * 100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LegendTile(
                        label: item.label,
                        amount: formatter(item.amount),
                        percentage: '${percentage.toStringAsFixed(1)}%',
                        colors: item.gradient.colors,
                      ),
                    );
                  }),
                ] else ...[
                  _buildChildCategoryAnalysis(rangeTransactions, selectedCategory, formatter),
                ],
              ],
            ),
    );
  }

  Widget _buildComparisonSection({
    required String title,
    required String subtitle,
    required String metricType,
    required _DateRange rangeA,
    required _DateRange rangeB,
    required ValueChanged<_DateRange> onRangeAChanged,
    required ValueChanged<_DateRange> onRangeBChanged,
    required List<Transaction> transactions,
    required String Function(double) formatter,
    required List<Color> palette,
  }) {
    final amountA = _sumByType(rangeA.apply(transactions), metricType);
        final amountB = _sumByType(rangeB.apply(transactions), metricType);
    final total = amountA + amountB;
    final percentA = total == 0 ? 0.0 : (amountA / total) * 100;
    final percentB = total == 0 ? 0.0 : (amountB / total) * 100;
    final delta = amountB - amountA;
    final maxY = math.max(amountA, amountB);
    final gradientA = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        palette[0],
        Color.lerp(palette[0], palette[1], 0.45)!,
        palette[1],
      ],
    );
    final gradientB = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        palette[1],
        Color.lerp(palette[1], palette[0], 0.45)!,
        palette[0],
      ],
    );
    final trendMonths = _buildMonthAxis(rangeA, rangeB);
    final seriesA = _buildMonthlySeries(
      range: rangeA,
      transactions: transactions,
      metricType: metricType,
      axisMonths: trendMonths,
    );
    final seriesB = _buildMonthlySeries(
      range: rangeB,
      transactions: transactions,
      metricType: metricType,
      axisMonths: trendMonths,
    );
    final trendMax = <double>[
      ...seriesA.map((point) => point.value),
      ...seriesB.map((point) => point.value),
    ].fold<double>(0, (current, value) => math.max(current, value));

    return _ReportCard(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              if (stacked) {
                return Column(
                  children: [
                    _DateRangeEditor(
                      label: 'Range A',
                      range: rangeA,
                      accent: palette[0],
                      onChanged: onRangeAChanged,
                    ),
                    const SizedBox(height: 12),
                    _DateRangeEditor(
                      label: 'Range B',
                      range: rangeB,
                      accent: palette[1],
                      onChanged: onRangeBChanged,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _DateRangeEditor(
                      label: 'Range A',
                      range: rangeA,
                      accent: palette[0],
                      onChanged: onRangeAChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateRangeEditor(
                      label: 'Range B',
                      range: rangeB,
                      accent: palette[1],
                      onChanged: onRangeBChanged,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 364, // increased by ~30%
            child: total == 0
                ? const _EmptyChart(message: 'No data found in the selected ranges.')
                : BarChart(
                    BarChartData(
                      maxY: maxY == 0 ? 10 : maxY * 1.25,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY == 0 ? 2 : maxY / 4,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Colors.white10,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() == 0) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Text('Range A', style: TextStyle(color: Colors.white70)),
                                );
                              }
                              if (value.toInt() == 1) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Text('Range B', style: TextStyle(color: Colors.white70)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: amountA,
                              width: 34,
                              borderRadius: BorderRadius.circular(18),
                              gradient: gradientA,
                            ),
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: amountB,
                              width: 34,
                              borderRadius: BorderRadius.circular(18),
                              gradient: gradientB,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1528),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Trend',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'See how the selected ranges move month by month.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                      SizedBox(
                        height: 338,
                    child: trendMonths.isEmpty
                      ? const _EmptyChart(message: 'No monthly trend available for the selected ranges.')
                      : LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: math.max(trendMonths.length - 1, 0).toDouble(),
                                minY: 0,
                                maxY: trendMax == 0 ? 10 : trendMax * 1.25,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: trendMax == 0 ? 2 : trendMax / 4,
                              getDrawingHorizontalLine: (_) => const FlLine(
                                color: Colors.white10,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 36,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= trendMonths.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        DateFormat('MMM yy').format(trendMonths[index]),
                                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (spots) {
                                  return spots.map((spot) {
                                    final month = trendMonths[spot.x.toInt()];
                                    return LineTooltipItem(
                                      '${DateFormat('MMM yyyy').format(month)}\n${formatter(spot.y)}',
                                      const TextStyle(color: Colors.white),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: seriesA.map((point) => FlSpot(point.x.toDouble(), point.value)).toList(),
                                isCurved: true,
                                gradient: gradientA,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: gradientA.colors
                                        .map((color) => color.withValues(alpha: 0.16))
                                        .toList(),
                                  ),
                                ),
                              ),
                              LineChartBarData(
                                spots: seriesB.map((point) => FlSpot(point.x.toDouble(), point.value)).toList(),
                                isCurved: true,
                                gradient: gradientB,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: gradientB.colors
                                        .map((color) => color.withValues(alpha: 0.14))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 600;
                    final items = [
                      _TrendLegend(
                        label: 'Range A trend',
                        colors: gradientA.colors,
                      ),
                      _TrendLegend(
                        label: 'Range B trend',
                        colors: gradientB.colors,
                      ),
                    ];
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          items[0],
                          const SizedBox(height: 8),
                          items[1],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: items[0]),
                        const SizedBox(width: 12),
                        Expanded(child: items[1]),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              if (stacked) {
                return Column(
                  children: [
                    _ComparisonBlock(
                      label: 'Range A',
                      value: formatter(amountA),
                      percentage: percentA,
                      gradient: gradientA,
                    ),
                    const SizedBox(height: 12),
                    _ComparisonBlock(
                      label: 'Range B',
                      value: formatter(amountB),
                      percentage: percentB,
                      gradient: gradientB,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _ComparisonBlock(
                      label: 'Range A',
                      value: formatter(amountA),
                      percentage: percentA,
                      gradient: gradientA,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ComparisonBlock(
                      label: 'Range B',
                      value: formatter(amountB),
                      percentage: percentB,
                      gradient: gradientB,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(label: 'Delta', value: '${delta >= 0 ? '+' : ''}${formatter(delta)}'),
              _MetricChip(label: 'Range A %', value: '${percentA.toStringAsFixed(1)}%'),
              _MetricChip(label: 'Range B %', value: '${percentB.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  List<_CategoryChartItem> _buildExpenseBreakdown(List<Transaction> transactions) {
    final totals = <String, double>{};

    for (final transaction in transactions.where((t) => t.type == 'expense')) {
      final parent = _parentCategory(transaction.category);
      totals[parent] = (totals[parent] ?? 0) + transaction.amount;
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final gradients = List.generate(entries.length, (index) => _chartGradientAt(index));

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final gradient = gradients[index % gradients.length];
      return _CategoryChartItem(
        label: entry.key,
        amount: entry.value,
        gradient: gradient,
        color: gradient.colors.first,
      );
    });
  }

  String _parentCategory(String category) {
    final parts = category.split(' - ');
    return parts.first.trim();
  }

  String _childCategory(String category) {
    final parts = category.split(' - ');
    if (parts.length > 1) {
      return parts.sublist(1).join(' - ').trim();
    }
    return category.trim();
  }

  List<String> _buildExpenseParentCategories(List<Transaction> transactions) {
    final parents = transactions
        .where((t) => t.type == 'expense')
        .map((t) => _parentCategory(t.category))
        .toSet()
        .toList();
    parents.sort((a, b) => a.compareTo(b));
    return parents;
  }

  List<_CategoryChartItem> _buildExpenseChildBreakdown(
    List<Transaction> transactions,
    String parentCategory,
  ) {
    final totals = <String, double>{};

    for (final transaction in transactions.where((t) => t.type == 'expense' && _parentCategory(t.category) == parentCategory)) {
      final child = _childCategory(transaction.category);
      totals[child] = (totals[child] ?? 0) + transaction.amount;
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final gradients = List.generate(entries.length, (index) => _chartGradientAt(index));

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final gradient = gradients[index % gradients.length];
      return _CategoryChartItem(
        label: entry.key,
        amount: entry.value,
        gradient: gradient,
        color: gradient.colors.first,
      );
    });
  }

  Widget _buildExpenseCategoryFilter(List<String> categories) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1528),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedExpenseParentCategory,
                isExpanded: true,
                dropdownColor: const Color(0xFF10182E),
                hint: const Text('Select parent category', style: TextStyle(color: Colors.white70)),
                icon: const Icon(Icons.expand_more, color: Colors.white70),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All categories', style: TextStyle(color: Colors.white70)),
                  ),
                  ...categories.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category,
                      child: Text(category, style: const TextStyle(color: Colors.white)),
                    ),
                  )
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedExpenseParentCategory = value;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildCategoryAnalysis(
    List<Transaction> transactions,
    String parentCategory,
    String Function(double) formatter,
  ) {
    final childBreakdown = _buildExpenseChildBreakdown(transactions, parentCategory);
    final total = childBreakdown.fold<double>(0, (sum, item) => sum + item.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Child categories for $parentCategory',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 416,
          child: childBreakdown.isEmpty
              ? const _EmptyChart(message: 'No child categories found for this parent category.')
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _RoundedPieChart(
                        items: childBreakdown,
                        total: total,
                        size: 416,
                        innerRadius: 112,
                        thicknessScale: 1.05,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatter(total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 18),
        ...childBreakdown.map((item) {
          final percentage = total == 0 ? 0.0 : (item.amount / total) * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LegendTile(
              label: item.label,
              amount: formatter(item.amount),
              percentage: '${percentage.toStringAsFixed(1)}%',
              colors: item.gradient.colors,
            ),
          );
        }),
      ],
    );
  }

  double _sumByType(List<Transaction> transactions, String type) {
    return transactions.where((t) => t.type == type).fold(0.0, (sum, t) => sum + t.amount);
  }

  List<DateTime> _buildMonthAxis(_DateRange rangeA, _DateRange rangeB) {
    final firstMonth = _monthStart(
      rangeA.start.isBefore(rangeB.start) ? rangeA.start : rangeB.start,
    );
    final lastMonth = _monthStart(
      rangeA.end.isAfter(rangeB.end) ? rangeA.end : rangeB.end,
    );

    final months = <DateTime>[];
    var cursor = firstMonth;
    while (!cursor.isAfter(lastMonth)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return months;
  }

  List<_MonthlyPoint> _buildMonthlySeries({
    required _DateRange range,
    required List<Transaction> transactions,
    required String metricType,
    required List<DateTime> axisMonths,
  }) {
    final totals = <String, double>{};
    for (final transaction in range.apply(transactions).where((t) => t.type == metricType)) {
      final month = _monthStart(transaction.date);
      final key = _monthKey(month);
      totals[key] = (totals[key] ?? 0) + transaction.amount;
    }

    return List.generate(axisMonths.length, (index) {
      final month = axisMonths[index];
      final inRange = !_monthStart(month).isBefore(_monthStart(range.start)) &&
          !_monthStart(month).isAfter(_monthStart(range.end));
      final value = inRange ? (totals[_monthKey(month)] ?? 0.0) : 0.0;
      return _MonthlyPoint(x: index, value: value);
    });
  }

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  String _monthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

enum _ReportTimeframe {
  currentMonth('Current Month'),
  quarter('Quarter'),
  halfYear('Half Year'),
  fullYear('Full Year'),
  custom('Custom');

  const _ReportTimeframe(this.label);

  final String label;
}

enum _ReportSection {
  balanceMix('Balance Mix', Icons.pie_chart_outline_rounded),
  expenseAnalysis('Expense Analysis', Icons.receipt_long_rounded),
  investmentAnalysis('Investment Analysis', Icons.trending_up_rounded);

  const _ReportSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _AggregatedHolding {
  const _AggregatedHolding({
    required this.symbol,
    required this.name,
    required this.totalQuantity,
    required this.totalInvestedAmount,
    required this.totalCurrentValue,
    this.unitLabel = '',
  });

  final String symbol;
  final String name;
  final double totalQuantity;
  final double totalInvestedAmount;
  final double totalCurrentValue;
  final String unitLabel;

  double get avgBuyPrice => totalQuantity == 0 ? 0 : totalInvestedAmount / totalQuantity;
  double get avgCurrentPrice => totalQuantity == 0 ? 0 : totalCurrentValue / totalQuantity;
  double get profitLoss => totalCurrentValue - totalInvestedAmount;
  double get profitLossPercent => totalInvestedAmount == 0 ? 0 : (profitLoss / totalInvestedAmount) * 100;

  _AggregatedHolding copyWith({
    double? addQuantity,
    double? addInvestedAmount,
    double? addCurrentValue,
  }) {
    return _AggregatedHolding(
      symbol: symbol,
      name: name,
      totalQuantity: totalQuantity + (addQuantity ?? 0),
      totalInvestedAmount: totalInvestedAmount + (addInvestedAmount ?? 0),
      totalCurrentValue: totalCurrentValue + (addCurrentValue ?? 0),
      unitLabel: unitLabel,
    );
  }
}

class _DateRange {
  const _DateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  String get label => '${_formatDate(start)} - ${_formatDate(end)}';

  List<Transaction> apply(List<Transaction> transactions) {
    final safeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return transactions.where((transaction) {
      return !transaction.date.isBefore(start) && !transaction.date.isAfter(safeEnd);
    }).toList();
  }

  _DateRange copyWith({
    DateTime? start,
    DateTime? end,
  }) {
    final nextStart = start ?? this.start;
    final nextEnd = end ?? this.end;
    if (nextEnd.isBefore(nextStart)) {
      return _DateRange(start: nextStart, end: nextStart);
    }
    return _DateRange(start: nextStart, end: nextEnd);
  }

  static _DateRange forTimeframe(_ReportTimeframe timeframe, DateTime now) {
    final end = DateTime(now.year, now.month, now.day);

    switch (timeframe) {
      case _ReportTimeframe.currentMonth:
        return _DateRange(
          start: DateTime(now.year, now.month, 1),
          end: end,
        );
      case _ReportTimeframe.quarter:
        return _DateRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: end,
        );
      case _ReportTimeframe.halfYear:
        return _DateRange(
          start: DateTime(now.year, now.month - 5, 1),
          end: end,
        );
      case _ReportTimeframe.fullYear:
        return _DateRange(
          start: DateTime(now.year, now.month - 11, 1),
          end: end,
        );
      case _ReportTimeframe.custom:
        return _DateRange(
          start: DateTime(now.year, now.month, 1),
          end: end,
        );
    }
  }

  static String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }
}

class _BalanceSummary {
  const _BalanceSummary({
    required this.income,
    required this.expense,
    required this.investment,
    required this.inHand,
  });

  final double income;
  final double expense;
  final double investment;
  final double inHand;

  double get totalTracked => expense + investment + inHand;

  List<_CategoryChartItem> toChartItems() {
    return [
      _CategoryChartItem(
        label: 'Expenses',
        shortLabel: 'Expense',
        amount: expense < 0 ? 0 : expense,
        gradient: _chartGradientAt(0),
        color: _chartColorAt(0),
      ),
      _CategoryChartItem(
        label: 'Investments',
        shortLabel: 'Invest',
        amount: investment < 0 ? 0 : investment,
        gradient: _chartGradientAt(2),
        color: _chartColorAt(2),
      ),
      _CategoryChartItem(
        label: 'In Hand',
        shortLabel: 'In Hand',
        amount: inHand < 0 ? 0 : inHand,
        gradient: _chartGradientAt(4),
        color: _chartColorAt(4),
      ),
    ];
  }

  factory _BalanceSummary.fromTransactions(List<Transaction> transactions) {
    final income = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    final expense = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    final investment = transactions.where((t) => t.type == 'investment').fold(0.0, (sum, t) => sum + t.amount);
    final inHand = math.max(income - expense - investment, 0.0);

    return _BalanceSummary(
      income: income,
      expense: expense,
      investment: investment,
      inHand: inHand,
    );
  }
}

class _CategoryChartItem {
  const _CategoryChartItem({
    required this.label,
    required this.amount,
    required this.gradient,
    required this.color,
    String? shortLabel,
  }) : shortLabel = shortLabel ?? label;

  final String label;
  final String shortLabel;
  final double amount;
  final LinearGradient gradient;
  final Color color;
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6AA8FF).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.3,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendTile extends StatelessWidget {
  const _LegendTile({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.colors,
  });

  final String label;
  final String amount;
  final String percentage;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1528),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: colors),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(amount, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Text(
            percentage,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartBadge extends StatelessWidget {
  const _PieChartBadge({
    required this.percentage,
  });

  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF08101F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '${percentage.toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1528),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CategoryProgressTile extends StatelessWidget {
  const _CategoryProgressTile({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.gradient,
  });

  final String label;
  final String amount;
  final double percentage;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}% · $amount',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.white10),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (percentage / 100).clamp(0, 1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: gradient),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DateRangeEditor extends StatelessWidget {
  const _DateRangeEditor({
    required this.label,
    required this.range,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final _DateRange range;
  final Color accent;
  final ValueChanged<_DateRange> onChanged;

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? range.start : range.end,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: accent,
              surface: const Color(0xFF10182E),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF10182E)),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    onChanged(isStart ? range.copyWith(start: picked) : range.copyWith(end: picked));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1528),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _DateButton(
            title: 'Start',
            value: _DateRange._formatDate(range.start),
            onTap: () => _pickDate(context, true),
          ),
          const SizedBox(height: 10),
          _DateButton(
            title: 'End',
            value: _DateRange._formatDate(range.end),
            onTap: () => _pickDate(context, false),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121E39),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.calendar_month_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _ComparisonBlock extends StatelessWidget {
  const _ComparisonBlock({
    required this.label,
    required this.value,
    required this.percentage,
    required this.gradient,
  });

  final String label;
  final String value;
  final double percentage;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1528),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.white10),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (percentage / 100).clamp(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: gradient),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1528),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _MonthlyPoint {
  const _MonthlyPoint({
    required this.x,
    required this.value,
  });

  final int x;
  final double value;
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({
    required this.label,
    required this.colors,
  });

  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(colors: colors),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _RoundedPieChart extends StatelessWidget {
  const _RoundedPieChart({
    required this.items,
    required this.total,
    required this.size,
    required this.innerRadius,
    this.thicknessScale = 1.0,
  });

  final List<_CategoryChartItem> items;
  final double total;
  final double size;
  final double innerRadius;
  final double thicknessScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RoundedPiePainter(items: items, total: total, innerRadius: innerRadius, thicknessScale: thicknessScale),
      ),
    );
  }
}

class _RoundedPiePainter extends CustomPainter {
  _RoundedPiePainter({required this.items, required this.total, required this.innerRadius, required this.thicknessScale});

  final List<_CategoryChartItem> items;
  final double total;
  final double innerRadius;
  final double thicknessScale;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2;
    final baseThickness = outerRadius - innerRadius;
    final thickness = baseThickness * thicknessScale;
    var startAngle = -math.pi / 2;

    for (final item in items) {
      final sweep = (item.amount / total) * (math.pi * 2);

      // create a per-slice sweep gradient using the item's gradient colors if available
      final shaderColors = item.gradient.colors;
      final rect = Rect.fromCircle(center: center, radius: (innerRadius + outerRadius) / 2);
      final sweepGradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: shaderColors.isNotEmpty ? shaderColors : [item.color, item.color],
        transform: GradientRotation(0),
      );

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..shader = sweepGradient.createShader(rect);

      canvas.drawArc(rect, startAngle, sweep, false, paint);

      // draw percentage label at arc midpoint (skip for very small slices)
      final percentage = total == 0 ? 0.0 : (item.amount / total) * 100;
      if (percentage >= 3.0 && sweep > 0.1) {
        final mid = startAngle + sweep / 2;
        final labelRadius = innerRadius + thickness * 0.66; // slightly more outward
        final labelOffset = Offset(center.dx + math.cos(mid) * labelRadius, center.dy + math.sin(mid) * labelRadius);
        final text = '${percentage.toStringAsFixed(1)}%';
        final tp = TextPainter(
          text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();
        final textPos = labelOffset - Offset(tp.width / 2, tp.height / 2);
        tp.paint(canvas, textPos);
      }

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
