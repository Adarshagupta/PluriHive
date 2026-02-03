import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { SeasonService } from "./season.service";
import { SeasonStats } from "./season-stats.entity";
import { RedisModule } from "../redis/redis.module";

@Module({
  imports: [TypeOrmModule.forFeature([SeasonStats]), RedisModule],
  providers: [SeasonService],
  exports: [SeasonService, TypeOrmModule],
})
export class SeasonModule {}
