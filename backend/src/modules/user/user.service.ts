import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async findById(id: string): Promise<User> {
    return this.userRepository.findOne({ 
      where: { id },
      relations: ['territories', 'activities'],
    });
  }

  async updateProfile(userId: string, updates: Partial<User>): Promise<User> {
    await this.userRepository.update(userId, updates);
    return this.findById(userId);
  }

  async updateStats(userId: string, stats: {
    distanceKm?: number;
    steps?: number;
    territories?: number;
    points?: number;
    workouts?: number;
  }): Promise<User> {
    const user = await this.findById(userId);
    
    if (stats.distanceKm) user.totalDistanceKm += stats.distanceKm;
    if (stats.steps) user.totalSteps += stats.steps;
    if (stats.territories) user.totalTerritoriesCaptured += stats.territories;
    if (stats.points) {
      user.totalPoints += stats.points;
      // Level up calculation (every 1000 points = 1 level)
      user.level = Math.floor(user.totalPoints / 1000);
    }
    if (stats.workouts) user.totalWorkouts += stats.workouts;
    
    return this.userRepository.save(user);
  }
}
