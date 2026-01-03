import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Territory } from './territory.entity';
import { UserService } from '../user/user.service';

@Injectable()
export class TerritoryService {
  constructor(
    @InjectRepository(Territory)
    private territoryRepository: Repository<Territory>,
    private userService: UserService,
  ) {}

  async captureTerritories(
    userId: string, 
    hexIds: string[], 
    coordinates: { lat: number; lng: number }[],
    routePointsArray?: { lat: number; lng: number }[][]
  ) {
    const newTerritories = [];
    const recapturedTerritories = [];

    for (let i = 0; i < hexIds.length; i++) {
      const hexId = hexIds[i];
      const coord = coordinates[i];
      const routePoints = routePointsArray ? routePointsArray[i] : null;

      // Check if territory exists
      const existing = await this.territoryRepository.findOne({ 
        where: { hexId },
        relations: ['owner'],
      });

      if (existing) {
        // Territory exists - update it
        if (existing.ownerId !== userId) {
          // Recapture from another user
          existing.ownerId = userId;
          existing.captureCount++;
          existing.points = 0;
          existing.lastBattleAt = new Date();
          if (routePoints) existing.routePoints = routePoints;
          
          await this.territoryRepository.save(existing);
          recapturedTerritories.push(existing);
        } else {
          // Same user recapturing their own territory
          existing.captureCount++;
          existing.capturedAt = new Date();
          if (routePoints) existing.routePoints = routePoints;
          await this.territoryRepository.save(existing);
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
        });
        
        await this.territoryRepository.save(territory);
        newTerritories.push(territory);
      }
    }

    // Update user stats - only track territory count, no points bonus
    await this.userService.updateStats(userId, {
      territories: newTerritories.length + recapturedTerritories.length,
      points: 0, // Points come from distance only
    });

    return {
      newTerritories,
      recapturedTerritories,
      totalPoints: 0, // No territory bonus points
      totalCaptured: newTerritories.length + recapturedTerritories.length,
    };
  }

  async getAllTerritories(): Promise<Territory[]> {
    return this.territoryRepository.find({
      relations: ['owner'],
      order: { capturedAt: 'DESC' },
    });
  }

  async getUserTerritories(userId: string): Promise<Territory[]> {
    return this.territoryRepository.find({
      where: { ownerId: userId },
      order: { capturedAt: 'DESC' },
    });
  }

  async getNearbyTerritories(lat: number, lng: number, radiusKm: number = 5): Promise<Territory[]> {
    // Simple bounding box query (can be optimized with PostGIS)
    const latDelta = radiusKm / 111.0; // 1 degree = ~111 km
    const lngDelta = radiusKm / (111.0 * Math.cos(lat * Math.PI / 180));

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
}
