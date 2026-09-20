import 'package:journal/core/formatters.dart';
import 'package:journal/shared/models/models.dart';

class SideBucket {
  const SideBucket({required this.trades, required this.pnl});
  final int trades;
  final num pnl;
}

class DayBucket {
  const DayBucket({
    required this.label,
    required this.pnl,
    required this.trades,
  });
  final String label;
  final num pnl;
  final int trades;
}

class SymbolBucket {
  const SymbolBucket({
    required this.symbol,
    required this.pnl,
    required this.trades,
  });
  final String symbol;
  final num pnl;
  final int trades;
}

class StatRow {
  const StatRow({
    required this.label,
    required this.value,
    this.negative = false,
  });
  final String label;
  final String value;
  final bool negative;
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.closedCount,
    required this.openCount,
    required this.wins,
    required this.losses,
    required this.breakeven,
    required this.totalPnl,
    required this.grossProfit,
    required this.grossLoss,
    required this.winRate,
    required this.profitFactor,
    required this.expectancy,
    required this.avgWin,
    required this.avgLoss,
    required this.best,
    required this.worst,
    required this.winStreak,
    required this.lossStreak,
    required this.riskReward,
    required this.longs,
    required this.shorts,
    required this.weekdays,
    required this.symbols,
    required this.holdAll,
    required this.holdWins,
    required this.holdLosses,
    required this.commissions,
    required this.swaps,
    required this.tradingDays,
    required this.winningDays,
    required this.losingDays,
    required this.breakevenDays,
    required this.dayWinStreak,
    required this.dayLossStreak,
    required this.avgDailyPnl,
    required this.avgWinningDay,
    required this.avgLosingDay,
    required this.bestDay,
    required this.worstDay,
    required this.avgDailyVolume,
    required this.bestMonth,
    required this.worstMonth,
    required this.avgMonth,
    required this.maxDrawdown,
    required this.maxDrawdownPct,
  });

  final int closedCount;
  final int openCount;
  final int wins;
  final int losses;
  final int breakeven;
  final num totalPnl;
  final num grossProfit;
  final num grossLoss;
  final double winRate;
  final double profitFactor;
  final num expectancy;
  final num avgWin;
  final num avgLoss;
  final num best;
  final num worst;
  final int winStreak;
  final int lossStreak;
  final double riskReward;
  final SideBucket longs;
  final SideBucket shorts;
  final List<DayBucket> weekdays;
  final List<SymbolBucket> symbols;
  final String holdAll;
  final String holdWins;
  final String holdLosses;
  final num commissions;
  final num swaps;
  final int tradingDays;
  final int winningDays;
  final int losingDays;
  final int breakevenDays;
  final int dayWinStreak;
  final int dayLossStreak;
  final num avgDailyPnl;
  final num avgWinningDay;
  final num avgLosingDay;
  final num bestDay;
  final num worstDay;
  final num avgDailyVolume;
  final String bestMonth;
  final String worstMonth;
  final num avgMonth;
  final num maxDrawdown;
  final double maxDrawdownPct;

  factory AnalyticsSnapshot.fromTrades(
    List<Trade> source, {
    required String period,
    required String resultFilter,
    double? drawdownPct,
  }) {
    final now = DateTime.now();
    final from = switch (period) {
      'Today' => DateTime(now.year, now.month, now.day),
      '7 Days' => now.subtract(const Duration(days: 7)),
      '30 Days' => now.subtract(const Duration(days: 30)),
      '3 Months' => DateTime(now.year, now.month - 3, now.day),
      '1 Year' => DateTime(now.year - 1, now.month, now.day),
      _ => null,
    };
    var trades = source.where((t) {
      if (from == null) return true;
      final at = (t.closedAt ?? t.openedAt).toLocal();
      return !at.isBefore(from);
    }).toList();
    if (resultFilter == 'Winners') {
      trades = trades.where((t) => t.isWin).toList();
    } else if (resultFilter == 'Losers') {
      trades = trades.where((t) => t.isLoss).toList();
    }

    final closed = trades.where((t) => !t.isOpen).toList()
      ..sort(
        (a, b) =>
            (a.closedAt ?? a.openedAt).compareTo(b.closedAt ?? b.openedAt),
      );
    final open = trades.where((t) => t.isOpen).toList();
    final winTrades = closed.where((t) => t.isWin).toList();
    final lossTrades = closed.where((t) => t.isLoss).toList();
    final beTrades = closed.where((t) => t.isBreakEven).toList();
    final grossProfit = winTrades.fold<num>(
      0,
      (s, t) => s + parseMoney(t.netProfit),
    );
    final grossLoss = lossTrades.fold<num>(
      0,
      (s, t) => s + parseMoney(t.netProfit),
    );
    final net = closed.fold<num>(0, (s, t) => s + parseMoney(t.netProfit));
    final avgWin = winTrades.isEmpty ? 0 : grossProfit / winTrades.length;
    final avgLossAbs = lossTrades.isEmpty
        ? 0
        : grossLoss.abs() / lossTrades.length;
    final decided = winTrades.length + lossTrades.length;
    final winRate = decided == 0 ? 0.0 : winTrades.length / decided * 100;
    final profitFactor = grossLoss.abs() == 0
        ? (grossProfit > 0 ? grossProfit.toDouble() : 0.0)
        : grossProfit / grossLoss.abs();
    final expectancy = closed.isEmpty
        ? 0
        : (winRate / 100) * avgWin - ((100 - winRate) / 100) * avgLossAbs;
    final best = winTrades.isEmpty
        ? 0
        : winTrades
              .map((t) => parseMoney(t.netProfit))
              .reduce((a, b) => a > b ? a : b);
    final worst = lossTrades.isEmpty
        ? 0
        : lossTrades
              .map((t) => parseMoney(t.netProfit))
              .reduce((a, b) => a < b ? a : b);

    final longs = closed.where((t) => t.direction == 'BUY').toList();
    final shorts = closed.where((t) => t.direction == 'SELL').toList();

    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdayMap = {
      for (var i = 0; i < 7; i++) i: (pnl: 0.0 as num, trades: 0),
    };
    for (final trade in closed) {
      final day = (trade.closedAt ?? trade.openedAt).toLocal().weekday - 1;
      final current = weekdayMap[day]!;
      weekdayMap[day] = (
        pnl: current.pnl + parseMoney(trade.netProfit),
        trades: current.trades + 1,
      );
    }

    final bySymbol = <String, ({num pnl, int trades})>{};
    for (final trade in closed) {
      final current = bySymbol[trade.symbol] ?? (pnl: 0, trades: 0);
      bySymbol[trade.symbol] = (
        pnl: current.pnl + parseMoney(trade.netProfit),
        trades: current.trades + 1,
      );
    }
    final symbols = bySymbol.entries.toList()
      ..sort((a, b) => b.value.pnl.compareTo(a.value.pnl));

    final byDay = <String, num>{};
    final byDayVolume = <String, num>{};
    for (final trade in closed) {
      final key = _dayKey(trade.closedAt ?? trade.openedAt);
      byDay[key] = (byDay[key] ?? 0) + parseMoney(trade.netProfit);
      byDayVolume[key] = (byDayVolume[key] ?? 0) + parseMoney(trade.volume);
    }
    final dayValues = byDay.values.toList();
    final winDays = dayValues.where((v) => v > 0).toList();
    final lossDays = dayValues.where((v) => v < 0).toList();
    final beDays = dayValues.where((v) => v == 0).toList();

    final byMonth = <String, num>{};
    for (final trade in closed) {
      final at = (trade.closedAt ?? trade.openedAt).toLocal();
      final key = '${at.year}-${at.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + parseMoney(trade.netProfit);
    }
    String monthLabel(String key) {
      final parts = key.split('-');
      const names = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${names[int.parse(parts[1]) - 1]} ${parts[0]}';
    }

    String bestMonth = 'No data';
    String worstMonth = 'No data';
    num avgMonth = 0;
    if (byMonth.isNotEmpty) {
      final sorted = byMonth.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      worstMonth = monthLabel(sorted.first.key);
      bestMonth = monthLabel(sorted.last.key);
      avgMonth = byMonth.values.reduce((a, b) => a + b) / byMonth.length;
    }

    final ddPct = drawdownPct ?? 0;
    final peak = closed.fold<num>(0, (s, t) => s + parseMoney(t.netProfit));

    return AnalyticsSnapshot(
      closedCount: closed.length,
      openCount: open.length,
      wins: winTrades.length,
      losses: lossTrades.length,
      breakeven: beTrades.length,
      totalPnl: net,
      grossProfit: grossProfit,
      grossLoss: grossLoss,
      winRate: winRate,
      profitFactor: profitFactor.toDouble(),
      expectancy: expectancy,
      avgWin: avgWin,
      avgLoss: lossTrades.isEmpty ? 0 : -avgLossAbs,
      best: best,
      worst: worst,
      winStreak: _maxStreak(closed, winning: true),
      lossStreak: _maxStreak(closed, winning: false),
      riskReward: avgLossAbs == 0 ? 0 : avgWin / avgLossAbs,
      longs: SideBucket(
        trades: longs.length,
        pnl: longs.fold(0, (s, t) => s + parseMoney(t.netProfit)),
      ),
      shorts: SideBucket(
        trades: shorts.length,
        pnl: shorts.fold(0, (s, t) => s + parseMoney(t.netProfit)),
      ),
      weekdays: [
        for (var i = 0; i < 7; i++)
          DayBucket(
            label: labels[i],
            pnl: weekdayMap[i]!.pnl,
            trades: weekdayMap[i]!.trades,
          ),
      ],
      symbols: symbols
          .take(5)
          .map(
            (e) => SymbolBucket(
              symbol: e.key,
              pnl: e.value.pnl,
              trades: e.value.trades,
            ),
          )
          .toList(),
      holdAll: _avgHold(closed),
      holdWins: _avgHold(winTrades),
      holdLosses: _avgHold(lossTrades),
      commissions: closed.fold(0, (s, t) => s + parseMoney(t.commission)),
      swaps: closed.fold(0, (s, t) => s + parseMoney(t.swap)),
      tradingDays: byDay.length,
      winningDays: winDays.length,
      losingDays: lossDays.length,
      breakevenDays: beDays.length,
      dayWinStreak: _maxDayStreak(byDay, winning: true),
      dayLossStreak: _maxDayStreak(byDay, winning: false),
      avgDailyPnl: dayValues.isEmpty ? 0 : net / dayValues.length,
      avgWinningDay: winDays.isEmpty
          ? 0
          : winDays.reduce((a, b) => a + b) / winDays.length,
      avgLosingDay: lossDays.isEmpty
          ? 0
          : lossDays.reduce((a, b) => a + b) / lossDays.length,
      bestDay: dayValues.isEmpty
          ? 0
          : dayValues.reduce((a, b) => a > b ? a : b),
      worstDay: dayValues.isEmpty
          ? 0
          : dayValues.reduce((a, b) => a < b ? a : b),
      avgDailyVolume: byDayVolume.isEmpty
          ? 0
          : byDayVolume.values.reduce((a, b) => a + b) / byDayVolume.length,
      bestMonth: bestMonth,
      worstMonth: worstMonth,
      avgMonth: avgMonth,
      maxDrawdown: ddPct == 0 ? 0 : (peak.abs() * ddPct.abs() / 100),
      maxDrawdownPct: ddPct.abs(),
    );
  }

  static String _dayKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static int _maxStreak(List<Trade> closed, {required bool winning}) {
    var max = 0;
    var current = 0;
    for (final trade in closed) {
      if (trade.isBreakEven) continue;
      final hit = winning ? trade.isWin : trade.isLoss;
      if (hit) {
        current += 1;
        if (current > max) max = current;
      } else {
        current = 0;
      }
    }
    return max;
  }

  static int _maxDayStreak(Map<String, num> byDay, {required bool winning}) {
    final keys = byDay.keys.toList()..sort();
    var max = 0;
    var current = 0;
    for (final key in keys) {
      final pnl = byDay[key] ?? 0;
      final hit = winning ? pnl > 0 : pnl < 0;
      if (hit) {
        current += 1;
        if (current > max) max = current;
      } else {
        current = 0;
      }
    }
    return max;
  }

  static String _avgHold(List<Trade> trades) {
    final durations = trades
        .where((t) => t.closedAt != null)
        .map((t) => t.closedAt!.difference(t.openedAt))
        .toList();
    if (durations.isEmpty) return '—';
    final seconds =
        durations.fold<int>(0, (s, d) => s + d.inSeconds) / durations.length;
    final d = Duration(seconds: seconds.round());
    if (d.inHours >= 24) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

List<EquityPoint> drawdownPoints(List<EquityPoint> points) {
  if (points.isEmpty) return points;
  var peak = points.first.equity;
  final result = <EquityPoint>[];
  for (final point in points) {
    if (point.equity > peak) peak = point.equity;
    final dd = peak == 0 ? 0.0 : (point.equity - peak) / peak * 100;
    result.add(EquityPoint(time: point.time, equity: dd));
  }
  return result;
}

double maxDrawdownPct(List<EquityPoint> points) {
  if (points.length < 2) return 0;
  var peak = points.first.equity;
  var minDd = 0.0;
  for (final point in points) {
    if (point.equity > peak) peak = point.equity;
    if (peak <= 0) continue;
    final dd = (point.equity - peak) / peak * 100;
    if (dd < minDd) minDd = dd;
  }
  return minDd;
}
