import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:journal/core/backup/drive_backup.dart';
import 'package:journal/core/backup/local_backup.dart';
import 'package:journal/core/errors.dart';
import 'package:journal/core/local/journal_database.dart';
import 'package:journal/core/local/trade_shots.dart';
import 'package:journal/core/local/local_analytics.dart';
import 'package:journal/shared/models/models.dart';
import 'package:uuid/uuid.dart';

class JournalState {
  const JournalState({
    required this.ready,
    required this.onboardingComplete,
    required this.startingBalance,
    required this.profile,
    required this.account,
    required this.strategies,
    required this.trades,
    this.cashMovements = const [],
  });

  final bool ready;
  final bool onboardingComplete;
  final String startingBalance;
  final UserAccount profile;
  final TradingAccount account;
  final List<StrategyOption> strategies;
  final List<Trade> trades;
  final List<CashMovement> cashMovements;

  JournalSnapshot get snapshot => JournalSnapshot(
    onboardingComplete: onboardingComplete,
    startingBalance: startingBalance,
    profile: profile,
    account: account,
    strategies: strategies,
    trades: trades,
    cashMovements: cashMovements,
  );

  JournalState copyWith({
    bool? ready,
    bool? onboardingComplete,
    String? startingBalance,
    UserAccount? profile,
    TradingAccount? account,
    List<StrategyOption>? strategies,
    List<Trade>? trades,
    List<CashMovement>? cashMovements,
  }) {
    return JournalState(
      ready: ready ?? this.ready,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      startingBalance: startingBalance ?? this.startingBalance,
      profile: profile ?? this.profile,
      account: account ?? this.account,
      strategies: strategies ?? this.strategies,
      trades: trades ?? this.trades,
      cashMovements: cashMovements ?? this.cashMovements,
    );
  }

  static JournalState fromSnapshot(JournalSnapshot snapshot) {
    return JournalState(
      ready: true,
      onboardingComplete: snapshot.onboardingComplete,
      startingBalance: snapshot.startingBalance,
      profile: snapshot.profile,
      account: snapshot.account,
      strategies: snapshot.strategies,
      trades: snapshot.trades,
      cashMovements: snapshot.cashMovements,
    );
  }
}

class JournalNotifier extends StateNotifier<JournalState> {
  JournalNotifier(this._db)
    : super(
        JournalState.fromSnapshot(
          JournalSnapshot.fresh(),
        ).copyWith(ready: false),
      ) {
    reload();
  }

  final JournalDatabase _db;

  Future<void> reload() async {
    final snapshot = await _db.load();
    state = JournalState.fromSnapshot(snapshot);
  }

  Future<void> _persist() async {
    await _db.save(state.snapshot);
  }

  Future<void> completeSetup({
    required String displayName,
    required String timezone,
    required String currency,
    required String startingBalance,
  }) async {
    await updateProfile(
      displayName: displayName,
      timezone: timezone,
      currency: currency,
      startingBalance: startingBalance,
    );
    state = state.copyWith(onboardingComplete: true);
    await _persist();
  }

  Future<void> completeOnboarding() => completeSetup(
    displayName: state.profile.displayName,
    timezone: state.profile.timezone,
    currency: state.profile.currency,
    startingBalance: state.startingBalance,
  );

  Future<void> updateProfile({
    String? displayName,
    String? timezone,
    String? currency,
    String? startingBalance,
  }) async {
    var account = state.account;
    if (currency != null) {
      account = account.copyWith(currency: currency);
    }
    state = state.copyWith(
      profile: state.profile.copyWith(
        displayName: displayName,
        timezone: timezone,
        currency: currency,
      ),
      account: account,
      startingBalance: startingBalance,
    );
    await _persist();
  }

  Future<Trade> createManual(Map<String, dynamic> body) async {
    final trade = buildManualTrade(
      accountId: state.account.id,
      timezone: state.profile.timezone,
      body: body,
    );
    state = state.copyWith(trades: sortTradesByEntry([trade, ...state.trades]));
    await _persist();
    return trade;
  }

  Future<Trade> updateManual(String tradeId, Map<String, dynamic> body) async {
    final existing = _tradeOrThrow(tradeId);
    final updated = buildManualTrade(
      accountId: state.account.id,
      timezone: state.profile.timezone,
      body: body,
      existing: existing,
    );
    state = state.copyWith(
      trades: sortTradesByEntry([
        for (final trade in state.trades)
          if (trade.id == tradeId) updated else trade,
      ]),
    );
    await _persist();
    return updated;
  }

  Future<Trade> saveJournal(String tradeId, Map<String, dynamic> body) async {
    final existing = _tradeOrThrow(tradeId);
    final strategyId = body['strategyId'] as String?;
    String? strategyName = existing.strategyName;
    if (strategyId != null) {
      for (final strategy in state.strategies) {
        if (strategy.id == strategyId) {
          strategyName = strategy.name;
          break;
        }
      }
    }
    final updated = buildManualTrade(
      accountId: state.account.id,
      timezone: state.profile.timezone,
      body: {
        ...body,
        'strategyName': strategyName,
        'riskFree': existing.riskFree,
        'openedAt': existing.openedAt.toUtc().toIso8601String(),
        'closedAt': existing.closedAt?.toUtc().toIso8601String(),
        'symbol': existing.symbol,
        'direction': existing.direction,
        'volume': existing.volume,
        'entryPrice': existing.entryPrice,
        'netProfit': existing.netProfit,
      },
      existing: existing,
    );
    state = state.copyWith(
      trades: sortTradesByEntry([
        for (final trade in state.trades)
          if (trade.id == tradeId) updated else trade,
      ]),
    );
    await _persist();
    return updated;
  }

  Future<void> deleteManual(String tradeId) async {
    _tradeOrThrow(tradeId);
    await TradeShotStore().removeAll(tradeId);
    state = state.copyWith(
      trades: [
        for (final trade in state.trades)
          if (trade.id != tradeId) trade,
      ],
    );
    await _persist();
  }

  Future<void> addCashMovement({
    required String type,
    required String amount,
    required DateTime at,
    String? note,
  }) async {
    final movement = CashMovement(
      id: const Uuid().v4(),
      type: type,
      amount: amount,
      at: at,
      note: note,
    );
    state = state.copyWith(
      cashMovements: sortCashNewest([movement, ...state.cashMovements]),
    );
    await _persist();
  }

  Future<void> deleteCashMovement(String id) async {
    state = state.copyWith(
      cashMovements: [
        for (final movement in state.cashMovements)
          if (movement.id != id) movement,
      ],
    );
    await _persist();
  }

  Future<void> restoreFromBackup(String json) async {
    final snapshot = _db.decodeBackup(json);
    await _db.save(snapshot);
    state = JournalState.fromSnapshot(snapshot);
  }

  String exportJson() => _db.encode(state.snapshot);

  Trade _tradeOrThrow(String id) {
    return state.trades.firstWhere(
      (t) => t.id == id,
      orElse: () => throw AppException('Trade not found.'),
    );
  }
}

final journalDatabaseProvider = Provider((ref) => JournalDatabase());

final journalProvider = StateNotifierProvider<JournalNotifier, JournalState>(
  (ref) => JournalNotifier(ref.watch(journalDatabaseProvider)),
);

final driveBackupProvider = Provider((ref) => DriveBackupService());
final localBackupProvider = Provider((ref) => LocalBackupService());

final localBackupsProvider = FutureProvider<List<LocalBackupInfo>>((ref) async {
  return ref.watch(localBackupProvider).list();
});

final googleAccountProvider = FutureProvider<GoogleSignInAccount?>((ref) async {
  return ref.watch(driveBackupProvider).currentUser();
});

final tradesProvider = Provider<AsyncValue<List<Trade>>>((ref) {
  final journal = ref.watch(journalProvider);
  if (!journal.ready) return const AsyncLoading();
  return AsyncData(sortTradesByEntry(journal.trades));
});

final tradeProvider = Provider.family<AsyncValue<Trade>, String>((ref, id) {
  final journal = ref.watch(journalProvider);
  if (!journal.ready) return const AsyncLoading();
  try {
    return AsyncData(journal.trades.firstWhere((t) => t.id == id));
  } catch (_) {
    return AsyncError(AppException('Trade not found.'), StackTrace.current);
  }
});

final overviewProvider = Provider<AsyncValue<AnalyticsOverview>>((ref) {
  final journal = ref.watch(journalProvider);
  if (!journal.ready) return const AsyncLoading();
  return AsyncData(
    LocalAnalytics.overview(
      trades: journal.trades,
      account: journal.account,
      startingBalance: journal.startingBalance,
      cashMovements: journal.cashMovements,
    ),
  );
});

final equityProvider = Provider<AsyncValue<List<EquityPoint>>>((ref) {
  final journal = ref.watch(journalProvider);
  if (!journal.ready) return const AsyncLoading();
  return AsyncData(
    LocalAnalytics.equity(
      trades: journal.trades,
      startingBalance: journal.startingBalance,
      cashMovements: journal.cashMovements,
    ),
  );
});

final calendarProvider = Provider.family<AsyncValue<List<CalendarDay>>, String>(
  (ref, month) {
    final journal = ref.watch(journalProvider);
    if (!journal.ready) return const AsyncLoading();
    return AsyncData(
      LocalAnalytics.calendar(trades: journal.trades, month: month),
    );
  },
);

final strategiesProvider = Provider<AsyncValue<List<StrategyOption>>>((ref) {
  final journal = ref.watch(journalProvider);
  if (!journal.ready) return const AsyncLoading();
  return AsyncData(strategiesWithPriceActionFirst(journal.strategies));
});

class TradeRepository {
  TradeRepository(this._journal);
  final JournalNotifier _journal;

  Future<Trade> createManual(Map<String, dynamic> body) =>
      _journal.createManual(body);
  Future<Trade> updateManual(String tradeId, Map<String, dynamic> body) =>
      _journal.updateManual(tradeId, body);
  Future<Trade> saveJournal(String tradeId, Map<String, dynamic> body) =>
      _journal.saveJournal(tradeId, body);
  Future<void> deleteManual(String tradeId) => _journal.deleteManual(tradeId);
}

final tradeRepositoryProvider = Provider(
  (ref) => TradeRepository(ref.read(journalProvider.notifier)),
);
