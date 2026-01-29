import { Controller, Get, Query } from '@nestjs/common';
import { AppUpdateService } from './app.update.service';

@Controller('app')
export class AppController {
  constructor(private readonly updateService: AppUpdateService) {}

  @Get('version')
  getVersion(
    @Query('platform') platform?: string,
    @Query('currentVersion') currentVersion?: string,
  ) {
    return this.updateService.getUpdateInfo(platform ?? 'android', currentVersion);
  }
}
