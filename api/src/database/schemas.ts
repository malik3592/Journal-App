import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

@Schema({ timestamps: true, collection: 'users' })
export class User {
  @Prop({ required: true, unique: true, lowercase: true })
  email: string;

  @Prop({ required: true })
  displayName: string;

  @Prop()
  passwordHash?: string;

  @Prop({ default: 'Asia/Karachi' })
  timezone: string;

  @Prop({ default: 'USD' })
  currency: string;
}
export type UserDocument = HydratedDocument<User>;
export const UserSchema = SchemaFactory.createForClass(User);

@Schema({ timestamps: true, collection: 'refresh_tokens' })
export class RefreshToken {
  @Prop({ type: Types.ObjectId, ref: User.name, required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ required: true })
  tokenHash: string;

  @Prop({ required: true })
  expiresAt: Date;
}
export type RefreshTokenDocument = HydratedDocument<RefreshToken>;
export const RefreshTokenSchema = SchemaFactory.createForClass(RefreshToken);

@Schema({ timestamps: true, collection: 'trading_accounts' })
export class TradingAccount {
  @Prop({ type: Types.ObjectId, ref: User.name, required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ default: 'Trading Account' })
  name: string;

  @Prop({ required: true })
  brokerName: string;

  @Prop()
  mt5Login?: string;

  @Prop()
  mt5Server?: string;

  @Prop({ default: 'demo' })
  accountType: string;

  @Prop({ default: 'USD' })
  currency: string;

  @Prop({ default: 'MT5' })
  connectionType: string;

  @Prop()
  leverage?: number;

  @Prop({ default: '0' })
  balance: string;

  @Prop({ default: '0' })
  equity: string;

  @Prop()
  lastSyncAt?: Date;

  @Prop({ default: 'Disconnected' })
  syncStatus: string;

  @Prop()
  syncRequestedAt?: Date;

  @Prop()
  lastSyncFrom?: Date;

  createdAt?: Date;
  updatedAt?: Date;
}
export type TradingAccountDocument = HydratedDocument<TradingAccount>;
export const TradingAccountSchema = SchemaFactory.createForClass(TradingAccount);
TradingAccountSchema.index({ mt5Login: 1, mt5Server: 1 });

@Schema({ timestamps: true, collection: 'strategies' })
export class Strategy {
  @Prop({ type: Types.ObjectId, ref: User.name, required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ required: true })
  name: string;

  @Prop()
  description?: string;

  @Prop({ default: '#1677FF' })
  color: string;

  @Prop({ default: true })
  active: boolean;
}
export type StrategyDocument = HydratedDocument<Strategy>;
export const StrategySchema = SchemaFactory.createForClass(Strategy);

@Schema({ _id: true })
export class ChecklistEntry {
  @Prop({ required: true })
  label: string;

  @Prop({ default: false })
  checked: boolean;

  @Prop()
  checkedAt?: Date;
}
export const ChecklistEntrySchema = SchemaFactory.createForClass(ChecklistEntry);

@Schema({ timestamps: true, collection: 'journal_trades' })
export class JournalTrade {
  @Prop({ type: Types.ObjectId, ref: TradingAccount.name, required: true, index: true })
  accountId: Types.ObjectId;

  @Prop()
  positionId?: string;

  @Prop({ default: 'MT5' })
  source: string;

  @Prop({ required: true })
  symbol: string;

  @Prop({ required: true })
  direction: string;

  @Prop({ required: true })
  volume: string;

  @Prop({ required: true })
  entryPrice: string;

  @Prop()
  exitPrice?: string;

  @Prop()
  stopLoss?: string;

  @Prop()
  takeProfit?: string;

  @Prop({ default: '0' })
  grossProfit: string;

  @Prop({ default: '0' })
  commission: string;

  @Prop({ default: '0' })
  swap: string;

  @Prop({ default: '0' })
  fee: string;

  @Prop({ default: '0' })
  netProfit: string;

  @Prop()
  riskAmount?: string;

  @Prop()
  realizedR?: string;

  @Prop()
  durationSeconds?: number;

  @Prop({ required: true })
  openedAt: Date;

  @Prop()
  closedAt?: Date;

  @Prop()
  session?: string;

  @Prop({ type: Types.ObjectId, ref: Strategy.name })
  strategyId?: Types.ObjectId;

  @Prop({ type: [String], default: [] })
  marketConditions: string[];

  @Prop()
  primaryEmotion?: string;

  @Prop({ type: [String], default: [] })
  secondaryEmotions: string[];

  @Prop()
  confidence?: number;

  @Prop()
  rating?: number;

  @Prop({ type: [String], default: [] })
  mistakes: string[];

  @Prop()
  notes?: string;

  @Prop()
  lessons?: string;

  @Prop({ default: 'INCOMPLETE' })
  journalStatus: string;

  @Prop()
  ticket?: string;

  @Prop()
  orderId?: string;

  @Prop()
  dealId?: string;

  @Prop()
  magicNumber?: number;

  @Prop({ default: false })
  needsReconciliation: boolean;

  @Prop({ type: [ChecklistEntrySchema], default: [] })
  checklist: ChecklistEntry[];
}
export type JournalTradeDocument = HydratedDocument<JournalTrade>;
export const JournalTradeSchema = SchemaFactory.createForClass(JournalTrade);
JournalTradeSchema.index({ accountId: 1, positionId: 1, source: 1 });
JournalTradeSchema.index({ accountId: 1, openedAt: -1 });

@Schema({ timestamps: true, collection: 'mt5_orders' })
export class Mt5Order {
  @Prop({ type: Types.ObjectId, ref: TradingAccount.name, required: true })
  accountId: Types.ObjectId;

  @Prop({ required: true })
  mt5OrderId: string;

  @Prop()
  mt5PositionId?: string;

  @Prop({ required: true })
  symbol: string;

  @Prop({ required: true })
  orderType: string;

  @Prop({ required: true })
  volume: string;

  @Prop({ required: true })
  price: string;

  @Prop()
  sl?: string;

  @Prop()
  tp?: string;

  @Prop({ required: true })
  state: string;

  @Prop({ required: true })
  orderTime: Date;

  @Prop({ type: Object, default: {} })
  rawPayload: Record<string, unknown>;
}
export type Mt5OrderDocument = HydratedDocument<Mt5Order>;
export const Mt5OrderSchema = SchemaFactory.createForClass(Mt5Order);
Mt5OrderSchema.index({ accountId: 1, mt5OrderId: 1 }, { unique: true });

@Schema({ timestamps: true, collection: 'mt5_deals' })
export class Mt5Deal {
  @Prop({ type: Types.ObjectId, ref: TradingAccount.name, required: true })
  accountId: Types.ObjectId;

  @Prop({ required: true })
  mt5DealId: string;

  @Prop()
  mt5OrderId?: string;

  @Prop()
  mt5PositionId?: string;

  @Prop({ required: true })
  symbol: string;

  @Prop({ required: true })
  dealType: string;

  @Prop({ required: true })
  entryType: string;

  @Prop({ required: true })
  volume: string;

  @Prop({ required: true })
  price: string;

  @Prop({ default: '0' })
  profit: string;

  @Prop({ default: '0' })
  commission: string;

  @Prop({ default: '0' })
  swap: string;

  @Prop({ default: '0' })
  fee: string;

  @Prop({ default: 0 })
  magic: number;

  @Prop({ default: '' })
  comment: string;

  @Prop({ required: true })
  executionTime: Date;

  @Prop({ type: Object, default: {} })
  rawPayload: Record<string, unknown>;
}
export type Mt5DealDocument = HydratedDocument<Mt5Deal>;
export const Mt5DealSchema = SchemaFactory.createForClass(Mt5Deal);
Mt5DealSchema.index({ accountId: 1, mt5DealId: 1 }, { unique: true });

export const MODEL_DEFS = [
  { name: User.name, schema: UserSchema },
  { name: RefreshToken.name, schema: RefreshTokenSchema },
  { name: TradingAccount.name, schema: TradingAccountSchema },
  { name: Strategy.name, schema: StrategySchema },
  { name: JournalTrade.name, schema: JournalTradeSchema },
  { name: Mt5Order.name, schema: Mt5OrderSchema },
  { name: Mt5Deal.name, schema: Mt5DealSchema },
];
