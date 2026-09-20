import 'package:journal/core/formatters.dart';
import 'package:journal/shared/models/models.dart';

class QualityBar {
  const QualityBar({
    required this.label,
    required this.earned,
    required this.max,
  });
  final String label;
  final int earned;
  final int max;
  double get fraction => max == 0 ? 0 : earned / max;
}

class ExecutionFlags {
  const ExecutionFlags({
    required this.followedPlan,
    required this.properRisk,
    required this.goodEntry,
    required this.patientExit,
  });

  final bool followedPlan;
  final bool properRisk;
  final bool goodEntry;
  final bool patientExit;

  int get score =>
      (followedPlan ? 10 : 0) +
      (properRisk ? 10 : 0) +
      (goodEntry ? 10 : 0) +
      (patientExit ? 10 : 0);

  static ExecutionFlags fromTrade(Trade trade) {
    final mistakes = {for (final item in trade.mistakes) item.toLowerCase()};
    final rr = tradeRiskRewardRatio(
      direction: trade.direction,
      entryPrice: trade.entryPrice,
      stopLoss: trade.stopLoss,
      takeProfit: trade.takeProfit,
    );
    return ExecutionFlags(
      followedPlan:
          !mistakes.contains('broke strategy') &&
          trade.checklist.any((e) => e.checked),
      properRisk: rr != null && rr >= 1,
      goodEntry:
          !mistakes.contains('entered early') &&
          !mistakes.contains('entered late'),
      patientExit:
          !mistakes.contains('moved take profit') &&
          !mistakes.contains('moved stop loss'),
    );
  }
}

class TradeQuality {
  const TradeQuality({
    required this.profitability,
    required this.execution,
    required this.journal,
    required this.rating,
    required this.flags,
  });

  final int profitability;
  final int execution;
  final int journal;
  final int rating;
  final ExecutionFlags flags;

  int get total => profitability + execution + journal + rating;
  int get max => 100;

  String get grade {
    if (total >= 80) return 'Excellent';
    if (total >= 60) return 'Good';
    if (total >= 40) return 'Average';
    return 'Needs work';
  }

  List<QualityBar> get bars => [
    QualityBar(label: 'Profitability', earned: profitability, max: 30),
    QualityBar(label: 'Execution', earned: execution, max: 40),
    QualityBar(label: 'Journal', earned: journal, max: 20),
    QualityBar(label: 'Rating', earned: rating, max: 10),
  ];

  static TradeQuality fromTrade(Trade trade) {
    final flags = ExecutionFlags.fromTrade(trade);
    return TradeQuality(
      profitability: _profitability(trade),
      execution: flags.score,
      journal: _journal(trade),
      rating: _rating(trade),
      flags: flags,
    );
  }

  static int _profitability(Trade trade) {
    if (trade.isWin) return 30;
    if (trade.isBreakEven) return 15;
    return 0;
  }

  static int _journal(Trade trade) {
    return ((trade.notes?.trim().isNotEmpty == true ||
                trade.preAnalysis.isNotEmpty)
            ? 5
            : 0) +
        (trade.postReview?.trim().isNotEmpty == true ? 5 : 0) +
        (trade.primaryEmotion?.trim().isNotEmpty == true ? 5 : 0) +
        (trade.lessons?.trim().isNotEmpty == true ? 5 : 0);
  }

  static int _rating(Trade trade) {
    final value = trade.rating ?? 0;
    if (value <= 0) return 0;
    return value.clamp(1, 10);
  }
}

class TradeAverageCompare {
  const TradeAverageCompare({
    required this.peerLabel,
    required this.averagePnl,
    required this.pnlDeltaPct,
    required this.averageHold,
    required this.holdDeltaPct,
    required this.executionPct,
    required this.executionDeltaPct,
  });

  final String peerLabel;
  final num? averagePnl;
  final double? pnlDeltaPct;
  final Duration? averageHold;
  final double? holdDeltaPct;
  final double executionPct;
  final double? executionDeltaPct;

  static TradeAverageCompare of(Trade trade, List<Trade> all) {
    final peers = all.where((item) {
      if (item.id == trade.id || item.isOpen) return false;
      if (trade.isWin) return item.isWin;
      if (trade.isLoss) return item.isLoss;
      if (trade.isBreakEven) return item.isBreakEven;
      return !item.isOpen;
    }).toList();
    final group = [trade, ...peers];
    final avgPnl =
        group.fold<num>(0, (sum, item) => sum + parseMoney(item.netProfit)) /
        group.length;
    final holds = [
      for (final item in group)
        if (tradeHoldDuration(item.openedAt, item.closedAt) != null)
          tradeHoldDuration(item.openedAt, item.closedAt)!,
    ];
    final avgHold = holds.isEmpty
        ? null
        : Duration(
            seconds:
                (holds.fold<int>(0, (s, d) => s + d.inSeconds) / holds.length)
                    .round(),
          );
    final thisPnl = parseMoney(trade.netProfit);
    final thisHold = tradeHoldDuration(trade.openedAt, trade.closedAt);
    final thisExec = TradeQuality.fromTrade(trade).execution / 40 * 100;
    final avgExec =
        group.fold<int>(
          0,
          (sum, item) => sum + TradeQuality.fromTrade(item).execution,
        ) /
        group.length /
        40 *
        100;
    return TradeAverageCompare(
      peerLabel: trade.isWin
          ? 'vs avg winner'
          : trade.isLoss
          ? 'vs avg loser'
          : 'vs your average',
      averagePnl: avgPnl,
      pnlDeltaPct: _deltaPct(thisPnl, avgPnl),
      averageHold: avgHold,
      holdDeltaPct:
          thisHold == null || avgHold == null || avgHold.inSeconds == 0
          ? null
          : _deltaPct(thisHold.inSeconds, avgHold.inSeconds),
      executionPct: thisExec,
      executionDeltaPct: _deltaPct(thisExec, avgExec),
    );
  }

  static double? _deltaPct(num current, num average) {
    if (average == 0) return current == 0 ? 0 : null;
    return (current - average) / average.abs() * 100;
  }
}
