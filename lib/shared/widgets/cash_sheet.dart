import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/core/local/local_analytics.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/shared/models/models.dart';

Future<void> showCashSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CashSheet(),
  );
}

Future<void> showAddCashSheet(BuildContext context, {required String type}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddCashSheet(type: type),
  );
}

class _CashSheet extends ConsumerWidget {
  const _CashSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider);
    final overview = ref.watch(overviewProvider).valueOrNull;
    final balance =
        overview?.balance ??
        parseMoney(journal.startingBalance) +
            LocalAnalytics.cashNet(journal.cashMovements);
    final movements = sortCashNewest(journal.cashMovements);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Balance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            money(balance),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          Text(
            journal.account.currency,
            style: const TextStyle(color: AppColors.secondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => showAddCashSheet(context, type: 'deposit'),
                  child: const Text('Deposit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      showAddCashSheet(context, type: 'withdrawal'),
                  child: const Text('Withdraw'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (movements.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No deposits or withdrawals yet.',
                style: TextStyle(color: AppColors.secondary, fontSize: 13),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: CashHistoryList(movements: movements),
            ),
        ],
      ),
    );
  }
}

class _AddCashSheet extends ConsumerStatefulWidget {
  const _AddCashSheet({required this.type});
  final String type;

  @override
  ConsumerState<_AddCashSheet> createState() => _AddCashSheetState();
}

class _AddCashSheetState extends ConsumerState<_AddCashSheet> {
  final amount = TextEditingController();
  final note = TextEditingController();
  late DateTime at;
  String? error;

  bool get isDeposit => widget.type == 'deposit';

  @override
  void initState() {
    super.initState();
    at = DateTime.now();
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: at,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    setState(() {
      error = null;
      at = DateTime(date.year, date.month, date.day, at.hour, at.minute);
    });
  }

  Future<void> _save() async {
    final parsed = normalizePoint(amount.text);
    final value = parseMoney(parsed).abs();
    if (value <= 0) {
      setState(() => error = 'Enter an amount greater than 0.');
      return;
    }
    final text = note.text.trim();
    await ref
        .read(journalProvider.notifier)
        .addCashMovement(
          type: isDeposit ? 'deposit' : 'withdrawal',
          amount: value.toString(),
          at: at,
          note: text.isEmpty ? null : text,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isDeposit ? 'Deposit' : 'Withdraw',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [PointInputFormatter(signed: false)],
            decoration: const InputDecoration(labelText: 'Amount'),
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            trailing: Text(
              formatDate(at),
              style: const TextStyle(color: AppColors.secondary),
            ),
            onTap: _pickDate,
          ),
          TextField(
            controller: note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: AppColors.negative)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class CashHistoryList extends ConsumerWidget {
  const CashHistoryList({
    super.key,
    required this.movements,
    this.nested = false,
  });
  final List<CashMovement> movements;
  final bool nested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: nested ? const NeverScrollableScrollPhysics() : null,
      itemCount: movements.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = movements[index];
        final value = parseMoney(item.amount).abs();
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: AppColors.negative.withValues(alpha: 0.2),
            child: const Icon(Icons.delete_outline, color: AppColors.negative),
          ),
          onDismissed: (_) =>
              ref.read(journalProvider.notifier).deleteCashMovement(item.id),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.isDeposit ? Icons.south_west : Icons.north_east,
              color: item.isDeposit ? AppColors.positive : AppColors.negative,
            ),
            title: Text(item.isDeposit ? 'Deposit' : 'Withdrawal'),
            subtitle: Text(
              [
                formatDate(item.at),
                if ((item.note ?? '').isNotEmpty) item.note!,
              ].join(' · '),
              style: const TextStyle(color: AppColors.secondary, fontSize: 12),
            ),
            trailing: Text(
              '${item.isDeposit ? '+' : '-'}${money(value)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: item.isDeposit ? AppColors.positive : AppColors.negative,
              ),
            ),
          ),
        );
      },
    );
  }
}
