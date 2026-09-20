export type ClosedTrade = {
  netProfit: number;
  closedAt: Date | null;
  openedAt: Date;
  status: 'OPEN' | 'CLOSED';
  session?: string | null;
  symbol: string;
  strategyName?: string | null;
  primaryEmotion?: string | null;
  realizedR?: number | null;
};

export type EquityPoint = { t: Date; equity: number };

export function closedOnly(trades: ClosedTrade[]): ClosedTrade[] {
  return trades.filter((t) => t.status === 'CLOSED' && t.closedAt);
}

export function computeOverview(trades: ClosedTrade[]) {
  const closed = closedOnly(trades);
  const wins = closed.filter((t) => t.netProfit > 0);
  const losses = closed.filter((t) => t.netProfit < 0);
  const grossProfit = wins.reduce((s, t) => s + t.netProfit, 0);
  const grossLoss = losses.reduce((s, t) => s + t.netProfit, 0);
  const absLoss = Math.abs(grossLoss);
  const netPnl = closed.reduce((s, t) => s + t.netProfit, 0);
  const winRate = closed.length ? (wins.length / closed.length) * 100 : null;
  const profitFactor = absLoss === 0 ? (grossProfit > 0 ? null : null) : grossProfit / absLoss;
  const averageWin = wins.length ? grossProfit / wins.length : null;
  const averageLoss = losses.length ? absLoss / losses.length : null;
  const lossRate = closed.length ? losses.length / closed.length : 0;
  const winRateFrac = closed.length ? wins.length / closed.length : 0;
  const expectancy =
    averageWin !== null && averageLoss !== null
      ? winRateFrac * averageWin - lossRate * averageLoss
      : null;
  const rValues = closed
    .map((t) => t.realizedR)
    .filter((v): v is number => v !== null && v !== undefined);
  const averageR = rValues.length
    ? rValues.reduce((s, v) => s + v, 0) / rValues.length
    : null;
  const durations = closed
    .filter((t) => t.closedAt)
    .map((t) => (t.closedAt!.getTime() - t.openedAt.getTime()) / 1000);
  const averageDuration = durations.length
    ? durations.reduce((s, v) => s + v, 0) / durations.length
    : null;

  return {
    totalTrades: closed.length,
    winningTrades: wins.length,
    losingTrades: losses.length,
    winRate,
    netPnl,
    grossProfit,
    grossLoss,
    profitFactor,
    averageWin,
    averageLoss,
    largestWin: wins.length ? Math.max(...wins.map((t) => t.netProfit)) : null,
    largestLoss: losses.length ? Math.min(...losses.map((t) => t.netProfit)) : null,
    expectancy,
    averageR,
    averageTradeDuration: averageDuration,
  };
}

export function maxDrawdown(points: EquityPoint[]): number | null {
  if (points.length < 2) return null;
  let peak = points[0].equity;
  let maxDd = 0;
  for (const p of points) {
    if (p.equity > peak) peak = p.equity;
    if (peak <= 0) continue;
    const dd = (p.equity - peak) / peak;
    if (dd < maxDd) maxDd = dd;
  }
  return maxDd === 0 ? 0 : maxDd * 100;
}

export function groupBy<T>(items: T[], keyFn: (item: T) => string) {
  const map = new Map<string, T[]>();
  for (const item of items) {
    const key = keyFn(item);
    const list = map.get(key) ?? [];
    list.push(item);
    map.set(key, list);
  }
  return map;
}
