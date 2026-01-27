import { Controller, Get, Query, BadRequestException } from "@nestjs/common";
import { LeaderboardService } from "./leaderboard.service";

@Controller("leaderboard")
export class LeaderboardController {
  constructor(private leaderboardService: LeaderboardService) {}

  @Get("global")
  async getGlobalLeaderboard(@Query("limit") limit?: string) {
    try {
      const parsedLimit = limit ? Math.min(parseInt(limit), 100) : 50;
      const users = await this.leaderboardService.getLeaderboard(parsedLimit);
      return users;
    } catch (error) {
      console.error("Leaderboard error:", error);
      throw new BadRequestException("Failed to load leaderboard");
    }
  }

  @Get("weekly")
  async getWeeklyLeaderboard(@Query("limit") limit?: string) {
    try {
      const parsedLimit = limit ? Math.min(parseInt(limit), 100) : 50;
      const users =
        await this.leaderboardService.getWeeklyLeaderboard(parsedLimit);
      return users;
    } catch (error) {
      console.error("Weekly leaderboard error:", error);
      throw new BadRequestException("Failed to load weekly leaderboard");
    }
  }

  @Get("monthly")
  async getMonthlyLeaderboard(@Query("limit") limit?: string) {
    try {
      const parsedLimit = limit ? Math.min(parseInt(limit), 100) : 75;
      const users =
        await this.leaderboardService.getMonthlyLeaderboard(parsedLimit);
      return users;
    } catch (error) {
      console.error("Monthly leaderboard error:", error);
      throw new BadRequestException("Failed to load monthly leaderboard");
    }
  }

  @Get("rank")
  async getUserRank(@Query("userId") userId: string) {
    if (!userId) {
      throw new BadRequestException("User ID is required");
    }

    try {
      const rank = await this.leaderboardService.getUserRank(userId);
      return rank;
    } catch (error) {
      console.error("User rank error:", error);
      throw new BadRequestException("Failed to get user rank");
    }
  }

  @Get("search")
  async searchUsers(@Query("q") query: string, @Query("limit") limit?: string) {
    if (!query?.trim()) {
      throw new BadRequestException("Search query is required");
    }

    try {
      const parsedLimit = limit ? Math.min(parseInt(limit), 50) : 20;
      const users = await this.leaderboardService.searchUsers(
        query.trim(),
        parsedLimit,
      );
      return users;
    } catch (error) {
      console.error("Search users error:", error);
      throw new BadRequestException("Failed to search users");
    }
  }

  @Get("stats")
  async getStats() {
    try {
      const stats = await this.leaderboardService.getStats();
      return stats;
    } catch (error) {
      console.error("Stats error:", error);
      throw new BadRequestException("Failed to get stats");
    }
  }
}
