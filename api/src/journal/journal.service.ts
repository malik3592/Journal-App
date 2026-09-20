import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { idOf, isJournalComplete } from '../common/money';
import { Strategy, StrategyDocument } from '../database/schemas';
import { TradesService } from '../trades/trades.service';
import { UpdateJournalDto } from '../trades/dto';
import { serializeTrade } from '../trades/serialize-trade';

@Injectable()
export class JournalService {
  constructor(
    private readonly trades: TradesService,
    @InjectModel(Strategy.name) private readonly strategyModel: Model<StrategyDocument>,
  ) {}

  async get(userId: string, tradeId: string) {
    return this.trades.get(userId, tradeId);
  }

  async update(userId: string, tradeId: string, dto: UpdateJournalDto) {
    const trade = await this.trades.owned(userId, tradeId);
    if (dto.checklist) {
      trade.checklist = dto.checklist.map((item) => ({
        label: item.label,
        checked: item.checked,
        checkedAt: item.checked ? new Date() : undefined,
      }));
    }
    const checklist = trade.checklist ?? [];
    const strategyId = dto.strategyId ?? (trade.strategyId ? idOf(trade.strategyId) : null);
    const complete = isJournalComplete({
      strategyId,
      primaryEmotion: dto.primaryEmotion ?? trade.primaryEmotion,
      notes: dto.notes ?? trade.notes,
      checklistCount: checklist.length,
      checkedCount: checklist.filter((i) => i.checked).length,
    });
    trade.strategyId = strategyId ? new Types.ObjectId(strategyId) : trade.strategyId;
    trade.primaryEmotion = dto.primaryEmotion ?? trade.primaryEmotion;
    trade.secondaryEmotions = dto.secondaryEmotions ?? trade.secondaryEmotions;
    trade.marketConditions = dto.marketConditions ?? trade.marketConditions;
    trade.mistakes = dto.mistakes ?? trade.mistakes;
    trade.notes = dto.notes ?? trade.notes;
    trade.lessons = dto.lessons ?? trade.lessons;
    trade.confidence = dto.confidence ?? trade.confidence;
    trade.rating = dto.rating ?? trade.rating;
    trade.journalStatus = complete ? 'COMPLETE' : 'INCOMPLETE';
    await trade.save();
    return serializeTrade(await this.trades.owned(userId, tradeId));
  }

  async listStrategies(userId: string) {
    const rows = await this.strategyModel
      .find({ userId: new Types.ObjectId(userId), active: true })
      .sort({ name: 1 });
    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      description: row.description ?? null,
      color: row.color,
      active: row.active,
    }));
  }
}
