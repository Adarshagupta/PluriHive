import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { User } from "./user.entity";
import { UserController } from "./user.controller";
import { UserService } from "./user.service";
import { RedisModule } from "../redis/redis.module";
import { RealtimeModule } from "../realtime/realtime.module";

@Module({
  imports: [TypeOrmModule.forFeature([User]), RedisModule, RealtimeModule],
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
})
export class UserModule {}
