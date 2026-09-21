import 'dart:convert';
import 'dart:io';

import 'package:journal/core/constants.dart';
import 'package:journal/core/errors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/core/session.dart';
import 'package:journal/shared/models/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

const defaultStrategyNames = [
  'Price Action',
  'Breakout',
  'Retest',
  'Trend Continuation',
  'Reversal',
  'Support / Resistance',
  'Liquidity Sweep',
  'FVG',
  'Order Block',
  'Other',
];

class JournalSnapshot {
  const JournalSnapshot({
    required this.onboardingComplete,
    required this.startingBalance,
    required this.profile,
    required this.account,
    required this.strategies,
    required this.trades,
    this.cashMovements = const [],
  });

  final bool onboardingComplete;
  final String startingBalance;
  final UserAccount profile;
  final TradingAccount account;
  final List<StrategyOption> strategies;
  final List<Trade> trades;
  final List<CashMovement> cashMovements;

  JournalSnapshot copyWith({
    bool? onboardingComplete,
    String? startingBalance,
    UserAccount? profile,
    TradingAccount? account,
    List<StrategyOption>? strategies,
    List<Trade>? trades,
    List<CashMovement>? cashMovements,
  }) {
    return JournalSnapshot(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      startingBalance: startingBalance ?? this.startingBalance,
      profile: profile ?? this.profile,
      account: account ?? this.account,
      strategies: strategies ?? this.strategies,
      trades: trades ?? this.trades,
      cashMovements: cashMovements ?? this.cashMovements,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'onboardingComplete': onboardingComplete,
    'startingBalance': startingBalance,
    'profile': profile.toJson(),
    'account': account.toJson(),
    'strategies': strategies.map((s) => s.toJson()).toList(),
    'trades': trades.map((t) => t.toJson()).toList(),
    'cashMovements': cashMovements.map((m) => m.toJson()).toList(),
  };

  factory JournalSnapshot.fresh() {
    final profileId = _uuid.v4();
    final accountId = _uuid.v4();
    return JournalSnapshot(
      onboardingComplete: false,
      startingBalance: '0',
      profile: UserAccount(
        id: profileId,
        email: '',
        displayName: 'Trader',
        timezone: 'UTC',
        currency: 'USD',
      ),
      account: TradingAccount(
        id: accountId,
        name: 'Manual Journal',
        brokerName: 'Manual',
        connectionType: 'MANUAL',
        currency: 'USD',
        balance: '0',
        equity: '0',
        syncStatus: 'Local',
      ),
      strategies: [
        for (final name in defaultStrategyNames)
          StrategyOption(id: _uuid.v4(), name: name),
      ],
      trades: const [],
      cashMovements: const [],
    );
  }

  factory JournalSnapshot.fromJson(Map<String, dynamic> json) {
    final loaded = (json['strategies'] as List<dynamic>? ?? [])
        .map((e) => StrategyOption.fromJson(e as Map<String, dynamic>))
        .toList();
    final trades = sortTradesByEntry(
      (json['trades'] as List<dynamic>? ?? []).map(
        (e) => Trade.fromJson(e as Map<String, dynamic>),
      ),
    );
    return JournalSnapshot(
      onboardingComplete: json['onboardingComplete'] as bool? ?? true,
      startingBalance: json['startingBalance']?.toString() ?? '0',
      profile: json['profile'] is Map<String, dynamic>
          ? UserAccount.fromJson(json['profile'] as Map<String, dynamic>)
          : JournalSnapshot.fresh().profile,
      account: json['account'] is Map<String, dynamic>
          ? TradingAccount.fromJson(json['account'] as Map<String, dynamic>)
          : JournalSnapshot.fresh().account,
      strategies: mergeDefaultStrategies(loaded),
      trades: trades,
      cashMovements: sortCashNewest(
        (json['cashMovements'] as List<dynamic>? ?? []).map(
          (e) => CashMovement.fromJson(e as Map<String, dynamic>),
        ),
      ),
    );
  }
}

List<StrategyOption> strategiesWithPriceActionFirst(
  List<StrategyOption> items,
) {
  final priceAction = <StrategyOption>[];
  final rest = <StrategyOption>[];
  for (final strategy in items) {
    if (strategy.name.trim().toLowerCase() == 'price action') {
      priceAction.add(strategy);
    } else {
      rest.add(strategy);
    }
  }
  return [...priceAction, ...rest];
}

StrategyOption? defaultStrategy(List<StrategyOption> items) {
  for (final strategy in items) {
    if (strategy.name.trim().toLowerCase() == 'price action') return strategy;
  }
  return items.isEmpty ? null : items.first;
}

List<StrategyOption> mergeDefaultStrategies(List<StrategyOption> existing) {
  final source = existing.isEmpty
      ? JournalSnapshot.fresh().strategies
      : existing;
  final names = {
    for (final strategy in source) strategy.name.trim().toLowerCase(),
  };
  final extra = [
    for (final name in defaultStrategyNames)
      if (!names.contains(name.toLowerCase()))
        StrategyOption(id: _uuid.v4(), name: name),
  ];
  return strategiesWithPriceActionFirst([...source, ...extra]);
}

class JournalDatabase {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/${AppConfig.localJournalFileName}');
  }

  Future<JournalSnapshot> load() async {
    final file = await _file();
    if (!await file.exists()) return JournalSnapshot.fresh();
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return JournalSnapshot.fromJson(json);
    } catch (_) {
      return JournalSnapshot.fresh();
    }
  }

  Future<void> save(JournalSnapshot snapshot) async {
    final file = await _file();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
  }

  String encode(JournalSnapshot snapshot) =>
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson());

  JournalSnapshot decodeBackup(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['trades'] is! List && json['profile'] is! Map) {
        throw AppException('This file is not a Journal backup.');
      }
      return JournalSnapshot.fromJson(json).copyWith(onboardingComplete: true);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Could not read the Google Drive backup.');
    }
  }
}

Trade buildManualTrade({
  required String accountId,
  required String timezone,
  required Map<String, dynamic> body,
  String? id,
  Trade? existing,
}) {
  final openedAt = DateTime.parse(
    body['openedAt'] as String? ??
        existing?.openedAt.toUtc().toIso8601String() ??
        DateTime.now().toUtc().toIso8601String(),
  );
  final closedRaw = body.containsKey('closedAt')
      ? body['closedAt'] as String?
      : existing?.closedAt?.toUtc().toIso8601String();
  final closedAt = closedRaw == null || closedRaw.isEmpty
      ? null
      : DateTime.parse(closedRaw);
  final direction =
      body['direction'] as String? ?? existing?.direction ?? 'BUY';
  final entryPrice = (body['entryPrice'] ?? existing?.entryPrice ?? '0')
      .toString();
  final exitPrice = body.containsKey('exitPrice')
      ? body['exitPrice']?.toString()
      : existing?.exitPrice;
  final net = signedTradePnl(
    direction: direction,
    entryPrice: entryPrice,
    exitPrice: exitPrice,
    amount: (body['netProfit'] ?? existing?.netProfit ?? '0').toString(),
  );
  final riskFree = body.containsKey('riskFree')
      ? body['riskFree'] == true
      : existing?.riskFree ?? false;
  final strategyId = body['strategyId'] as String? ?? existing?.strategyId;
  final notes = body.containsKey('notes')
      ? _optionalText(body['notes'])
      : existing?.notes;
  final emotion = body['primaryEmotion'] as String? ?? existing?.primaryEmotion;
  final checklist = body['checklist'] is List
      ? (body['checklist'] as List)
            .map(
              (e) =>
                  ChecklistEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList()
      : existing?.checklist ?? const <ChecklistEntry>[];
  final preAnalysis = body['preAnalysis'] is List
      ? (body['preAnalysis'] as List).map((e) => e.toString()).toList()
      : existing?.preAnalysis ?? const <String>[];
  final complete = journalIsComplete(
    strategyId: strategyId,
    emotion: emotion,
    notes: notes,
    checklistStarted: checklist.any((e) => e.checked),
    preAnalysis: preAnalysis,
  );

  return Trade(
    id: id ?? existing?.id ?? _uuid.v4(),
    accountId: accountId,
    source: 'MANUAL',
    symbol: (body['symbol'] as String? ?? existing?.symbol ?? 'UNKNOWN')
        .toUpperCase(),
    direction: direction,
    volume: (body['volume'] ?? existing?.volume ?? '0').toString(),
    entryPrice: entryPrice,
    exitPrice: exitPrice,
    stopLoss: body.containsKey('stopLoss')
        ? body['stopLoss']?.toString()
        : existing?.stopLoss,
    takeProfit: body.containsKey('takeProfit')
        ? body['takeProfit']?.toString()
        : existing?.takeProfit,
    netProfit: net,
    commission: body.containsKey('commission')
        ? body['commission']?.toString()
        : existing?.commission,
    swap: body.containsKey('swap') ? body['swap']?.toString() : existing?.swap,
    fee: body.containsKey('fee') ? body['fee']?.toString() : existing?.fee,
    openedAt: openedAt,
    closedAt: closedAt,
    session: classifySession(openedAt, timezone),
    strategyId: strategyId,
    strategyName: body['strategyName'] as String? ?? existing?.strategyName,
    primaryEmotion: emotion,
    notes: notes,
    timeframe: body.containsKey('timeframe')
        ? _optionalText(body['timeframe'])
        : existing?.timeframe,
    preAnalysis: preAnalysis,
    postReview: body.containsKey('postReview')
        ? _optionalText(body['postReview'])
        : existing?.postReview,
    lessons: body['lessons'] as String? ?? existing?.lessons,
    confidence: body['confidence'] as int? ?? existing?.confidence,
    rating: body['rating'] as int? ?? existing?.rating,
    ticket: existing?.ticket,
    riskFree: riskFree,
    journalStatus: complete ? 'COMPLETE' : 'INCOMPLETE',
    result: tradeResult(closedAt: closedAt, netProfit: net, riskFree: riskFree),
    marketConditions: body['marketConditions'] is List
        ? (body['marketConditions'] as List).map((e) => e.toString()).toList()
        : existing?.marketConditions ?? const [],
    mistakes: body['mistakes'] is List
        ? (body['mistakes'] as List).map((e) => e.toString()).toList()
        : existing?.mistakes ?? const [],
    entryReasons: body['entryReasons'] is List
        ? (body['entryReasons'] as List).map((e) => e.toString()).toList()
        : existing?.entryReasons ?? const [],
    exitReasons: body['exitReasons'] is List
        ? (body['exitReasons'] as List).map((e) => e.toString()).toList()
        : existing?.exitReasons ?? const [],
    checklist: checklist,
    screenshots: body['screenshots'] is List
        ? (body['screenshots'] as List).map((e) => e.toString()).toList()
        : existing?.screenshots ?? const [],
  );
}

String? _optionalText(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
