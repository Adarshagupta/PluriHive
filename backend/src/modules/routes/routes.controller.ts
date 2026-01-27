import { Body, Controller, Get, Param, Post, Query, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RoutesService } from './routes.service';
import { CreateRouteDto } from './dto/create-route.dto';

@Controller('routes')
@UseGuards(JwtAuthGuard)
export class RoutesController {
  constructor(private routesService: RoutesService) {}

  @Post()
  async createRoute(@Request() req, @Body() dto: CreateRouteDto) {
    return this.routesService.createRoute(req.user.id, dto);
  }

  @Get('my')
  async getMyRoutes(@Request() req) {
    return this.routesService.getUserRoutes(req.user.id);
  }

  @Get('popular')
  async getPopularRoutes(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLat = parseFloat(lat);
    const parsedLng = parseFloat(lng);
    const parsedRadius = radiusKm ? parseFloat(radiusKm) : 5;
    const parsedLimit = limit ? Math.min(parseInt(limit, 10), 25) : 10;
    return this.routesService.getPopularRoutesNear(
      parsedLat,
      parsedLng,
      parsedRadius,
      parsedLimit,
    );
  }

  @Get(':id')
  async getRouteById(@Request() req, @Param('id') id: string) {
    return this.routesService.getRouteById(req.user.id, id);
  }

  @Post(':id/use')
  async recordRouteUsage(@Param('id') id: string) {
    return this.routesService.recordRouteUse(id);
  }
}
