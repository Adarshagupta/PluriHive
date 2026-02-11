import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { json, urlencoded } from 'body-parser';
import { existsSync } from 'fs';
import * as path from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const isProd = process.env.NODE_ENV === 'production';
  const corsOrigins = (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (isProd) {
    if (!process.env.JWT_SECRET) {
      throw new Error('JWT_SECRET must be set in production');
    }

    const hasDatabaseUrl = Boolean(process.env.DATABASE_URL);
    const hasDiscreteDatabaseConfig = Boolean(
      process.env.DATABASE_HOST &&
        process.env.DATABASE_USER &&
        process.env.DATABASE_PASSWORD &&
        process.env.DATABASE_NAME,
    );

    if (!hasDatabaseUrl && !hasDiscreteDatabaseConfig) {
      throw new Error(
        'DATABASE_URL or DATABASE_HOST/DATABASE_USER/DATABASE_PASSWORD/DATABASE_NAME must be set in production',
      );
    }

    if (corsOrigins.length === 0) {
      console.warn(
        'CORS_ORIGINS is not set in production. Allowing all origins temporarily.',
      );
    }
  }

  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Enable CORS for Flutter app / web client
  app.enableCors({
    origin: isProd ? (corsOrigins.length > 0 ? corsOrigins : true) : true,
    credentials: true,
  });

  const bodyLimit = process.env.BODY_LIMIT || '10mb';
  app.use(json({ limit: bodyLimit }));
  app.use(urlencoded({ extended: true, limit: bodyLimit }));

  const staticRoot = path.join(__dirname, '..', 'public');
  if (existsSync(staticRoot)) {
    app.useStaticAssets(staticRoot, { prefix: '/static' });
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
