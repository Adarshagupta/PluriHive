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
        const databaseUrl = config.get<string>('DATABASE_URL');
        const isCockroach =
          databaseUrl?.includes('cockroach') ||
          config.get<string>('DATABASE_PROVIDER') === 'cockroachdb';
        const sslEnabled =
          config.get<string>('DATABASE_SSL') === 'true' ||
          (databaseUrl && databaseUrl.includes('sslmode='));
        const syncEnabled = config.get<string>('TYPEORM_SYNC') === 'true' && !isCockroach;

        const baseConfig = {
          type: 'postgres' as const,
          entities: [__dirname + '/**/*.entity{.ts,.js}'],
          synchronize: syncEnabled,
          logging: config.get<string>('NODE_ENV') !== 'production',
          ssl: sslEnabled ? { rejectUnauthorized: false } : false,
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
  ],
})
export class AppModule {}
