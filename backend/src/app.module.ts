import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import * as path from 'path';
import { AuthModule } from './modules/auth/auth.module';
import { UserModule } from './modules/user/user.module';
import { TerritoryModule } from './modules/territory/territory.module';
import { TrackingModule } from './modules/tracking/tracking.module';
import { LeaderboardModule } from './modules/leaderboard/leaderboard.module';
import { AchievementModule } from './modules/achievement/achievement.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { RoutesModule } from './modules/routes/routes.module';
import { AppModule as AppUpdateModule } from './modules/app/app.module';
import { EngagementModule } from './modules/engagement/engagement.module';
import { LegalModule } from './modules/legal/legal.module';
import { FactionModule } from './modules/faction/faction.module';
import { DuelModule } from './modules/duel/duel.module';

@Module({
  imports: [
    // Configuration
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [
        path.join(process.cwd(), '.env'),
        path.join(process.cwd(), 'backend', '.env'),
      ],
    }),
    
    // Database
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const parseNumber = (value: string | undefined, fallback: number) => {
          if (!value) return fallback;
          const parsed = Number.parseInt(value, 10);
          return Number.isFinite(parsed) ? parsed : fallback;
        };
        const parseBool = (value: string | undefined, fallback: boolean) => {
          if (value == null) return fallback;
          return value.toLowerCase() === 'true';
        };

        const databaseUrl = config.get<string>('DATABASE_URL');
        const isCockroach =
          databaseUrl?.includes('cockroach') ||
          config.get<string>('DATABASE_PROVIDER') === 'cockroachdb';
        const sslEnabled =
          config.get<string>('DATABASE_SSL') === 'true' ||
          (databaseUrl && databaseUrl.includes('sslmode='));
        const syncEnabled = config.get<string>('TYPEORM_SYNC') === 'true' && !isCockroach;
        const retryAttempts = parseNumber(
          config.get<string>('DATABASE_RETRY_ATTEMPTS'),
          10,
        );
        const retryDelay = parseNumber(
          config.get<string>('DATABASE_RETRY_DELAY_MS'),
          2000,
        );
        const poolMax = parseNumber(
          config.get<string>('DATABASE_POOL_MAX'),
          10,
        );
        const idleTimeoutMillis = parseNumber(
          config.get<string>('DATABASE_IDLE_TIMEOUT_MS'),
          30000,
        );
        const connectionTimeoutMillis = parseNumber(
          config.get<string>('DATABASE_CONNECT_TIMEOUT_MS'),
          5000,
        );
        const keepAlive = parseBool(
          config.get<string>('DATABASE_KEEP_ALIVE'),
          true,
        );
        const keepAliveInitialDelayMillis = parseNumber(
          config.get<string>('DATABASE_KEEP_ALIVE_DELAY_MS'),
          10000,
        );

        const baseConfig = {
          type: 'postgres' as const,
          entities: [__dirname + '/**/*.entity{.ts,.js}'],
          synchronize: syncEnabled,
          logging: config.get<string>('NODE_ENV') !== 'production',
          ssl: sslEnabled ? { rejectUnauthorized: false } : false,
          retryAttempts,
          retryDelay,
          extra: {
            max: poolMax,
            idleTimeoutMillis,
            connectionTimeoutMillis,
            keepAlive,
            keepAliveInitialDelayMillis,
          },
        };

        if (databaseUrl) {
          return {
            ...baseConfig,
            url: databaseUrl,
          };
        }

        return {
          ...baseConfig,
          host: config.get<string>('DATABASE_HOST', 'localhost'),
          port: parseInt(config.get<string>('DATABASE_PORT', '5432'), 10),
          username: config.get<string>('DATABASE_USER', 'postgres'),
          password: config.get<string>('DATABASE_PASSWORD'),
          database: config.get<string>('DATABASE_NAME', 'plurihive'),
        };
      },
    }),
    
    // Feature Modules
    AuthModule,
    UserModule,
    TerritoryModule,
    TrackingModule,
    LeaderboardModule,
    AchievementModule,
    RealtimeModule,
    RoutesModule,
    AppUpdateModule,
    EngagementModule,
    LegalModule,
    FactionModule,
    DuelModule,
  ],
})
export class AppModule {}
