import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Activity } from './activity.entity';
import { MapDrop } from '../engagement/entities/map-drop.entity';
import { TrackingService } from './tracking.service';
import { TrackingController } from './tracking.controller';
import { UserModule } from '../user/user.module';
import { RedisModule } from '../redis/redis.module';
import { EngagementModule } from '../engagement/engagement.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Activity, MapDrop]),
    UserModule,
    RedisModule,
    EngagementModule,
  ],
  providers: [TrackingService],
  controllers: [TrackingController],
  exports: [TrackingService],
})
export class TrackingModule {}
