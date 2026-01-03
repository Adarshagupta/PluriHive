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

  async captureTerritories(userId: string, hexIds: string[], coordinates: { lat: number; lng: number }[]) {
    const newTerritories = [];
    const recapturedTerritories = [];
    let totalPoints = 0;

    for (let i = 0; i < hexIds.length; i++) {
      const hexId = hexIds[i];
      const coord = coordinates[i];

      // Check if territory exists
      const existing = await this.territoryRepository.findOne({ 
        where: { hexId },
        relations: ['owner'],
      });

      if (existing) {
        // Recapture from another user
        if (existing.ownerId !== userId) {
          existing.ownerId = userId;
          existing.captureCount++;
          existing.points = 50 + (existing.captureCount * 10); // Bonus for contested territories
          existing.lastBattleAt = new Date();
          
          await this.territoryRepository.save(existing);
          recapturedTerritories.push(existing);
          totalPoints += existing.points;
        }
      } else {
        // New territory
        const territory = this.territoryRepository.create({
          hexId,
          latitude: coord.lat,
          longitude: coord.lng,
          ownerId: userId,
          points: 50,
        });
        
        await this.territoryRepository.save(territory);
        newTerritories.push(territory);
        totalPoints += 50;
      }
    }

    // Update user stats
    await this.userService.updateStats(userId, {
      territories: newTerritories.length + recapturedTerritories.length,
      points: totalPoints,
    });

    return {
      newTerritories,
      recapturedTerritories,
      totalPoints,
      totalCaptured: newTerritories.length + recapturedTerritories.length,
    };
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
