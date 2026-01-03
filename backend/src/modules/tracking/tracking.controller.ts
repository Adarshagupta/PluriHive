import { Controller, Post, Get, Body, UseGuards, Request, Param, Query } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TrackingService } from './tracking.service';

@Controller('activities')
export class TrackingController {
  constructor(private trackingService: TrackingService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  async saveActivity(@Request() req, @Body() activityData: any) {
    return this.trackingService.saveActivity(req.user.id, activityData);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  async getUserActivities(@Request() req, @Query('limit') limit?: number) {
    return this.trackingService.getUserActivities(req.user.id, limit);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async getActivityById(@Param('id') id: string) {
    return this.trackingService.getActivityById(id);
  }
}
