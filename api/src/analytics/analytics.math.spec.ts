import { computeOverview, maxDrawdown } from './analytics.math';

describe('analytics math', () => {
  const closed = (net: number, day = 1) => ({
    netProfit: net,
    closedAt: new Date(`2026-09-0${day}T12:00:00Z`),
    openedAt: new Date(`2026-09-0${day}T10:00:00Z`),
    status: 'CLOSED' as const,
    symbol: 'XAUUSD',
    realizedR: null,
  });

  it('computes win rate from closed trades only', () => {
    const result = computeOverview([
      closed(100),
      closed(-50),
      {
        netProfit: 20,
        closedAt: null,
        openedAt: new Date(),
        status: 'OPEN',
        symbol: 'EURUSD',
        realizedR: null,
      },
    ]);
    expect(result.totalTrades).toBe(2);
    expect(result.winRate).toBe(50);
    expect(result.netPnl).toBe(50);
  });

  it('returns null profit factor when there is no loss', () => {
    const result = computeOverview([closed(100), closed(40)]);
    expect(result.profitFactor).toBeNull();
  });

  it('computes profit factor and expectancy', () => {
    const result = computeOverview([closed(100), closed(100), closed(-50)]);
    expect(result.profitFactor).toBeCloseTo(4);
    expect(result.expectancy).toBeCloseTo((2 / 3) * 100 - (1 / 3) * 50);
  });

  it('computes max drawdown from an equity curve', () => {
    const dd = maxDrawdown([
      { t: new Date(), equity: 100 },
      { t: new Date(), equity: 120 },
      { t: new Date(), equity: 90 },
      { t: new Date(), equity: 110 },
    ]);
    expect(dd).toBeCloseTo(-25);
  });
});
