import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/errors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/core/nav.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/shared/models/models.dart';
import 'package:journal/shared/widgets/ui.dart';

class ManualTradeScreen extends ConsumerStatefulWidget {
  const ManualTradeScreen({super.key, this.tradeId});
  final String? tradeId;

  @override
  ConsumerState<ManualTradeScreen> createState() => _ManualTradeScreenState();
}

class _ManualTradeScreenState extends ConsumerState<ManualTradeScreen> {
  final symbol = TextEditingController(text: 'XAUUSD');
  final volume = TextEditingController(text: '0.10');
  final entry = TextEditingController();
  final exit = TextEditingController();
  final stopLoss = TextEditingController();
  final takeProfit = TextEditingController();
  final pnl = TextEditingController();
  final commission = TextEditingController();
  String direction = 'BUY';
  DateTime openedAt = DateTime.now().subtract(const Duration(hours: 1));
  DateTime? closedAt = DateTime.now();
  bool riskFree = false;
  bool loading = false;
  bool primed = false;
  String? error;

  bool get isEditing => widget.tradeId != null;

  @override
  void initState() {
    super.initState();
    symbol.addListener(_clearError);
    volume.addListener(_clearError);
    stopLoss.addListener(_clearError);
    takeProfit.addListener(_clearError);
    commission.addListener(_clearError);
    entry.addListener(_refreshPreview);
    exit.addListener(_refreshPreview);
    pnl.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    symbol.removeListener(_clearError);
    volume.removeListener(_clearError);
    stopLoss.removeListener(_clearError);
    takeProfit.removeListener(_clearError);
    commission.removeListener(_clearError);
    entry.removeListener(_refreshPreview);
    exit.removeListener(_refreshPreview);
    pnl.removeListener(_refreshPreview);
    symbol.dispose();
    volume.dispose();
    entry.dispose();
    exit.dispose();
    stopLoss.dispose();
    takeProfit.dispose();
    pnl.dispose();
    commission.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (!mounted) return;
    setState(() => error = null);
  }

  void _clearError() {
    if (error != null) setState(() => error = null);
  }

  String get _calculatedPnl => signedTradePnl(
    direction: direction,
    entryPrice: entry.text,
    exitPrice: exit.text,
    amount: pnl.text,
  );

  void _prime(Trade trade) {
    if (primed) return;
    primed = true;
    entry.removeListener(_refreshPreview);
    exit.removeListener(_refreshPreview);
    pnl.removeListener(_refreshPreview);
    symbol.text = trade.symbol;
    volume.text = trade.volume;
    entry.text = trade.entryPrice;
    exit.text = trade.exitPrice ?? '';
    stopLoss.text = trade.stopLoss ?? '';
    takeProfit.text = trade.takeProfit ?? '';
    pnl.text = formatUnsignedAmount(parseMoney(trade.netProfit));
    commission.text = trade.commission ?? '';
    direction = trade.direction;
    openedAt = trade.openedAt.toLocal();
    closedAt = trade.closedAt?.toLocal();
    riskFree = trade.riskFree;
    entry.addListener(_refreshPreview);
    exit.addListener(_refreshPreview);
    pnl.addListener(_refreshPreview);
  }

  Map<String, dynamic> _numbers() {
    final body = <String, dynamic>{
      'symbol': symbol.text.trim(),
      'direction': direction,
      'volume': normalizePoint(volume.text) ?? volume.text.trim(),
      'entryPrice': normalizePoint(entry.text) ?? entry.text.trim(),
      'exitPrice': normalizePoint(exit.text),
      'stopLoss': normalizePoint(stopLoss.text),
      'takeProfit': normalizePoint(takeProfit.text),
      'netProfit': _calculatedPnl,
      'commission': normalizePoint(commission.text),
      'riskFree': riskFree,
    };
    body.removeWhere((_, value) => value == null || value == '');
    return body;
  }

  Future<void> _pickDateTime({required bool open}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final initial = (open ? openedAt : closedAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    if (time != null) {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      setState(() {
        error = null;
        if (open) {
          openedAt = value;
        } else {
          closedAt = value;
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Future<void> _submit() async {
    if (normalizePoint(entry.text) == null ||
        normalizePoint(volume.text) == null) {
      setState(
        () => error =
            'Volume and entry need a number, including decimals or points.',
      );
      return;
    }
    if (parseMoney(pnl.text) != 0 && normalizePoint(exit.text) == null) {
      setState(
        () => error =
            'Add an exit price so the app can mark this as profit or loss.',
      );
      return;
    }
    if (closedAt != null && normalizePoint(exit.text) == null) {
      setState(() => error = 'Closed trades need an exit price.');
      return;
    }
    if (closedAt != null && !closedAt!.isAfter(openedAt)) {
      setState(() => error = 'Close date and time must be after open.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final times = {
        'openedAt': openedAt.toUtc().toIso8601String(),
        'closedAt': closedAt?.toUtc().toIso8601String(),
      };
      final Trade trade;
      if (isEditing) {
        trade = await ref.read(tradeRepositoryProvider).updateManual(
          widget.tradeId!,
          {..._numbers(), ...times},
        );
      } else {
        trade = await ref.read(tradeRepositoryProvider).createManual({
          ..._numbers(),
          ...times,
        });
      }
      if (!mounted) return;
      await showAfterSaveOptions(
        context: context,
        title: isEditing ? 'Trade updated' : 'Trade saved',
        message: 'Journal this trade now, or go back to your trades list.',
        primaryLabel: 'Journal trade',
        onPrimary: () => context.go('/trade/${trade.id}/journal'),
        secondaryLabel: 'Go back',
        onSecondary: () => context.go('/trades'),
      );
    } on AppException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _pnlPreview() {
    final hasExit = normalizePoint(exit.text) != null;
    final hasAmount = parseMoney(pnl.text) != 0;
    if (!hasExit || !hasAmount) {
      return const Text(
        'BUY profits if exit is higher. SELL profits if exit is lower.',
        style: TextStyle(color: AppColors.secondary, fontSize: 13),
      );
    }
    final value = parseMoney(_calculatedPnl);
    if (riskFree) {
      return Text(
        'Break even / risk free  ${signedMoney(value)}. P&L is kept, this is not a win or a loss.',
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final label = value > 0
        ? 'Profit'
        : value < 0
        ? 'Loss'
        : 'Breakeven';
    final color = value > 0
        ? AppColors.positive
        : value < 0
        ? AppColors.negative
        : AppColors.secondary;
    return Text(
      '$label  ${signedMoney(value)}',
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editAsync = isEditing
        ? ref.watch(tradeProvider(widget.tradeId!))
        : null;
    if (editAsync != null) {
      return editAsync.when(
        data: (trade) {
          _prime(trade);
          return _form();
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
      );
    }
    return _form();
  }

  Widget _form() {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit trade' : 'Add manual trade'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => popOrGo(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: symbol,
            decoration: const InputDecoration(labelText: 'Symbol'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: direction,
            items: const [
              DropdownMenuItem(value: 'BUY', child: Text('BUY')),
              DropdownMenuItem(value: 'SELL', child: Text('SELL')),
            ],
            onChanged: (value) => setState(() {
              error = null;
              direction = value ?? 'BUY';
            }),
            decoration: const InputDecoration(labelText: 'Direction'),
          ),
          const SizedBox(height: 12),
          PointsField(controller: volume, label: 'Volume (lots)'),
          const SizedBox(height: 12),
          PointsField(controller: entry, label: 'Entry price'),
          const SizedBox(height: 12),
          PointsField(controller: exit, label: 'Exit price'),
          const SizedBox(height: 12),
          PointsField(controller: stopLoss, label: 'Stop loss'),
          const SizedBox(height: 12),
          PointsField(controller: takeProfit, label: 'Take profit'),
          const SizedBox(height: 12),
          PointsField(
            controller: pnl,
            label: 'P&L amount',
            helper: 'Number only. + or − is set from buy/sell and prices.',
          ),
          const SizedBox(height: 8),
          _pnlPreview(),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: riskFree,
            onChanged: (value) => setState(() {
              error = null;
              riskFree = value ?? false;
            }),
            title: const Text('Break even / Risk free'),
            subtitle: const Text(
              'P&L still counts in totals. This trade is not a win or a loss.',
              style: TextStyle(color: AppColors.secondary, fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          PointsField(controller: commission, label: 'Commission'),
          const SizedBox(height: 12),
          DateTimeField(
            label: 'Open date and time',
            value: openedAt,
            onPick: () => _pickDateTime(open: true),
          ),
          const SizedBox(height: 12),
          DateTimeField(
            label: 'Close date and time',
            value: closedAt,
            emptyLabel: 'Still open',
            onPick: () => _pickDateTime(open: false),
            onClear: () => setState(() {
              error = null;
              closedAt = null;
            }),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: AppColors.negative)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: loading ? null : _submit,
            child: Text(
              loading
                  ? 'Saving...'
                  : isEditing
                  ? 'Save changes'
                  : 'Save trade',
            ),
          ),
        ],
      ),
    );
  }
}
