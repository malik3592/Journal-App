import { Transform } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MinLength,
} from 'class-validator';

const POINT = /^-?\d+(\.\d+)?$/;

function toPoint({ value }: { value: unknown }) {
  if (value === null || value === undefined) return undefined;
  let text = String(value).trim();
  if (!text) return undefined;
  if (text.includes(',') && !text.includes('.')) {
    text = text.replace(',', '.');
  } else {
    text = text.replace(/,/g, '');
  }
  return text;
}

function PointString() {
  return Matches(POINT, {
    message: 'Enter a number, including decimals or points (for example 12.5)',
  });
}

export class CreateManualTradeDto {
  @IsString()
  accountId: string;

  @IsString()
  @MinLength(1)
  symbol: string;

  @IsIn(['BUY', 'SELL'])
  direction: 'BUY' | 'SELL';

  @Transform(toPoint)
  @PointString()
  volume: string;

  @Transform(toPoint)
  @PointString()
  entryPrice: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  exitPrice?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  stopLoss?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  takeProfit?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  netProfit?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  commission?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  swap?: string;

  @IsDateString()
  openedAt: string;

  @IsOptional()
  @IsDateString()
  closedAt?: string;
}

export class UpdateManualTradeDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  symbol?: string;

  @IsOptional()
  @IsIn(['BUY', 'SELL'])
  direction?: 'BUY' | 'SELL';

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  volume?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  entryPrice?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  exitPrice?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  stopLoss?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  takeProfit?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  netProfit?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  commission?: string;

  @IsOptional()
  @Transform(toPoint)
  @PointString()
  swap?: string;

  @IsOptional()
  @IsDateString()
  openedAt?: string;

  @IsOptional()
  @IsDateString()
  closedAt?: string;
}

export class UpdateJournalDto {
  @IsOptional()
  @IsString()
  strategyId?: string;

  @IsOptional()
  @IsString()
  primaryEmotion?: string;

  @IsOptional()
  secondaryEmotions?: string[];

  @IsOptional()
  marketConditions?: string[];

  @IsOptional()
  mistakes?: string[];

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString()
  lessons?: string;

  @IsOptional()
  confidence?: number;

  @IsOptional()
  rating?: number;

  @IsOptional()
  checklist?: { label: string; checked: boolean }[];
}
