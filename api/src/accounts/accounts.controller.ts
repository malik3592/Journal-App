import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AccountsService } from './accounts.service';
import { CreateAccountDto } from './dto';

@UseGuards(JwtAuthGuard)
@Controller('accounts')
export class AccountsController {
  constructor(private readonly accounts: AccountsService) {}

  @Get()
  list(@Req() req: { user: { userId: string } }) {
    return this.accounts.list(req.user.userId);
  }

  @Post()
  create(
    @Req() req: { user: { userId: string } },
    @Body() dto: CreateAccountDto,
  ) {
    return this.accounts.create(req.user.userId, dto);
  }

  @Get(':id')
  get(@Req() req: { user: { userId: string } }, @Param('id') id: string) {
    return this.accounts.get(req.user.userId, id);
  }

  @Delete(':id')
  remove(@Req() req: { user: { userId: string } }, @Param('id') id: string) {
    return this.accounts.remove(req.user.userId, id);
  }

  @Post(':id/sync')
  sync(@Req() req: { user: { userId: string } }, @Param('id') id: string) {
    return this.accounts.requestSync(req.user.userId, id);
  }

  @Get(':id/sync-status')
  status(@Req() req: { user: { userId: string } }, @Param('id') id: string) {
    return this.accounts.syncStatus(req.user.userId, id);
  }
}
