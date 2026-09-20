import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AnalyticsService } from './analytics.service';

@UseGuards(JwtAuthGuard)
@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  @Get('overview')
  overview(
    @Req() req: { user: { userId: string } },
    @Query('accountId') accountId?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.analytics.overview(req.user.userId, accountId, from, to);
  }

  @Get('equity')
  equity(
    @Req() req: { user: { userId: string } },
    @Query('accountId') accountId?: string,
  ) {
    return this.analytics.equity(req.user.userId, accountId);
  }

  @Get('calendar')
  calendar(
    @Req() req: { user: { userId: string } },
    @Query('accountId') accountId?: string,
    @Query('month') month?: string,
  ) {
    return this.analytics.calendar(req.user.userId, accountId, month);
  }

  @Get('sessions')
  sessions(
    @Req() req: { user: { userId: string } },
    @Query('accountId') accountId?: string,
  ) {
    return this.analytics.grouped(req.user.userId, 'session', accountId);
  }

  @Get('symbols')
  symbols(
    @Req() req: { user: { userId: string } },
    @Query('accountId') accountId?: string,
  ) {
    return this.analytics.grouped(req.user.userId, 'symbol', accountId);
  }

  @Get('strategies')
  strategies(
    @Req() req: { user: { userId: string } },
    @Query('accountId') accountId?: string,
  ) {
    return this.analytics.grouped(req.user.userId, 'strategyName', accountId);
  }

  @Get('emotions')
  emotions(
    @Req() req: { user: { userId: string } },
    @Query('accountId') accountId?: string,
  ) {
    return this.analytics.grouped(req.user.userId, 'primaryEmotion', accountId);
  }

  @Get('daily')
  daily(
    @Req() req: { user: { userId: string } },
    @Query('date') date: string,
    @Query('accountId') accountId?: string,
  ) {
    return this.analytics.daily(req.user.userId, date, accountId);
  }
}
