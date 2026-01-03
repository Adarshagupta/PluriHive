import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './modules/auth/auth.module';
import { UserModule } from './modules/user/user.module';
import { TerritoryModule } from './modules/territory/territory.module';
import { TrackingModule } from './modules/tracking/tracking.module';
import { LeaderboardModule } from './modules/leaderboard/leaderboard.module';
import { AchievementModule } from './modules/achievement/achievement.module';
import { RealtimeModule } from './modules/realtime/realtime.module';

@Module({
  imports: [
    // Configuration
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    
    // Database
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DATABASE_HOST || 'localhost',
      port: parseInt(process.env.DATABASE_PORT) || 5432,
      username: process.env.DATABASE_USER || 'postgres',
      password: process.env.DATABASE_PASSWORD,
      database: process.env.DATABASE_NAME || 'plurihive',
      entities: [__dirname + '/**/*.entity{.ts,.js}'],
      synchronize: true, // Set to false in production
      logging: true,
    }),
    
    // Feature Modules
    AuthModule,
    UserModule,
    TerritoryModule,
    TrackingModule,
    LeaderboardModule,
    AchievementModule,
    RealtimeModule,
  ],
})
export class AppModule {}
