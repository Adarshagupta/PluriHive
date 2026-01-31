import { IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateTerritoryNameDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  name?: string;
}
