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

@Injectable()
export class TerritoryService {
  constructor(
    @InjectRepository(Territory)
    private territoryRepository: Repository<Territory>,
    private userService: UserService,
    private redisService: RedisService,
    private realtimeGateway: RealtimeGateway,
  ) {}

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

    const newTerritories = [];
    const recapturedTerritories = [];
    const toSave: Territory[] = [];
    const updatedHexIds = new Set<string>();

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

      if (existing) {
        if (
          sessionId &&
          existing.ownerId === userId &&
          existing.lastCaptureSessionId === sessionId
        ) {
          continue;
        }
        // Territory exists - update it
        if (existing.ownerId !== userId) {
          // Recapture from another user
          existing.ownerId = userId;
          existing.captureCount++;
          existing.points = 0;
          existing.lastBattleAt = new Date();
          existing.lastCaptureSessionId = sessionId;
          existing.name = null;
          if (routePoints) existing.routePoints = routePoints;

          toSave.push(existing);
          recapturedTerritories.push(existing);
          updatedHexIds.add(hexId);
        } else {
          // Same user recapturing their own territory
          existing.captureCount++;
          existing.capturedAt = new Date();
          existing.lastCaptureSessionId = sessionId;
          if (routePoints) existing.routePoints = routePoints;
          toSave.push(existing);
          updatedHexIds.add(hexId);
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
        });

        toSave.push(territory);
        newTerritories.push(territory);
        updatedHexIds.add(hexId);
      }
    }

    if (toSave.length > 0) {
      await this.territoryRepository.save(toSave);
    }

    // Update user stats - only track territory count, no points bonus
    await this.userService.updateStats(userId, {
      territories: newTerritories.length + recapturedTerritories.length,
      points: 0, // Points come from distance only
    });

    await this.redisService.bumpVersion(this.getTerritoriesVersionKey());

    if (updatedHexIds.size > 0) {
      const broadcastTerritories = await this.territoryRepository.find({
        where: { hexId: In(Array.from(updatedHexIds)) },
        relations: ['owner'],
      });
      this.realtimeGateway.emitTerritoriesCaptured(broadcastTerritories);
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
  ): Promise<Territory[]> {
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(this.getTerritoriesVersionKey());
      const cacheKey = `territories:all:v${version}:limit:${limit}:offset:${offset}`;
      const cached = await this.redisService.getJson<Territory[]>(cacheKey);
      if (cached) {
        return cached;
      }
      const territories = await this.territoryRepository.find({
        relations: ['owner'],
        order: { capturedAt: 'DESC' },
        take: limit,
        skip: offset,
      });
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, territories, ttlSeconds);
      }
      return territories;
    }

    return this.territoryRepository.find({
      relations: ['owner'],
      order: { capturedAt: 'DESC' },
      take: limit,
      skip: offset,
    });
  }

  async getUserTerritories(userId: string): Promise<Territory[]> {
    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(this.getTerritoriesVersionKey());
      const cacheKey = `territories:user:${userId}:v${version}`;
      const cached = await this.redisService.getJson<Territory[]>(cacheKey);
      if (cached) {
        return cached;
      }
      const territories = await this.territoryRepository.find({
        where: { ownerId: userId },
        order: { capturedAt: 'DESC' },
      });
      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, territories, ttlSeconds);
      }
      return territories;
    }

    return this.territoryRepository.find({
      where: { ownerId: userId },
      order: { capturedAt: 'DESC' },
    });
  }

  async getNearbyTerritories(lat: number, lng: number, radiusKm: number = 5): Promise<Territory[]> {
    // Simple bounding box query (can be optimized with PostGIS)
    const latDelta = radiusKm / 111.0; // 1 degree = ~111 km
    const lngDelta = radiusKm / (111.0 * Math.cos(lat * Math.PI / 180));

    if (this.redisService.isEnabled()) {
      const version = await this.redisService.getVersion(this.getTerritoriesVersionKey());
      const latKey = Number(lat).toFixed(4);
      const lngKey = Number(lng).toFixed(4);
      const radiusKey = Number(radiusKm).toFixed(2);
      const cacheKey = `territories:nearby:v${version}:lat:${latKey}:lng:${lngKey}:r:${radiusKey}`;
      const cached = await this.redisService.getJson<Territory[]>(cacheKey);
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

      const ttlSeconds = this.redisService.getDefaultTtlSeconds();
      if (ttlSeconds > 0) {
        await this.redisService.setJson(cacheKey, territories, ttlSeconds);
      }
      return territories;
    }

    return this.territoryRepository
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
  }

  async getBossTerritories(limit: number = 3) {
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

    const weekIndex = this.getWeekIndex(new Date());
    const start = weekIndex % candidates.length;

    const bosses = [];
    for (let i = 0; i < Math.min(limit, candidates.length); i++) {
      bosses.push(candidates[(start + i) % candidates.length]);
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
