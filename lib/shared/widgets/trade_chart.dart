import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/core/market/ohlc.dart';
import 'package:journal/shared/models/models.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TradeChart extends StatelessWidget {
  const TradeChart({super.key, required this.trade});
  final Trade trade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TradingViewMarketChart(trade: trade),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _LegendDot(color: AppColors.primary, label: 'Entry'),
            _LegendDot(color: AppColors.gold, label: 'Exit'),
            _LegendDot(color: AppColors.negative, label: 'SL'),
            _LegendDot(color: AppColors.positive, label: 'TP'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
        ),
      ],
    );
  }
}

class TradingViewMarketChart extends StatefulWidget {
  const TradingViewMarketChart({super.key, required this.trade});
  final Trade trade;

  @override
  State<TradingViewMarketChart> createState() => _TradingViewMarketChartState();
}

class _TradingViewMarketChartState extends State<TradingViewMarketChart> {
  WebViewController? _controller;
  var _failed = false;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TradingViewMarketChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trade.symbol != widget.trade.symbol ||
        oldWidget.trade.entryPrice != widget.trade.entryPrice ||
        oldWidget.trade.exitPrice != widget.trade.exitPrice ||
        oldWidget.trade.stopLoss != widget.trade.stopLoss ||
        oldWidget.trade.takeProfit != widget.trade.takeProfit ||
        oldWidget.trade.openedAt != widget.trade.openedAt ||
        oldWidget.trade.closedAt != widget.trade.closedAt) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _loading = true;
    });
    final trade = widget.trade;
    final candles = await MarketOhlc.fetch(
      symbol: trade.symbol,
      openedAt: trade.openedAt,
      closedAt: trade.closedAt,
    );
    if (!mounted) return;

    final times = [for (final bar in candles) bar.time];
    final entryPrice = parseMoney(trade.entryPrice);
    final exitPrice = parseMoney(trade.exitPrice);
    final sl = parseMoney(trade.stopLoss);
    final tp = parseMoney(trade.takeProfit);
    final entryTime = snapBarTime(
      trade.openedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
      times,
    );
    final exitTime = trade.closedAt == null
        ? null
        : snapBarTime(
            trade.closedAt!.toUtc().millisecondsSinceEpoch ~/ 1000,
            times,
          );

    final payload = jsonEncode({
      'candles': [for (final bar in candles) bar.toJson()],
      'buy': trade.direction.toUpperCase() != 'SELL',
      'entry': {
        'price': entryPrice == 0 ? null : entryPrice,
        'time': entryTime,
      },
      'exit': {'price': exitPrice == 0 ? null : exitPrice, 'time': exitTime},
      'sl': sl == 0 ? null : sl,
      'tp': tp == 0 ? null : tp,
    });

    final html =
        '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html, body, #chart { margin: 0; padding: 0; height: 100%; width: 100%; background: #101721; }
  #fallback { color: #8C98A8; font: 12px/1.4 -apple-system, sans-serif; padding: 16px; }
</style>
</head>
<body>
<div id="chart"></div>
<script>
const data = $payload;
function boot() {
  if (!window.LightweightCharts) {
    document.getElementById('chart').innerHTML = '<div id="fallback">TradingView chart failed to load.</div>';
    return;
  }
  const chart = LightweightCharts.createChart(document.getElementById('chart'), {
    autoSize: true,
    layout: { background: { color: '#101721' }, textColor: '#8C98A8' },
    grid: { vertLines: { color: '#253041' }, horzLines: { color: '#253041' } },
    rightPriceScale: { borderColor: '#253041' },
    timeScale: { borderColor: '#253041', timeVisible: true, secondsVisible: false },
    crosshair: { mode: 0 }
  });
  const candle = chart.addCandlestickSeries({
    upColor: '#19C37D',
    downColor: '#EF5350',
    borderVisible: false,
    wickUpColor: '#19C37D',
    wickDownColor: '#EF5350'
  });
  if (data.candles.length) {
    candle.setData(data.candles);
  } else if (data.entry.price) {
    const points = [{ time: data.entry.time, value: data.entry.price }];
    if (data.exit.time && data.exit.price) points.push({ time: data.exit.time, value: data.exit.price });
    else points.push({ time: data.entry.time + 3600, value: data.entry.price });
    candle.setData(points.map(function(p) {
      return { time: p.time, open: p.value, high: p.value, low: p.value, close: p.value };
    }));
  }
  function priceLine(price, color, title, style) {
    if (price == null) return;
    candle.createPriceLine({
      price: Number(price),
      color: color,
      title: title,
      lineWidth: 2,
      lineStyle: style,
      axisLabelVisible: true
    });
  }
  priceLine(data.entry.price, '#1677FF', 'Entry', 0);
  priceLine(data.exit.price, '#F5C451', 'Exit', 2);
  priceLine(data.sl, '#EF5350', 'SL', 2);
  priceLine(data.tp, '#19C37D', 'TP', 2);
  const markers = [];
  if (data.entry.time && data.entry.price) {
    markers.push({
      time: data.entry.time,
      position: data.buy ? 'belowBar' : 'aboveBar',
      color: '#1677FF',
      shape: data.buy ? 'arrowUp' : 'arrowDown',
      text: 'Entry'
    });
  }
  if (data.exit.time && data.exit.price) {
    markers.push({
      time: data.exit.time,
      position: data.buy ? 'aboveBar' : 'belowBar',
      color: '#F5C451',
      shape: data.buy ? 'arrowDown' : 'arrowUp',
      text: 'Exit'
    });
  }
  candle.setMarkers(markers);
  if (data.entry.time && data.exit.time && data.entry.price && data.exit.price) {
    const path = chart.addLineSeries({
      color: '#1677FF',
      lineWidth: 2,
      lastValueVisible: false,
      priceLineVisible: false
    });
    path.setData([
      { time: data.entry.time, value: Number(data.entry.price) },
      { time: data.exit.time, value: Number(data.exit.price) }
    ]);
  }
  chart.timeScale().fitContent();
}
</script>
<script src="https://unpkg.com/lightweight-charts@4.2.3/dist/lightweight-charts.standalone.production.js" onload="boot()" onerror="document.getElementById('chart').innerHTML='<div id=fallback>TradingView chart failed to load.</div>'"></script>
</body>
</html>
''';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _failed = true;
                _loading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: 'https://unpkg.com');

    if (!mounted) return;
    setState(() {
      _controller = controller;
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return TradeLevelsChart(trade: widget.trade);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (_loading)
              const ColoredBox(
                color: AppColors.surface,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class TradeLevelsChart extends StatelessWidget {
  const TradeLevelsChart({super.key, required this.trade});
  final Trade trade;

  @override
  Widget build(BuildContext context) {
    final entry = parseMoney(trade.entryPrice);
    final exit = parseMoney(trade.exitPrice);
    final sl = parseMoney(trade.stopLoss);
    final tp = parseMoney(trade.takeProfit);
    final prices = [
      if (entry != 0) entry,
      if (exit != 0) exit,
      if (sl != 0) sl,
      if (tp != 0) tp,
    ];
    if (prices.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Add entry, SL, or TP to see trade levels.',
            style: TextStyle(color: AppColors.secondary),
          ),
        ),
      );
    }

    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    final pad = (max - min).abs() * 0.12;
    final floor = (min - (pad == 0 ? min.abs() * 0.002 : pad)).toDouble();
    final ceil = (max + (pad == 0 ? max.abs() * 0.002 : pad)).toDouble();
    final buy = trade.direction.toUpperCase() != 'SELL';
    final end = exit == 0 ? entry : exit;

    Color lineColor(String kind) {
      return switch (kind) {
        'SL' => AppColors.negative,
        'TP' => AppColors.positive,
        'Exit' => trade.isLoss ? AppColors.negative : AppColors.positive,
        _ => buy ? AppColors.primary : AppColors.gold,
      };
    }

    HorizontalLine level(String label, num value) {
      final color = lineColor(label);
      return HorizontalLine(
        y: value.toDouble(),
        color: color,
        strokeWidth: 1.4,
        dashArray: label == 'Exit' ? [6, 4] : null,
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 8, bottom: 2),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          labelResolver: (_) => '$label ${value.toString()}',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Market candles need an internet connection. Trade levels are below.',
          style: TextStyle(color: AppColors.secondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 1,
              minY: floor,
              maxY: ceil,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.border.withValues(alpha: 0.7),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (_) => FlLine(
                  color: AppColors.border.withValues(alpha: 0.45),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (entry != 0) level('Entry', entry),
                  if (exit != 0) level('Exit', exit),
                  if (sl != 0) level('SL', sl),
                  if (tp != 0) level('TP', tp),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    FlSpot(0, entry == 0 ? end.toDouble() : entry.toDouble()),
                    FlSpot(1, end.toDouble()),
                  ],
                  color: trade.isLoss
                      ? AppColors.negative
                      : trade.isWin
                      ? AppColors.positive
                      : AppColors.primary,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
