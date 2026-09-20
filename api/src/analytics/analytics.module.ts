import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import {
  JournalTrade,
  JournalTradeSchema,
  TradingAccount,
  TradingAccountSchema,
} from '../database/schemas';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: TradingAccount.name, schema: TradingAccountSchema },
      { name: JournalTrade.name, schema: JournalTradeSchema },
    ]),
  ],
  controllers: [AnalyticsController],
  providers: [AnalyticsService],
})
export class AnalyticsModule {}
