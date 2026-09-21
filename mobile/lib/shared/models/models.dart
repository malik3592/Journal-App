class UserAccount {
  const UserAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.timezone,
    required this.currency,
  });

  final String id;
  final String email;
  final String displayName;
  final String timezone;
  final String currency;

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Trader',
        timezone: json['timezone'] as String? ?? 'UTC',
        currency: json['currency'] as String? ?? 'USD',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'timezone': timezone,
        'currency': currency,
      };

  UserAccount copyWith({
    String? email,
    String? displayName,
    String? timezone,
    String? currency,
  }) {
    return UserAccount(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      timezone: timezone ?? this.timezone,
      currency: currency ?? this.currency,
    );
  }
}

class TradingAccount {
  const TradingAccount({
    required this.id,
    required this.name,
    required this.brokerName,
    required this.connectionType,
    required this.currency,
    required this.balance,
    required this.equity,
    required this.syncStatus,
    this.mt5Login,
    this.mt5Server,
    this.accountType,
    this.leverage,
    this.lastSyncAt,
  });

  final String id;
  final String name;
  final String brokerName;
  final String connectionType;
  final String currency;
  final String balance;
  final String equity;
  final String syncStatus;
  final String? mt5Login;
  final String? mt5Server;
  final String? accountType;
  final int? leverage;
  final DateTime? lastSyncAt;

  bool get isMt5 => connectionType == 'MT5';

  factory TradingAccount.fromJson(Map<String, dynamic> json) => TradingAccount(
        id: json['id'] as String,
        name: json['name'] as String,
        brokerName: json['brokerName'] as String,
        connectionType: json['connectionType'] as String? ?? 'MANUAL',
        currency: json['currency'] as String? ?? 'USD',
        balance: json['balance']?.toString() ?? '0',
        equity: json['equity']?.toString() ?? '0',
        syncStatus: json['syncStatus'] as String? ?? 'Disconnected',
        mt5Login: json['mt5Login'] as String?,
        mt5Server: json['mt5Server'] as String?,
        accountType: json['accountType'] as String?,
        leverage: json['leverage'] as int?,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.tryParse(json['lastSyncAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brokerName': brokerName,
        'connectionType': connectionType,
        'currency': currency,
        'balance': balance,
        'equity': equity,
        'syncStatus': syncStatus,
        'mt5Login': mt5Login,
        'mt5Server': mt5Server,
        'accountType': accountType,
        'leverage': leverage,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
      };

  TradingAccount copyWith({
    String? name,
    String? currency,
    String? balance,
    String? equity,
    String? syncStatus,
  }) {
    return TradingAccount(
      id: id,
      name: name ?? this.name,
      brokerName: brokerName,
      connectionType: connectionType,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      equity: equity ?? this.equity,
      syncStatus: syncStatus ?? this.syncStatus,
      mt5Login: mt5Login,
      mt5Server: mt5Server,
      accountType: accountType,
      leverage: leverage,
      lastSyncAt: lastSyncAt,
    );
  }
}

class CashMovement {
  const CashMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.at,
    this.note,
  });

  final String id;
  final String type;
  final String amount;
  final DateTime at;
  final String? note;

  bool get isDeposit => type == 'deposit';
  bool get isWithdrawal => type == 'withdrawal';

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'deposit',
        amount: json['amount']?.toString() ?? '0',
        at: DateTime.parse(json['at'] as String),
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'at': at.toIso8601String(),
        'note': note,
      };
}

List<CashMovement> sortCashNewest(Iterable<CashMovement> items) {
  return [...items]..sort((a, b) {
        final byTime = b.at.compareTo(a.at);
        if (byTime != 0) return byTime;
        return b.id.compareTo(a.id);
      });
}

class ChecklistEntry {
  const ChecklistEntry({
    required this.label,
    required this.checked,
    this.id,
    this.checkedAt,
  });

  final String? id;
  final String label;
  final bool checked;
  final DateTime? checkedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'checked': checked,
        'checkedAt': checkedAt?.toIso8601String(),
      };

  factory ChecklistEntry.fromJson(Map<String, dynamic> json) => ChecklistEntry(
        id: json['id'] as String?,
        label: json['label'] as String,
        checked: json['checked'] as bool? ?? false,
        checkedAt: json['checkedAt'] != null
            ? DateTime.tryParse(json['checkedAt'] as String)
            : null,
      );
}

class Trade {
  const Trade({
    required this.id,
    required this.accountId,
    required this.source,
    required this.symbol,
    required this.direction,
    required this.volume,
    required this.entryPrice,
    required this.netProfit,
    required this.openedAt,
    required this.journalStatus,
    required this.result,
    this.exitPrice,
    this.stopLoss,
    this.takeProfit,
    this.commission,
    this.swap,
    this.fee,
    this.closedAt,
    this.session,
    this.strategyId,
    this.strategyName,
    this.primaryEmotion,
    this.notes,
    this.timeframe,
    this.preAnalysis = const [],
    this.postReview,
    this.lessons,
    this.confidence,
    this.rating,
    this.ticket,
    this.riskFree = false,
    this.marketConditions = const [],
    this.mistakes = const [],
    this.entryReasons = const [],
    this.exitReasons = const [],
    this.checklist = const [],
    this.screenshots = const [],
  });

  final String id;
  final String accountId;
  final String source;
  final String symbol;
  final String direction;
  final String volume;
  final String entryPrice;
  final String? exitPrice;
  final String? stopLoss;
  final String? takeProfit;
  final String netProfit;
  final String? commission;
  final String? swap;
  final String? fee;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? session;
  final String? strategyId;
  final String? strategyName;
  final String? primaryEmotion;
  final String? notes;
  final String? timeframe;
  final List<String> preAnalysis;
  final String? postReview;
  final String? lessons;
  final int? confidence;
  final int? rating;
  final String? ticket;
  final bool riskFree;
  final String journalStatus;
  final String result;
  final List<String> marketConditions;
  final List<String> mistakes;
  final List<String> entryReasons;
  final List<String> exitReasons;
  final List<ChecklistEntry> checklist;
  final List<String> screenshots;

  bool get isMt5 => source == 'MT5';
  bool get isOpen => result == 'OPEN';
  bool get isWin => result == 'WIN';
  bool get isLoss => result == 'LOSS';
  bool get isBreakEven => result == 'BE';
  String get resultLabel => isOpen
      ? 'OPEN'
      : riskFree
          ? 'BE/RF'
          : result;

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        source: json['source'] as String? ?? 'MANUAL',
        symbol: json['symbol'] as String,
        direction: json['direction'] as String,
        volume: json['volume']?.toString() ?? '0',
        entryPrice: json['entryPrice']?.toString() ?? '0',
        exitPrice: json['exitPrice']?.toString(),
        stopLoss: json['stopLoss']?.toString(),
        takeProfit: json['takeProfit']?.toString(),
        netProfit: json['netProfit']?.toString() ?? '0',
        commission: json['commission']?.toString(),
        swap: json['swap']?.toString(),
        fee: json['fee']?.toString(),
        openedAt: DateTime.parse(json['openedAt'] as String),
        closedAt: json['closedAt'] != null
            ? DateTime.tryParse(json['closedAt'] as String)
            : null,
        session: json['session'] as String?,
        strategyId: json['strategyId'] as String?,
        strategyName: json['strategyName'] as String?,
        primaryEmotion: json['primaryEmotion'] as String?,
        notes: json['notes'] as String?,
        timeframe: json['timeframe'] as String?,
        preAnalysis: _stringList(json['preAnalysis']),
        postReview: json['postReview'] as String?,
        lessons: json['lessons'] as String?,
        confidence: json['confidence'] as int?,
        rating: json['rating'] as int?,
        ticket: json['ticket'] as String?,
        riskFree: json['riskFree'] == true,
        journalStatus: json['journalStatus'] as String? ?? 'INCOMPLETE',
        result: json['result'] as String? ?? 'OPEN',
        marketConditions: _stringList(json['marketConditions']),
        mistakes: _stringList(json['mistakes']),
        entryReasons: _stringList(json['entryReasons']),
        exitReasons: _stringList(json['exitReasons']),
        checklist: (json['checklist'] as List<dynamic>? ?? [])
            .map((e) => ChecklistEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        screenshots: _stringList(json['screenshots']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'source': source,
        'symbol': symbol,
        'direction': direction,
        'volume': volume,
        'entryPrice': entryPrice,
        'exitPrice': exitPrice,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'netProfit': netProfit,
        'commission': commission,
        'swap': swap,
        'fee': fee,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'session': session,
        'strategyId': strategyId,
        'strategyName': strategyName,
        'primaryEmotion': primaryEmotion,
        'notes': notes,
        'timeframe': timeframe,
        'preAnalysis': preAnalysis,
        'postReview': postReview,
        'lessons': lessons,
        'confidence': confidence,
        'rating': rating,
        'ticket': ticket,
        'riskFree': riskFree,
        'journalStatus': journalStatus,
        'result': result,
        'marketConditions': marketConditions,
        'mistakes': mistakes,
        'entryReasons': entryReasons,
        'exitReasons': exitReasons,
        'checklist': checklist.map((e) => e.toJson()).toList(),
        'screenshots': screenshots,
      };
}

List<Trade> sortTradesByEntry(Iterable<Trade> trades) {
  return [...trades]..sort((a, b) {
        final byEntry = b.openedAt.compareTo(a.openedAt);
        if (byEntry != 0) return byEntry;
        return b.id.compareTo(a.id);
      });
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

class AnalyticsOverview {
  const AnalyticsOverview({
    required this.totalTrades,
    required this.winRate,
    required this.netPnl,
    required this.profitFactor,
    required this.maxDrawdown,
    required this.averageR,
    required this.expectancy,
    required this.equity,
    required this.balance,
    required this.todayPnl,
    required this.journalCompletion,
    required this.currency,
    this.averageWin,
    this.averageLoss,
    this.largestWin,
    this.largestLoss,
    this.winningTrades = 0,
    this.losingTrades = 0,
  });

  final int totalTrades;
  final double? winRate;
  final String netPnl;
  final double? profitFactor;
  final double? maxDrawdown;
  final double? averageR;
  final String? expectancy;
  final double equity;
  final double balance;
  final String todayPnl;
  final double journalCompletion;
  final String currency;
  final String? averageWin;
  final String? averageLoss;
  final String? largestWin;
  final String? largestLoss;
  final int winningTrades;
  final int losingTrades;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) =>
      AnalyticsOverview(
        totalTrades: json['totalTrades'] as int? ?? 0,
        winRate: (json['winRate'] as num?)?.toDouble(),
        netPnl: json['netPnl']?.toString() ?? '0',
        profitFactor: (json['profitFactor'] as num?)?.toDouble(),
        maxDrawdown: (json['maxDrawdown'] as num?)?.toDouble(),
        averageR: (json['averageR'] as num?)?.toDouble(),
        expectancy: json['expectancy']?.toString(),
        equity: (json['equity'] as num?)?.toDouble() ?? 0,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        todayPnl: json['todayPnl']?.toString() ?? '0',
        journalCompletion: (json['journalCompletion'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        averageWin: json['averageWin']?.toString(),
        averageLoss: json['averageLoss']?.toString(),
        largestWin: json['largestWin']?.toString(),
        largestLoss: json['largestLoss']?.toString(),
        winningTrades: json['winningTrades'] as int? ?? 0,
        losingTrades: json['losingTrades'] as int? ?? 0,
      );
}

class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.netPnl,
    required this.trades,
    required this.winRate,
  });

  final DateTime date;
  final String netPnl;
  final int trades;
  final double winRate;

  factory CalendarDay.fromJson(Map<String, dynamic> json) => CalendarDay(
        date: DateTime.parse(json['date'] as String),
        netPnl: json['netPnl']?.toString() ?? '0',
        trades: json['trades'] as int? ?? 0,
        winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      );
}

class StrategyOption {
  const StrategyOption({required this.id, required this.name});
  final String id;
  final String name;

  factory StrategyOption.fromJson(Map<String, dynamic> json) => StrategyOption(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class EquityPoint {
  const EquityPoint({required this.time, required this.equity});
  final DateTime time;
  final double equity;
}
