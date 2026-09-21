import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/core/local/journal_database.dart';
import 'package:journal/core/local/trade_shots.dart';
import 'package:journal/core/nav.dart';
import 'package:journal/features/auth/lock_controller.dart';
import 'package:journal/features/dashboard/home_screen.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/shared/models/models.dart';
import 'package:journal/shared/widgets/trade_chart.dart';
import 'package:journal/shared/widgets/ui.dart';

class TradesScreen extends ConsumerStatefulWidget {
  const TradesScreen({super.key});

  @override
  ConsumerState<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends ConsumerState<TradesScreen> {
  String query = '';
  String? result;

  @override
  Widget build(BuildContext context) {
    final trades = ref.watch(tradesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trades',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manual trades saved on this device',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.secondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search symbol / ticket',
                ),
                onChanged: (value) =>
                    setState(() => query = value.toLowerCase()),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final item in ['ALL', 'WIN', 'LOSS', 'BE', 'OPEN'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item),
                        selected: (result ?? 'ALL') == item,
                        onSelected: (_) => setState(
                          () => result = item == 'ALL' ? null : item,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: trades.when(
                data: (list) {
                  final filtered = list.where((t) {
                    final matchesQuery =
                        query.isEmpty ||
                        t.symbol.toLowerCase().contains(query) ||
                        (t.ticket ?? '').contains(query);
                    final matchesResult =
                        result == null ||
                        (result == 'BE' ? t.isBreakEven : t.result == result);
                    return matchesQuery && matchesResult;
                  }).toList();
                  if (filtered.isEmpty) {
                    return EmptyState(
                      title: 'No trades yet',
                      message: 'Add a trade manually to start journaling.',
                      actionLabel: 'Add a trade',
                      onAction: () => context.push('/manual-trade'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.read(journalProvider.notifier).reload(),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final trade in filtered)
                          Dismissible(
                            key: ValueKey(trade.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.negative.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: AppColors.negative,
                              ),
                            ),
                            confirmDismiss: (_) =>
                                confirmDeleteTrade(context, trade.symbol),
                            onDismissed: (_) => ref
                                .read(tradeRepositoryProvider)
                                .deleteManual(trade.id),
                            child: TradeTile(trade: trade),
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.read(journalProvider.notifier).reload(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TradeDetailScreen extends ConsumerWidget {
  const TradeDetailScreen({super.key, required this.tradeId});
  final String tradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradeAsync = ref.watch(tradeProvider(tradeId));
    return tradeAsync.when(
      data: (trade) => Scaffold(
        appBar: AppBar(
          title: const Text('Trade Detail'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => popOrGo(context),
          ),
          actions: [
            IconButton(
              tooltip: 'Edit',
              onPressed: () => context.push('/trade/${trade.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => deleteTrade(context, ref, trade),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const StatusChip(label: 'Manual', positive: true),
                const Spacer(),
                StatusChip(label: trade.resultLabel),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              trade.symbol,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            Text(
              '${trade.direction} · ${trade.volume} Lots',
              style: const TextStyle(color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            PnlText(parseMoney(trade.netProfit), size: 28),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TRADE DATA',
                    style: TextStyle(color: AppColors.secondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _row('Ticket', trade.ticket ?? '—'),
                  _row('Open Time', formatDateTime(trade.openedAt)),
                  _row(
                    'Close Time',
                    trade.closedAt == null
                        ? 'Open'
                        : formatDateTime(trade.closedAt!),
                  ),
                  _row('Entry Price', trade.entryPrice),
                  _row('Exit Price', trade.exitPrice ?? '—'),
                  _row('Stop Loss', trade.stopLoss ?? '—'),
                  _row('Timeframe', trade.timeframe ?? '—'),
                  _row('Take Profit', trade.takeProfit ?? '—'),
                  _row('Commission', trade.commission ?? '0'),
                  _row('Swap', trade.swap ?? '0'),
                  if (trade.riskFree) _row('Outcome', 'Break even / Risk free'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _TradeDetailActions(trade: trade),
          ],
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TradeDetailActions extends StatelessWidget {
  const _TradeDetailActions({required this.trade});
  final Trade trade;

  static final _secondaryStyle = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    foregroundColor: AppColors.text,
    side: const BorderSide(color: AppColors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  @override
  Widget build(BuildContext context) {
    final complete = trade.journalStatus == 'COMPLETE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (complete) ...[
          const Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: AppColors.positive),
              SizedBox(width: 6),
              Text(
                'Journal complete',
                style: TextStyle(
                  color: AppColors.positive,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/trade/${trade.id}/analysis'),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Analyze trade'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/trade/${trade.id}/journal'),
            style: _secondaryStyle,
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Update journal'),
          ),
        ] else
          FilledButton.icon(
            onPressed: () => context.push('/trade/${trade.id}/journal'),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Complete journal'),
          ),
      ],
    );
  }
}

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, required this.tradeId});
  final String tradeId;

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final notes = TextEditingController();
  final postReview = TextEditingController();
  final lessons = TextEditingController();
  final _shots = TradeShotStore();
  String? strategyId;
  String? emotion;
  int confidence = 3;
  int rating = 5;
  final selectedConditions = <String>{};
  final selectedMistakes = <String>{};
  final selectedEntryReasons = <String>{};
  final selectedExitReasons = <String>{};
  final screenshots = <String>[];
  late List<ChecklistEntry> checklist;
  String? timeframe;
  final selectedPre = <String>{};
  String? postChoice;
  bool loading = false;
  String? message;
  bool primed = false;

  static const emotions = [
    'Calm',
    'Confident',
    'Neutral',
    'Hesitant',
    'Fearful',
    'Greedy',
    'FOMO',
    'Revenge',
    'Frustrated',
    'Overconfident',
    'Patient',
    'Impatient',
    'Anxious',
    'Doubtful',
    'Excited',
    'Bored',
    'Stressed',
    'Distracted',
    'Disciplined',
    'Impulsive',
  ];
  static const conditions = [
    'Trending',
    'Ranging',
    'Volatile',
    'Low Volatility',
    'News Driven',
    'Strong Trend',
    'Weak Trend',
    'Breakout',
    'Consolidation',
    'Pullback',
    'Reversal',
    'Choppy',
    'Liquidity Sweep',
    'High Liquidity',
    'Low Liquidity',
    'Session Open',
    'Pre-News',
    'Post-News',
    'Unclear',
  ];
  static const mistakes = [
    'Entered early',
    'Entered late',
    'Oversized',
    'Moved stop loss',
    'Moved take profit',
    'FOMO',
    'Revenge trade',
    'Ignored confirmation',
    'Broke strategy',
    'Overtraded',
    'No Stop Loss',
    'Risked Too Much',
    'Poor Risk/Reward',
    'Wrong Position Size',
    'Chased Price',
    'Entered Without Setup',
    'Ignored Market Context',
    'Ignored Trend',
    'Traded Against Trend',
    'Entered During News',
    'Ignored Spread',
    'Ignored Liquidity',
    'Duplicate Entry',
    'Too Many Entries',
    'Partial Exit Too Early',
    'Did Not Take Planned Profit',
    'Closed Trade Emotionally',
    'Did Not Follow Trading Session',
    'None',
  ];
  static const entryReasons = [
    'Breakout',
    'Pullback',
    'Retest',
    'Support/Resistance',
    'Trend Continuation',
    'Trend Reversal',
    'Liquidity Sweep',
    'Price Action',
    'Indicator Confirmation',
    'News/Event',
    'Other',
  ];
  static const exitReasons = [
    'Take Profit Hit',
    'Stop Loss Hit',
    'Manual Profit',
    'Manual Loss',
    'Trailing Stop',
    'Moved Stop',
    'Moved Take Profit',
    'Fear',
    'Greed',
    'News',
    'Market Reversal',
    'Other',
  ];
  static const otherLabel = 'Other';
  static const timeframes = [
    '1m',
    '5m',
    '15m',
    '30m',
    '1H',
    '4H',
    '1D',
    '1W',
    '1M',
  ];
  static const preTradeOptions = [
    'QML',
    'Inter Level 4 A+',
    'JTL1',
    'JTL2',
    'Inter Level 3',
    'SBR',
    'RBS',
    'Double Bottom',
    'Double Top',
    'FIB',
    'Clear higher-timeframe bias',
    'At key support / resistance',
    'Liquidity sweep then entry',
    'Breakout and retest',
    'Session open setup',
    'News / high-impact event',
    otherLabel,
  ];
  static const postTradeOptions = [
    'Perfect Execution',
    'Good Entry',
    'Poor Entry',
    'Good Exit',
    'Poor Exit',
    'Risk Was Well Managed',
    'Risk Was Too High',
    'Trade Was Too Large',
    'Exited Due to Emotion',
    'Exited Due to Fear',
    'Exited Due to Greed',
    'Missed the Setup',
    'Should Have Waited',
    'Followed Confirmation',
    'Ignored Confirmation',
    'Market Changed',
    'News Affected Trade',
    'Spread Affected Trade',
    'Setup Worked as Expected',
    'Setup Failed',
    'Trade Was Unnecessary',
    'Followed the plan',
    'Good execution',
    'Cut winner too early',
    'Held loser too long',
    'Moved stop or target',
    'Entered too early / late',
    'Broke my rules',
    otherLabel,
  ];

  String? _choiceFromStored(String? stored, List<String> options) {
    final text = stored?.trim() ?? '';
    if (text.isEmpty) return null;
    if (options.contains(text) && text != otherLabel) return text;
    return otherLabel;
  }

  String _storedFromChoice(String? choice, TextEditingController other) {
    if (choice == null) return '';
    if (choice == otherLabel) return other.text.trim();
    return choice;
  }

  @override
  void dispose() {
    notes.removeListener(_clearMessage);
    postReview.removeListener(_clearMessage);
    lessons.removeListener(_clearMessage);
    notes.dispose();
    postReview.dispose();
    lessons.dispose();
    super.dispose();
  }

  void _clearMessage() {
    if (message != null && mounted) setState(() => message = null);
  }

  void _prime(Trade trade) {
    if (primed) return;
    primed = true;
    timeframe = trade.timeframe;
    selectedPre
      ..clear()
      ..addAll(
        trade.preAnalysis.map((item) {
          if (item == 'A+' || item == 'Inter Level 4')
            return 'Inter Level 4 A+';
          return item;
        }),
      );
    if (selectedPre.isEmpty && (trade.notes ?? '').trim().isNotEmpty) {
      final stored = trade.notes!.trim();
      if (preTradeOptions.contains(stored) && stored != otherLabel) {
        selectedPre.add(stored);
      } else {
        selectedPre.add(otherLabel);
        notes.text = stored;
      }
    } else if (selectedPre.contains(otherLabel)) {
      notes.text = trade.notes ?? '';
    }
    postChoice = _choiceFromStored(trade.postReview, postTradeOptions);
    postReview.text = postChoice == otherLabel ? (trade.postReview ?? '') : '';
    lessons.text = trade.lessons ?? '';
    notes.addListener(_clearMessage);
    postReview.addListener(_clearMessage);
    lessons.addListener(_clearMessage);
    strategyId =
        trade.strategyId ??
        defaultStrategy(
          ref.read(strategiesProvider).valueOrNull ?? const [],
        )?.id;
    emotion = trade.primaryEmotion;
    confidence = trade.confidence ?? 3;
    rating = trade.rating ?? 5;
    selectedConditions.addAll(trade.marketConditions);
    selectedMistakes.addAll(trade.mistakes);
    selectedEntryReasons.addAll(trade.entryReasons);
    selectedExitReasons.addAll(trade.exitReasons);
    screenshots
      ..clear()
      ..addAll(trade.screenshots);
    checklist = trade.checklist.isNotEmpty
        ? [...trade.checklist]
        : [
            const ChecklistEntry(
              label: 'Checked higher timeframe',
              checked: false,
            ),
            const ChecklistEntry(label: 'Risk within limits', checked: false),
            const ChecklistEntry(label: 'Fits my trading plan', checked: false),
            const ChecklistEntry(
              label: 'Key levels identified',
              checked: false,
            ),
            const ChecklistEntry(
              label: 'Economic calendar checked',
              checked: false,
            ),
          ];
  }

  Map<String, dynamic> _journalBody() => {
    'strategyId':
        strategyId ??
        defaultStrategy(
          ref.read(strategiesProvider).valueOrNull ?? const [],
        )?.id,
    'primaryEmotion': emotion,
    'timeframe': timeframe,
    'preAnalysis': selectedPre.toList(),
    'notes': selectedPre.contains(otherLabel) ? notes.text : null,
    'postReview': _storedFromChoice(postChoice, postReview),
    'lessons': lessons.text,
    'confidence': confidence,
    'rating': rating,
    'marketConditions': selectedConditions.toList(),
    'mistakes': selectedMistakes.toList(),
    'entryReasons': selectedEntryReasons.toList(),
    'exitReasons': selectedExitReasons.toList(),
    'checklist': checklist.map((e) => e.toJson()).toList(),
    'screenshots': screenshots,
    'journalStatus': 'COMPLETE',
  };

  Future<void> _save() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      await ref
          .read(tradeRepositoryProvider)
          .saveJournal(widget.tradeId, _journalBody());
      if (!mounted) return;
      await showAfterSaveOptions(
        context: context,
        title: 'Journal saved',
        message: 'Go back to this trade, or return to your trades list.',
        primaryLabel: 'Back to trade',
        onPrimary: () => context.go('/trade/${widget.tradeId}'),
        secondaryLabel: 'All trades',
        onSecondary: () => context.go('/trades'),
      );
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addShot() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ref
        .read(lockProvider.notifier)
        .runWhileUnlocked(
          () => ImagePicker().pickImage(source: source, imageQuality: 85),
        );
    if (picked == null || !mounted) return;
    final stored = await _shots.import(
      tradeId: widget.tradeId,
      sourcePath: picked.path,
    );
    setState(() => screenshots.add(stored));
    await ref.read(tradeRepositoryProvider).saveJournal(widget.tradeId, {
      'screenshots': screenshots,
    });
  }

  Future<void> _removeShot(String path) async {
    await _shots.remove(path);
    setState(() => screenshots.remove(path));
    await ref.read(tradeRepositoryProvider).saveJournal(widget.tradeId, {
      'screenshots': screenshots,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tradeAsync = ref.watch(tradeProvider(widget.tradeId));
    final strategies = ref.watch(strategiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => popOrGo(context, '/trade/${widget.tradeId}'),
        ),
      ),
      body: tradeAsync.when(
        data: (trade) {
          _prime(trade);
          final checked = checklist.where((e) => e.checked).length;
          final rr = tradeRiskReward(
            direction: trade.direction,
            entryPrice: trade.entryPrice,
            stopLoss: trade.stopLoss,
            takeProfit: trade.takeProfit,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JournalHeader(trade: trade),
              const SizedBox(height: 16),
              strategies.when(
                data: (items) {
                  final selected = strategyId ?? defaultStrategy(items)?.id;
                  return DropdownButtonFormField<String>(
                    initialValue: items.any((s) => s.id == selected)
                        ? selected
                        : null,
                    hint: const Text('Strategy / Setup'),
                    items: items
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      message = null;
                      strategyId = value;
                    }),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(e.toString()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('tf_$timeframe'),
                initialValue:
                    timeframe != null && timeframes.contains(timeframe)
                    ? timeframe
                    : null,
                hint: const Text('Trade timeframe'),
                decoration: const InputDecoration(labelText: 'Timeframe'),
                items: [
                  for (final item in timeframes)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) => setState(() {
                  message = null;
                  timeframe = value;
                }),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Pre-trade analysis',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select every setup that applied',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in preTradeOptions)
                          FilterChip(
                            label: Text(item),
                            selected: selectedPre.contains(item),
                            onSelected: (v) => setState(() {
                              message = null;
                              v
                                  ? selectedPre.add(item)
                                  : selectedPre.remove(item);
                            }),
                          ),
                      ],
                    ),
                    if (selectedPre.contains(otherLabel)) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        maxLines: 4,
                        minLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText:
                              'Why this setup? What did you see before entry?',
                          hintStyle: TextStyle(color: AppColors.secondary),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Entry reasons',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in entryReasons)
                      FilterChip(
                        label: Text(item),
                        selected: selectedEntryReasons.contains(item),
                        onSelected: (v) => setState(() {
                          message = null;
                          v
                              ? selectedEntryReasons.add(item)
                              : selectedEntryReasons.remove(item);
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Post-trade review',
                child: _SelectOrOther(
                  value: postChoice,
                  options: postTradeOptions,
                  other: postReview,
                  hint: 'Select how the trade went',
                  otherHint: 'What happened? How was the execution?',
                  onChanged: (value) => setState(() {
                    message = null;
                    postChoice = value;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Exit reasons',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in exitReasons)
                      FilterChip(
                        label: Text(item),
                        selected: selectedExitReasons.contains(item),
                        onSelected: (v) => setState(() {
                          message = null;
                          v
                              ? selectedExitReasons.add(item)
                              : selectedExitReasons.remove(item);
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Emotions',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in emotions)
                      ChoiceChip(
                        label: Text(item),
                        selected: emotion == item,
                        onSelected: (_) => setState(() {
                          message = null;
                          emotion = item;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Lessons learned',
                child: TextField(
                  controller: lessons,
                  maxLines: 3,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'What will you do differently next time?',
                    hintStyle: TextStyle(color: AppColors.secondary),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Risk : Reward',
                child: Text(
                  rr ?? 'Add SL and TP to see R:R',
                  style: TextStyle(
                    fontSize: rr == null ? 14 : 22,
                    fontWeight: FontWeight.w800,
                    color: rr == null ? AppColors.secondary : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Rating',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confidence  $confidence/5'),
                    Slider(
                      value: confidence.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: (v) => setState(() {
                        message = null;
                        confidence = v.round();
                      }),
                    ),
                    Text('Process rating  $rating/10'),
                    Slider(
                      value: rating.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (v) => setState(() {
                        message = null;
                        rating = v.round();
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Tags',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in conditions)
                      FilterChip(
                        label: Text(item),
                        selected: selectedConditions.contains(item),
                        onSelected: (v) => setState(() {
                          message = null;
                          v
                              ? selectedConditions.add(item)
                              : selectedConditions.remove(item);
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Mistakes',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in mistakes)
                      FilterChip(
                        label: Text(item),
                        selected: selectedMistakes.contains(item),
                        onSelected: (v) => setState(() {
                          message = null;
                          v
                              ? selectedMistakes.add(item)
                              : selectedMistakes.remove(item);
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Execution checklist',
                trailing: '$checked/${checklist.length}',
                child: Column(
                  children: [
                    for (var i = 0; i < checklist.length; i++)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: checklist[i].checked,
                        title: Text(checklist[i].label),
                        onChanged: (value) => setState(() {
                          message = null;
                          checklist[i] = ChecklistEntry(
                            label: checklist[i].label,
                            checked: value ?? false,
                          );
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Screenshots',
                child: _ScreenshotStrip(
                  paths: screenshots,
                  store: _shots,
                  onAdd: _addShot,
                  onRemove: _removeShot,
                ),
              ),
              const SizedBox(height: 16),
              _JournalSection(
                title: 'Chart',
                child: TradeChart(trade: trade),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(message!, style: const TextStyle(color: AppColors.gold)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: loading ? null : _save,
                child: Text(
                  loading
                      ? 'Saving...'
                      : trade.journalStatus == 'COMPLETE'
                      ? 'Update Journal'
                      : 'Save Journal',
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString()),
      ),
    );
  }
}

class _JournalHeader extends StatelessWidget {
  const _JournalHeader({required this.trade});
  final Trade trade;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
          const SizedBox(height: 6),
          Text(
            [
              trade.direction,
              '${trade.volume} lots',
              if ((trade.timeframe ?? '').isNotEmpty) trade.timeframe!,
            ].join(' · '),
            style: const TextStyle(color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Entry ${trade.entryPrice}   →   Exit ${trade.exitPrice ?? '—'}',
          ),
          Text(
            formatDateTime(trade.openedAt),
            style: const TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          PnlText(parseMoney(trade.netProfit), size: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push('/trade/${trade.id}/edit'),
              child: const Text('Edit numbers'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectOrOther extends StatelessWidget {
  const _SelectOrOther({
    required this.value,
    required this.options,
    required this.other,
    required this.hint,
    required this.otherHint,
    required this.onChanged,
  });

  final String? value;
  final List<String> options;
  final TextEditingController other;
  final String hint;
  final String otherHint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('${hint}_$value'),
          initialValue: value != null && options.contains(value) ? value : null,
          hint: Text(hint),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: onChanged,
        ),
        if (value == _JournalScreenState.otherLabel) ...[
          const SizedBox(height: 12),
          TextField(
            controller: other,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: otherHint,
              hintStyle: const TextStyle(color: AppColors.secondary),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _JournalSection extends StatelessWidget {
  const _JournalSection({
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ScreenshotStrip extends StatelessWidget {
  const _ScreenshotStrip({
    required this.paths,
    required this.store,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> paths;
  final TradeShotStore store;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final path in paths)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FutureBuilder<File?>(
                future: store.resolve(path),
                builder: (context, snapshot) {
                  final file = snapshot.data;
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: file == null
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                builder: (context) => Dialog(
                                  child: InteractiveViewer(
                                    child: Image.file(file),
                                  ),
                                ),
                              ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: file == null
                              ? const ColoredBox(
                                  color: AppColors.elevated,
                                  child: SizedBox(
                                    width: 96,
                                    height: 96,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  file,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.background.withValues(
                              alpha: 0.7,
                            ),
                            minimumSize: const Size(28, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          iconSize: 16,
                          onPressed: () => onRemove(path),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(96, 96),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined),
                SizedBox(height: 6),
                Text('Add', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDeleteTrade(BuildContext context, String symbol) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete trade?'),
          content: Text(
            'This removes $symbol from your journal. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> deleteTrade(
  BuildContext context,
  WidgetRef ref,
  Trade trade,
) async {
  if (!await confirmDeleteTrade(context, trade.symbol) || !context.mounted)
    return;
  await ref.read(tradeRepositoryProvider).deleteManual(trade.id);
  if (!context.mounted) return;
  context.go('/trades');
}
