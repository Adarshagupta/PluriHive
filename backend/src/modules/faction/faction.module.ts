import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { Faction } from "./faction.entity";
import { FactionMembership } from "./faction-membership.entity";
import { FactionService } from "./faction.service";
import { FactionController } from "./faction.controller";
import { SeasonModule } from "../season/season.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([Faction, FactionMembership]),
    SeasonModule,
  ],
  controllers: [FactionController],
  providers: [FactionService],
  exports: [FactionService],
})
export class FactionModule {}
