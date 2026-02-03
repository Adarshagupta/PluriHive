import { Type } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(20)
  @Max(300)
  weight?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(80)
  @Max(250)
  height?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(10)
  @Max(120)
  age?: number;

  @IsOptional()
  @IsString()
  @IsIn(['male', 'female', 'other', 'prefer_not_say', 'unspecified'])
  gender?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(56)
  country?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  profilePicture?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1024)
  avatarModelUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1024)
  avatarImageUrl?: string;
}
