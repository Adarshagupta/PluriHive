import { Controller, Post, Get, Body, UseGuards, Request, Param, Query } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryService } from './territory.service';

@Controller('territories')
export class TerritoryController {
  constructor(private territoryService: TerritoryService) {}

  @Post('capture')
  @UseGuards(JwtAuthGuard)
  async captureTerritories(
    @Request() req,
    @Body() body: { 
      hexIds: string[]; 
      coordinates: { lat: number; lng: number }[];
      routePoints?: { lat: number; lng: number }[][];
    },
  ) {
    return this.territoryService.captureTerritories(
      req.user.id,
      body.hexIds,
      body.coordinates,
      body.routePoints,
    );
  }

  @Get('all')
  async getAllTerritories() {
    return this.territoryService.getAllTerritories();
  }

  @Get('user/:userId')
  async getUserTerritories(@Param('userId') userId: string) {
    return this.territoryService.getUserTerritories(userId);
  }

  @Get('nearby')
  async getNearbyTerritories(
    @Query('lat') lat: number,
    @Query('lng') lng: number,
    @Query('radius') radius?: number,
  ) {
    return this.territoryService.getNearbyTerritories(lat, lng, radius);
  }
}
