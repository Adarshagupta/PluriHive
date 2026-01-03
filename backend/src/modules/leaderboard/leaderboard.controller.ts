import { Controller, Get, Query } from '@nestjs/common';
import { LeaderboardService } from './leaderboard.service';

@Controller('leaderboard')
export class LeaderboardController {
  constructor(private leaderboardService: LeaderboardService) {}

  @Get('global')
  async getGlobalLeaderboard(@Query('limit') limit?: number) {
    return this.leaderboardService.getGlobalLeaderboard(limit ? parseInt(limit.toString()) : 50);
  }
}
