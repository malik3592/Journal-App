import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:journal/core/formatters.dart';

class OhlcBar {
  const OhlcBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final int time;
  final double open;
  final double high;
  final double low;
  final double close;

  Map<String, num> toJson() => {
    'time': time,
    'open': open,
    'high': high,
    'low': low,
    'close': close,
  };
}

class MarketOhlc {
  static Future<List<OhlcBar>> fetch({
    required String symbol,
    required DateTime openedAt,
    DateTime? closedAt,
  }) async {
    final end = closedAt ?? DateTime.now();
    var from = openedAt.subtract(const Duration(hours: 8));
    var to = end.add(const Duration(hours: 8));
    if (to.difference(from) < const Duration(hours: 12)) {
      from = openedAt.subtract(const Duration(hours: 12));
      to = end.add(const Duration(hours: 12));
    }
    final crypto = _binanceSymbol(symbol);
    if (crypto != null) {
      final bars = await _binance(crypto, from, to);
      if (bars.isNotEmpty) return bars;
    }
    return _yahoo(yahooSymbol(symbol), from, to);
  }

  static String _interval(Duration span) {
    if (span.inHours <= 8) return '5m';
    if (span.inHours <= 48) return '15m';
    if (span.inDays <= 14) return '60m';
    return '1d';
  }

  static String _binanceInterval(Duration span) {
    if (span.inHours <= 8) return '5m';
    if (span.inHours <= 48) return '15m';
    if (span.inDays <= 14) return '1h';
    return '1d';
  }

  static String? _binanceSymbol(String raw) {
    final symbol = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s/_:]'), '');
    const map = {
      'BTCUSD': 'BTCUSDT',
      'BTCUSDT': 'BTCUSDT',
      'ETHUSD': 'ETHUSDT',
      'ETHUSDT': 'ETHUSDT',
    };
    return map[symbol];
  }

  static Future<List<OhlcBar>> _yahoo(
    String symbol,
    DateTime from,
    DateTime to,
  ) async {
    final interval = _interval(to.difference(from));
    final uri =
        Uri.https('query1.finance.yahoo.com', '/v8/finance/chart/$symbol', {
          'period1': '${from.toUtc().millisecondsSinceEpoch ~/ 1000}',
          'period2': '${to.toUtc().millisecondsSinceEpoch ~/ 1000}',
          'interval': interval,
          'includePrePost': 'false',
        });
    try {
      final res = await http
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['chart'] is Map
          ? (json['chart'] as Map)['result']
          : null;
      if (results is! List || results.isEmpty) return const [];
      final result = results.first as Map<String, dynamic>;
      final times = (result['timestamp'] as List<dynamic>? ?? []).cast<num>();
      final quote =
          (((result['indicators'] as Map?)?['quote'] as List?)?.first
              as Map?) ??
          const {};
      final opens = (quote['open'] as List<dynamic>? ?? []);
      final highs = (quote['high'] as List<dynamic>? ?? []);
      final lows = (quote['low'] as List<dynamic>? ?? []);
      final closes = (quote['close'] as List<dynamic>? ?? []);
      final bars = <OhlcBar>[];
      for (var i = 0; i < times.length; i++) {
        final open = (opens.elementAtOrNull(i) as num?)?.toDouble();
        final high = (highs.elementAtOrNull(i) as num?)?.toDouble();
        final low = (lows.elementAtOrNull(i) as num?)?.toDouble();
        final close = (closes.elementAtOrNull(i) as num?)?.toDouble();
        if (open == null || high == null || low == null || close == null)
          continue;
        bars.add(
          OhlcBar(
            time: times[i].toInt(),
            open: open,
            high: high,
            low: low,
            close: close,
          ),
        );
      }
      return bars;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<OhlcBar>> _binance(
    String symbol,
    DateTime from,
    DateTime to,
  ) async {
    final uri = Uri.https('api.binance.com', '/api/v3/klines', {
      'symbol': symbol,
      'interval': _binanceInterval(to.difference(from)),
      'startTime': '${from.toUtc().millisecondsSinceEpoch}',
      'endTime': '${to.toUtc().millisecondsSinceEpoch}',
      'limit': '500',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final rows = jsonDecode(res.body);
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is List && row.length >= 5)
            OhlcBar(
              time: (row[0] as num).toInt() ~/ 1000,
              open: double.parse(row[1].toString()),
              high: double.parse(row[2].toString()),
              low: double.parse(row[3].toString()),
              close: double.parse(row[4].toString()),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

int snapBarTime(int unix, List<int> times) {
  if (times.isEmpty) return unix;
  return times.reduce((a, b) => (a - unix).abs() <= (b - unix).abs() ? a : b);
}
