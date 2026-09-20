import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, Types } from 'mongoose';
import {
  ClosedTrade,
  computeOverview,
  groupBy,
  maxDrawdown,
} from './analytics.math';
import {
  JournalTrade,
  JournalTradeDocument,
  StrategyDocument,
  TradingAccount,
  TradingAccountDocument,
} from '../database/schemas';

@Injectable()
export class AnalyticsService {
  constructor(
    @InjectModel(TradingAccount.name)
    private readonly accounts: Model<TradingAccountDocument>,
    @InjectModel(JournalTrade.name)
    private readonly trades: Model<JournalTradeDocument>,
  ) {}

  async overview(userId: string, accountId?: string, from?: string, to?: string) {
    const loaded = await this.load(userId, accountId, from, to);
    const overview = computeOverview(loaded.closed);
    const points = this.equityPoints(loaded.closed, loaded.startingEquity);
    const drawdown = maxDrawdown(points);
    const journaled = loaded.raw.filter((t) => t.journalStatus === 'COMPLETE').length;
    return {
      ...this.stringifyOverview(overview),
      maxDrawdown: drawdown,
      journalCompletion: loaded.raw.filter((t) => t.closedAt).length
        ? (journaled / loaded.raw.filter((t) => t.closedAt).length) * 100
        : 0,
      equity: loaded.equity,
      balance: loaded.balance,
      currency: loaded.currency,
      todayPnl: this.todayPnl(loaded.closed),
    };
  }

  async equity(userId: string, accountId?: string) {
    const loaded = await this.load(userId, accountId);
    return this.equityPoints(loaded.closed, loaded.startingEquity).map((p) => ({
      t: p.t.toISOString(),
      equity: p.equity.toFixed(2),
    }));
  }

  async calendar(userId: string, accountId?: string, month?: string) {
    const loaded = await this.load(userId, accountId);
    const days = new Map<string, { pnl: number; trades: number; wins: number }>();
    for (const t of loaded.closed) {
      if (!t.closedAt) continue;
      const key = t.closedAt.toISOString().slice(0, 10);
      const current = days.get(key) ?? { pnl: 0, trades: 0, wins: 0 };
      current.pnl += t.netProfit;
      current.trades += 1;
      if (t.netProfit > 0) current.wins += 1;
      days.set(key, current);
    }
    const prefix = month ?? new Date().toISOString().slice(0, 7);
    return [...days.entries()]
      .filter(([day]) => day.startsWith(prefix))
      .map(([date, v]) => ({
        date,
        netPnl: v.pnl.toFixed(2),
        trades: v.trades,
        winRate: v.trades ? (v.wins / v.trades) * 100 : 0,
      }));
  }

  async grouped(
    userId: string,
    key: 'session' | 'symbol' | 'strategyName' | 'primaryEmotion',
    accountId?: string,
  ) {
    const loaded = await this.load(userId, accountId);
    const groups = groupBy(loaded.closed, (t) => String(t[key] ?? 'Unspecified'));
    return [...groups.entries()].map(([name, list]) => {
      const overview = computeOverview(list);
      return { name, ...this.stringifyOverview(overview) };
    });
  }

  async daily(userId: string, date: string, accountId?: string) {
    const loaded = await this.load(userId, accountId);
    const day = loaded.closed.filter(
      (t) => t.closedAt && t.closedAt.toISOString().slice(0, 10) === date,
    );
    const overview = computeOverview(day);
    const best = day.reduce<(typeof day)[0] | null>(
      (acc, t) => (!acc || t.netProfit > acc.netProfit ? t : acc),
      null,
    );
    const worst = day.reduce<(typeof day)[0] | null>(
      (acc, t) => (!acc || t.netProfit < acc.netProfit ? t : acc),
      null,
    );
    return {
      date,
      ...this.stringifyOverview(overview),
      bestTrade: best ? { symbol: best.symbol, netProfit: best.netProfit.toFixed(2) } : null,
      worstTrade: worst ? { symbol: worst.symbol, netProfit: worst.netProfit.toFixed(2) } : null,
    };
  }

  private stringifyOverview(overview: ReturnType<typeof computeOverview>) {
    const n = (v: number | null) => (v === null || Number.isNaN(v) ? null : Number(v.toFixed(4)));
    return {
      totalTrades: overview.totalTrades,
      winningTrades: overview.winningTrades,
      losingTrades: overview.losingTrades,
      winRate: n(overview.winRate),
      netPnl: overview.netPnl.toFixed(2),
      grossProfit: overview.grossProfit.toFixed(2),
      grossLoss: overview.grossLoss.toFixed(2),
      profitFactor: n(overview.profitFactor),
      averageWin: overview.averageWin !== null ? overview.averageWin.toFixed(2) : null,
      averageLoss: overview.averageLoss !== null ? overview.averageLoss.toFixed(2) : null,
      largestWin: overview.largestWin !== null ? overview.largestWin.toFixed(2) : null,
      largestLoss: overview.largestLoss !== null ? overview.largestLoss.toFixed(2) : null,
      expectancy: overview.expectancy !== null ? overview.expectancy.toFixed(2) : null,
      averageR: n(overview.averageR),
      averageTradeDuration: overview.averageTradeDuration,
    };
  }

  private todayPnl(closed: ClosedTrade[]) {
    const today = new Date().toISOString().slice(0, 10);
    return closed
      .filter((t) => t.closedAt && t.closedAt.toISOString().slice(0, 10) === today)
      .reduce((s, t) => s + t.netProfit, 0)
      .toFixed(2);
  }

  private equityPoints(closed: ClosedTrade[], starting: number) {
    const sorted = [...closed].sort(
      (a, b) => (a.closedAt?.getTime() ?? 0) - (b.closedAt?.getTime() ?? 0),
    );
    let equity = starting;
    const points = [{ t: sorted[0]?.openedAt ?? new Date(), equity }];
    for (const t of sorted) {
      equity += t.netProfit;
      points.push({ t: t.closedAt ?? t.openedAt, equity });
    }
    return points;
  }

  private async load(userId: string, accountId?: string, from?: string, to?: string) {
    const accountFilter: FilterQuery<TradingAccountDocument> = {
      userId: new Types.ObjectId(userId),
    };
    if (accountId) accountFilter._id = accountId;
    const accounts = await this.accounts.find(accountFilter);
    const tradeFilter: FilterQuery<JournalTradeDocument> = {
      accountId: { $in: accounts.map((a) => a._id) },
    };
    if (from || to) {
      tradeFilter.openedAt = {
        ...(from ? { $gte: new Date(from) } : {}),
        ...(to ? { $lte: new Date(to) } : {}),
      };
    }
    const raw = await this.trades.find(tradeFilter).populate('strategyId');
    const closed: ClosedTrade[] = raw.map((t) => {
      const strategy = t.populated('strategyId')
        ? (t.strategyId as unknown as StrategyDocument)
        : null;
      return {
        netProfit: Number(t.netProfit),
        closedAt: t.closedAt ?? null,
        openedAt: t.openedAt,
        status: t.closedAt ? 'CLOSED' : 'OPEN',
        session: t.session,
        symbol: t.symbol,
        strategyName: strategy?.name ?? null,
        primaryEmotion: t.primaryEmotion,
        realizedR: t.realizedR ? Number(t.realizedR) : null,
      };
    });
    const equity = accounts.reduce((s, a) => s + Number(a.equity), 0);
    const balance = accounts.reduce((s, a) => s + Number(a.balance), 0);
    const closedPnl = closed
      .filter((t) => t.status === 'CLOSED')
      .reduce((s, t) => s + t.netProfit, 0);
    return {
      raw,
      closed,
      equity,
      balance,
      currency: accounts[0]?.currency ?? 'USD',
      startingEquity: equity - closedPnl,
    };
  }
}
