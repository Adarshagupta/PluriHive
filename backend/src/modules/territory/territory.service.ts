import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Territory } from './territory.entity';
import { UserService } from '../user/user.service';
import { RedisService } from '../redis/redis.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { SeasonService } from '../season/season.service';
import { DuelService } from '../duel/duel.service';

@Injectable()
export class TerritoryService {
  private readonly decayGraceDays: number;
  private readonly decayPerDay: number;

  constructor(
    @InjectRepository(Territory)
    private territoryRepository: Repository<Territory>,
    private userService: UserService,
    private redisService: RedisService,
    private realtimeGateway: RealtimeGateway,
    private seasonService: SeasonService,
    private duelService: DuelService,
  ) {
    this.decayGraceDays = this.parseNumber(
      process.env.TERRITORY_DECAY_GRACE_DAYS,
      14,
    );
    this.decayPerDay = this.parseNumber(
      process.env.TERRITORY_DECAY_PER_DAY,
      10,
    );
  }

  async captureTerritories(
    userId: string, 
    hexIds: string[], 
    coordinates: { lat: number; lng: number }[],
    routePointsArray?: { lat: number; lng: number }[][],
    captureSessionId?: string
  ) {
    if (hexIds.length !== coordinates.length) {
      throw new BadRequestException('hexIds and coordinates length mismatch');
    }
    if (hexIds.length === 0) {
      throw new BadRequestException('No territories provided');
    }
    if (hexIds.length > 5000) {
      throw new BadRequestException('Too many territories in one request');
    }

    await this.ensureSeasonIsCurrent();

    const now = new Date();
    const newTerritories = [];
    const recapturedTerritories = [];
    const toSave: Territory[] = [];
    const updatedHexIds = new Set<string>();
    const defenseAlerts: Array<{
      ownerId: string;
      territory: Territory;
    }> = [];
    const capturedCoordinates: Array<{ lat: number; lng: number }> = [];

    const existingTerritories = await this.territoryRepository.find({
      where: { hexId: In(hexIds) },
      relations: ['owner'],
    });
    const existingMap = new Map(existingTerritories.map((t) => [t.hexId, t]));

    const sessionId = captureSessionId?.trim() || undefined;

    for (let i = 0; i < hexIds.length; i++) {
      const hexId = hexIds[i];
      const coord = coordinates[i];
      let routePoints = null;
      if (routePointsArray && routePointsArray.length > 0) {
        if (routePointsArray.length === hexIds.length) {
          routePoints = routePointsArray[i];
        } else if (routePointsArray.length === 1) {
          routePoints = routePointsArray[0];
        }
      }

      // Check if territory exists
      const existing = existingMap.get(hexId);
      const routePointsDefined = Array.isArray(routePoints) && routePoints.length > 0;

      if (existing) {
        const effectiveStrength = this.computeEffectiveStrength(existing, now);
        if (effectiveStrength <= 0 && existing.ownerId) {
          existing.ownerId = null;
          existing.owner = null;
          existing.name = null;
          existing.decayedAt = now;
          existing.strength = 0;
        }

        if (
          sessionId &&
          existing.ownerId === userId &&
          existing.lastCaptureSessionId === sessionId
        ) {
          continue;
        }
        // Territory exists - update it
        if (!existing.ownerId) {
          existing.ownerId = userId;
          existing.owner = null;
          existing.captureCount = Math.max(existing.captureCount || 0, 0) + 1;
          existing.points = 0;
          existing.capturedAt = now;
          existing.lastCaptureSessionId = sessionId;
          existing.lastDefendedAt = now;
          existing.strength = 100;
          existing.decayedAt = null;
          if (routePointsDefined) existing.routePoints = routePoints;

          toSave.push(existing);
          newTerritories.push(existing);
          updatedHexIds.add(hexId);
          capturedCoordinates.push(coord);
        } else if (existing.ownerId !== userId) {
          // Recapture from another user
          const previousOwnerId = existing.ownerId;
          existing.ownerId = userId;
          existing.owner = null;
          existing.captureCount++;
          existing.points = 0;
          existing.lastBattleAt = now;
          existing.lastCaptureSessionId = sessionId;
          existing.lastDefendedAt = now;
          existing.strength = 100;
          existing.decayedAt = null;
          existing.name = null;
          if (routePointsDefined) existing.routePoints = routePoints;

          toSave.push(existing);
          recapturedTerritories.push(existing);
          updatedHexIds.add(hexId);
          capturedCoordinates.push(coord);
          defenseAlerts.push({ ownerId: previousOwnerId, territory: existing });
        } else {
          // Same user recapturing their own territory
          existing.captureCount++;
          existing.capturedAt = now;
          existing.lastCaptureSessionId = sessionId;
          existing.lastDefendedAt = now;
          existing.strength = 100;
          existing.decayedAt = null;
          if (routePointsDefined) existing.routePoints = routePoints;
          toSave.push(existing);
          updatedHexIds.add(hexId);
          capturedCoordinates.push(coord);
        }
      } else {
        // New territory
        const territory = this.territoryRepository.create({
          hexId,
          latitude: coord.lat,
          longitude: coord.lng,
          ownerId: userId,
          points: 0,
          routePoints: routePoints || [],
          lastCaptureSessionId: sessionId,
          capturedAt: now,
          lastDefendedAt: now,
          strength: 100,
        });

        toSave.push(territory);
        newTerritories.push(territory);
        updatedHexIds.add(hexId);
        capturedCoordinates.push(coord);
      }
    }

    if (toSave.length > 0) {
      await this.territoryRepository.save(toSave);
    }

    // Update user stats - only track territory count, no points bonus
    await this.userService.updateStats(userId, {
      territories: newTerritories.length + recapturedTerritories.length,
      points: 0, // Points come from distance only
    }, { occurredAt: now });

    await this.redisService.bumpVersion(this.getTerritoriesVersionKey());

    if (updatedHexIds.size > 0) {
      const broadcastTerritories = await this.territoryRepository.find({
        where: { hexId: In(Array.from(updatedHexIds)) },
        relations: ['owner'],
      });
      this.realtimeGateway.emitTerritoriesCaptured(broadcastTerritories);
    }

    if (capturedCoordinates.length > 0) {
      try {
        await this.duelService.registerTerritoryCaptures(
          userId,
          capturedCoordinates,
          now,
        );
      } catch (error) {
        console.error("Duel scoring failed:", error);
      }
    }

    if (defenseAlerts.length > 0) {
      for (const alert of defenseAlerts) {
        this.realtimeGateway.emitTerritoryDefenseAlert(alert.ownerId, {
          territoryId: alert.territory.id,
          hexId: alert.territory.hexId,
          attackerId: userId,
          occurredAt: now.toISOString(),
        });
      }
    }

    return {
      newTerritories,
      recapturedTerritories,
      totalPoints: 0, // No territory bonus points
      totalCaptured: newTerritories.length + recapturedTerritories.length,
    };
  }

  async getAllTerritories(
    limit: number = 5000,
    offset: number = 0,
  ): Promise<any[]> {
    await this.ensureSeasonIsCurrent();
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(this.getTerritoriesVersionKey());
      const cacheKey = `territories:all:v${version}:limit:${limit}:offset:${offset}`;
      const cached = await this.redisService.getJson<any[]>(cacheKey);
      if (cached) {
        return cached;
      }
      const territories = await this.territoryRepository.find({
        relations: ['owner'],
        order: { capturedAt: 'DESC' },
        take: limit,
        skip: offset,
      });
      const serialized = await this.applyDecayAndSerialize(territories);
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, serialized, ttlSeconds);
      }
      return serialized;
    }

    const territories = await this.territoryRepository.find({
      relations: ['owner'],
      order: { capturedAt: 'DESC' },
      take: limit,
      skip: offset,
    });
    return this.applyDecayAndSerialize(territories);
  }

  async getUserTerritories(userId: string): Promise<any[]> {
    await this.ensureSeasonIsCurrent();
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(this.getTerritoriesVersionKey());
      const cacheKey = `territories:user:${userId}:v${version}`;
      const cached = await this.redisService.getJson<any[]>(cacheKey);
      if (cached) {
        return cached;
      }
      const territories = await this.territoryRepository.find({
        where: { ownerId: userId },
        order: { capturedAt: 'DESC' },
      });
      const serialized = await this.applyDecayAndSerialize(territories);
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, serialized, ttlSeconds);
      }
      return serialized;
    }

    const territories = await this.territoryRepository.find({
      where: { ownerId: userId },
      order: { capturedAt: 'DESC' },
    });
    return this.applyDecayAndSerialize(territories);
  }

  async getNearbyTerritories(lat: number, lng: number, radiusKm: number = 5): Promise<any[]> {
    // Simple bounding box query (can be optimized with PostGIS)
    const latDelta = radiusKm / 111.0; // 1 degree = ~111 km
    const lngDelta = radiusKm / (111.0 * Math.cos(lat * Math.PI / 180));

    await this.ensureSeasonIsCurrent();
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(this.getTerritoriesVersionKey());
      const latKey = Number(lat).toFixed(4);
      const lngKey = Number(lng).toFixed(4);
      const radiusKey = Number(radiusKm).toFixed(2);
      const cacheKey = `territories:nearby:v${version}:lat:${latKey}:lng:${lngKey}:r:${radiusKey}`;
      const cached = await this.redisService.getJson<any[]>(cacheKey);
      if (cached) {
        return cached;
      }

      const territories = await this.territoryRepository
        .createQueryBuilder('territory')
        .leftJoinAndSelect('territory.owner', 'owner')
        .where('territory.latitude BETWEEN :minLat AND :maxLat', {
          minLat: lat - latDelta,
          maxLat: lat + latDelta,
        })
        .andWhere('territory.longitude BETWEEN :minLng AND :maxLng', {
          minLng: lng - lngDelta,
          maxLng: lng + lngDelta,
        })
        .getMany();

      const serialized = await this.applyDecayAndSerialize(territories);
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, serialized, ttlSeconds);
      }
      return serialized;
    }

    const territories = await this.territoryRepository
      .createQueryBuilder('territory')
      .leftJoinAndSelect('territory.owner', 'owner')
      .where('territory.latitude BETWEEN :minLat AND :maxLat', {
        minLat: lat - latDelta,
        maxLat: lat + latDelta,
      })
      .andWhere('territory.longitude BETWEEN :minLng AND :maxLng', {
        minLng: lng - lngDelta,
        maxLng: lng + lngDelta,
      })
      .getMany();
    return this.applyDecayAndSerialize(territories);
  }

  async getBossTerritories(limit: number = 3) {
    await this.ensureSeasonIsCurrent();
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(this.getTerritoriesVersionKey());
      const cacheKey = `territories:boss:v${version}:limit:${limit}`;
      const cached = await this.redisService.getJson<any[]>(cacheKey);
      if (cached) {
        return cached;
      }
      const bosses = await this.computeBossTerritories(limit);
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, bosses, ttlSeconds);
      }
      return bosses;
    }

    return this.computeBossTerritories(limit);
  }

  private async computeBossTerritories(limit: number) {
    const candidates = await this.territoryRepository.find({
      relations: ['owner'],
      order: { captureCount: 'DESC', capturedAt: 'DESC' },
      take: Math.max(limit, 20),
    });

    if (candidates.length === 0) return [];

    const serialized = await this.applyDecayAndSerialize(candidates);
    const active = serialized.filter((territory) => territory.ownerId);
    if (active.length === 0) return [];

    const weekIndex = this.getWeekIndex(new Date());
    const start = weekIndex % active.length;

    const bosses = [];
    for (let i = 0; i < Math.min(limit, active.length); i++) {
      bosses.push(active[(start + i) % active.length]);
    }

    return bosses.map((territory, index) => ({
      ...territory,
      isBoss: true,
      bossRewardPoints: 200 + index * 50,
    }));
  }

  private getTerritoriesVersionKey() {
    return 'cache:territories:version';
  }

  private async ensureSeasonIsCurrent() {
    const rotation = await this.seasonService.ensureSeasonRotation();
    if (!rotation.rotated) return;

    await this.territoryRepository
      .createQueryBuilder()
      .delete()
      .from(Territory)
      .execute();
    await this.redisService.bumpVersion(this.getTerritoriesVersionKey());
  }

  private async applyDecayAndSerialize(territories: Territory[]) {
    if (!territories || territories.length === 0) return [];
    const now = new Date();
    const updates: Territory[] = [];
    const serialized = territories.map((territory) => {
      const effectiveStrength = this.computeEffectiveStrength(territory, now);
      if (effectiveStrength <= 0 && territory.ownerId) {
        territory.ownerId = null;
        territory.owner = null;
        territory.name = null;
        territory.decayedAt = now;
        territory.strength = 0;
        updates.push(territory);
      }
      return {
        ...territory,
        effectiveStrength,
      };
    });

    if (updates.length > 0) {
      await this.territoryRepository.save(updates);
      await this.redisService.bumpVersion(this.getTerritoriesVersionKey());
    }

    return serialized;
  }

  private computeEffectiveStrength(territory: Territory, now: Date) {
    const baseStrength = Number(territory.strength ?? 100);
    const lastActive =
      territory.lastDefendedAt || territory.lastBattleAt || territory.capturedAt;
    if (!lastActive) return baseStrength;

    const msPerDay = 24 * 60 * 60 * 1000;
    const daysSince = Math.floor(
      (now.getTime() - new Date(lastActive).getTime()) / msPerDay,
    );
    if (daysSince <= this.decayGraceDays) return baseStrength;
    const decayDays = Math.max(0, daysSince - this.decayGraceDays);
    const decayed = decayDays * this.decayPerDay;
    return Math.max(0, baseStrength - decayed);
  }

  private parseNumber(value: string | undefined, fallback: number) {
    if (!value) return fallback;
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  async updateTerritoryName(userId: string, territoryId: string, name?: string) {
    const territory = await this.territoryRepository.findOne({
      where: { id: territoryId },
    });
    if (!territory) {
      throw new NotFoundException('Territory not found');
    }
    if (territory.ownerId !== userId) {
      throw new ForbiddenException('Only the owner can rename this territory');
    }

    const trimmed = (name ?? '').trim();
    if (trimmed.length > 40) {
      throw new BadRequestException('Territory name is too long');
    }
    if (trimmed.length > 0 && trimmed.length < 2) {
      throw new BadRequestException('Territory name is too short');
    }

    territory.name = trimmed.length == 0 ? null : trimmed;
    await this.territoryRepository.save(territory);
    await this.redisService.bumpVersion(this.getTerritoriesVersionKey());
    return territory;
  }

  private getWeekIndex(date: Date) {
    const msPerWeek = 7 * 24 * 60 * 60 * 1000;
    const epoch = Date.UTC(2024, 0, 1);
    return Math.floor((date.getTime() - epoch) / msPerWeek);
  }
}
