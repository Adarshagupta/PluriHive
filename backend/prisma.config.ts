import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';
import path from 'node:path';

export default defineConfig({
  schema: path.join('prisma', 'schema.prisma'),
  migrations: {
    path: path.join('prisma', 'migrations'),
  },
  engine: 'classic',
  datasource: {
    url: env('DATABASE_URL'),
  },
});
