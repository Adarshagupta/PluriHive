import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class RoutePointDto {
  @Type(() => Number)
  @Min(-90)
  @Max(90)
  lat: number;

  @Type(() => Number)
  @Min(-180)
  @Max(180)
  lng: number;
}

export class CreateRouteDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsBoolean()
  isPublic?: boolean;

  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => RoutePointDto)
  routePoints: RoutePointDto[];
}
