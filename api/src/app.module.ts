import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DatabaseModule } from './database/database.module';
import { AuthModule } from './auth/auth.module';
import { AccountsModule } from './accounts/accounts.module';
import { TradesModule } from './trades/trades.module';
import { JournalModule } from './journal/journal.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { Mt5Module } from './mt5/mt5.module';
import { HealthController } from './health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    AuthModule,
    AccountsModule,
    TradesModule,
    JournalModule,
    AnalyticsModule,
    Mt5Module,
  ],
  controllers: [HealthController],
})
export class AppModule {}
