import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { EngagementController } from "./engagement.controller";
import { EngagementService } from "./engagement.service";
import { MapDrop } from "./entities/map-drop.entity";
import { MapDropBoost } from "./entities/map-drop-boost.entity";
import { PoiMissionEntity } from "./entities/poi-mission.entity";
import { RewardUnlock } from "./entities/reward-unlock.entity";
import { User } from "../user/user.entity";
import { UserModule } from "../user/user.module";
import { RealtimeModule } from "../realtime/realtime.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([
      MapDrop,
      MapDropBoost,
      PoiMissionEntity,
      RewardUnlock,
      User,
    ]),
    UserModule,
    RealtimeModule,
  ],
  controllers: [EngagementController],
  providers: [EngagementService],
  exports: [EngagementService],
})
export class EngagementModule {}
