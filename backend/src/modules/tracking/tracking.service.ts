import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Activity } from './activity.entity';
import { UserService } from '../user/user.service';

@Injectable()
export class TrackingService {
  constructor(
    @InjectRepository(Activity)
    private activityRepository: Repository<Activity>,
    private userService: UserService,
  ) {}

  async saveActivity(userId: string, activityData: Partial<Activity>): Promise<Activity> {
    const activity = this.activityRepository.create({
      ...activityData,
      userId,
    });

    const savedActivity = await this.activityRepository.save(activity);

    // Update user stats
    await this.userService.updateStats(userId, {
      distanceKm: activityData.distanceMeters ? activityData.distanceMeters / 1000 : 0,
      steps: activityData.steps || 0,
      territories: activityData.territoriesCaptured || 0,
      points: activityData.pointsEarned || 0,
      workouts: 1,
    });

    return savedActivity;
  }

  async getUserActivities(userId: string, limit: number = 50): Promise<any[]> {
    const activities = await this.activityRepository.find({
      where: { userId },
      relations: ['user'],
      order: { createdAt: 'DESC' },
      take: limit,
    });

    // Manually serialize to avoid circular references
    return activities.map(activity => ({
      ...activity,
      user: activity.user ? {
        id: activity.user.id,
        name: activity.user.name,
        email: activity.user.email,
        profilePicture: activity.user.profilePicture,
      } : null,
    }));
  }

  async getActivityById(id: string): Promise<Activity> {
    return this.activityRepository.findOne({ where: { id } });
  }
}
