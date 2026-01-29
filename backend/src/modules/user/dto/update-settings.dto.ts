import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateSettingsDto {
  @IsOptional()
  @IsIn(['metric', 'imperial'])
  units?: 'metric' | 'imperial';

  @IsOptional()
  @IsIn(['high', 'medium', 'low'])
  gpsAccuracy?: 'high' | 'medium' | 'low';

  @IsOptional()
  @IsBoolean()
  hapticFeedback?: boolean;

  @IsOptional()
  @IsBoolean()
  pushNotifications?: boolean;

  @IsOptional()
  @IsBoolean()
  emailNotifications?: boolean;

  @IsOptional()
  @IsBoolean()
  streakReminders?: boolean;

  @IsOptional()
  @IsBoolean()
  smartReminders?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  smartReminderTime?: string;

  @IsOptional()
  @IsBoolean()
  leaderboardUpdates?: boolean;

  @IsOptional()
  @IsBoolean()
  territoryAlerts?: boolean;

  @IsOptional()
  @IsBoolean()
  achievementAlerts?: boolean;

  @IsOptional()
  @IsBoolean()
  darkMode?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  language?: string;
}
