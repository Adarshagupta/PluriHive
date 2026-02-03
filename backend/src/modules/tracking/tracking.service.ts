import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Between, Repository } from "typeorm";
import { Activity } from "./activity.entity";
import { UserService } from "../user/user.service";
import { CreateActivityDto } from "./dto/activity.dto";
import { RedisService } from "../redis/redis.service";
import { MapDrop } from "../engagement/entities/map-drop.entity";
import { EngagementService } from "../engagement/engagement.service";

@Injectable()
export class TrackingService {
  private readonly maxRoutePoints = 5000;
  private readonly maxDistanceMeters = 200000;

  constructor(
    @InjectRepository(Activity)
    private activityRepository: Repository<Activity>,
    @InjectRepository(MapDrop)
    private mapDropRepository: Repository<MapDrop>,
    private userService: UserService,
    private redisService: RedisService,
    private engagementService: EngagementService,
  ) {}

  async saveActivity(
    userId: string,
    activityData: CreateActivityDto | Partial<Activity>,
  ): Promise<Activity> {
    const normalizedData = this.normalizeActivityData(activityData);
    const clientId = normalizedData.clientId?.toString().trim();

    if (clientId) {
      const existing = await this.activityRepository.findOne({
        where: { userId, clientId },
      });
      if (existing) {
        return existing;
      }
    }

    if (
      !normalizedData.routePoints ||
      normalizedData.routePoints.length === 0
    ) {
      throw new BadRequestException("Route points are required");
    }
    if (normalizedData.routePoints.length > this.maxRoutePoints) {
      throw new BadRequestException("Route too large to save");
    }
    if ((normalizedData.distanceMeters ?? 0) > this.maxDistanceMeters) {
      throw new BadRequestException("Distance exceeds maximum allowed");
    }

    if (normalizedData.startTime && normalizedData.endTime) {
      const start = new Date(normalizedData.startTime);
      const end = new Date(normalizedData.endTime);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
        throw new BadRequestException("Invalid start or end time");
      }
      if (end < start) {
        throw new BadRequestException("End time must be after start time");
      }
    }

    // Derive distance from route points to avoid client tampering
    const computedDistance = this.calculateRouteDistance(
      normalizedData.routePoints,
    );
    if (computedDistance > 0) {
      normalizedData.distanceMeters = Math.min(
        computedDistance,
        this.maxDistanceMeters,
      );
    }

    // Normalize territories to captured hex count if provided
    if (
      normalizedData.capturedHexIds &&
      normalizedData.capturedHexIds.length > 0
    ) {
      normalizedData.territoriesCaptured = normalizedData.capturedHexIds.length;
    }

    // Derive average speed from duration if possible
    if (
      normalizedData.startTime &&
      normalizedData.endTime &&
      normalizedData.distanceMeters
    ) {
      const start = new Date(normalizedData.startTime);
      const end = new Date(normalizedData.endTime);
      const durationSeconds = Math.max(
        0,
        (end.getTime() - start.getTime()) / 1000,
      );
      if (durationSeconds > 0) {
        normalizedData.averageSpeed =
          normalizedData.distanceMeters / durationSeconds;
      }
    }

    // Derive points from distance (1 point per 100m) + apply map drop boosts
    if (normalizedData.distanceMeters) {
      normalizedData.pointsEarned = await this.calculateBoostedPoints(
        userId,
        normalizedData.routePoints,
        normalizedData.startTime,
        normalizedData.endTime,
        normalizedData.distanceMeters,
      );
    }

    const activity = this.activityRepository.create({
      ...normalizedData,
      userId,
      clientId: clientId || undefined,
    });

    const savedActivity = await this.activityRepository.save(activity);

    const lastPoint =
      normalizedData.routePoints?.[normalizedData.routePoints.length - 1];
    if (
      lastPoint &&
      typeof lastPoint.latitude === "number" &&
      typeof lastPoint.longitude === "number"
    ) {
      await this.userService.updateLastLocation(
        userId,
        lastPoint.latitude,
        lastPoint.longitude,
        normalizedData.endTime ?? new Date(),
      );
    }

    // Update user stats
    await this.userService.updateStats(
      userId,
      {
        distanceKm: normalizedData.distanceMeters
          ? normalizedData.distanceMeters / 1000
          : 0,
        steps: normalizedData.steps || 0,
        territories: normalizedData.territoriesCaptured || 0,
        points: normalizedData.pointsEarned || 0,
        workouts: 1,
      },
      {
        notify: false,
        occurredAt: normalizedData.endTime ?? new Date(),
      },
    );

    const streakDate = normalizedData.endTime
      ? new Date(normalizedData.endTime)
      : new Date();
    await this.userService.updateStreak(userId, streakDate, { notify: false });
    this.userService.notifyStatsUpdated(userId);

    try {
      await this.engagementService.updateMissionsFromActivity(userId, {
        distanceMeters: normalizedData.distanceMeters,
        steps: normalizedData.steps,
        territories: normalizedData.territoriesCaptured,
        workouts: 1,
        occurredAt: normalizedData.endTime ?? new Date(),
      });
    } catch (error) {
      console.error("Mission update failed:", error);
    }

    await this.redisService.bumpVersion(this.getActivitiesVersionKey(userId));

    return savedActivity;
  }

  private normalizeActivityData(
    activityData: CreateActivityDto | Partial<Activity>,
  ): Partial<Activity> {
    const routePoints = activityData.routePoints?.map((point: any) => ({
      latitude: Number(point.latitude),
      longitude: Number(point.longitude),
      timestamp:
        point.timestamp instanceof Date
          ? point.timestamp
          : new Date(point.timestamp),
      altitude: typeof point.altitude === "number" ? point.altitude : undefined,
    }));

    const startTime =
      activityData.startTime instanceof Date
        ? activityData.startTime
        : activityData.startTime
          ? new Date(activityData.startTime as any)
          : undefined;

    const endTime =
      activityData.endTime instanceof Date
        ? activityData.endTime
        : activityData.endTime
          ? new Date(activityData.endTime as any)
          : undefined;

    return {
      ...activityData,
      clientId:
        typeof (activityData as any).clientId === "string"
          ? (activityData as any).clientId.trim()
          : undefined,
      routePoints,
      startTime,
      endTime,
    };
  }

  async getUserActivities(userId: string, limit: number = 50): Promise<any[]> {
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(
        this.getActivitiesVersionKey(userId),
      );
      const cacheKey = `activities:${userId}:v${version}:limit:${limit}`;
      const cached = await this.redisService.getJson<any[]>(cacheKey);
      if (cached) {
        return cached;
      }
      const activities = await this.activityRepository.find({
        where: { userId },
        relations: ["user"],
        order: { createdAt: "DESC" },
        take: limit,
      });

      const serialized = activities.map((activity) =>
        this.serializeActivity(activity),
      );

      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, serialized, ttlSeconds);
      }
      return serialized;
    }

    const activities = await this.activityRepository.find({
      where: { userId },
      relations: ["user"],
      order: { createdAt: "DESC" },
      take: limit,
    });

    return activities.map((activity) => this.serializeActivity(activity));
  }

  async getActivityById(id: string): Promise<Activity> {
    return this.activityRepository.findOne({ where: { id } });
  }

  async getActivityByIdForUser(userId: string, id: string): Promise<any> {
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(
        this.getActivitiesVersionKey(userId),
      );
      const cacheKey = `activity:${userId}:${id}:v${version}`;
      const cached = await this.redisService.getJson<any>(cacheKey);
      if (cached) {
        return cached;
      }
      const activity = await this.activityRepository.findOne({
        where: { id, userId },
        relations: ["user"],
      });
      if (!activity) {
        throw new NotFoundException("Activity not found");
      }
      const serialized = this.serializeActivity(activity);
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, serialized, ttlSeconds);
      }
      return serialized;
    }

    const activity = await this.activityRepository.findOne({
      where: { id, userId },
      relations: ["user"],
    });
    if (!activity) {
      throw new NotFoundException("Activity not found");
    }
    return this.serializeActivity(activity);
  }

  private getActivitiesVersionKey(userId: string) {
    return `cache:activities:${userId}:version`;
  }

  private serializeActivity(activity: Activity) {
    return {
      ...activity,
      user: activity.user
        ? {
            id: activity.user.id,
            name: activity.user.name,
            email: activity.user.email,
            profilePicture: activity.user.profilePicture,
          }
        : null,
    };
  }

  private calculateRouteDistance(
    routePoints: Array<{
      latitude: number;
      longitude: number;
      timestamp?: Date;
    }>,
  ): number {
    if (!routePoints || routePoints.length < 2) return 0;
    let total = 0;
    for (let i = 1; i < routePoints.length; i++) {
      const prev = routePoints[i - 1];
      const cur = routePoints[i];
      if (
        typeof prev.latitude !== "number" ||
        typeof prev.longitude !== "number" ||
        typeof cur.latitude !== "number" ||
        typeof cur.longitude !== "number"
      ) {
        continue;
      }
      total += this.haversineDistanceMeters(
        prev.latitude,
        prev.longitude,
        cur.latitude,
        cur.longitude,
      );
    }
    return total;
  }

  private haversineDistanceMeters(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const R = 6371000;
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private async calculateBoostedPoints(
    userId: string,
    routePoints: Array<{
      latitude: number;
      longitude: number;
      timestamp?: Date;
    }>,
    startTime?: Date,
    endTime?: Date,
    distanceMeters?: number,
  ): Promise<number> {
    const basePoints = Math.round((distanceMeters || 0) / 100);
    if (!routePoints || routePoints.length < 2) return basePoints;
    if (!startTime || !endTime) return basePoints;

    const lookbackMs = 2 * 60 * 1000;
    const lookbackStart = new Date(startTime.getTime() - lookbackMs);

    const pickedDrops = await this.mapDropRepository.find({
      where: {
        userId,
        pickedAt: Between(lookbackStart, endTime),
      },
      order: { pickedAt: "ASC" },
    });

    if (pickedDrops.length === 0) return basePoints;

    const boostWindows = this.buildBoostWindows(pickedDrops);
    if (boostWindows.length === 0) return basePoints;

    let bonusPoints = 0;
    for (let i = 1; i < routePoints.length; i++) {
      const prev = routePoints[i - 1];
      const cur = routePoints[i];
      if (!prev || !cur) continue;
      if (!(prev.timestamp instanceof Date) || !(cur.timestamp instanceof Date)) {
        continue;
      }
      const segmentDistance = this.haversineDistanceMeters(
        prev.latitude,
        prev.longitude,
        cur.latitude,
        cur.longitude,
      );
      if (segmentDistance <= 0) continue;
      const midpoint = new Date(
        (prev.timestamp.getTime() + cur.timestamp.getTime()) / 2,
      );
      const window = boostWindows.find(
        (interval) =>
          midpoint >= interval.start && midpoint <= interval.end,
      );
      if (!window) continue;
      const multiplier = Math.max(1, window.multiplier || 2);
      bonusPoints += (segmentDistance / 100) * (multiplier - 1);
    }

    return Math.round(basePoints + bonusPoints);
  }

  private buildBoostWindows(
    picks: MapDrop[],
  ): Array<{ start: Date; end: Date; multiplier: number }> {
    const windows: Array<{ start: Date; end: Date; multiplier: number }> = [];
    let currentStart: Date | null = null;
    let currentEnd: Date | null = null;
    let currentMultiplier = 2;

    for (const pick of picks) {
      if (!pick.pickedAt) continue;
      const durationMs = (pick.boostSeconds || 120) * 1000;
      const start = pick.pickedAt;
      if (currentEnd && start <= currentEnd) {
        currentEnd = new Date(currentEnd.getTime() + durationMs);
      } else {
        if (currentStart && currentEnd) {
          windows.push({
            start: currentStart,
            end: currentEnd,
            multiplier: currentMultiplier,
          });
        }
        currentStart = start;
        currentEnd = new Date(start.getTime() + durationMs);
        currentMultiplier = pick.boostMultiplier || 2;
      }
    }

    if (currentStart && currentEnd) {
      windows.push({
        start: currentStart,
        end: currentEnd,
        multiplier: currentMultiplier,
      });
    }

    return windows;
  }
}
