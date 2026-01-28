import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
  MaxLength,
} from 'class-validator';

export class RoutePointDto {
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;

  @IsDateString()
  timestamp: string;
}

export class CreateActivityDto {
  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => RoutePointDto)
  routePoints: RoutePointDto[];

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(200000)
  distanceMeters: number;

  @IsString()
  duration: string;

  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(30)
  averageSpeed?: number;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  steps: number;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  caloriesBurned: number;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  territoriesCaptured: number;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  pointsEarned: number;

  @IsDateString()
  startTime: string;

  @IsDateString()
  endTime: string;

  @IsOptional()
  @IsString()
  routeMapSnapshot?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5000)
  @IsString({ each: true })
  capturedHexIds?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(64)
  clientId?: string;
}
