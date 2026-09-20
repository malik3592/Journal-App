import { Body, Controller, Get, Param, Patch, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JournalService } from './journal.service';
import { UpdateJournalDto } from '../trades/dto';

@UseGuards(JwtAuthGuard)
@Controller()
export class JournalController {
  constructor(private readonly journal: JournalService) {}

  @Get('trades/:id/journal')
  get(@Req() req: { user: { userId: string } }, @Param('id') id: string) {
    return this.journal.get(req.user.userId, id);
  }

  @Patch('trades/:id/journal')
  update(
    @Req() req: { user: { userId: string } },
    @Param('id') id: string,
    @Body() dto: UpdateJournalDto,
  ) {
    return this.journal.update(req.user.userId, id, dto);
  }

  @Get('strategies')
  strategies(@Req() req: { user: { userId: string } }) {
    return this.journal.listStrategies(req.user.userId);
  }
}
