import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { In, Repository } from "typeorm";
import { User } from "../user/user.entity";
import { RedisService } from "../redis/redis.service";
import { Friendship } from "./friendship.entity";
import { SeasonStats } from "../season/season-stats.entity";
import { SeasonService } from "../season/season.service";
import { FactionMembership } from "../faction/faction-membership.entity";

@Injectable()
export class LeaderboardService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Friendship)
    private friendshipRepository: Repository<Friendship>,
    @InjectRepository(SeasonStats)
    private seasonStatsRepository: Repository<SeasonStats>,
    @InjectRepository(FactionMembership)
    private factionMembershipRepository: Repository<FactionMembership>,
    private redisService: RedisService,
    private seasonService: SeasonService,
  ) {}

  async getLeaderboard(limit: number = 50): Promise<User[]> {
    return this.getLeaderboardWithCache("global", limit);
  }

  async getWeeklyLeaderboard(limit: number = 50): Promise<User[]> {
    return this.getLeaderboardWithCache("weekly", limit);
  }

  async getMonthlyLeaderboard(limit: number = 75): Promise<User[]> {
    return this.getLeaderboardWithCache("monthly", limit);
  }

  async getFriendsLeaderboard(
    userId: string,
    limit: number = 50,
  ): Promise<User[]> {
    const friendIds = await this.getFriendIds(userId);
    if (friendIds.length === 0) {
      return [];
    }

    return this.userRepository.find({
      where: { id: In(friendIds) },
      order: { totalPoints: "DESC" },
      take: limit,
      select: [
        "id",
        "name",
        "totalPoints",
        "level",
        "totalDistanceKm",
        "totalSteps",
        "totalTerritoriesCaptured",
        "totalWorkouts",
      ],
    });
  }

  async getNearbyLeaderboard(
    latitude: number,
    longitude: number,
    radiusKm: number = 5,
    limit: number = 50,
    excludeUserId?: string,
  ): Promise<User[]> {
    const latDelta = radiusKm / 111;
    const lngDelta =
      radiusKm / (111 * Math.max(Math.cos((latitude * Math.PI) / 180), 0.2));

    const minLat = latitude - latDelta;
    const maxLat = latitude + latDelta;
    const minLng = longitude - lngDelta;
    const maxLng = longitude + lngDelta;

    const query = this.userRepository
      .createQueryBuilder("user")
      .where("user.lastLatitude IS NOT NULL")
      .andWhere("user.lastLongitude IS NOT NULL")
      .andWhere("user.lastLatitude BETWEEN :minLat AND :maxLat", {
        minLat,
        maxLat,
      })
      .andWhere("user.lastLongitude BETWEEN :minLng AND :maxLng", {
        minLng,
        maxLng,
      })
      .orderBy("user.totalPoints", "DESC")
      .limit(limit)
      .select([
        "user.id",
        "user.name",
        "user.totalPoints",
        "user.level",
        "user.totalDistanceKm",
        "user.totalSteps",
        "user.totalTerritoriesCaptured",
        "user.totalWorkouts",
      ]);

    if (excludeUserId) {
      query.andWhere("user.id != :excludeUserId", { excludeUserId });
    }

    return query.getMany();
  }

  async getCityLeaderboard(city: string, limit: number = 50): Promise<User[]> {
    const normalized = this.normalizeCity(city);
    if (!normalized) return [];

    return this.userRepository.find({
      where: { cityNormalized: normalized },
      order: { totalPoints: "DESC" },
      take: limit,
      select: [
        "id",
        "name",
        "totalPoints",
        "level",
        "totalDistanceKm",
        "totalSteps",
        "totalTerritoriesCaptured",
        "totalWorkouts",
      ],
    });
  }

  async getCityLeaderboardForUser(
    userId: string,
    limit: number = 50,
  ): Promise<User[]> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      select: ["id", "cityNormalized"],
    });
    if (!user?.cityNormalized) {
      return [];
    }
    return this.getCityLeaderboard(user.cityNormalized, limit);
  }

  async getSeasonLeaderboard(limit: number = 50) {
    const seasonId = this.seasonService.getCurrentSeasonId();
    const stats = await this.seasonStatsRepository.find({
      where: { seasonId },
      relations: ["user"],
      order: { points: "DESC" },
      take: limit,
    });

    return stats.map((row) => ({
      id: row.userId,
      name: row.user?.name ?? "Unknown",
      totalPoints: row.points,
      seasonPoints: row.points,
      level: row.user?.level ?? 1,
      totalDistanceKm: Number(row.distanceKm || 0),
      totalSteps: row.steps || 0,
      totalTerritoriesCaptured: row.territories || 0,
      totalWorkouts: row.workouts || 0,
      seasonId,
    }));
  }

  async getFactionLeaderboard(factionId: string, limit: number = 50) {
    const seasonId = this.seasonService.getCurrentSeasonId();
    const memberships = await this.factionMembershipRepository.find({
      where: { factionId, seasonId },
      relations: ["user"],
    });
    if (memberships.length === 0) return [];

    const userIds = memberships.map((membership) => membership.userId);
    const stats = await this.seasonStatsRepository.find({
      where: { seasonId, userId: In(userIds) },
    });
    const statsMap = new Map(stats.map((row) => [row.userId, row]));

    const rows = memberships.map((membership) => {
      const row = statsMap.get(membership.userId);
      return {
        id: membership.userId,
        name: membership.user?.name ?? "Unknown",
        totalPoints: row?.points ?? 0,
        seasonPoints: row?.points ?? 0,
        level: membership.user?.level ?? 1,
        totalDistanceKm: Number(row?.distanceKm || 0),
        totalSteps: row?.steps || 0,
        totalTerritoriesCaptured: row?.territories || 0,
        totalWorkouts: row?.workouts || 0,
        seasonId,
      };
    });

    rows.sort((a, b) => b.totalPoints - a.totalPoints);
    return rows.slice(0, limit);
  }

  async getUserRank(
    userId: string,
  ): Promise<{ rank: number; user: User | null }> {
    const cacheKey = await this.getVersionedCacheKey("rank", userId);
    const cached = await this.redisService.getJson<{
      rank: number;
      user: User | null;
    }>(cacheKey);
    if (cached) {
      return cached;
    }

    const users = await this.userRepository.find({
      order: { totalPoints: "DESC" },
      select: ["id", "name", "totalPoints"],
    });

    const userIndex = users.findIndex((user) => user.id === userId);

    if (userIndex === -1) {
      return { rank: 0, user: null };
    }

    const result = {
      rank: userIndex + 1,
      user: users[userIndex],
    };

    const ttlSeconds = this.getCacheTtlSeconds();
    if (ttlSeconds > 0) {
      await this.redisService.setJson(cacheKey, result, ttlSeconds);
    }

    return result;
  }

  async searchUsers(query: string, limit: number = 20): Promise<User[]> {
    const sanitizedQuery = query.trim();
    const normalized = sanitizedQuery.toLowerCase();
    const cacheKey = await this.getVersionedCacheKey(
      "search",
      `${normalized}:${limit}`,
    );
    const cached = await this.redisService.getJson<User[]>(cacheKey);
    if (cached) {
      return cached;
    }

    const users = await this.userRepository
      .createQueryBuilder("user")
      .where("LOWER(user.name) LIKE LOWER(:query)", { query: `%${sanitizedQuery}%` })
      .orderBy("user.totalPoints", "DESC")
      .limit(limit)
      .select([
        "user.id",
        "user.name",
        "user.totalPoints",
        "user.level",
        "user.totalDistanceKm",
        "user.totalSteps",
        "user.totalTerritoriesCaptured",
        "user.totalWorkouts",
      ])
      .getMany();

    const ttlSeconds = this.getCacheTtlSeconds();
    if (ttlSeconds > 0) {
      await this.redisService.setJson(cacheKey, users, ttlSeconds);
    }

    return users;
  }

  async getStats(): Promise<{
    totalUsers: number;
    totalPoints: number;
    totalDistance: number;
    totalSteps: number;
    totalTerritories: number;
  }> {
    const cacheKey = await this.getVersionedCacheKey("stats");
    const cached = await this.redisService.getJson<{
      totalUsers: number;
      totalPoints: number;
      totalDistance: number;
      totalSteps: number;
      totalTerritories: number;
    }>(cacheKey);
    if (cached) {
      return cached;
    }

    const result = await this.userRepository
      .createQueryBuilder("user")
      .select([
        "COUNT(user.id) as totalUsers",
        "COALESCE(SUM(user.totalPoints), 0) as totalPoints",
        "COALESCE(SUM(user.totalDistanceKm), 0) as totalDistance",
        "COALESCE(SUM(user.totalSteps), 0) as totalSteps",
        "COALESCE(SUM(user.totalTerritoriesCaptured), 0) as totalTerritories",
      ])
      .getRawOne();

    const stats = {
      totalUsers: parseInt(result?.totalUsers) || 0,
      totalPoints: parseInt(result?.totalPoints) || 0,
      totalDistance: parseFloat(result?.totalDistance) || 0,
      totalSteps: parseInt(result?.totalSteps) || 0,
      totalTerritories: parseInt(result?.totalTerritories) || 0,
    };

    const ttlSeconds = this.getCacheTtlSeconds();
    if (ttlSeconds > 0) {
      await this.redisService.setJson(cacheKey, stats, ttlSeconds);
    }

    return stats;
  }

  private getCacheKey(scope: string, suffix?: string | number): string {
    if (suffix !== undefined) {
      return `leaderboard:${scope}:${suffix}`;
    }
    return `leaderboard:${scope}`;
  }

  private getLeaderboardVersionKey() {
    return "cache:leaderboard:version";
  }

  private async getVersionedCacheKey(
    scope: string,
    suffix?: string | number,
  ): Promise<string> {
    const version = await this.redisService.getVersion(
      this.getLeaderboardVersionKey(),
    );
    const versionTag = `v${version}`;
    if (suffix !== undefined) {
      return this.getCacheKey(scope, `${versionTag}:${suffix}`);
    }
    return this.getCacheKey(scope, versionTag);
  }

  private getCacheTtlSeconds(): number {
    return this.redisService.getDefaultTtlSeconds();
  }

  private shouldSeedLeaderboard(): boolean {
    return (
      process.env.SEED_LEADERBOARD === "true" &&
      process.env.NODE_ENV !== "production"
    );
  }

  private async queryLeaderboard(limit: number): Promise<User[]> {
    return this.userRepository.find({
      order: { totalPoints: "DESC" },
      take: limit,
      select: [
        "id",
        "name",
        "totalPoints",
        "level",
        "totalDistanceKm",
        "totalSteps",
        "totalTerritoriesCaptured",
        "totalWorkouts",
      ],
    });
  }

  private async fetchLeaderboard(limit: number): Promise<User[]> {
    let users = await this.queryLeaderboard(limit);

    if (users.length === 0 && this.shouldSeedLeaderboard()) {
      await this.createTestUsers();
      users = await this.queryLeaderboard(limit);
    }

    return users;
  }

  private async getLeaderboardWithCache(
    scope: string,
    limit: number,
  ): Promise<User[]> {
    const cacheKey = await this.getVersionedCacheKey(scope, limit);
    const shouldSeed = this.shouldSeedLeaderboard();
    const cached = await this.redisService.getJson<User[]>(cacheKey);
    if (cached && (cached.length > 0 || !shouldSeed)) {
      return cached;
    }

    const users = await this.fetchLeaderboard(limit);
    const ttlSeconds = this.getCacheTtlSeconds();
    if (ttlSeconds > 0) {
      await this.redisService.setJson(cacheKey, users, ttlSeconds);
    }
    return users;
  }

  private async createTestUsers(): Promise<void> {
    const testUsers = [
      {
        name: "Alex Champion",
        email: "alex@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 2500,
        level: 5,
        totalDistanceKm: 125.5,
        totalSteps: 250000,
        totalTerritoriesCaptured: 45,
        totalWorkouts: 85,
        hasCompletedOnboarding: true,
      },
      {
        name: "Sarah Runner",
        email: "sarah@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 2200,
        level: 4,
        totalDistanceKm: 108.3,
        totalSteps: 210000,
        totalTerritoriesCaptured: 38,
        totalWorkouts: 72,
        hasCompletedOnboarding: true,
      },
      {
        name: "Mike Explorer",
        email: "mike@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 1950,
        level: 4,
        totalDistanceKm: 95.7,
        totalSteps: 185000,
        totalTerritoriesCaptured: 32,
        totalWorkouts: 65,
        hasCompletedOnboarding: true,
      },
      {
        name: "Lisa Trekker",
        email: "lisa@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 1800,
        level: 3,
        totalDistanceKm: 87.2,
        totalSteps: 165000,
        totalTerritoriesCaptured: 28,
        totalWorkouts: 58,
        hasCompletedOnboarding: true,
      },
      {
        name: "David Walker",
        email: "david@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 1650,
        level: 3,
        totalDistanceKm: 78.9,
        totalSteps: 145000,
        totalTerritoriesCaptured: 24,
        totalWorkouts: 52,
        hasCompletedOnboarding: true,
      },
      {
        name: "Emma Fitness",
        email: "emma@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 1500,
        level: 3,
        totalDistanceKm: 72.4,
        totalSteps: 138000,
        totalTerritoriesCaptured: 21,
        totalWorkouts: 48,
        hasCompletedOnboarding: true,
      },
      {
        name: "James Active",
        email: "james@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 1350,
        level: 2,
        totalDistanceKm: 65.8,
        totalSteps: 125000,
        totalTerritoriesCaptured: 18,
        totalWorkouts: 42,
        hasCompletedOnboarding: true,
      },
      {
        name: "Olivia Stride",
        email: "olivia@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 1200,
        level: 2,
        totalDistanceKm: 58.3,
        totalSteps: 112000,
        totalTerritoriesCaptured: 15,
        totalWorkouts: 38,
        hasCompletedOnboarding: true,
      },
      {
        name: "Noah Pacer",
        email: "noah@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 1050,
        level: 2,
        totalDistanceKm: 52.1,
        totalSteps: 98000,
        totalTerritoriesCaptured: 12,
        totalWorkouts: 34,
        hasCompletedOnboarding: true,
      },
      {
        name: "Sophia Trail",
        email: "sophia@plurihive.com",
        password: "$2b$10$dummyhash123456789012345678901234567890",
        totalPoints: 900,
        level: 2,
        totalDistanceKm: 45.6,
        totalSteps: 85000,
        totalTerritoriesCaptured: 10,
        totalWorkouts: 30,
        hasCompletedOnboarding: true,
      },
    ];

    for (const userData of testUsers) {
      try {
        const existing = await this.userRepository.findOne({
          where: { email: userData.email },
        });

        if (!existing) {
          const user = this.userRepository.create(userData);
          await this.userRepository.save(user);
        }
      } catch (error) {
        // Ignore errors
      }
    }
  }

  private async getFriendIds(userId: string): Promise<string[]> {
    const friendships = await this.friendshipRepository.find({
      where: [
        { userId, status: "accepted" },
        { friendId: userId, status: "accepted" },
      ],
    });

    const ids = new Set<string>();
    for (const friendship of friendships) {
      const otherId =
        friendship.userId === userId
          ? friendship.friendId
          : friendship.userId;
      if (otherId && otherId !== userId) {
        ids.add(otherId);
      }
    }
    return Array.from(ids);
  }

  private normalizeCity(value?: string) {
    if (!value) return null;
    const trimmed = value.trim().toLowerCase();
    return trimmed.length > 0 ? trimmed : null;
  }
}
