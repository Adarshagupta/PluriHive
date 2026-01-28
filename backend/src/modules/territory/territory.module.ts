import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Territory } from './territory.entity';
import { TerritoryController } from './territory.controller';
import { TerritoryService } from './territory.service';
import { UserModule } from '../user/user.module';
import { RedisModule } from '../redis/redis.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Territory]),
    UserModule,
    RedisModule,
  ],
  controllers: [TerritoryController],
  providers: [TerritoryService],
  exports: [TerritoryService],
})
export class TerritoryModule {}
