import { IsString, MaxLength } from "class-validator";

export class RewardRequestDto {
  @IsString()
  @MaxLength(64)
  rewardId: string;
}
