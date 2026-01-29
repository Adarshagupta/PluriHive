import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppUpdateService } from './app.update.service';

@Module({
  imports: [ConfigModule],
  controllers: [AppController],
  providers: [AppUpdateService],
})
export class AppModule {}
