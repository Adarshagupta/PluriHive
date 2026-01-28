import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { User } from "./user.entity";
import { UpdateProfileDto } from "./dto/update-profile.dto";
import { UpdateSettingsDto } from "./dto/update-settings.dto";
import { RedisService } from "../redis/redis.service";
import { RealtimeGateway } from "../realtime/realtime.gateway";

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private redisService: RedisService,
    private realtimeGateway: RealtimeGateway,
  ) {}

  async findById(id: string): Promise<User> {
    return this.userRepository.findOne({
      where: { id },
      relations: ["territories", "activities"],
    });
  }

  async updateProfile(
    userId: string,
    updates: UpdateProfileDto,
  ): Promise<User> {
    console.log("📝 updateProfile called for user:", userId);
    console.log("📝 Updates received:", JSON.stringify(updates, null, 2));

    const allowedUpdates: Partial<User> = {};
    if (updates.name !== undefined) allowedUpdates.name = updates.name;
    if (updates.weight !== undefined) allowedUpdates.weight = updates.weight;
    if (updates.height !== undefined) allowedUpdates.height = updates.height;
    if (updates.age !== undefined) allowedUpdates.age = updates.age;
    if (updates.gender !== undefined) allowedUpdates.gender = updates.gender;
    if (updates.profilePicture !== undefined) {
      allowedUpdates.profilePicture = updates.profilePicture;
    }
    if (updates.avatarModelUrl !== undefined) {
      allowedUpdates.avatarModelUrl = updates.avatarModelUrl;
    }
    if (updates.avatarImageUrl !== undefined) {
      allowedUpdates.avatarImageUrl = updates.avatarImageUrl;
    }

    await this.userRepository.update(userId, allowedUpdates);

    const updatedUser = await this.findById(userId);
    console.log("✅ Profile updated. New values:", {
      weight: updatedUser.weight,
      height: updatedUser.height,
      age: updatedUser.age,
      gender: updatedUser.gender,
    });

    await this.bumpUserCacheVersion(userId);
    return updatedUser;
  }

  async completeOnboarding(userId: string): Promise<User> {
    await this.userRepository.update(userId, { hasCompletedOnboarding: true });
    const user = await this.findById(userId);
    await this.bumpUserCacheVersion(userId);
    return user;
  }

  async fixOnboardingForAllUsers(): Promise<{ updated: number }> {
    const result = await this.userRepository.update(
      { hasCompletedOnboarding: false },
      { hasCompletedOnboarding: true },
    );
    await this.redisService.bumpVersion(this.getUserGlobalVersionKey());
    return { updated: result.affected || 0 };
  }

  async updateStats(
    userId: string,
    stats: {
      distanceKm?: number;
      steps?: number;
      territories?: number;
      points?: number;
      workouts?: number;
    },
    options?: { notify?: boolean },
  ): Promise<User> {
    const user = await this.findById(userId);

    // Convert decimal fields from string to number (PostgreSQL returns decimals as strings)
    if (stats.distanceKm) {
      user.totalDistanceKm = Number(user.totalDistanceKm) + stats.distanceKm;
    }
    if (stats.steps) user.totalSteps += stats.steps;
    if (stats.territories) user.totalTerritoriesCaptured += stats.territories;
    if (stats.points) {
      user.totalPoints += stats.points;
      // Level up calculation (every 1000 points = 1 level)
      user.level = Math.floor(user.totalPoints / 1000);
    }
    if (stats.workouts) user.totalWorkouts += stats.workouts;

    const saved = await this.userRepository.save(user);
    await this.bumpUserCacheVersion(userId);
    if (options?.notify ?? true) {
      this.notifyStatsUpdated(userId);
    }
    return saved;
  }

  async updateSettings(
    userId: string,
    settings: UpdateSettingsDto,
  ): Promise<User> {
    const user = await this.findById(userId);
    user.settings = { ...user.settings, ...settings };
    const saved = await this.userRepository.save(user);
    await this.bumpUserCacheVersion(userId);
    await this.redisService.bumpVersion("cache:leaderboard:version");
    return saved;
  }

  async updateStreak(
    userId: string,
    activityDate: Date,
    options?: { notify?: boolean },
  ): Promise<void> {
    const user = await this.findById(userId);

    const today = this.toDateOnly(activityDate);
    this.grantWeeklyFreezeIfNeeded(user, today);

    if (!user.lastActiveDate) {
      user.currentStreak = 1;
      user.longestStreak = Math.max(
        user.longestStreak || 0,
        user.currentStreak,
      );
      user.lastActiveDate = today;
      await this.userRepository.save(user);
      await this.bumpUserCacheVersion(userId);
      if (options?.notify ?? true) {
        this.notifyStatsUpdated(userId);
      }
      return;
    }

    const lastActive = this.toDateOnly(new Date(user.lastActiveDate));
    const daysSince = this.daysBetween(lastActive, today);

    if (daysSince <= 0) {
      // Same day or invalid ordering - nothing to do
      return;
    }

    if (daysSince === 1) {
      user.currentStreak = (user.currentStreak || 0) + 1;
    } else if (daysSince === 2 && (user.streakFreezes || 0) > 0) {
      user.streakFreezes = Math.max((user.streakFreezes || 0) - 1, 0);
      user.currentStreak = (user.currentStreak || 0) + 1;
    } else {
      user.currentStreak = 1;
    }

    user.longestStreak = Math.max(user.longestStreak || 0, user.currentStreak);
    user.lastActiveDate = today;

    await this.userRepository.save(user);
    await this.bumpUserCacheVersion(userId);
    if (options?.notify ?? true) {
      this.notifyStatsUpdated(userId);
    }
  }

  notifyStatsUpdated(userId: string) {
    this.realtimeGateway.emitUserStatsUpdated(userId, {
      userId,
      updatedAt: new Date().toISOString(),
    });
  }

  private toDateOnly(date: Date): Date {
    return new Date(
      Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
    );
  }

  private daysBetween(start: Date, end: Date): number {
    const msPerDay = 24 * 60 * 60 * 1000;
    return Math.floor((end.getTime() - start.getTime()) / msPerDay);
  }

  private grantWeeklyFreezeIfNeeded(user: User, today: Date) {
    const weekStart = this.getWeekStart(today);
    const lastGrant = user.lastFreezeGrantDate
      ? this.toDateOnly(new Date(user.lastFreezeGrantDate))
      : null;

    if (!lastGrant || lastGrant.getTime() < weekStart.getTime()) {
      user.streakFreezes = Math.max(user.streakFreezes || 0, 1);
      user.lastFreezeGrantDate = weekStart;
    }
  }

  private getWeekStart(date: Date): Date {
    const d = this.toDateOnly(date);
    const day = d.getUTCDay(); // 0=Sun
    const diff = (day + 6) % 7; // days since Monday
    d.setUTCDate(d.getUTCDate() - diff);
    return d;
  }

  sanitizeUser(user: User) {
    // Ensure password is never serialized
    const { password, ...safe } = user as User & { password?: string };
    return safe;
  }

  async getPublicProfile(userId: string): Promise<Partial<User> | null> {
    if (this.redisService.isEnabled()) {
      const version = await this.getUserCacheVersion(userId);
      const cacheKey = `user:public:${userId}:v${version}`;
      const cached = await this.redisService.getJson<Partial<User>>(cacheKey);
      if (cached) {
        return cached;
      }
      const user = await this.userRepository.findOne({
        where: { id: userId },
        select: [
          "id",
          "name",
          "profilePicture",
          "avatarModelUrl",
          "avatarImageUrl",
          "level",
          "totalPoints",
          "totalDistanceKm",
          "totalTerritoriesCaptured",
          "totalWorkouts",
        ],
      });
      const result = user || null;
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, result, ttlSeconds);
      }
      return result;
    }

    const user = await this.userRepository.findOne({
      where: { id: userId },
      select: [
        "id",
        "name",
        "profilePicture",
        "avatarModelUrl",
        "avatarImageUrl",
        "level",
        "totalPoints",
        "totalDistanceKm",
        "totalTerritoriesCaptured",
        "totalWorkouts",
      ],
    });
    return user || null;
  }

  async getUserStats(userId: string): Promise<{
    totalDistanceKm: number;
    totalSteps: number;
    totalTerritoriesCaptured: number;
    totalWorkouts: number;
    totalPoints: number;
    level: number;
    totalCaloriesBurned: number;
    totalDurationSeconds: number;
    currentStreak: number;
    longestStreak: number;
    streakFreezes: number;
  }> {
    if (this.redisService.isEnabled()) {
      const version = await this.getUserCacheVersion(userId);
      const cacheKey = `user:stats:${userId}:v${version}`;
      const cached = await this.redisService.getJson<{
        totalDistanceKm: number;
        totalSteps: number;
        totalTerritoriesCaptured: number;
        totalWorkouts: number;
        totalPoints: number;
        level: number;
        totalCaloriesBurned: number;
        totalDurationSeconds: number;
        currentStreak: number;
        longestStreak: number;
        streakFreezes: number;
      }>(cacheKey);
      if (cached) {
        return cached;
      }

      const user = await this.findById(userId);
      const stats = await this.computeUserStats(user);
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, stats, ttlSeconds);
      }
      return stats;
    }

    const user = await this.findById(userId);
    return this.computeUserStats(user);
  }

  async getProfile(userId: string) {
    if (!this.redisService.isEnabled()) {
      const user = await this.findById(userId);
      return this.sanitizeUser(user);
    }
    const version = await this.getUserCacheVersion(userId);
    const cacheKey = `user:profile:${userId}:v${version}`;
    const cached = await this.redisService.getJson<Partial<User>>(cacheKey);
    if (cached) {
      return cached;
    }
    const user = await this.findById(userId);
    const safe = this.sanitizeUser(user);
    const ttlSeconds = this.redisService.getDefaultTtlSeconds();
    if (ttlSeconds > 0) {
      await this.redisService.setJson(cacheKey, safe, ttlSeconds);
    }
    return safe;
  }

  async getSettings(userId: string) {
    if (!this.redisService.isEnabled()) {
      const user = await this.findById(userId);
      return user.settings || {};
    }
    const version = await this.getUserCacheVersion(userId);
    const cacheKey = `user:settings:${userId}:v${version}`;
    const cached =
      await this.redisService.getJson<Record<string, any>>(cacheKey);
    if (cached) {
      return cached;
    }
    const user = await this.findById(userId);
    const settings = user.settings || {};
    const ttlSeconds = this.redisService.getDefaultTtlSeconds();
    if (ttlSeconds > 0) {
      await this.redisService.setJson(cacheKey, settings, ttlSeconds);
    }
    return settings;
  }

  private async computeUserStats(user: User) {
    // Calculate calories and duration from activities
    let totalCaloriesBurned = 0;
    let totalDurationSeconds = 0;

    if (user.activities && user.activities.length > 0) {
      for (const activity of user.activities) {
        totalCaloriesBurned += activity.caloriesBurned || 0;

        // Parse duration string (format: "X seconds")
        if (activity.duration) {
          const durationStr = activity.duration.toString();
          const match = durationStr.match(/(\d+)/);
          if (match) {
            totalDurationSeconds += parseInt(match[1]);
          }
        }
      }
    }

    return {
      totalDistanceKm: Number(user.totalDistanceKm),
      totalSteps: user.totalSteps,
      totalTerritoriesCaptured: user.totalTerritoriesCaptured,
      totalWorkouts: user.totalWorkouts,
      totalPoints: user.totalPoints,
      level: user.level,
      totalCaloriesBurned,
      totalDurationSeconds,
      currentStreak: user.currentStreak || 0,
      longestStreak: user.longestStreak || 0,
      streakFreezes: user.streakFreezes || 0,
    };
  }

  private getUserGlobalVersionKey() {
    return "cache:user:global:version";
  }

  private getUserVersionKey(userId: string) {
    return `cache:user:${userId}:version`;
  }

  private async getUserCacheVersion(userId: string): Promise<string> {
    const [globalVersion, userVersion] = await Promise.all([
      this.redisService.getVersion(this.getUserGlobalVersionKey()),
      this.redisService.getVersion(this.getUserVersionKey(userId)),
    ]);
    return `g${globalVersion}:u${userVersion}`;
  }

  private async bumpUserCacheVersion(userId: string) {
    await this.redisService.bumpVersion(this.getUserVersionKey(userId));
  }
}
