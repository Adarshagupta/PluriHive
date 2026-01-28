import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { json, urlencoded } from 'body-parser';
import { existsSync } from 'fs';
import * as path from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  
  const isProd = process.env.NODE_ENV === 'production';
  const corsOrigins = (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (isProd && corsOrigins.length === 0) {
    throw new Error('CORS_ORIGINS must be set in production');
  }

  // Enable CORS for Flutter app / web client
  app.enableCors({
    origin: isProd ? corsOrigins : true,
    credentials: true,
  });

  const bodyLimit = process.env.BODY_LIMIT || '10mb';
  app.use(json({ limit: bodyLimit }));
  app.use(urlencoded({ extended: true, limit: bodyLimit }));

  const staticRoot = path.join(__dirname, '..', 'public');
  if (existsSync(staticRoot)) {
    app.useStaticAssets(staticRoot, { prefix: '/static' });
  }

  if (isProd) {
    const requiredEnv = ['JWT_SECRET', 'DATABASE_PASSWORD'];
    for (const key of requiredEnv) {
      if (!process.env[key]) {
        throw new Error(`${key} must be set in production`);
      }
    }
  }
  
  // Global validation pipe
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));

  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0'); // Bind to 0.0.0.0 for cloud deployment
  
  console.log(`🚀 PluriHive Backend running on: http://0.0.0.0:${port}`);
  console.log(`📡 WebSocket server ready for real-time updates`);
}

bootstrap();
