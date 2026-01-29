import {
  Controller,
  Get,
  Query,
  BadRequestException,
  Request,
  UseGuards,
} from "@nestjs/common";
import { LeaderboardService } from "./leaderboard.service";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";

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

  @UseGuards(JwtAuthGuard)
  @Get("friends")
  async getFriendsLeaderboard(@Request() req, @Query("limit") limit?: string) {
    try {
      const parsedLimit = limit ? Math.min(parseInt(limit), 100) : 50;
      const users = await this.leaderboardService.getFriendsLeaderboard(
        req.user.id,
        parsedLimit,
      );
      return users;
    } catch (error) {
      console.error("Friends leaderboard error:", error);
      throw new BadRequestException("Failed to load friends leaderboard");
    }
  }

  @UseGuards(JwtAuthGuard)
  @Get("nearby")
  async getNearbyLeaderboard(
    @Request() req,
    @Query("lat") lat?: string,
    @Query("lng") lng?: string,
    @Query("radiusKm") radiusKm?: string,
    @Query("limit") limit?: string,
  ) {
    if (!lat || !lng) {
      throw new BadRequestException("lat and lng are required");
    }

    const parsedLat = parseFloat(lat);
    const parsedLng = parseFloat(lng);
    if (Number.isNaN(parsedLat) || Number.isNaN(parsedLng)) {
      throw new BadRequestException("Invalid lat/lng");
    }

    try {
      const parsedRadius = radiusKm
        ? Math.min(Math.max(parseFloat(radiusKm), 0.2), 50)
        : 5;
      const parsedLimit = limit ? Math.min(parseInt(limit), 100) : 50;
      const users = await this.leaderboardService.getNearbyLeaderboard(
        parsedLat,
        parsedLng,
        parsedRadius,
        parsedLimit,
        req.user?.id,
      );
      return users;
    } catch (error) {
      console.error("Nearby leaderboard error:", error);
      throw new BadRequestException("Failed to load nearby leaderboard");
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
