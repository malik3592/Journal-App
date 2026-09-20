import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class ServiceTokenGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{ headers: Record<string, string> }>();
    const header = request.headers['x-mt5-token'] || request.headers['authorization'];
    const token = this.config.get<string>('MT5_SERVICE_TOKEN') ?? 'dev-mt5-service-token';
    const provided = String(header ?? '').replace(/^Bearer\s+/i, '');
    if (!provided || provided !== token) {
      throw new UnauthorizedException('Invalid MT5 service token.');
    }
    return true;
  }
}
