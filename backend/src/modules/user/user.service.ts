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

  async completeOnboarding(userId: string): Promise<User> {
    await this.userRepository.update(userId, { hasCompletedOnboarding: true });
    return this.findById(userId);
  }

  async fixOnboardingForAllUsers(): Promise<{ updated: number }> {
    const result = await this.userRepository.update(
      { hasCompletedOnboarding: false },
      { hasCompletedOnboarding: true }
    );
    return { updated: result.affected || 0 };
  }

  async updateStats(userId: string, stats: {
    distanceKm?: number;
    steps?: number;
    territories?: number;
    points?: number;
    workouts?: number;
  }): Promise<User> {
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
    
    return this.userRepository.save(user);
  }

  async updateSettings(userId: string, settings: any): Promise<User> {
    const user = await this.findById(userId);
    user.settings = { ...user.settings, ...settings };
    return this.userRepository.save(user);
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
  }> {
    const user = await this.findById(userId);
    
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
    };
  }
}
