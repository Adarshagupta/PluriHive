import { Controller, Get, Put, Body, UseGuards, Request, Param, ForbiddenException, Headers } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UserService } from './user.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UpdateSettingsDto } from './dto/update-settings.dto';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UserController {
  constructor(
    private userService: UserService,
    private configService: ConfigService,
  ) {}

  @Get('profile')
  async getProfile(@Request() req) {
    return this.userService.getProfile(req.user.id);
  }

  @Put('profile')
  async updateProfile(@Request() req, @Body() updates: UpdateProfileDto) {
    const user = await this.userService.updateProfile(req.user.id, updates);
    return this.userService.sanitizeUser(user);
  }

  @Put('complete-onboarding')
  async completeOnboarding(@Request() req) {
    return this.userService.completeOnboarding(req.user.id);
  }

  // Temporary endpoint to fix existing users
  @Put('admin/fix-onboarding')
  async fixOnboardingForAll(@Headers('x-admin-key') adminKey?: string) {
    const expectedKey = this.configService.get<string>('ADMIN_API_KEY');
    if (!expectedKey || adminKey !== expectedKey) {
      throw new ForbiddenException('Admin key required');
    }
    return this.userService.fixOnboardingForAllUsers();
  }

  // Specific routes MUST come before parameterized routes
  @Get('settings')
  async getSettings(@Request() req) {
    return this.userService.getSettings(req.user.id);
  }

  @Put('settings')
  async updateSettings(@Request() req, @Body() settings: UpdateSettingsDto) {
    return this.userService.updateSettings(req.user.id, settings);
  }

  @Get('stats')
  async getUserStats(@Request() req) {
    return this.userService.getUserStats(req.user.id);
  }

  // Parameterized route comes last
  @Get(':id')
  async getUserById(@Request() req, @Param('id') id: string) {
    if (id === req.user.id) {
      return this.userService.getProfile(id);
    }
    return this.userService.getPublicProfile(id);
  }
}
