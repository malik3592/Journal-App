import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import * as bcrypt from 'bcrypt';
import { createHash, randomBytes } from 'crypto';
import { Model, Types } from 'mongoose';
import { idOf } from '../common/money';
import {
  RefreshToken,
  RefreshTokenDocument,
  Strategy,
  StrategyDocument,
  User,
  UserDocument,
} from '../database/schemas';
import { LoginDto, RegisterDto } from './dto';

const DEFAULT_STRATEGIES = [
  'Breakout',
  'Retest',
  'Trend Continuation',
  'Reversal',
  'Support / Resistance',
  'Liquidity Sweep',
  'FVG',
  'Order Block',
  'Other',
];

@Injectable()
export class AuthService {
  constructor(
    @InjectModel(User.name) private readonly users: Model<UserDocument>,
    @InjectModel(RefreshToken.name)
    private readonly refreshTokens: Model<RefreshTokenDocument>,
    @InjectModel(Strategy.name) private readonly strategyModel: Model<StrategyDocument>,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.users.findOne({ email: dto.email.toLowerCase() });
    if (existing) {
      throw new ConflictException('An account with this email already exists.');
    }
    const passwordHash = await bcrypt.hash(dto.password, 12);
    const user = await this.users.create({
      email: dto.email.toLowerCase(),
      displayName: dto.displayName,
      passwordHash,
    });
    await this.strategyModel.insertMany(
      DEFAULT_STRATEGIES.map((name) => ({ userId: user._id, name })),
    );
    return this.issueTokens(
      idOf(user),
      user.email,
      user.displayName,
      user.timezone,
      user.currency,
    );
  }

  async login(dto: LoginDto) {
    const user = await this.users.findOne({ email: dto.email.toLowerCase() });
    if (!user?.passwordHash) {
      throw new UnauthorizedException('Invalid email or password.');
    }
    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Invalid email or password.');
    }
    return this.issueTokens(
      idOf(user),
      user.email,
      user.displayName,
      user.timezone,
      user.currency,
    );
  }

  async refresh(refreshToken: string) {
    const tokenHash = hashToken(refreshToken);
    const stored = await this.refreshTokens
      .findOne({ tokenHash, expiresAt: { $gt: new Date() } })
      .populate('userId');
    if (!stored || !stored.userId) {
      throw new UnauthorizedException('Session expired. Please sign in again.');
    }
    await this.refreshTokens.deleteOne({ _id: stored._id });
    const user = stored.userId as unknown as UserDocument;
    return this.issueTokens(
      idOf(user),
      user.email,
      user.displayName,
      user.timezone,
      user.currency,
    );
  }

  async logout(userId: string) {
    await this.refreshTokens.deleteMany({ userId: new Types.ObjectId(userId) });
    return { success: true };
  }

  async me(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) throw new UnauthorizedException();
    return {
      id: idOf(user),
      email: user.email,
      displayName: user.displayName,
      timezone: user.timezone,
      currency: user.currency,
    };
  }

  private async issueTokens(
    userId: string,
    email: string,
    displayName: string,
    timezone: string,
    currency: string,
  ) {
    const accessToken = await this.jwt.signAsync(
      { sub: userId, email },
      {
        secret: this.config.get('JWT_ACCESS_SECRET') ?? 'dev-access-secret-change-me',
        expiresIn: '15m',
      },
    );
    const refreshToken = randomBytes(48).toString('hex');
    await this.refreshTokens.create({
      userId: new Types.ObjectId(userId),
      tokenHash: hashToken(refreshToken),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });
    return {
      accessToken,
      refreshToken,
      user: { id: userId, email, displayName, timezone, currency },
    };
  }
}

function hashToken(token: string) {
  return createHash('sha256').update(token).digest('hex');
}
