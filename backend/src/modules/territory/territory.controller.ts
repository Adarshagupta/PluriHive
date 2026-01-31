import {
  Controller,
  Post,
  Get,
  Patch,
  Body,
  UseGuards,
  Request,
  Param,
  Query,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryService } from './territory.service';
import { CaptureTerritoryDto } from './dto/capture-territory.dto';
import { UpdateTerritoryNameDto } from './dto/update-territory-name.dto';

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
      body.captureSessionId,
    );
  }

  @Get('all')
  async getAllTerritories(
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    const parsedLimit = limit ? Math.min(Number(limit), 5000) : 5000;
    const parsedOffset = offset ? Math.max(Number(offset), 0) : 0;
    return this.territoryService.getAllTerritories(parsedLimit, parsedOffset);
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

  @Patch(':id/name')
  @UseGuards(JwtAuthGuard)
  async updateTerritoryName(
    @Request() req,
    @Param('id') id: string,
    @Body() body: UpdateTerritoryNameDto,
  ) {
    return this.territoryService.updateTerritoryName(
      req.user.id,
      id,
      body.name,
    );
  }
}
