import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { serializeAccount } from '../common/serializers';
import { TradingAccount, TradingAccountDocument } from '../database/schemas';
import { CreateAccountDto } from './dto';

@Injectable()
export class AccountsService {
  constructor(
    @InjectModel(TradingAccount.name)
    private readonly accounts: Model<TradingAccountDocument>,
  ) {}

  async list(userId: string) {
    const rows = await this.accounts
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ createdAt: 1 });
    return rows.map(serializeAccount);
  }

  async create(userId: string, dto: CreateAccountDto) {
    const connectionType = dto.connectionType ?? 'MT5';
    if (connectionType === 'MT5' && dto.mt5Login && dto.mt5Server) {
      const existing = await this.accounts.findOne({
        userId: new Types.ObjectId(userId),
        mt5Login: dto.mt5Login,
        mt5Server: dto.mt5Server,
      });
      if (existing) {
        throw new ConflictException('This MT5 account is already connected.');
      }
    }
    const account = await this.accounts.create({
      userId: new Types.ObjectId(userId),
      name: dto.name,
      brokerName: dto.brokerName,
      mt5Login: dto.mt5Login,
      mt5Server: dto.mt5Server,
      connectionType,
      accountType: dto.accountType ?? 'demo',
      currency: dto.currency ?? 'USD',
      syncStatus: connectionType === 'MT5' ? 'Disconnected' : 'Manual',
    });
    return serializeAccount(account);
  }

  async get(userId: string, id: string) {
    return serializeAccount(await this.owned(userId, id));
  }

  async remove(userId: string, id: string) {
    await this.owned(userId, id);
    await this.accounts.deleteOne({ _id: id });
    return { success: true };
  }

  async requestSync(userId: string, id: string) {
    const account = await this.owned(userId, id);
    if (account.connectionType !== 'MT5') {
      return serializeAccount(account);
    }
    account.syncRequestedAt = new Date();
    account.syncStatus = 'Syncing';
    await account.save();
    return serializeAccount(account);
  }

  async syncStatus(userId: string, id: string) {
    const account = await this.owned(userId, id);
    return {
      status: account.syncStatus,
      lastSyncAt: account.lastSyncAt ?? null,
      syncRequestedAt: account.syncRequestedAt ?? null,
    };
  }

  private async owned(userId: string, id: string) {
    const account = await this.accounts.findOne({
      _id: id,
      userId: new Types.ObjectId(userId),
    });
    if (!account) throw new NotFoundException('Account not found.');
    return account;
  }
}
