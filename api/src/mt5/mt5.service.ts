import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { classifySession, idOf } from '../common/money';
import {
  JournalTrade,
  JournalTradeDocument,
  Mt5Deal,
  Mt5DealDocument,
  Mt5Order,
  Mt5OrderDocument,
  TradingAccount,
  TradingAccountDocument,
  UserDocument,
} from '../database/schemas';
import { Mt5SyncDto, decimal } from './dto';

@Injectable()
export class Mt5Service {
  constructor(
    @InjectModel(TradingAccount.name)
    private readonly accounts: Model<TradingAccountDocument>,
    @InjectModel(Mt5Order.name) private readonly orders: Model<Mt5OrderDocument>,
    @InjectModel(Mt5Deal.name) private readonly deals: Model<Mt5DealDocument>,
    @InjectModel(JournalTrade.name)
    private readonly trades: Model<JournalTradeDocument>,
  ) {}

  async sync(dto: Mt5SyncDto) {
    const accounts = await this.accounts
      .find({ mt5Login: dto.mt5Login, mt5Server: dto.mt5Server })
      .populate('userId');
    if (!accounts.length) {
      return { updated: 0, reason: 'No linked MT5 account' };
    }
    let updated = 0;
    for (const account of accounts) {
      account.name = dto.account.name ?? account.name;
      account.brokerName = dto.brokerName ?? account.brokerName;
      account.currency = dto.account.currency ?? account.currency;
      account.accountType = dto.account.accountType ?? account.accountType;
      account.leverage = dto.account.leverage ?? account.leverage;
      account.balance = dto.account.balance;
      account.equity = dto.account.equity;
      account.lastSyncAt = new Date();
      account.syncStatus = 'Connected';
      account.lastSyncFrom = new Date();
      await account.save();

      for (const order of dto.orders ?? []) {
        const mt5OrderId = String(order.ticket ?? order.mt5OrderId ?? '');
        if (!mt5OrderId) continue;
        await this.orders.updateOne(
          { accountId: account._id, mt5OrderId },
          {
            $set: { rawPayload: order },
            $setOnInsert: {
              accountId: account._id,
              mt5OrderId,
              mt5PositionId: order.position_id ? String(order.position_id) : undefined,
              symbol: String(order.symbol ?? ''),
              orderType: String(order.type ?? order.orderType ?? ''),
              volume: String(order.volume_initial ?? order.volume ?? 0),
              price: String(order.price_open ?? order.price ?? 0),
              sl: decimal(order.sl as string | undefined) ?? undefined,
              tp: decimal(order.tp as string | undefined) ?? undefined,
              state: String(order.state ?? 'filled'),
              orderTime: new Date(String(order.time_setup ?? order.orderTime ?? Date.now())),
            },
          },
          { upsert: true },
        );
      }

      for (const deal of dto.deals ?? []) {
        const mt5DealId = String(deal.ticket ?? deal.mt5DealId ?? '');
        if (!mt5DealId) continue;
        await this.deals.updateOne(
          { accountId: account._id, mt5DealId },
          {
            $set: { rawPayload: deal },
            $setOnInsert: {
              accountId: account._id,
              mt5DealId,
              mt5OrderId: deal.order ? String(deal.order) : undefined,
              mt5PositionId: deal.position_id ? String(deal.position_id) : undefined,
              symbol: String(deal.symbol ?? ''),
              dealType: String(deal.type ?? deal.dealType ?? ''),
              entryType: String(deal.entry ?? deal.entryType ?? ''),
              volume: String(deal.volume ?? 0),
              price: String(deal.price ?? 0),
              profit: String(deal.profit ?? 0),
              commission: String(deal.commission ?? 0),
              swap: String(deal.swap ?? 0),
              fee: String(deal.fee ?? 0),
              magic: Number(deal.magic ?? 0),
              comment: String(deal.comment ?? ''),
              executionTime: new Date(String(deal.time ?? deal.executionTime ?? Date.now())),
            },
          },
          { upsert: true },
        );
      }

      const user = account.userId as unknown as UserDocument;
      for (const trade of dto.trades ?? []) {
        const existing = await this.trades.findOne({
          accountId: account._id,
          positionId: trade.positionId,
          source: 'MT5',
        });
        const openedAt = new Date(trade.openedAt);
        const closedAt = trade.closedAt ? new Date(trade.closedAt) : undefined;
        const data = {
          positionId: trade.positionId,
          source: 'MT5',
          symbol: trade.symbol,
          direction: trade.direction,
          volume: trade.volume,
          entryPrice: trade.entryPrice,
          exitPrice: decimal(trade.exitPrice) ?? undefined,
          stopLoss: decimal(trade.stopLoss) ?? undefined,
          takeProfit: decimal(trade.takeProfit) ?? undefined,
          grossProfit: trade.grossProfit ?? '0',
          commission: trade.commission ?? '0',
          swap: trade.swap ?? '0',
          fee: trade.fee ?? '0',
          netProfit: trade.netProfit,
          openedAt,
          closedAt,
          durationSeconds: closedAt
            ? Math.round((closedAt.getTime() - openedAt.getTime()) / 1000)
            : undefined,
          session: trade.session ?? classifySession(openedAt, user?.timezone ?? 'UTC'),
          ticket: trade.ticket,
          orderId: trade.orderId,
          dealId: trade.dealId,
          magicNumber: trade.magicNumber,
          needsReconciliation: trade.needsReconciliation ?? false,
        };
        if (existing) {
          Object.assign(existing, data);
          await existing.save();
        } else {
          await this.trades.create({
            accountId: account._id,
            ...data,
            journalStatus: 'INCOMPLETE',
          });
        }
      }
      updated += 1;
    }
    return { updated, accounts: accounts.map((a) => idOf(a)) };
  }
}
