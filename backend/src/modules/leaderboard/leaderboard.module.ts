import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../user/user.entity';
import { Friendship } from './friendship.entity';
import { LeaderboardService } from './leaderboard.service';
import { LeaderboardController } from './leaderboard.controller';
import { RedisModule } from '../redis/redis.module';
import { SeasonStats } from '../season/season-stats.entity';
import { SeasonModule } from '../season/season.module';
import { FactionMembership } from '../faction/faction-membership.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Friendship, SeasonStats, FactionMembership]),
    RedisModule,
    SeasonModule,
  ],
  providers: [LeaderboardService],
  controllers: [LeaderboardController],
  exports: [LeaderboardService],
})
export class LeaderboardModule {}
