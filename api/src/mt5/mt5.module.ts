import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import {
  JournalTrade,
  JournalTradeSchema,
  Mt5Deal,
  Mt5DealSchema,
  Mt5Order,
  Mt5OrderSchema,
  TradingAccount,
  TradingAccountSchema,
} from '../database/schemas';
import { Mt5Controller } from './mt5.controller';
import { Mt5Service } from './mt5.service';
import { ServiceTokenGuard } from './service-token.guard';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: TradingAccount.name, schema: TradingAccountSchema },
      { name: Mt5Order.name, schema: Mt5OrderSchema },
      { name: Mt5Deal.name, schema: Mt5DealSchema },
      { name: JournalTrade.name, schema: JournalTradeSchema },
    ]),
  ],
  controllers: [Mt5Controller],
  providers: [Mt5Service, ServiceTokenGuard],
})
export class Mt5Module {}
