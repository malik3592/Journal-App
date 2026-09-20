String classifySession(DateTime openedAt, String timeZone) {
  DateTime local;
  try {
    local = openedAt.toUtc();
    if (timeZone == 'UTC' || timeZone.isEmpty) {
      local = openedAt.toUtc();
    } else {
      local = openedAt.toLocal();
    }
  } catch (_) {
    local = openedAt.toLocal();
  }
  final hour = local.hour;
  if (hour >= 0 && hour < 8) return 'Asian';
  if (hour >= 8 && hour < 13) return 'London';
  if (hour >= 13 && hour < 16) return 'London / New York Overlap';
  if (hour >= 16 && hour < 22) return 'New York';
  return 'Other';
}

String tradeResult({
  required DateTime? closedAt,
  required String netProfit,
  bool riskFree = false,
}) {
  if (closedAt == null) return 'OPEN';
  if (riskFree) return 'BE';
  final pnl = num.tryParse(netProfit) ?? 0;
  if (pnl > 0) return 'WIN';
  if (pnl < 0) return 'LOSS';
  return 'BE';
}
