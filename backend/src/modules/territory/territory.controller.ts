import { Controller, Post, Get, Body, UseGuards, Request, Param, Query } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryService } from './territory.service';
import { CaptureTerritoryDto } from './dto/capture-territory.dto';

@Controller('territories')
export class TerritoryController {
  constructor(private territoryService: TerritoryService) {}

  @Post('capture')
  @UseGuards(JwtAuthGuard)
  async captureTerritories(
    @Request() req,
    @Body() body: CaptureTerritoryDto,
  ) {
    return this.territoryService.captureTerritories(
      req.user.id,
      body.hexIds,
      body.coordinates,
      body.routePoints,
    );
  }

  @Get('all')
  async getAllTerritories(@Query('limit') limit?: number) {
    const parsedLimit = limit ? Math.min(Number(limit), 500) : 500;
    return this.territoryService.getAllTerritories(parsedLimit);
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

  @Get('boss')
  async getBossTerritories(@Query('limit') limit?: number) {
    const parsedLimit = limit ? Math.min(Number(limit), 10) : 3;
    return this.territoryService.getBossTerritories(parsedLimit);
  }
}
