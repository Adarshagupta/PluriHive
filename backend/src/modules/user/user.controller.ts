import { Controller, Get, Put, Body, UseGuards, Request, Param } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UserService } from './user.service';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UserController {
  constructor(private userService: UserService) {}

  @Get('profile')
  async getProfile(@Request() req) {
    return this.userService.findById(req.user.id);
  }

  @Put('profile')
  async updateProfile(@Request() req, @Body() updates: any) {
    return this.userService.updateProfile(req.user.id, updates);
  }

  @Put('complete-onboarding')
  async completeOnboarding(@Request() req) {
    return this.userService.completeOnboarding(req.user.id);
  }

  // Temporary endpoint to fix existing users
  @Put('admin/fix-onboarding')
  async fixOnboardingForAll() {
    return this.userService.fixOnboardingForAllUsers();
  }

  // Specific routes MUST come before parameterized routes
  @Get('settings')
  async getSettings(@Request() req) {
    const user = await this.userService.findById(req.user.id);
    return user.settings || {};
  }

  @Put('settings')
  async updateSettings(@Request() req, @Body() settings: any) {
    return this.userService.updateSettings(req.user.id, settings);
  }

  @Get('stats')
  async getUserStats(@Request() req) {
    return this.userService.getUserStats(req.user.id);
  }

  // Parameterized route comes last
  @Get(':id')
  async getUserById(@Param('id') id: string) {
    return this.userService.findById(id);
  }
}
