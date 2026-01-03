import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../user/user.entity';

@Injectable()
export class LeaderboardService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async getGlobalLeaderboard(limit: number = 50): Promise<User[]> {
    return this.userRepository.find({
      order: { totalPoints: 'DESC' },
      take: limit,
      select: ['id', 'name', 'email', 'totalPoints', 'level', 'totalDistanceKm', 'totalSteps', 'totalTerritoriesCaptured'],
    });
  }
}
