import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Request,
  UseGuards,
} from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { EngagementService } from "./engagement.service";
import { DropSyncDto } from "./dto/drop-sync.dto";
import { PoiMissionRequestDto } from "./dto/poi-mission.dto";
import { RewardRequestDto } from "./dto/reward.dto";

@Controller("engagement")
@UseGuards(JwtAuthGuard)
export class EngagementController {
  constructor(private readonly engagementService: EngagementService) {}

  @Post("drops/sync")
  async syncDrops(@Request() req, @Body() body: DropSyncDto) {
    return this.engagementService.syncDrops(req.user.id, body.lat, body.lng);
  }

  @Get("missions/poi")
  async getPoiMission(
    @Request() req,
    @Query() query: PoiMissionRequestDto,
  ) {
    return this.engagementService.getPoiMission(
      req.user.id,
      query.lat,
      query.lng,
    );
  }

  @Post("missions/poi/visit")
  async visitPoiMission(@Request() req, @Body() body: PoiMissionRequestDto) {
    return this.engagementService.visitPoiMission(
      req.user.id,
      body.lat,
      body.lng,
    );
  }

  @Get("missions/daily")
  async getDailyMissions(@Request() req) {
    return this.engagementService.getDailyMissions(req.user.id);
  }

  @Get("missions/weekly")
  async getWeeklyMissions(@Request() req) {
    return this.engagementService.getWeeklyMissions(req.user.id);
  }

  @Get("rewards")
  async getRewards(@Request() req) {
    return this.engagementService.getRewardsState(req.user.id);
  }

  @Post("rewards/unlock")
  async unlockReward(@Request() req, @Body() body: RewardRequestDto) {
    return this.engagementService.unlockReward(req.user.id, body.rewardId);
  }

  @Post("rewards/select")
  async selectReward(@Request() req, @Body() body: RewardRequestDto) {
    return this.engagementService.selectReward(req.user.id, body.rewardId);
  }
}
