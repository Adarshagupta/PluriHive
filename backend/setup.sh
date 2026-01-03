#!/bin/bash

# PluriHive Backend Complete Setup Script

echo "🚀 Setting up PluriHive Backend..."

# Install remaining dependencies
echo "📦 Installing ts-node-dev..."
npm install --save-dev ts-node-dev

# Create .env file
if [ ! -f .env ]; then
  echo "📝 Creating .env file..."
  cp .env.example .env
  echo "⚠️  Please update .env with your database credentials!"
fi

# Create remaining module files
echo "📁 Creating remaining modules..."

# Tracking Module
mkdir -p src/modules/tracking
cat > src/modules/tracking/tracking.module.ts << 'EOF'
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Activity } from './activity.entity';
import { TrackingController } from './tracking.controller';
import { TrackingService } from './tracking.service';
import { UserModule } from '../user/user.module';

@Module({
  imports: [TypeOrmModule.forFeature([Activity]), UserModule],
  controllers: [TrackingController],
  providers: [TrackingService],
  exports: [TrackingService],
})
export class TrackingModule {}
EOF

cat > src/modules/tracking/tracking.service.ts << 'EOF'
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

  async saveActivity(userId: string, activityData: Partial<Activity>) {
    const activity = this.activityRepository.create({
      ...activityData,
      userId,
    });

    await this.activityRepository.save(activity);

    // Update user stats
    await this.userService.updateStats(userId, {
      distanceKm: activityData.distanceMeters / 1000,
      steps: activityData.steps,
      workouts: 1,
    });

    return activity;
  }

  async getUserActivities(userId: string): Promise<Activity[]> {
    return this.activityRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  async getActivityById(id: string): Promise<Activity> {
    return this.activityRepository.findOne({ where: { id } });
  }
}
EOF

cat > src/modules/tracking/tracking.controller.ts << 'EOF'
import { Controller, Post, Get, Body, UseGuards, Request, Param } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TrackingService } from './tracking.service';

@Controller('activities')
@UseGuards(JwtAuthGuard)
export class TrackingController {
  constructor(private trackingService: TrackingService) {}

  @Post()
  async saveActivity(@Request() req, @Body() activityData: any) {
    return this.trackingService.saveActivity(req.user.id, activityData);
  }

  @Get()
  async getUserActivities(@Request() req) {
    return this.trackingService.getUserActivities(req.user.id);
  }

  @Get(':id')
  async getActivityById(@Param('id') id: string) {
    return this.trackingService.getActivityById(id);
  }
}
EOF

# Leaderboard Module  
mkdir -p src/modules/leaderboard
cat > src/modules/leaderboard/leaderboard.module.ts << 'EOF'
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../user/user.entity';
import { LeaderboardController } from './leaderboard.controller';
import { LeaderboardService } from './leaderboard.service';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [LeaderboardController],
  providers: [LeaderboardService],
})
export class LeaderboardModule {}
EOF

cat > src/modules/leaderboard/leaderboard.service.ts << 'EOF'
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

  async getGlobalLeaderboard(limit: number = 50) {
    return this.userRepository.find({
      order: { totalPoints: 'DESC' },
      take: limit,
      select: ['id', 'name', 'email', 'totalPoints', 'level', 'totalDistanceKm', 'totalTerritoriesCaptured'],
    });
  }
}
EOF

cat > src/modules/leaderboard/leaderboard.controller.ts << 'EOF'
import { Controller, Get, Query } from '@nestjs/common';
import { LeaderboardService } from './leaderboard.service';

@Controller('leaderboard')
export class LeaderboardController {
  constructor(private leaderboardService: LeaderboardService) {}

  @Get('global')
  async getGlobalLeaderboard(@Query('limit') limit?: number) {
    return this.leaderboardService.getGlobalLeaderboard(limit);
  }
}
EOF

# Achievement Module
mkdir -p src/modules/achievement
cat > src/modules/achievement/achievement.module.ts << 'EOF'
import { Module } from '@nestjs/common';

@Module({})
export class AchievementModule {}
EOF

# Realtime (WebSocket) Module
mkdir -p src/modules/realtime
cat > src/modules/realtime/realtime.module.ts << 'EOF'
import { Module } from '@nestjs/common';
import { RealtimeGateway } from './realtime.gateway';

@Module({
  providers: [RealtimeGateway],
})
export class RealtimeModule {}
EOF

cat > src/modules/realtime/realtime.gateway.ts << 'EOF'
import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ cors: { origin: '*' } })
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private connectedUsers = new Map<string, string>(); // socketId -> userId

  handleConnection(client: Socket) {
    console.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.connectedUsers.delete(client.id);
    console.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('user:connect')
  handleUserConnect(client: Socket, userId: string) {
    this.connectedUsers.set(client.id, userId);
    console.log(`User ${userId} connected with socket ${client.id}`);
  }

  @SubscribeMessage('territory:captured')
  handleTerritoryCaptured(client: Socket, data: any) {
    // Broadcast to nearby users
    this.server.emit('territory:contested', data);
  }

  @SubscribeMessage('location:update')
  handleLocationUpdate(client: Socket, data: any) {
    // Broadcast real-time location
    client.broadcast.emit('user:location', data);
  }

  // Server methods to emit events
  emitLeaderboardUpdate(leaderboard: any) {
    this.server.emit('leaderboard:update', leaderboard);
  }

  emitAchievementUnlocked(userId: string, achievement: any) {
    this.server.emit('achievement:unlocked', { userId, achievement });
  }
}
EOF

echo "✅ Backend structure created!"
echo ""
echo "Next steps:"
echo "1. Update .env with your PostgreSQL credentials"
echo "2. Create database: createdb plurihive"
echo "3. Run: npm run start:dev"
echo ""
echo "🎉 Backend will be ready at http://localhost:3000"
