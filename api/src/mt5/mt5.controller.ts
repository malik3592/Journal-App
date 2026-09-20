import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { Mt5Service } from './mt5.service';
import { Mt5SyncDto } from './dto';
import { ServiceTokenGuard } from './service-token.guard';

@UseGuards(ServiceTokenGuard)
@Controller('internal/mt5')
export class Mt5Controller {
  constructor(private readonly mt5: Mt5Service) {}

  @Post('sync')
  sync(@Body() dto: Mt5SyncDto) {
    return this.mt5.sync(dto);
  }
}
