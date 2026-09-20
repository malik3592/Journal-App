import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, Types } from 'mongoose';
import { classifySession, idOf, moneyMath } from '../common/money';
import {
  JournalTrade,
  JournalTradeDocument,
  TradingAccount,
  TradingAccountDocument,
  User,
  UserDocument,
} from '../database/schemas';
import { CreateManualTradeDto, UpdateManualTradeDto } from './dto';
import { serializeTrade } from './serialize-trade';

@Injectable()
export class TradesService {
  constructor(
    @InjectModel(JournalTrade.name)
    private readonly trades: Model<JournalTradeDocument>,
    @InjectModel(TradingAccount.name)
    private readonly accounts: Model<TradingAccountDocument>,
    @InjectModel(User.name)
    private readonly users: Model<UserDocument>,
  ) {}

  async list(
    userId: string,
    query: {
      accountId?: string;
      symbol?: string;
      direction?: string;
      result?: string;
      journalStatus?: string;
      source?: string;
      from?: string;
      to?: string;
    },
  ) {
    const accountFilter: FilterQuery<TradingAccountDocument> = {
      userId: new Types.ObjectId(userId),
    };
    if (query.accountId) accountFilter._id = query.accountId;
    const accounts = await this.accounts.find(accountFilter).select('_id');
    const accountIds = accounts.map((a) => a._id);
    if (!accountIds.length) return [];

    const filter: FilterQuery<JournalTradeDocument> = {
      accountId: { $in: accountIds },
    };
    if (query.symbol) filter.symbol = new RegExp(query.symbol, 'i');
    if (query.direction) filter.direction = query.direction;
    if (query.journalStatus) filter.journalStatus = query.journalStatus;
    if (query.source) filter.source = query.source;
    if (query.from || query.to) {
      filter.openedAt = {
        ...(query.from ? { $gte: new Date(query.from) } : {}),
        ...(query.to ? { $lte: new Date(query.to) } : {}),
      };
    }
    const rows = await this.trades
      .find(filter)
      .populate('strategyId')
      .sort({ openedAt: -1 });
    let serialized = rows.map(serializeTrade);
    if (query.result) {
      serialized = serialized.filter((t) => t.result === query.result);
    }
    return serialized;
  }

  async get(userId: string, id: string) {
    return serializeTrade(await this.owned(userId, id));
  }

  async createManual(userId: string, dto: CreateManualTradeDto) {
    const account = await this.accounts.findOne({
      _id: dto.accountId,
      userId: new Types.ObjectId(userId),
    });
    if (!account) throw new NotFoundException('Account not found.');
    const user = await this.users.findById(userId);
    const openedAt = new Date(dto.openedAt);
    const closedAt = dto.closedAt ? new Date(dto.closedAt) : undefined;
    const net = dto.netProfit ?? '0';
    const commission = dto.commission ?? '0';
    const swap = dto.swap ?? '0';
    const trade = await this.trades.create({
      accountId: account._id,
      source: 'MANUAL',
      symbol: dto.symbol.toUpperCase(),
      direction: dto.direction,
      volume: dto.volume,
      entryPrice: dto.entryPrice,
      exitPrice: dto.exitPrice,
      stopLoss: dto.stopLoss,
      takeProfit: dto.takeProfit,
      netProfit: net,
      commission,
      swap,
      grossProfit: moneyMath(moneyMath(net, commission, 'minus'), swap, 'minus'),
      openedAt,
      closedAt,
      durationSeconds: closedAt
        ? Math.round((closedAt.getTime() - openedAt.getTime()) / 1000)
        : undefined,
      session: classifySession(openedAt, user?.timezone ?? 'UTC'),
      journalStatus: 'INCOMPLETE',
    });
    return serializeTrade(await this.owned(userId, idOf(trade)));
  }

  async updateManual(userId: string, id: string, dto: UpdateManualTradeDto) {
    const trade = await this.owned(userId, id);
    if (trade.source !== 'MANUAL') {
      this.assertNotMutatingMt5Execution();
    }
    if (dto.symbol) trade.symbol = dto.symbol.toUpperCase();
    if (dto.direction) trade.direction = dto.direction;
    if (dto.volume) trade.volume = dto.volume;
    if (dto.entryPrice) trade.entryPrice = dto.entryPrice;
    if (dto.exitPrice !== undefined) trade.exitPrice = dto.exitPrice;
    if (dto.stopLoss !== undefined) trade.stopLoss = dto.stopLoss;
    if (dto.takeProfit !== undefined) trade.takeProfit = dto.takeProfit;
    if (dto.commission !== undefined) trade.commission = dto.commission;
    if (dto.swap !== undefined) trade.swap = dto.swap;
    if (dto.netProfit !== undefined) trade.netProfit = dto.netProfit;
    if (dto.openedAt) {
      trade.openedAt = new Date(dto.openedAt);
      const user = await this.users.findById(userId);
      trade.session = classifySession(trade.openedAt, user?.timezone ?? 'UTC');
    }
    if (dto.closedAt !== undefined) {
      trade.closedAt = dto.closedAt ? new Date(dto.closedAt) : undefined;
    }
    const net = trade.netProfit ?? '0';
    const commission = trade.commission ?? '0';
    const swap = trade.swap ?? '0';
    trade.grossProfit = moneyMath(moneyMath(net, commission, 'minus'), swap, 'minus');
    trade.durationSeconds = trade.closedAt
      ? Math.round((trade.closedAt.getTime() - trade.openedAt.getTime()) / 1000)
      : undefined;
    await trade.save();
    return serializeTrade(await this.owned(userId, id));
  }

  async owned(userId: string, id: string) {
    const trade = await this.trades.findById(id).populate('strategyId');
    if (!trade) throw new NotFoundException('Trade not found.');
    const account = await this.accounts.findById(trade.accountId);
    if (!account || idOf(account.userId) !== userId) {
      throw new NotFoundException('Trade not found.');
    }
    return trade;
  }

  assertNotMutatingMt5Execution() {
    throw new ForbiddenException('Imported MT5 execution data is read-only.');
  }
}
