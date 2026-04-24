import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../utils/app_settings.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportTimeframe _selectedTimeframe = _ReportTimeframe.currentMonth;
  _ChartDisplay _balanceChartDisplay = _ChartDisplay.pie;
  _ChartDisplay _expenseChartDisplay = _ChartDisplay.bar;
  _ReportSection _selectedSection = _ReportSection.balanceMix;

  late _DateRange _expenseCompareA;
  late _DateRange _expenseCompareB;
  late _DateRange _investmentCompareA;
  late _DateRange _investmentCompareB;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _expenseCompareA = _DateRange.forTimeframe(_ReportTimeframe.currentMonth, now);
    _expenseCompareB = _DateRange.forTimeframe(_ReportTimeframe.quarter, now);
    _investmentCompareA = _DateRange.forTimeframe(_ReportTimeframe.currentMonth, now);
    _investmentCompareB = _DateRange.forTimeframe(_ReportTimeframe.halfYear, now);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Transaction>('transactions').listenable(),
      builder: (context, Box<Transaction> box, _) {
        final transactions = box.values.toList()..sort((a, b) => a.date.compareTo(b.date));
        final currencyCode = AppSettings.getCurrency();
        String formatter(double value) => AppSettings.formatCurrency(value, currencyCode);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildSectionSelector(),
            const SizedBox(height: 18),
            _buildTimeframeSelector(),
            const SizedBox(height: 18),
            ..._buildSectionContent(transactions, formatter),
          ],
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
      subtitle: 'Use one rolling timeframe for the main balance and expense category charts.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _ReportTimeframe.values.map((timeframe) {
          final isSelected = timeframe == _selectedTimeframe;
          return ChoiceChip(
            selected: isSelected,
            label: Text(timeframe.label),
            selectedColor: const Color(0xFF7A85FF),
            backgroundColor: const Color(0xFF11182E),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => setState(() => _selectedTimeframe = timeframe),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionSelector() {
    return _ReportCard(
      title: 'Report View',
      subtitle: 'Switch between the key report areas instead of scrolling through one long page.',
      child: SegmentedButton<_ReportSection>(
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? const Color(0xFF2C417A) : const Color(0xFF0E1528);
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
        ),
        segments: _ReportSection.values.map((section) {
          return ButtonSegment<_ReportSection>(
            value: section,
            label: Text(section.label),
            icon: Icon(section.icon),
          );
        }).toList(),
        selected: <_ReportSection>{_selectedSection},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            setState(() => _selectedSection = selection.first);
          }
        },
      ),
    );
  }

  List<Widget> _buildSectionContent(
    List<Transaction> transactions,
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
          const SizedBox(height: 18),
          _buildComparisonSection(
            title: 'Expense Comparison',
            subtitle: 'Pick any two date ranges from the calendar and compare expense totals.',
            metricType: 'expense',
            rangeA: _expenseCompareA,
            rangeB: _expenseCompareB,
            onRangeAChanged: (range) => setState(() => _expenseCompareA = range),
            onRangeBChanged: (range) => setState(() => _expenseCompareB = range),
            transactions: transactions,
            formatter: formatter,
            palette: const [
              Color(0xFFE11D48),
              Color(0xFFF97316),
            ],
          ),
        ];
      case _ReportSection.investmentAnalysis:
        return [
          _buildComparisonSection(
            title: 'Investment Comparison',
            subtitle: 'Pick any two date ranges from the calendar and compare investment totals.',
            metricType: 'investment',
            rangeA: _investmentCompareA,
            rangeB: _investmentCompareB,
            onRangeAChanged: (range) => setState(() => _investmentCompareA = range),
            onRangeBChanged: (range) => setState(() => _investmentCompareB = range),
            transactions: transactions,
            formatter: formatter,
            palette: const [
              Color(0xFF0EA5E9),
              Color(0xFF22C55E),
            ],
          ),
        ];
    }
  }

  Widget _buildBalanceCharts(
    List<Transaction> transactions,
    String Function(double) formatter,
  ) {
    final range = _DateRange.forTimeframe(_selectedTimeframe, DateTime.now());
    final rangeTransactions = range.apply(transactions);
    final summary = _BalanceSummary.fromTransactions(rangeTransactions);
    final chartItems = summary.toChartItems();
    final totalTracked = summary.totalTracked;
    final maxY = chartItems.fold<double>(0, (current, item) => math.max(current, item.amount));

    return _ReportCard(
      title: 'Balance Mix',
      subtitle: '${_selectedTimeframe.label} · Expense vs investment vs in-hand amount',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartToggle(
            value: _balanceChartDisplay,
            onChanged: (value) => setState(() => _balanceChartDisplay = value),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 860;
              final chartWidget = SizedBox(
                height: 260,
                child: totalTracked <= 0
                    ? const _EmptyChart(message: 'No expense, investment, or balance data for this timeframe.')
                    : _balanceChartDisplay == _ChartDisplay.pie
                        ? PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius: 54,
                              sections: chartItems.map((item) {
                                final percentage = totalTracked == 0 ? 0.0 : (item.amount / totalTracked) * 100;
                              return PieChartSectionData(
                                value: item.amount,
                                gradient: item.gradient,
                                radius: 76,
                                title: '${percentage.toStringAsFixed(1)}%',
                                titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: maxY == 0 ? 10 : maxY * 1.25,
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
                                      final index = value.toInt();
                                      if (index < 0 || index >= chartItems.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          chartItems[index].shortLabel,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: List.generate(chartItems.length, (index) {
                                final item = chartItems[index];
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: item.amount,
                                      width: 26,
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: item.gradient,
                                    ),
                                  ],
                                );
                              }),
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
                    const SizedBox(height: 18),
                    legendWidget,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: chartWidget),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: legendWidget),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
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
      ),
    );
  }

  Widget _buildExpenseCategorySection(
    List<Transaction> transactions,
    String Function(double) formatter,
  ) {
    final range = _DateRange.forTimeframe(_selectedTimeframe, DateTime.now());
    final rangeTransactions = range.apply(transactions);
    final expenseBreakdown = _buildExpenseBreakdown(rangeTransactions);
    final totalExpenses = expenseBreakdown.fold<double>(0, (sum, item) => sum + item.amount);
    final maxAmount = expenseBreakdown.fold<double>(0, (sum, item) => math.max(sum, item.amount));

    return _ReportCard(
      title: 'Expense Category Analysis',
      subtitle: '${_selectedTimeframe.label} · Parent-category classification with money and percentage',
      child: expenseBreakdown.isEmpty
          ? const _EmptyChart(message: 'No expense data available in this timeframe.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartToggle(
                  value: _expenseChartDisplay,
                  onChanged: (value) => setState(() => _expenseChartDisplay = value),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 320,
                  child: _expenseChartDisplay == _ChartDisplay.pie
                      ? PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 46,
                            sections: expenseBreakdown.map((item) {
                              final percentage = totalExpenses == 0 ? 0.0 : (item.amount / totalExpenses) * 100;
                              return PieChartSectionData(
                                value: item.amount,
                                gradient: item.gradient,
                                radius: 74,
                                title: '${percentage.toStringAsFixed(1)}%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            maxY: maxAmount == 0 ? 10 : maxAmount * 1.2,
                            alignment: BarChartAlignment.spaceAround,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxAmount == 0 ? 2 : maxAmount / 4,
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
                                  reservedSize: 44,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= expenseBreakdown.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: SizedBox(
                                        width: 72,
                                        child: Text(
                                          expenseBreakdown[index].label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: List.generate(expenseBreakdown.length, (index) {
                              final item = expenseBreakdown[index];
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: item.amount,
                                    width: 22,
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: item.gradient,
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                ...expenseBreakdown.map((item) {
                  final percentage = totalExpenses == 0 ? 0.0 : (item.amount / totalExpenses) * 100;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CategoryProgressTile(
                      label: item.label,
                      amount: formatter(item.amount),
                      percentage: percentage,
                      gradient: item.gradient,
                    ),
                  );
                }),
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
            height: 280,
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
                              borderRadius: BorderRadius.circular(14),
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
                              borderRadius: BorderRadius.circular(14),
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
                  height: 260,
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

  Widget _buildChartToggle({
    required _ChartDisplay value,
    required ValueChanged<_ChartDisplay> onChanged,
  }) {
    return SegmentedButton<_ChartDisplay>(
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? const Color(0xFF2C417A) : const Color(0xFF0E1528);
        }),
        foregroundColor: WidgetStateProperty.all(Colors.white),
      ),
      segments: const [
        ButtonSegment<_ChartDisplay>(
          value: _ChartDisplay.pie,
          label: Text('Pie Chart'),
          icon: Icon(Icons.pie_chart_outline_rounded),
        ),
        ButtonSegment<_ChartDisplay>(
          value: _ChartDisplay.bar,
          label: Text('Bar Chart'),
          icon: Icon(Icons.bar_chart_rounded),
        ),
      ],
      selected: <_ChartDisplay>{value},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }

  List<_CategoryChartItem> _buildExpenseBreakdown(List<Transaction> transactions) {
    final totals = <String, double>{};

    for (final transaction in transactions.where((t) => t.type == 'expense')) {
      final parent = _parentCategory(transaction.category);
      totals[parent] = (totals[parent] ?? 0) + transaction.amount;
    }

    final gradients = <LinearGradient>[
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFBE123C), Color(0xFFE11D48), Color(0xFFF97316)],
      ),
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFB7185), Color(0xFFF43F5E), Color(0xFFEF4444)],
      ),
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9F1239), Color(0xFFFB7185), Color(0xFFFDA4AF)],
      ),
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFF59E0B)],
      ),
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF881337), Color(0xFFEC4899), Color(0xFFFB7185)],
      ),
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7F1D1D), Color(0xFFEF4444), Color(0xFFFCA5A5)],
      ),
    ];

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
  fullYear('Full Year');

  const _ReportTimeframe(this.label);

  final String label;
}

enum _ChartDisplay {
  pie,
  bar,
}

enum _ReportSection {
  balanceMix('Balance Mix', Icons.pie_chart_outline_rounded),
  expenseAnalysis('Expense Analysis', Icons.receipt_long_rounded),
  investmentAnalysis('Investment Analysis', Icons.trending_up_rounded);

  const _ReportSection(this.label, this.icon);

  final String label;
  final IconData icon;
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9F1239), Color(0xFFE11D48), Color(0xFFF97316)],
        ),
        color: const Color(0xFFE11D48),
      ),
      _CategoryChartItem(
        label: 'Investments',
        shortLabel: 'Invest',
        amount: investment < 0 ? 0 : investment,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0369A1), Color(0xFF0EA5E9), Color(0xFF22C55E)],
        ),
        color: const Color(0xFF0EA5E9),
      ),
      _CategoryChartItem(
        label: 'In Hand',
        shortLabel: 'In Hand',
        amount: inHand < 0 ? 0 : inHand,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAB308), Color(0xFFFACC15), Color(0xFFF59E0B)],
        ),
        color: const Color(0xFFFACC15),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121A30),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
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
