import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
final _date = DateFormat('MMM d, y');
final _time = DateFormat('h:mm a');
final _dateTime = DateFormat('MMM d, y h:mm a');

String money(num value) => _money.format(value);

String signedMoney(num value) {
  final formatted = _money.format(value.abs());
  if (value > 0) return '+$formatted';
  if (value < 0) return '-$formatted';
  return formatted;
}

num parseMoney(String? raw) => num.tryParse(raw ?? '') ?? 0;

String _stringifyAmount(num value) {
  if (value == 0) return '0';
  final abs = value.abs();
  final digits = abs == abs.roundToDouble() ? abs.toInt().toString() : abs.toString();
  return value < 0 ? '-$digits' : digits;
}

String formatUnsignedAmount(num value) => _stringifyAmount(value.abs());

/// BUY wins when exit is higher than entry. SELL wins when exit is lower.
/// The user types an unsigned amount; this applies + or −.
String signedTradePnl({
  required String direction,
  required String entryPrice,
  required String? exitPrice,
  required String? amount,
}) {
  final magnitude = parseMoney(amount).abs();
  if (magnitude == 0) return '0';
  final exit = (exitPrice ?? '').trim();
  if (exit.isEmpty) return '0';
  final entryN = parseMoney(entryPrice);
  final exitN = parseMoney(exit);
  if (exitN == entryN) return '0';
  final isBuy = direction.toUpperCase() != 'SELL';
  final isProfit = isBuy ? exitN > entryN : exitN < entryN;
  return _stringifyAmount(isProfit ? magnitude : -magnitude);
}

String? normalizePoint(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (text.contains(',') && !text.contains('.')) {
    text = text.replaceAll(',', '.');
  } else {
    text = text.replaceAll(',', '');
  }
  if (text == '-' || text == '.' || text == '-.') return null;
  return num.tryParse(text)?.toString();
}

class PointInputFormatter extends TextInputFormatter {
  const PointInputFormatter({this.signed = true});
  final bool signed;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue incoming,
  ) {
    final text = incoming.text.replaceAll(',', '.');
    if (text.isEmpty) return incoming.copyWith(text: text);
    final pattern = signed ? RegExp(r'^-?\d*\.?\d*$') : RegExp(r'^\d*\.?\d*$');
    if (!pattern.hasMatch(text) || '.'.allMatches(text).length > 1) {
      return oldValue;
    }
    return incoming.copyWith(text: text);
  }
}

String formatDate(DateTime value) => _date.format(value.toLocal());
String formatTime(DateTime value) => _time.format(value.toLocal());
String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());

bool journalIsComplete({
  required String? strategyId,
  required String? emotion,
  required String? notes,
  required bool checklistStarted,
  List<String> preAnalysis = const [],
}) {
  final hasPre = preAnalysis.any((item) => item != 'Other') || (notes ?? '').trim().isNotEmpty;
  return (strategyId ?? '').isNotEmpty &&
      (emotion ?? '').isNotEmpty &&
      hasPre &&
      checklistStarted;
}

/// BUY: risk = entry − SL, reward = TP − entry. SELL is the reverse.
String? tradeRiskReward({
  required String direction,
  required String entryPrice,
  required String? stopLoss,
  required String? takeProfit,
}) {
  final entry = parseMoney(entryPrice);
  final sl = parseMoney(stopLoss);
  final tp = parseMoney(takeProfit);
  if (entry == 0 || sl == 0 || tp == 0) return null;
  final isBuy = direction.toUpperCase() != 'SELL';
  final risk = isBuy ? entry - sl : sl - entry;
  final reward = isBuy ? tp - entry : entry - tp;
  if (risk <= 0 || reward <= 0) return null;
  final ratio = reward / risk;
  final digits = ratio >= 10 ? 1 : 2;
  return '1 : ${ratio.toStringAsFixed(digits)}';
}

double? tradeRiskRewardRatio({
  required String direction,
  required String entryPrice,
  required String? stopLoss,
  required String? takeProfit,
}) {
  final entry = parseMoney(entryPrice);
  final sl = parseMoney(stopLoss);
  final tp = parseMoney(takeProfit);
  if (entry == 0 || sl == 0 || tp == 0) return null;
  final isBuy = direction.toUpperCase() != 'SELL';
  final risk = isBuy ? entry - sl : sl - entry;
  final reward = isBuy ? tp - entry : entry - tp;
  if (risk <= 0 || reward <= 0) return null;
  return reward / risk;
}

Duration? tradeHoldDuration(DateTime openedAt, DateTime? closedAt) {
  if (closedAt == null) return null;
  final hold = closedAt.difference(openedAt);
  return hold.isNegative ? null : hold;
}

String formatHoldDuration(Duration? hold) {
  if (hold == null || hold.inSeconds <= 0) return '—';
  if (hold.inHours >= 24) return '${hold.inDays}d ${hold.inHours % 24}h';
  if (hold.inHours >= 1) return '${hold.inHours}h ${hold.inMinutes % 60}m';
  if (hold.inMinutes >= 1) return '${hold.inMinutes}m';
  return '${hold.inSeconds}s';
}

double? tradePriceMovePct({required String entryPrice, required String? exitPrice}) {
  final entry = parseMoney(entryPrice);
  final exit = parseMoney(exitPrice);
  if (entry == 0 || exit == 0) return null;
  return (exit - entry) / entry * 100;
}

String tradingViewSymbol(String raw) {
  final symbol = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s/_]'), '');
  if (symbol.isEmpty) return 'OANDA:XAUUSD';
  if (symbol.contains(':')) return symbol;
  const aliases = {
    'XAUUSD': 'OANDA:XAUUSD',
    'XAUUSDM': 'OANDA:XAUUSD',
    'GOLD': 'OANDA:XAUUSD',
    'XAU': 'OANDA:XAUUSD',
    'XAGUSD': 'OANDA:XAGUSD',
    'SILVER': 'OANDA:XAGUSD',
    'BTCUSD': 'BINANCE:BTCUSDT',
    'BTCUSDT': 'BINANCE:BTCUSDT',
    'ETHUSD': 'BINANCE:ETHUSDT',
    'ETHUSDT': 'BINANCE:ETHUSDT',
    'US30': 'FOREXCOM:US30',
    'NAS100': 'FOREXCOM:NAS100',
    'US100': 'FOREXCOM:NAS100',
    'SPX500': 'FOREXCOM:SPX500',
    'GER40': 'FOREXCOM:GER40',
    'UK100': 'FOREXCOM:UK100',
  };
  return aliases[symbol] ?? 'OANDA:$symbol';
}

String yahooSymbol(String raw) {
  final symbol = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s/_]'), '');
  final stripped = symbol.contains(':') ? symbol.split(':').last : symbol;
  const aliases = {
    'XAUUSD': 'XAUUSD=X',
    'XAUUSDM': 'XAUUSD=X',
    'GOLD': 'XAUUSD=X',
    'XAU': 'XAUUSD=X',
    'XAGUSD': 'XAGUSD=X',
    'SILVER': 'XAGUSD=X',
    'BTCUSD': 'BTC-USD',
    'BTCUSDT': 'BTC-USD',
    'ETHUSD': 'ETH-USD',
    'ETHUSDT': 'ETH-USD',
    'US30': 'YM=F',
    'NAS100': 'NQ=F',
    'US100': 'NQ=F',
    'SPX500': 'ES=F',
    'GER40': 'FDAX=F',
    'UK100': 'FTSE',
  };
  final mapped = aliases[stripped];
  if (mapped != null) return mapped;
  if (RegExp(r'^[A-Z]{6}$').hasMatch(stripped)) return '$stripped=X';
  return stripped;
}
