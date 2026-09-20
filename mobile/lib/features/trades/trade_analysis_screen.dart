import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/core/local/trade_quality.dart';
import 'package:journal/core/nav.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/shared/widgets/ui.dart';

class TradeAnalysisScreen extends ConsumerWidget {
  const TradeAnalysisScreen({super.key, required this.tradeId});
  final String tradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradeAsync = ref.watch(tradeProvider(tradeId));
    final trades = ref.watch(journalProvider).trades;
    return tradeAsync.when(
      data: (trade) {
        final quality = TradeQuality.fromTrade(trade);
        final compare = TradeAverageCompare.of(trade, trades);
        final hold = tradeHoldDuration(trade.openedAt, trade.closedAt);
        final move = tradePriceMovePct(
          entryPrice: trade.entryPrice,
          exitPrice: trade.exitPrice,
        );
        final side = trade.direction.toUpperCase() == 'SELL' ? 'SHORT' : 'LONG';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Trade Analysis'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => popOrGo(context, '/trade/$tradeId'),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trade.symbol,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusChip(label: trade.resultLabel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        side,
                        if ((trade.timeframe ?? '').isNotEmpty)
                          trade.timeframe!,
                        formatDateTime(trade.openedAt),
                        'Held ${formatHoldDuration(hold)}',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PnlText(parseMoney(trade.netProfit), size: 26),
                        const Spacer(),
                        StatusChip(label: 'Score ${quality.total}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    _kv('Entry price', trade.entryPrice),
                    _kv('Exit price', trade.exitPrice ?? '—'),
                    _kv('Quantity', '${trade.volume} lots'),
                    _kv(
                      'Price move',
                      move == null
                          ? '—'
                          : '${move >= 0 ? '+' : ''}${move.toStringAsFixed(2)}%',
                      color: move == null
                          ? null
                          : move > 0
                          ? AppColors.positive
                          : move < 0
                          ? AppColors.negative
                          : AppColors.secondary,
                    ),
                    _kv('Duration', formatHoldDuration(hold), last: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trade simulation',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Candle replay around your entry and exit',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Icon(
                        Icons.ssid_chart,
                        color: AppColors.secondary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Trade replay not available',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This trade was added manually. Replay and simulation stay off so the app never connects to a broker.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Journal entry',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusChip(
                          label: trade.journalStatus == 'COMPLETE'
                              ? 'Journaled'
                              : 'Not journaled',
                          positive: trade.journalStatus == 'COMPLETE',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (trade.journalStatus == 'COMPLETE') ...[
                      Row(
                        children: [
                          Expanded(
                            child: _flag(
                              'Followed plan',
                              quality.flags.followedPlan,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _flag(
                              'Proper risk',
                              quality.flags.properRisk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _flag('Good entry', quality.flags.goodEntry),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _flag(
                              'Patient exit',
                              quality.flags.patientExit,
                            ),
                          ),
                        ],
                      ),
                      if (trade.preAnalysis.isNotEmpty) ...[
                        const Text(
                          'Pre-trade',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final item in trade.preAnalysis.where(
                              (e) => e != 'Other',
                            ))
                              StatusChip(label: item),
                          ],
                        ),
                        if (trade.notes?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          _journalLine('Other', trade.notes!),
                        ],
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Rating',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 1; i <= 10; i++)
                            Icon(
                              i <= quality.rating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 18,
                              color: i <= quality.rating
                                  ? AppColors.gold
                                  : AppColors.secondary,
                            ),
                          const SizedBox(width: 8),
                          Text('${quality.rating}/10'),
                        ],
                      ),
                      if (trade.lessons?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        _journalLine('Lessons learned', trade.lessons!),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/trade/${trade.id}/journal'),
                        child: const Text('View full journal'),
                      ),
                    ] else ...[
                      const Text(
                        'No journal entry for this trade.',
                        style: TextStyle(color: AppColors.secondary),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            context.push('/trade/${trade.id}/journal'),
                        child: const Text('Add journal entry'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trade quality',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: quality.total / quality.max,
                                strokeWidth: 8,
                                color: _gradeColor(quality.total),
                                backgroundColor: AppColors.border,
                              ),
                              Text(
                                '${quality.total}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _gradeColor(quality.total),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              for (final bar in quality.bars) ...[
                                _qualityBar(bar),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quality.grade,
                      style: TextStyle(
                        color: _gradeColor(quality.total),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'How is this calculated?',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Profitability (30): win 30, break even 15, loss 0.\n'
                      'Execution (40): 10 each for followed plan, 1:1+ R:R, clean entry, and leaving SL/TP alone.\n'
                      'Journal (20): 5 each for pre-trade, post-trade, emotion, and lessons.\n'
                      'Rating (10): the same 1–10 process rating from the journal.\n'
                      '80+ excellent · 60+ good · 40+ average · under 40 needs work.',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Insights',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusChip(label: 'Coming soon'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI-powered trading insights and pattern analysis.',
                      style: TextStyle(color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'vs your average',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _compareCard(
                      compare.peerLabel,
                      compare.averagePnl == null
                          ? '—'
                          : signedMoney(compare.averagePnl!),
                      compare.pnlDeltaPct,
                      moneyColor: compare.averagePnl,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _compareCard(
                      'Hold duration',
                      formatHoldDuration(compare.averageHold),
                      compare.holdDeltaPct,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _compareCard(
                      'Execution score',
                      '${compare.executionPct.round()}%',
                      compare.executionDeltaPct,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
    );
  }

  Widget _kv(String label, String value, {Color? color, bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flag(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? AppColors.positive : AppColors.secondary,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _journalLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _qualityBar(QualityBar bar) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            bar.label,
            style: const TextStyle(fontSize: 11, color: AppColors.secondary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: bar.fraction,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${bar.earned}/${bar.max}',
          style: const TextStyle(fontSize: 11, color: AppColors.secondary),
        ),
      ],
    );
  }

  Widget _compareCard(
    String label,
    String value,
    double? deltaPct, {
    num? moneyColor,
  }) {
    final delta = deltaPct == null
        ? '—'
        : '${deltaPct >= 0 ? '+' : ''}${deltaPct.toStringAsFixed(0)}%';
    final deltaColor = deltaPct == null || deltaPct == 0
        ? AppColors.secondary
        : deltaPct > 0
        ? AppColors.positive
        : AppColors.negative;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: AppColors.secondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: moneyColor == null
                  ? AppColors.text
                  : moneyColor > 0
                  ? AppColors.positive
                  : moneyColor < 0
                  ? AppColors.negative
                  : AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(delta, style: TextStyle(color: deltaColor, fontSize: 12)),
        ],
      ),
    );
  }

  Color _gradeColor(int score) {
    if (score >= 80) return AppColors.positive;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.gold;
    return AppColors.negative;
  }
}
