import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { User } from "./user.entity";
import { UserController } from "./user.controller";
import { UserService } from "./user.service";
import { RedisModule } from "../redis/redis.module";
import { RealtimeModule } from "../realtime/realtime.module";
import { EmailService } from "../notifications/email.service";
import { SeasonModule } from "../season/season.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([User]),
    RedisModule,
    RealtimeModule,
    SeasonModule,
  ],
  controllers: [UserController],
  providers: [UserService, EmailService],
  exports: [UserService],
})
export class UserModule {}
