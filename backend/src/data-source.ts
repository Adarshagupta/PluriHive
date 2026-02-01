import 'dotenv/config';
import { DataSource } from 'typeorm';

const parseNumber = (value: string | undefined, fallback: number) => {
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const baseConfig = {
  type: 'postgres' as const,
  entities: [__dirname + '/**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/migrations/*{.ts,.js}'],
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
  extra: {
    max: parseNumber(process.env.DATABASE_POOL_MAX, 10),
    idleTimeoutMillis: parseNumber(process.env.DATABASE_IDLE_TIMEOUT_MS, 30000),
    connectionTimeoutMillis: parseNumber(
      process.env.DATABASE_CONNECT_TIMEOUT_MS,
      5000,
    ),
    keepAlive: process.env.DATABASE_KEEP_ALIVE !== 'false',
    keepAliveInitialDelayMillis: parseNumber(
      process.env.DATABASE_KEEP_ALIVE_DELAY_MS,
      10000,
    ),
  },
};

const databaseUrl = process.env.DATABASE_URL;

export default new DataSource(
  databaseUrl
    ? {
        ...baseConfig,
        url: databaseUrl,
      }
    : {
        ...baseConfig,
        host: process.env.DATABASE_HOST || 'localhost',
        port: parseInt(process.env.DATABASE_PORT || '5432', 10),
        username: process.env.DATABASE_USER || 'postgres',
        password: process.env.DATABASE_PASSWORD,
        database: process.env.DATABASE_NAME || 'plurihive',
      },
);
