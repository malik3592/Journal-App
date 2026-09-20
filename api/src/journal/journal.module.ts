import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Strategy, StrategySchema } from '../database/schemas';
import { TradesModule } from '../trades/trades.module';
import { JournalController } from './journal.controller';
import { JournalService } from './journal.service';

@Module({
  imports: [
    TradesModule,
    MongooseModule.forFeature([{ name: Strategy.name, schema: StrategySchema }]),
  ],
  controllers: [JournalController],
  providers: [JournalService],
})
export class JournalModule {}
