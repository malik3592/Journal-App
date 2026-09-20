import { IsArray, IsObject, IsOptional, IsString } from 'class-validator';

export class Mt5SyncDto {
  @IsString()
  mt5Login: string;

  @IsString()
  mt5Server: string;

  @IsOptional()
  @IsString()
  brokerName?: string;

  @IsObject()
  account: {
    name?: string;
    currency?: string;
    accountType?: string;
    leverage?: number;
    balance: string;
    equity: string;
  };

  @IsOptional()
  @IsArray()
  orders?: Record<string, unknown>[];

  @IsOptional()
  @IsArray()
  deals?: Record<string, unknown>[];

  @IsOptional()
  @IsArray()
  positions?: Record<string, unknown>[];

  @IsOptional()
  @IsArray()
  trades?: NormalizedTradeDto[];
}

export type NormalizedTradeDto = {
  positionId: string;
  symbol: string;
  direction: 'BUY' | 'SELL';
  volume: string;
  entryPrice: string;
  exitPrice?: string | null;
  stopLoss?: string | null;
  takeProfit?: string | null;
  grossProfit?: string;
  commission?: string;
  swap?: string;
  fee?: string;
  netProfit: string;
  openedAt: string;
  closedAt?: string | null;
  ticket?: string;
  orderId?: string;
  dealId?: string;
  magicNumber?: number;
  needsReconciliation?: boolean;
  session?: string;
};

export const decimal = (value: string | number | null | undefined) =>
  value === null || value === undefined ? null : String(value);
