import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateAccountDto {
  @IsString()
  @MinLength(1)
  name: string;

  @IsString()
  brokerName: string;

  @IsOptional()
  @IsString()
  mt5Login?: string;

  @IsOptional()
  @IsString()
  mt5Server?: string;

  @IsOptional()
  @IsIn(['MT5', 'MANUAL'])
  connectionType?: 'MT5' | 'MANUAL';

  @IsOptional()
  @IsIn(['demo', 'live'])
  accountType?: string;

  @IsOptional()
  @IsString()
  currency?: string;
}
