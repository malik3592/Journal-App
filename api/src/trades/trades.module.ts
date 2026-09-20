import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import {
  JournalTrade,
  JournalTradeSchema,
  TradingAccount,
  TradingAccountSchema,
  User,
  UserSchema,
} from '../database/schemas';
import { TradesController } from './trades.controller';
import { TradesService } from './trades.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: JournalTrade.name, schema: JournalTradeSchema },
      { name: TradingAccount.name, schema: TradingAccountSchema },
      { name: User.name, schema: UserSchema },
    ]),
  ],
  controllers: [TradesController],
  providers: [TradesService],
  exports: [TradesService],
})
export class TradesModule {}
