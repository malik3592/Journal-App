import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/shared/models/models.dart';
import 'package:journal/shared/widgets/cash_sheet.dart';
import 'package:journal/shared/widgets/equity_chart.dart';
import 'package:journal/shared/widgets/ui.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final search = TextEditingController();
  String range = '1M';
  late DateTime month;
  String query = '';

  static const ranges = ['1D', '1W', '1M', '3M', 'ALL'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String get _monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  List<EquityPoint> _ranged(List<EquityPoint> points) {
    if (range == 'ALL' || points.isEmpty) return points;
    final now = DateTime.now();
    final from = switch (range) {
      '1D' => now.subtract(const Duration(days: 1)),
      '1W' => now.subtract(const Duration(days: 7)),
      '1M' => DateTime(now.year, now.month - 1, now.day),
      '3M' => DateTime(now.year, now.month - 3, now.day),
      _ => DateTime(2000),
    };
    return points.where((p) => !p.time.isBefore(from)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(overviewProvider);
    final trades = ref.watch(tradesProvider);
    final equity = ref.watch(equityProvider);
    final calendar = ref.watch(calendarProvider(_monthKey));
    final journal = ref.watch(journalProvider);
    final user = journal.profile;
    final tradeList = trades.valueOrNull ?? const <Trade>[];
    final stats = _DashboardStats.from(
      tradeList,
      overview.valueOrNull,
      balance:
          overview.valueOrNull?.balance ?? parseMoney(journal.startingBalance),
      currency: journal.account.currency,
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
              _Header(
                name: user.displayName,
                onAdd: () => context.push('/manual-trade'),
                onProfile: () => context.go('/more'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: search,
                onChanged: (value) =>
                    setState(() => query = value.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
              if (tradeList.isEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add a manual trade to fill this dashboard.',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/manual-trade'),
                        child: const Text('Add trade'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _KpiGrid(
                stats: stats,
                onBalanceTap: () => showCashSheet(context),
              ),
              const SizedBox(height: 12),
              _PerformanceCard(
                stats: stats,
                range: range,
                ranges: ranges,
                onRange: (value) => setState(() => range = value),
                points: _ranged(equity.valueOrNull ?? const []),
              ),
              const SizedBox(height: 12),
              _MonthlyPnlCard(
                month: month,
                days: calendar.valueOrNull ?? const [],
                monthlyPnl: stats.realized,
                onPrev: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                onNext: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
              ),
              const SizedBox(height: 12),
              _OpenPositionsCard(
                trades: stats.openTrades
                    .where(
                      (t) =>
                          query.isEmpty ||
                          t.symbol.toLowerCase().contains(query),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              _RecentActivityCard(
                trades: stats.recent
                    .where(
                      (t) =>
                          query.isEmpty ||
                          t.symbol.toLowerCase().contains(query),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              _TopPerformersCard(rows: stats.topSymbols),
              const SizedBox(height: 12),
              _QuickStatsCard(stats: stats),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.totalPnl,
    required this.balance,
    required this.currency,
    required this.realized,
    required this.winRate,
    required this.openCount,
    required this.closedCount,
    required this.avgWin,
    required this.avgLoss,
    required this.best,
    required this.worst,
    required this.openTrades,
    required this.recent,
    required this.topSymbols,
  });

  final num totalPnl;
  final num balance;
  final String currency;
  final num realized;
  final double winRate;
  final int openCount;
  final int closedCount;
  final num avgWin;
  final num avgLoss;
  final num best;
  final num worst;
  final List<Trade> openTrades;
  final List<Trade> recent;
  final List<({String symbol, num pnl, int trades})> topSymbols;

  factory _DashboardStats.from(
    List<Trade> trades,
    AnalyticsOverview? overview, {
    required num balance,
    required String currency,
  }) {
    final open = trades.where((t) => t.isOpen).toList();
    final closed = trades.where((t) => !t.isOpen).toList();
    final unrealized = open.fold<num>(0, (s, t) => s + parseMoney(t.netProfit));
    final realized = closed.fold<num>(0, (s, t) => s + parseMoney(t.netProfit));
    final wins = closed.where((t) => t.isWin).toList();
    final losses = closed.where((t) => t.isLoss).toList();
    final decided = wins.length + losses.length;
    final bySymbol = <String, ({num pnl, int trades})>{};
    for (final trade in closed) {
      final current = bySymbol[trade.symbol] ?? (pnl: 0, trades: 0);
      bySymbol[trade.symbol] = (
        pnl: current.pnl + parseMoney(trade.netProfit),
        trades: current.trades + 1,
      );
    }
    final top = bySymbol.entries.toList()
      ..sort((a, b) => b.value.pnl.compareTo(a.value.pnl));
    return _DashboardStats(
      totalPnl: overview != null
          ? parseMoney(overview.netPnl)
          : realized + unrealized,
      balance: balance,
      currency: currency,
      realized: realized,
      winRate:
          overview?.winRate ?? (decided == 0 ? 0 : wins.length / decided * 100),
      openCount: open.length,
      closedCount: closed.length,
      avgWin: overview?.averageWin != null
          ? parseMoney(overview!.averageWin)
          : (wins.isEmpty
                ? 0
                : wins.fold<num>(0, (s, t) => s + parseMoney(t.netProfit)) /
                      wins.length),
      avgLoss: overview?.averageLoss != null
          ? parseMoney(overview!.averageLoss)
          : (losses.isEmpty
                ? 0
                : losses.fold<num>(0, (s, t) => s + parseMoney(t.netProfit)) /
                      losses.length),
      best: overview?.largestWin != null
          ? parseMoney(overview!.largestWin)
          : (closed.isEmpty
                ? 0
                : closed
                      .map((t) => parseMoney(t.netProfit))
                      .reduce((a, b) => a > b ? a : b)),
      worst: overview?.largestLoss != null
          ? parseMoney(overview!.largestLoss)
          : (closed.isEmpty
                ? 0
                : closed
                      .map((t) => parseMoney(t.netProfit))
                      .reduce((a, b) => a < b ? a : b)),
      openTrades: open,
      recent: trades.take(6).toList(),
      topSymbols: top
          .take(3)
          .map((e) => (symbol: e.key, pnl: e.value.pnl, trades: e.value.trades))
          .toList(),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({required this.onAdd, required this.onProfile, this.name});
  final VoidCallback onAdd;
  final VoidCallback onProfile;
  final String? name;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(
                DateFormat('E, MMM d').format(_now),
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Text(
          DateFormat('h:mm:ss a').format(_now),
          style: const TextStyle(color: AppColors.secondary, fontSize: 12),
        ),
        const SizedBox(width: 8),
        _RoundIcon(icon: Icons.add, onTap: widget.onAdd, filled: true),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onProfile,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.elevated,
            child: Text(
              (widget.name ?? 'T').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.elevated,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled ? Colors.white : AppColors.text,
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats, required this.onBalanceTap});
  final _DashboardStats stats;
  final VoidCallback onBalanceTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.primary,
                label: 'TOTAL P&L',
                value: signedMoney(stats.totalPnl),
                valueColor: stats.totalPnl >= 0
                    ? AppColors.primary
                    : AppColors.negative,
                subtitle: '${stats.openCount + stats.closedCount} trades',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.gold,
                label: 'BALANCE',
                value: money(stats.balance),
                valueColor: AppColors.text,
                subtitle: stats.currency,
                onTap: onBalanceTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFF4EA3F7),
                label: 'REALIZED',
                value: signedMoney(stats.realized),
                valueColor: AppColors.text,
                subtitle: '${stats.closedCount} closed trades',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: Icons.gps_fixed,
                iconColor: AppColors.positive,
                label: 'WIN RATE',
                value: '${stats.winRate.toStringAsFixed(0)}%',
                valueColor: AppColors.text,
                progress: (stats.winRate / 100).clamp(0, 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    this.subtitle,
    this.progress,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 6),
            if (progress != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  color: AppColors.positive,
                  backgroundColor: AppColors.border,
                ),
              )
            else
              Text(
                subtitle ?? '',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.stats,
    required this.range,
    required this.ranges,
    required this.onRange,
    required this.points,
  });

  final _DashboardStats stats;
  final String range;
  final List<String> ranges;
  final ValueChanged<String> onRange;
  final List<EquityPoint> points;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERFORMANCE',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            signedMoney(stats.totalPnl),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in ranges)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(item, style: const TextStyle(fontSize: 11)),
                      selected: range == item,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onRange(item),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          EquityChart(points: points),
        ],
      ),
    );
  }
}

class _MonthlyPnlCard extends StatelessWidget {
  const _MonthlyPnlCard({
    required this.month,
    required this.days,
    required this.monthlyPnl,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final List<CalendarDay> days;
  final num monthlyPnl;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final map = {
      for (final d in days) DateTime(d.date.year, d.date.month, d.date.day): d,
    };
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final start = first.weekday - 1;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monthly P&L',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'Monthly: ${signedMoney(monthlyPnl)}',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left, size: 20),
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
                icon: const Icon(Icons.chevron_right, size: 20),
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
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: start + daysInMonth,
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
              final today = DateTime.now();
              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              Color fill = AppColors.elevated;
              if (data != null) {
                final pnl = parseMoney(data.netPnl);
                fill = pnl > 0
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : pnl < 0
                    ? AppColors.negative.withValues(alpha: 0.35)
                    : AppColors.elevated;
              }
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? Border.all(color: AppColors.primary) : null,
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
              );
            },
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _LegendDot(color: AppColors.primary, label: 'Profit'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.negative, label: 'Loss'),
            ],
          ),
        ],
      ),
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

class _OpenPositionsCard extends StatelessWidget {
  const _OpenPositionsCard({required this.trades});
  final List<Trade> trades;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open Positions',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (trades.isEmpty)
            const _MutedEmpty(
              icon: Icons.view_list_outlined,
              label: 'No open positions',
            )
          else
            Column(
              children: [
                for (final trade in trades.take(4)) TradeTile(trade: trade),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/trades'),
              child: const Text('View All Positions  →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.trades});
  final List<Trade> trades;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Activity',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Text(
                '${trades.length} trades',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (trades.isEmpty)
            const _MutedEmpty(icon: Icons.schedule, label: 'No recent activity')
          else
            Column(
              children: [
                for (final trade in trades.take(5)) TradeTile(trade: trade),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/trades'),
              child: const Text('View All Activity  →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPerformersCard extends StatelessWidget {
  const _TopPerformersCard({required this.rows});
  final List<({String symbol, num pnl, int trades})> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Performers',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const _MutedEmpty(
              icon: Icons.insights_outlined,
              label: 'No trading data yet',
            )
          else
            for (final row in rows)
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

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({required this.stats});
  final _DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _quickRow(
            _mini(
              'Avg Win',
              signedMoney(stats.avgWin),
              stats.avgWin >= 0,
              Alignment.centerLeft,
            ),
            _mini(
              'Avg Loss',
              signedMoney(stats.avgLoss),
              stats.avgLoss >= 0,
              Alignment.centerRight,
            ),
          ),
          const SizedBox(height: 16),
          _quickRow(
            _mini(
              'Best Trade',
              signedMoney(stats.best),
              stats.best >= 0,
              Alignment.centerLeft,
            ),
            _mini(
              'Worst Trade',
              signedMoney(stats.worst),
              stats.worst >= 0,
              Alignment.centerRight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickRow(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        Expanded(child: right),
      ],
    );
  }

  Widget _mini(String label, String value, bool positive, Alignment align) {
    final right = align == Alignment.centerRight;
    return Column(
      crossAxisAlignment: right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: const TextStyle(color: AppColors.secondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align,
          child: Text(
            value,
            maxLines: 1,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: positive ? AppColors.positive : AppColors.negative,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _MutedEmpty extends StatelessWidget {
  const _MutedEmpty({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.secondary)),
        ],
      ),
    );
  }
}

class TradeTile extends StatelessWidget {
  const TradeTile({super.key, required this.trade});
  final Trade trade;

  @override
  Widget build(BuildContext context) {
    final pnl = parseMoney(trade.netProfit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/trade/${trade.id}'),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.elevated,
                child: Text(
                  trade.symbol.substring(0, trade.symbol.length.clamp(0, 2)),
                  style: const TextStyle(color: AppColors.gold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trade.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${trade.direction} · ${trade.volume}',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PnlText(pnl, size: 14),
                  StatusChip(label: trade.resultLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
