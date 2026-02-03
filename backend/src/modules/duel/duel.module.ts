import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { Duel } from "./duel.entity";
import { DuelService } from "./duel.service";
import { DuelController } from "./duel.controller";
import { RealtimeModule } from "../realtime/realtime.module";

@Module({
  imports: [TypeOrmModule.forFeature([Duel]), RealtimeModule],
  providers: [DuelService],
  controllers: [DuelController],
  exports: [DuelService],
})
export class DuelModule {}
