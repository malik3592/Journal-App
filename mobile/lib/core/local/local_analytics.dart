import 'package:journal/core/formatters.dart';
import 'package:journal/shared/models/models.dart';

class LocalAnalytics {
  static num cashNet(List<CashMovement> movements) {
    return movements.fold<num>(0, (s, m) {
      final n = parseMoney(m.amount).abs();
      return s + (m.isWithdrawal ? -n : n);
    });
  }

  static AnalyticsOverview overview({
    required List<Trade> trades,
    required TradingAccount account,
    required String startingBalance,
    List<CashMovement> cashMovements = const [],
  }) {
    final closed = trades.where((t) => !t.isOpen).toList();
    final wins = closed.where((t) => t.isWin).toList();
    final losses = closed.where((t) => t.isLoss).toList();
    final net = closed.fold<num>(0, (s, t) => s + parseMoney(t.netProfit));
    final grossProfit = wins.fold<num>(
      0,
      (s, t) => s + parseMoney(t.netProfit),
    );
    final grossLoss = losses.fold<num>(
      0,
      (s, t) => s + parseMoney(t.netProfit),
    );
    final start = parseMoney(startingBalance);
    final cash = cashNet(cashMovements);
    final openPnl = trades
        .where((t) => t.isOpen)
        .fold<num>(0, (s, t) => s + parseMoney(t.netProfit));
    final today = DateTime.now();
    final todayPnl = closed
        .where((t) {
          final at = (t.closedAt ?? t.openedAt).toLocal();
          return at.year == today.year &&
              at.month == today.month &&
              at.day == today.day;
        })
        .fold<num>(0, (s, t) => s + parseMoney(t.netProfit));
    final journaled = trades.where((t) => t.journalStatus == 'COMPLETE').length;
    final closable = trades.where((t) => t.closedAt != null).length;
    final avgWin = wins.isEmpty ? null : grossProfit / wins.length;
    final avgLoss = losses.isEmpty ? null : grossLoss / losses.length;
    final largestWin = wins.isEmpty
        ? null
        : wins
              .map((t) => parseMoney(t.netProfit))
              .reduce((a, b) => a > b ? a : b);
    final largestLoss = losses.isEmpty
        ? null
        : losses
              .map((t) => parseMoney(t.netProfit))
              .reduce((a, b) => a < b ? a : b);
    final decided = wins.length + losses.length;
    final winRate = decided == 0 ? null : wins.length / decided * 100;
    final profitFactor = grossLoss.abs() == 0
        ? (grossProfit > 0 ? grossProfit.toDouble() : null)
        : grossProfit / grossLoss.abs();
    final expectancy = closed.isEmpty
        ? null
        : ((winRate ?? 0) / 100) * (avgWin ?? 0) -
              ((100 - (winRate ?? 0)) / 100) * (avgLoss?.abs() ?? 0);

    return AnalyticsOverview(
      totalTrades: trades.length,
      winRate: winRate,
      netPnl: net.toStringAsFixed(2),
      profitFactor: profitFactor,
      maxDrawdown: _maxDrawdownPct(
        equity(
          trades: trades,
          startingBalance: startingBalance,
          cashMovements: cashMovements,
        ),
      ),
      averageR: null,
      expectancy: expectancy?.toStringAsFixed(2),
      equity: (start + net + cash + openPnl).toDouble(),
      balance: (start + net + cash).toDouble(),
      todayPnl: todayPnl.toStringAsFixed(2),
      journalCompletion: closable == 0 ? 0 : journaled / closable * 100,
      currency: account.currency,
      averageWin: avgWin?.toStringAsFixed(2),
      averageLoss: avgLoss?.toStringAsFixed(2),
      largestWin: largestWin?.toStringAsFixed(2),
      largestLoss: largestLoss?.toStringAsFixed(2),
      winningTrades: wins.length,
      losingTrades: losses.length,
    );
  }

  static List<EquityPoint> equity({
    required List<Trade> trades,
    required String startingBalance,
    List<CashMovement> cashMovements = const [],
  }) {
    final events = <({DateTime time, double delta})>[
      for (final trade in trades.where((t) => !t.isOpen))
        (
          time: trade.closedAt ?? trade.openedAt,
          delta: parseMoney(trade.netProfit).toDouble(),
        ),
      for (final movement in cashMovements)
        (
          time: movement.at,
          delta:
              parseMoney(movement.amount).abs().toDouble() *
              (movement.isWithdrawal ? -1 : 1),
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    var value = parseMoney(startingBalance).toDouble();
    final points = <EquityPoint>[
      EquityPoint(
        time: events.isEmpty ? DateTime.now() : events.first.time,
        equity: value,
      ),
    ];
    for (final event in events) {
      value += event.delta;
      points.add(EquityPoint(time: event.time, equity: value));
    }
    return points;
  }

  static List<CalendarDay> calendar({
    required List<Trade> trades,
    required String month,
  }) {
    final days = <String, ({num pnl, int trades, int wins})>{};
    for (final trade in trades.where((t) => !t.isOpen)) {
      final at = (trade.closedAt ?? trade.openedAt).toLocal();
      final key =
          '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      final current = days[key] ?? (pnl: 0, trades: 0, wins: 0);
      final pnl = parseMoney(trade.netProfit);
      days[key] = (
        pnl: current.pnl + pnl,
        trades: current.trades + 1,
        wins: current.wins + (trade.isWin ? 1 : 0),
      );
    }
    return days.entries
        .where((e) => e.key.startsWith(month))
        .map(
          (e) => CalendarDay(
            date: DateTime.parse(e.key),
            netPnl: e.value.pnl.toStringAsFixed(2),
            trades: e.value.trades,
            winRate: e.value.trades == 0
                ? 0
                : e.value.wins / e.value.trades * 100,
          ),
        )
        .toList();
  }

  static double _maxDrawdownPct(List<EquityPoint> points) {
    if (points.length < 2) return 0;
    var peak = points.first.equity;
    var minDd = 0.0;
    for (final point in points) {
      if (point.equity > peak) peak = point.equity;
      if (peak <= 0) continue;
      final dd = (point.equity - peak) / peak * 100;
      if (dd < minDd) minDd = dd;
    }
    return minDd.abs();
  }
}
