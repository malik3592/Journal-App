import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/core/nav.dart';
import 'package:journal/features/analytics/analytics_stats.dart';
import 'package:journal/features/dashboard/home_screen.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/shared/models/models.dart';
import 'package:journal/shared/widgets/equity_chart.dart';
import 'package:journal/shared/widgets/ui.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  static const periods = [
    'Today',
    '7 Days',
    '30 Days',
    '3 Months',
    '1 Year',
    'All Time',
  ];
  static const filters = ['All Trades', 'Winners', 'Losers'];

  String period = '30 Days';
  String resultFilter = 'All Trades';
  bool showDrawdown = false;
  late DateTime month;
  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
  }

  String get _monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final trades = ref.watch(tradesProvider).valueOrNull ?? const <Trade>[];
    final equity =
        ref.watch(equityProvider).valueOrNull ?? const <EquityPoint>[];
    final calendar =
        ref.watch(calendarProvider(_monthKey)).valueOrNull ??
        const <CalendarDay>[];
    final overview = ref.watch(overviewProvider).valueOrNull;
    final ddPct = maxDrawdownPct(equity);
    final stats = AnalyticsSnapshot.fromTrades(
      trades,
      period: period,
      resultFilter: resultFilter,
      drawdownPct: overview?.maxDrawdown ?? ddPct,
    );
    final chartPoints = showDrawdown ? drawdownPoints(equity) : equity;
    final dayTrades = selectedDay == null
        ? const <Trade>[]
        : sortTradesByEntry(
            trades.where((t) {
              final at = (t.closedAt ?? t.openedAt).toLocal();
              return at.year == selectedDay!.year &&
                  at.month == selectedDay!.month &&
                  at.day == selectedDay!.day;
            }),
          );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(journalProvider.notifier).reload();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Text(
                'Analysis',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(
                formatDate(DateTime.now()),
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Performance Analytics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _ChipRow(
                label: 'TIME PERIOD',
                items: periods,
                selected: period,
                onSelect: (value) => setState(() => period = value),
              ),
              const SizedBox(height: 8),
              _ChipRow(
                label: 'FILTER BY',
                items: filters,
                selected: resultFilter,
                onSelect: (value) => setState(() => resultFilter = value),
              ),
              const SizedBox(height: 12),
              _HeadlineGrid(stats: stats),
              const SizedBox(height: 12),
              _EquityCard(
                points: chartPoints,
                showDrawdown: showDrawdown,
                onToggle: (value) => setState(() => showDrawdown = value),
              ),
              const SizedBox(height: 12),
              _MiniStatWrap(stats: stats),
              const SizedBox(height: 12),
              _DistributionCard(stats: stats),
              const SizedBox(height: 12),
              _LongShortCard(stats: stats),
              const SizedBox(height: 12),
              _DayPerformanceCard(stats: stats),
              const SizedBox(height: 12),
              _TopSymbolsCard(stats: stats),
              const SizedBox(height: 12),
              _TradingCalendarCard(
                month: month,
                days: calendar,
                selected: selectedDay,
                onPrev: () => setState(() {
                  month = DateTime(month.year, month.month - 1);
                  selectedDay = null;
                }),
                onNext: () => setState(() {
                  month = DateTime(month.year, month.month + 1);
                  selectedDay = null;
                }),
                onSelect: (day) => setState(() => selectedDay = day),
              ),
              const SizedBox(height: 12),
              _DayTradesCard(day: selectedDay, trades: dayTrades),
              const SizedBox(height: 12),
              _YourStatsCard(stats: stats, period: period),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(item, style: const TextStyle(fontSize: 12)),
                    selected: selected == item,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onSelect(item),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeadlineGrid extends StatelessWidget {
  const _HeadlineGrid({required this.stats});
  final AnalyticsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final winColor = stats.winRate <= 0
        ? AppColors.negative
        : AppColors.positive;
    final pfColor = stats.profitFactor < 1
        ? AppColors.negative
        : AppColors.positive;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _HeadlineTile(
                label: 'TOTAL P&L',
                value: signedMoney(stats.totalPnl),
                valueColor: AppColors.primary,
                subtitle: 'From ${stats.closedCount} closed trades',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeadlineTile(
                label: 'WIN RATE',
                value: '${stats.winRate.toStringAsFixed(1)}%',
                valueColor: winColor,
                subtitle: '${stats.wins} wins · ${stats.losses} losses',
                progress: (stats.winRate / 100).clamp(0, 1),
                progressColor: winColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _HeadlineTile(
                label: 'PROFIT FACTOR',
                value: stats.profitFactor.toStringAsFixed(2),
                valueColor: pfColor,
                subtitle: stats.profitFactor < 1 ? 'Needs work' : 'Healthy',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeadlineTile(
                label: 'EXPECTANCY',
                value: signedMoney(stats.expectancy),
                valueColor: AppColors.primary,
                subtitle: 'Expected profit per trade',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeadlineTile extends StatelessWidget {
  const _HeadlineTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subtitle,
    this.progress,
    this.progressColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String subtitle;
  final double? progress;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (progress != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress == 0 ? 1 : progress,
                minHeight: 4,
                color: progressColor,
                backgroundColor: AppColors.border,
              ),
            )
          else
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.secondary, fontSize: 11),
            ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.secondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _EquityCard extends StatelessWidget {
  const _EquityCard({
    required this.points,
    required this.showDrawdown,
    required this.onToggle,
  });

  final List<EquityPoint> points;
  final bool showDrawdown;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equity Curve',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Cumulative P&L progression',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Equity'),
                    selected: !showDrawdown,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onToggle(false),
                  ),
                  ChoiceChip(
                    label: const Text('Drawdown'),
                    selected: showDrawdown,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onToggle(true),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          EquityChart(
            points: points,
            emptyLabel: 'Complete trades to see your equity curve',
            lineColor: showDrawdown ? AppColors.negative : AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _MiniStatWrap extends StatelessWidget {
  const _MiniStatWrap({required this.stats});
  final AnalyticsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('AVG WINNER', signedMoney(stats.avgWin), stats.avgWin >= 0),
      ('AVG LOSER', signedMoney(stats.avgLoss), stats.avgLoss >= 0),
      ('BEST TRADE', signedMoney(stats.best), stats.best >= 0),
      ('WORST TRADE', signedMoney(stats.worst), stats.worst >= 0),
      ('WIN STREAK', '${stats.winStreak}', true),
      ('LOSS STREAK', '${stats.lossStreak}', false),
      (
        'RISK:REWARD',
        stats.riskReward.toStringAsFixed(2),
        stats.riskReward >= 1,
      ),
      ('OPEN TRADES', '${stats.openCount}', true),
    ];
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _mini(items[i], Alignment.centerLeft)),
                Expanded(child: _mini(items[i + 1], Alignment.centerRight)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini((String, String, bool) item, Alignment align) {
    final right = align == Alignment.centerRight;
    return Column(
      crossAxisAlignment: right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          item.$1,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align,
          child: Text(
            item.$2,
            maxLines: 1,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: item.$3 ? AppColors.text : AppColors.negative,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.stats});
  final AnalyticsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.wins + stats.losses;
    final winFrac = total == 0 ? 0.5 : stats.wins / total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Win / Loss Distribution',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Text(
                '${stats.wins} winners · ${stats.losses} losers',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (winFrac * 1000).round().clamp(1, 999),
                    child: Container(color: AppColors.primary),
                  ),
                  Expanded(
                    flex: ((1 - winFrac) * 1000).round().clamp(1, 999),
                    child: Container(color: AppColors.negative),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metric(
                'GROSS PROFIT',
                signedMoney(stats.grossProfit),
                AppColors.primary,
                Alignment.centerLeft,
              ),
              _metric(
                'GROSS LOSS',
                signedMoney(stats.grossLoss),
                AppColors.negative,
                Alignment.center,
              ),
              _metric(
                'NET RESULT',
                signedMoney(stats.totalPnl),
                AppColors.text,
                Alignment.centerRight,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color, Alignment align) {
    final textAlign = align == Alignment.centerRight
        ? TextAlign.right
        : align == Alignment.center
        ? TextAlign.center
        : TextAlign.left;
    return Expanded(
      child: Column(
        crossAxisAlignment: align == Alignment.centerRight
            ? CrossAxisAlignment.end
            : align == Alignment.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: textAlign,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: align,
            child: Text(
              value,
              maxLines: 1,
              textAlign: textAlign,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LongShortCard extends StatelessWidget {
  const _LongShortCard({required this.stats});
  final AnalyticsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.longs.trades + stats.shorts.trades;
    final longFrac = total == 0 ? 0.5 : stats.longs.trades / total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Long vs Short',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Text(
            'Performance by trade direction',
            style: TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (longFrac * 1000).round().clamp(1, 999),
                    child: Container(color: AppColors.primary),
                  ),
                  Expanded(
                    flex: ((1 - longFrac) * 1000).round().clamp(1, 999),
                    child: Container(color: AppColors.negative),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _side('Long', stats.longs, stats.closedCount, AppColors.primary),
          const SizedBox(height: 8),
          _side('Short', stats.shorts, stats.closedCount, AppColors.negative),
        ],
      ),
    );
  }

  Widget _side(String label, SideBucket bucket, int closed, Color color) {
    final share = closed == 0 ? 0.0 : bucket.trades / closed * 100;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${bucket.trades} trades  ${share.toStringAsFixed(1)}%',
          style: const TextStyle(color: AppColors.secondary, fontSize: 12),
        ),
        const SizedBox(width: 12),
        PnlText(bucket.pnl, size: 14),
      ],
    );
  }
}

class _DayPerformanceCard extends StatelessWidget {
  const _DayPerformanceCard({required this.stats});
  final AnalyticsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Day Performance',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Text(
            'Find your best trading days',
            style: TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final day in stats.weekdays)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      day.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${day.trades} trades',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  PnlText(day.pnl, size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopSymbolsCard extends StatelessWidget {
  const _TopSymbolsCard({required this.stats});
  final AnalyticsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Symbols',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Text(
            'Best performing assets',
            style: TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (stats.symbols.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No symbol data yet',
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            )
          else
            for (final row in stats.symbols)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.symbol,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${row.trades} trades',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    PnlText(row.pnl, size: 14),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TradingCalendarCard extends StatelessWidget {
  const _TradingCalendarCard({
    required this.month,
    required this.days,
    required this.selected,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final List<CalendarDay> days;
  final DateTime? selected;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final map = {
      for (final d in days) DateTime(d.date.year, d.date.month, d.date.day): d,
    };
    final first = DateTime(month.year, month.month, 1);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final start = first.weekday - 1;
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trading Calendar',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Text(
            'Daily P&L heatmap — tap a day to see its trades',
            style: TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${months[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: start + count,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < start) return const SizedBox.shrink();
              final day = index - start + 1;
              final date = DateTime(month.year, month.month, day);
              final data = map[date];
              final isSelected =
                  selected != null &&
                  selected!.year == date.year &&
                  selected!.month == date.month &&
                  selected!.day == date.day;
              Color fill = AppColors.elevated;
              if (data != null) {
                final pnl = parseMoney(data.netPnl);
                fill = pnl > 0
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : pnl < 0
                    ? AppColors.negative.withValues(alpha: 0.4)
                    : AppColors.elevated;
              }
              return InkWell(
                onTap: () => onSelect(date),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: AppColors.primary)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 12,
            children: [
              _Legend(color: AppColors.primary, label: 'Profitable Day'),
              _Legend(color: AppColors.negative, label: 'Losing Day'),
              _Legend(color: AppColors.elevated, label: 'No Trades'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _DayTradesCard extends StatelessWidget {
  const _DayTradesCard({required this.day, required this.trades});
  final DateTime? day;
  final List<Trade> trades;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Day Trades',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (day == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Tap a day with trades to view details',
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            )
          else if (trades.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No trades on this day',
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            )
          else
            Column(
              children: [for (final trade in trades) TradeTile(trade: trade)],
            ),
        ],
      ),
    );
  }
}

class _YourStatsCard extends StatelessWidget {
  const _YourStatsCard({required this.stats, required this.period});
  final AnalyticsSnapshot stats;
  final String period;

  @override
  Widget build(BuildContext context) {
    final rows = [
      StatRow(
        label: 'Total P&L',
        value: signedMoney(stats.totalPnl),
        negative: stats.totalPnl < 0,
      ),
      StatRow(
        label: 'Average daily volume',
        value: stats.avgDailyVolume.toStringAsFixed(2),
      ),
      StatRow(label: 'Average winning trade', value: signedMoney(stats.avgWin)),
      StatRow(
        label: 'Average losing trade',
        value: signedMoney(stats.avgLoss),
        negative: true,
      ),
      StatRow(label: 'Total number of trades', value: '${stats.closedCount}'),
      StatRow(label: 'Number of winning trades', value: '${stats.wins}'),
      StatRow(
        label: 'Number of losing trades',
        value: '${stats.losses}',
        negative: true,
      ),
      StatRow(
        label: 'Number of break even trades',
        value: '${stats.breakeven}',
      ),
      StatRow(label: 'Max consecutive wins', value: '${stats.winStreak}'),
      StatRow(
        label: 'Max consecutive losses',
        value: '${stats.lossStreak}',
        negative: true,
      ),
      StatRow(
        label: 'Total commissions',
        value: signedMoney(stats.commissions),
      ),
      StatRow(label: 'Total swap', value: signedMoney(stats.swaps)),
      StatRow(label: 'Largest profit', value: signedMoney(stats.best)),
      StatRow(
        label: 'Largest loss',
        value: signedMoney(stats.worst),
        negative: true,
      ),
      StatRow(label: 'Avg hold time (All)', value: stats.holdAll),
      StatRow(label: 'Avg hold time (Winners)', value: stats.holdWins),
      StatRow(label: 'Avg hold time (Losers)', value: stats.holdLosses),
      StatRow(label: 'Open trades', value: '${stats.openCount}'),
      StatRow(label: 'Total trading days', value: '${stats.tradingDays}'),
      StatRow(label: 'Winning days', value: '${stats.winningDays}'),
      StatRow(
        label: 'Losing days',
        value: '${stats.losingDays}',
        negative: true,
      ),
      StatRow(label: 'Breakeven days', value: '${stats.breakevenDays}'),
      StatRow(
        label: 'Max consecutive winning days',
        value: '${stats.dayWinStreak}',
      ),
      StatRow(
        label: 'Max consecutive losing days',
        value: '${stats.dayLossStreak}',
        negative: true,
      ),
      StatRow(
        label: 'Average daily P&L',
        value: signedMoney(stats.avgDailyPnl),
        negative: stats.avgDailyPnl < 0,
      ),
      StatRow(
        label: 'Average winning day P&L',
        value: signedMoney(stats.avgWinningDay),
      ),
      StatRow(
        label: 'Average losing day P&L',
        value: signedMoney(stats.avgLosingDay),
        negative: true,
      ),
      StatRow(
        label: 'Largest profitable day',
        value: signedMoney(stats.bestDay),
      ),
      StatRow(
        label: 'Largest losing day',
        value: signedMoney(stats.worstDay),
        negative: true,
      ),
      StatRow(label: 'Trade expectancy', value: signedMoney(stats.expectancy)),
      StatRow(
        label: 'Max drawdown',
        value: signedMoney(-stats.maxDrawdown.abs()),
        negative: true,
      ),
      StatRow(
        label: 'Max drawdown %',
        value: '${stats.maxDrawdownPct.toStringAsFixed(1)}%',
        negative: true,
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Stats',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  period.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _monthStat('BEST MONTH', stats.bestMonth, Alignment.centerLeft),
              _monthStat('WORST MONTH', stats.worstMonth, Alignment.center),
              _monthStat(
                'AVERAGE',
                signedMoney(stats.avgMonth),
                Alignment.centerRight,
                caption: 'per month',
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    row.value,
                    style: TextStyle(
                      color: row.negative ? AppColors.negative : AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthStat(
    String label,
    String value,
    Alignment align, {
    String? caption,
  }) {
    final textAlign = align == Alignment.centerRight
        ? TextAlign.right
        : align == Alignment.center
        ? TextAlign.center
        : TextAlign.left;
    return Expanded(
      child: Column(
        crossAxisAlignment: align == Alignment.centerRight
            ? CrossAxisAlignment.end
            : align == Alignment.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: textAlign,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: align,
            child: Text(
              value,
              maxLines: 1,
              textAlign: textAlign,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          if (caption != null)
            Text(
              caption,
              textAlign: textAlign,
              style: const TextStyle(color: AppColors.secondary, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime month;

  @override
  void initState() {
    super.initState();
    month = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final days = ref.watch(calendarProvider(key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        leading: IconButton(
          onPressed: () => popOrGo(context, '/more'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: days.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TradingCalendarCard(
              month: month,
              days: items,
              selected: null,
              onPrev: () =>
                  setState(() => month = DateTime(month.year, month.month - 1)),
              onNext: () =>
                  setState(() => month = DateTime(month.year, month.month + 1)),
              onSelect: (_) => context.go('/analytics'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString()),
      ),
    );
  }
}
