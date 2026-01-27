import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { User } from "../user/user.entity";

@Injectable()
export class LeaderboardService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async getLeaderboard(limit: number = 50): Promise<User[]> {
    // Get all users ordered by points
    let users = await this.userRepository.find({
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

    // If no users found, create test data
    const shouldSeed =
      process.env.SEED_LEADERBOARD === "true" &&
      process.env.NODE_ENV !== "production";
    if (users.length === 0 && shouldSeed) {
      await this.createTestUsers();
      users = await this.userRepository.find({
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

    return users;
  }

  async getWeeklyLeaderboard(limit: number = 50): Promise<User[]> {
    return this.getLeaderboard(limit);
  }

  async getMonthlyLeaderboard(limit: number = 75): Promise<User[]> {
    return this.getLeaderboard(limit);
  }

  async getUserRank(
    userId: string,
  ): Promise<{ rank: number; user: User | null }> {
    const users = await this.userRepository.find({
      order: { totalPoints: "DESC" },
      select: ["id", "name", "totalPoints"],
    });

    const userIndex = users.findIndex((user) => user.id === userId);

    if (userIndex === -1) {
      return { rank: 0, user: null };
    }

    return {
      rank: userIndex + 1,
      user: users[userIndex],
    };
  }

  async searchUsers(query: string, limit: number = 20): Promise<User[]> {
    const users = await this.userRepository
      .createQueryBuilder("user")
      .where("LOWER(user.name) LIKE LOWER(:query)", { query: `%${query}%` })
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

    return users;
  }

  async getStats(): Promise<{
    totalUsers: number;
    totalPoints: number;
    totalDistance: number;
    totalSteps: number;
    totalTerritories: number;
  }> {
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

    return {
      totalUsers: parseInt(result?.totalUsers) || 0,
      totalPoints: parseInt(result?.totalPoints) || 0,
      totalDistance: parseFloat(result?.totalDistance) || 0,
      totalSteps: parseInt(result?.totalSteps) || 0,
      totalTerritories: parseInt(result?.totalTerritories) || 0,
    };
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
}
