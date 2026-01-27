import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  Request,
  Param,
  Query,
} from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { TrackingService } from "./tracking.service";
import { CreateActivityDto } from "./dto/activity.dto";

@Controller("activities")
export class TrackingController {
  constructor(private trackingService: TrackingService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  async saveActivity(@Request() req, @Body() activityData: CreateActivityDto) {
    return this.trackingService.saveActivity(req.user.id, activityData);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  async getUserActivities(@Request() req, @Query("limit") limit?: number) {
    const parsedLimit = limit ? Math.min(Number(limit), 100) : 50;
    return this.trackingService.getUserActivities(req.user.id, parsedLimit);
  }

  @Get(":id")
  @UseGuards(JwtAuthGuard)
  async getActivityById(@Request() req, @Param("id") id: string) {
    return this.trackingService.getActivityByIdForUser(req.user.id, id);
  }
}
