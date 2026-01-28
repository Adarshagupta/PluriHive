import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, RedisClientType } from 'redis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: RedisClientType | null = null;
  private enabled = false;

  constructor(private readonly configService: ConfigService) {}

  async onModuleInit() {
    const redisUrl = this.configService.get<string>('REDIS_URL');
    if (!redisUrl) {
      this.logger.log('REDIS_URL not set; Redis cache disabled.');
      return;
    }

    this.client = createClient({ url: redisUrl });
    this.client.on('error', (error) => {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Redis error: ${message}`);
    });

    try {
      await this.client.connect();
      this.enabled = true;
      this.logger.log('Redis connected.');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Redis connection failed: ${message}`);
      this.enabled = false;
    }
  }

  async onModuleDestroy() {
    if (!this.client) return;
    try {
      await this.client.quit();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Redis shutdown failed: ${message}`);
    }
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  getDefaultTtlSeconds(): number {
    const ttlValue = this.configService.get<string>(
      'REDIS_CACHE_TTL_SECONDS',
      '30',
    );
    const ttlSeconds = parseInt(ttlValue, 10);
    if (Number.isNaN(ttlSeconds)) {
      return 30;
    }
    return Math.max(ttlSeconds, 0);
  }

  async get(key: string): Promise<string | null> {
    if (!this.enabled || !this.client) return null;
    const value = await this.client.get(key);
    return typeof value === 'string' ? value : null;
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (!this.enabled || !this.client) return;
    if (ttlSeconds && ttlSeconds > 0) {
      await this.client.set(key, value, { EX: ttlSeconds });
      return;
    }
    await this.client.set(key, value);
  }

  async del(key: string): Promise<void> {
    if (!this.enabled || !this.client) return;
    await this.client.del(key);
  }

  async incr(key: string): Promise<number | null> {
    if (!this.enabled || !this.client) return null;
    const value = await this.client.incr(key);
    if (typeof value === 'number') return value;
    const parsed = Number(value);
    return Number.isNaN(parsed) ? null : parsed;
  }

  async getVersion(key: string, defaultValue: number = 1): Promise<number> {
    if (!this.enabled) return defaultValue;
    const value = await this.get(key);
    const parsed = value ? parseInt(value, 10) : NaN;
    if (!value || Number.isNaN(parsed)) {
      await this.set(key, String(defaultValue));
      return defaultValue;
    }
    return parsed;
  }

  async bumpVersion(key: string, defaultValue: number = 1): Promise<number | null> {
    const incremented = await this.incr(key);
    if (incremented !== null) return incremented;
    if (!this.enabled) return null;
    const current = await this.getVersion(key, defaultValue);
    const next = current + 1;
    await this.set(key, String(next));
    return next;
  }

  async getJson<T>(key: string): Promise<T | null> {
    const value = await this.get(key);
    if (!value) return null;
    try {
      return JSON.parse(value) as T;
    } catch {
      return null;
    }
  }

  async setJson(key: string, value: unknown, ttlSeconds?: number): Promise<void> {
    await this.set(key, JSON.stringify(value), ttlSeconds);
  }
}
