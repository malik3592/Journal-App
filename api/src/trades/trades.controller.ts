import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TradesService } from './trades.service';
import { CreateManualTradeDto, UpdateManualTradeDto } from './dto';

@UseGuards(JwtAuthGuard)
@Controller('trades')
export class TradesController {
  constructor(private readonly trades: TradesService) {}

  @Get()
  list(
    @Req() req: { user: { userId: string } },
    @Query('accountId') accountId?: string,
    @Query('symbol') symbol?: string,
    @Query('direction') direction?: string,
    @Query('result') result?: string,
    @Query('journalStatus') journalStatus?: string,
    @Query('source') source?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.trades.list(req.user.userId, {
      accountId,
      symbol,
      direction,
      result,
      journalStatus,
      source,
      from,
      to,
    });
  }

  @Post('manual')
  createManual(
    @Req() req: { user: { userId: string } },
    @Body() dto: CreateManualTradeDto,
  ) {
    return this.trades.createManual(req.user.userId, dto);
  }

  @Get(':id')
  get(@Req() req: { user: { userId: string } }, @Param('id') id: string) {
    return this.trades.get(req.user.userId, id);
  }

  @Patch(':id')
  updateManual(
    @Req() req: { user: { userId: string } },
    @Param('id') id: string,
    @Body() dto: UpdateManualTradeDto,
  ) {
    return this.trades.updateManual(req.user.userId, id, dto);
  }
}
