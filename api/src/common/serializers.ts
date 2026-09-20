import { TradingAccountDocument } from '../database/schemas';
import { idOf } from './money';

export function serializeAccount(account: TradingAccountDocument) {
  return {
    id: idOf(account),
    name: account.name,
    brokerName: account.brokerName,
    mt5Login: account.mt5Login ?? null,
    mt5Server: account.mt5Server ?? null,
    accountType: account.accountType,
    currency: account.currency,
    connectionType: account.connectionType,
    leverage: account.leverage ?? null,
    balance: decimal(account.balance),
    equity: decimal(account.equity),
    lastSyncAt: account.lastSyncAt ?? null,
    syncStatus: account.syncStatus,
    createdAt: account.createdAt,
  };
}

export function decimal(value: number | string | null | undefined) {
  if (value === null || value === undefined) return null;
  return value.toString();
}
