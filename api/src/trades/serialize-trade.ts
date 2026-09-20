import { JournalTradeDocument, StrategyDocument } from '../database/schemas';
import { decimal } from '../common/serializers';
import { idOf } from '../common/money';

export function serializeTrade(trade: JournalTradeDocument) {
  const closed = Boolean(trade.closedAt);
  const result = !closed
    ? 'OPEN'
    : Number(trade.netProfit) > 0
      ? 'WIN'
      : Number(trade.netProfit) < 0
        ? 'LOSS'
        : 'BE';
  const strategy = trade.populated('strategyId')
    ? (trade.strategyId as unknown as StrategyDocument)
    : null;
  return {
    id: idOf(trade),
    accountId: idOf(trade.accountId),
    source: trade.source,
    symbol: trade.symbol,
    direction: trade.direction,
    volume: decimal(trade.volume),
    entryPrice: decimal(trade.entryPrice),
    exitPrice: decimal(trade.exitPrice),
    stopLoss: decimal(trade.stopLoss),
    takeProfit: decimal(trade.takeProfit),
    grossProfit: decimal(trade.grossProfit),
    commission: decimal(trade.commission),
    swap: decimal(trade.swap),
    fee: decimal(trade.fee),
    netProfit: decimal(trade.netProfit),
    riskAmount: decimal(trade.riskAmount),
    realizedR: decimal(trade.realizedR),
    durationSeconds: trade.durationSeconds ?? null,
    openedAt: trade.openedAt,
    closedAt: trade.closedAt ?? null,
    session: trade.session ?? null,
    strategyId: strategy ? idOf(strategy) : trade.strategyId ? idOf(trade.strategyId) : null,
    strategyName: strategy?.name ?? null,
    marketConditions: trade.marketConditions ?? [],
    primaryEmotion: trade.primaryEmotion ?? null,
    secondaryEmotions: trade.secondaryEmotions ?? [],
    confidence: trade.confidence ?? null,
    rating: trade.rating ?? null,
    mistakes: trade.mistakes ?? [],
    notes: trade.notes ?? null,
    lessons: trade.lessons ?? null,
    journalStatus: trade.journalStatus,
    ticket: trade.ticket ?? null,
    orderId: trade.orderId ?? null,
    dealId: trade.dealId ?? null,
    magicNumber: trade.magicNumber ?? null,
    needsReconciliation: trade.needsReconciliation,
    result,
    checklist: (trade.checklist ?? []).map((item) => ({
      id: idOf(item as unknown as { id?: string; _id?: { toString(): string } }),
      label: item.label,
      checked: item.checked,
      checkedAt: item.checkedAt ?? null,
    })),
  };
}
