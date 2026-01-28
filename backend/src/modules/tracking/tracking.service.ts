import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Activity } from "./activity.entity";
import { UserService } from "../user/user.service";
import { CreateActivityDto } from "./dto/activity.dto";
import { RedisService } from "../redis/redis.service";

@Injectable()
export class TrackingService {
  private readonly maxRoutePoints = 5000;
  private readonly maxDistanceMeters = 200000;

  constructor(
    @InjectRepository(Activity)
    private activityRepository: Repository<Activity>,
    private userService: UserService,
    private redisService: RedisService,
  ) {}

  async saveActivity(
    userId: string,
    activityData: CreateActivityDto | Partial<Activity>,
  ): Promise<Activity> {
    const normalizedData = this.normalizeActivityData(activityData);

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

    // Derive points from distance (1 point per 100m)
    if (normalizedData.distanceMeters) {
      normalizedData.pointsEarned = Math.round(
        normalizedData.distanceMeters / 100,
      );
    }

    const activity = this.activityRepository.create({
      ...normalizedData,
      userId,
    });

    const savedActivity = await this.activityRepository.save(activity);

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
      { notify: false },
    );

    const streakDate = normalizedData.endTime
      ? new Date(normalizedData.endTime)
      : new Date();
    await this.userService.updateStreak(userId, streakDate, { notify: false });
    this.userService.notifyStatsUpdated(userId);

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

      // Manually serialize to avoid circular references
      const serialized = activities.map((activity) => ({
        ...activity,
        user: activity.user
          ? {
              id: activity.user.id,
              name: activity.user.name,
              email: activity.user.email,
              profilePicture: activity.user.profilePicture,
            }
          : null,
      }));

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

    // Manually serialize to avoid circular references
    return activities.map((activity) => ({
      ...activity,
      user: activity.user
        ? {
            id: activity.user.id,
            name: activity.user.name,
            email: activity.user.email,
            profilePicture: activity.user.profilePicture,
          }
        : null,
    }));
  }

  async getActivityById(id: string): Promise<Activity> {
    return this.activityRepository.findOne({ where: { id } });
  }

  async getActivityByIdForUser(userId: string, id: string): Promise<Activity> {
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(
        this.getActivitiesVersionKey(userId),
      );
      const cacheKey = `activity:${userId}:${id}:v${version}`;
      const cached = await this.redisService.getJson<Activity>(cacheKey);
      if (cached) {
        return cached;
      }
      const activity = await this.activityRepository.findOne({
        where: { id, userId },
      });
      if (!activity) {
        throw new NotFoundException("Activity not found");
      }
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, activity, ttlSeconds);
      }
      return activity;
    }

    const activity = await this.activityRepository.findOne({
      where: { id, userId },
    });
    if (!activity) {
      throw new NotFoundException("Activity not found");
    }
    return activity;
  }

  private getActivitiesVersionKey(userId: string) {
    return `cache:activities:${userId}:version`;
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
}
