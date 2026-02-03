import { MigrationInterface, QueryRunner } from "typeorm";

export class AddCompetitiveFeatures1769990000000
  implements MigrationInterface
{
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "city" VARCHAR(80)',
    );
    await queryRunner.query(
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "cityNormalized" VARCHAR(80)',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_users_cityNormalized" ON "users" ("cityNormalized")',
    );

    await queryRunner.query(
      'ALTER TABLE "territories" ADD COLUMN IF NOT EXISTS "strength" INT DEFAULT 100',
    );
    await queryRunner.query(
      'ALTER TABLE "territories" ADD COLUMN IF NOT EXISTS "lastDefendedAt" TIMESTAMP NULL',
    );
    await queryRunner.query(
      'ALTER TABLE "territories" ADD COLUMN IF NOT EXISTS "decayedAt" TIMESTAMP NULL',
    );
    await queryRunner.query(
      'ALTER TABLE "territories" ALTER COLUMN "ownerId" DROP NOT NULL',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "season_stats" (
        "id" uuid PRIMARY KEY,
        "userId" VARCHAR(36) NOT NULL,
        "seasonId" VARCHAR(32) NOT NULL,
        "points" INT NOT NULL DEFAULT 0,
        "distanceKm" decimal(10,2) NOT NULL DEFAULT 0,
        "steps" INT NOT NULL DEFAULT 0,
        "territories" INT NOT NULL DEFAULT 0,
        "workouts" INT NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "FK_season_stats_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      'CREATE UNIQUE INDEX IF NOT EXISTS "IDX_season_stats_user_season" ON "season_stats" ("userId", "seasonId")',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "factions" (
        "id" uuid PRIMARY KEY,
        "key" VARCHAR(32) NOT NULL,
        "name" VARCHAR(64) NOT NULL,
        "color" VARCHAR(16) NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      'CREATE UNIQUE INDEX IF NOT EXISTS "IDX_factions_key" ON "factions" ("key")',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "faction_memberships" (
        "id" uuid PRIMARY KEY,
        "userId" VARCHAR(36) NOT NULL,
        "factionId" uuid NOT NULL,
        "seasonId" VARCHAR(32) NOT NULL,
        "joinedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "FK_faction_memberships_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_faction_memberships_faction" FOREIGN KEY ("factionId") REFERENCES "factions"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      'CREATE UNIQUE INDEX IF NOT EXISTS "IDX_faction_memberships_user_season" ON "faction_memberships" ("userId", "seasonId")',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_faction_memberships_faction" ON "faction_memberships" ("factionId")',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "missions" (
        "id" uuid PRIMARY KEY,
        "userId" VARCHAR(36) NOT NULL,
        "period" VARCHAR(16) NOT NULL,
        "type" VARCHAR(32) NOT NULL,
        "goal" INT NOT NULL DEFAULT 0,
        "progress" INT NOT NULL DEFAULT 0,
        "rewardPoints" INT NOT NULL DEFAULT 0,
        "periodStart" DATE NOT NULL,
        "completedAt" TIMESTAMP NULL,
        "rewardGrantedAt" TIMESTAMP NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "FK_missions_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      'CREATE UNIQUE INDEX IF NOT EXISTS "IDX_missions_unique" ON "missions" ("userId", "period", "type", "periodStart")',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "duels" (
        "id" uuid PRIMARY KEY,
        "challengerId" VARCHAR(36) NOT NULL,
        "opponentId" VARCHAR(36) NOT NULL,
        "status" VARCHAR(16) NOT NULL DEFAULT 'pending',
        "rule" VARCHAR(16) NOT NULL DEFAULT 'territories',
        "centerLat" decimal(10,7) NOT NULL,
        "centerLng" decimal(10,7) NOT NULL,
        "radiusKm" decimal(6,2) NOT NULL DEFAULT 1,
        "startAt" TIMESTAMP NULL,
        "endAt" TIMESTAMP NULL,
        "challengerScore" INT NOT NULL DEFAULT 0,
        "opponentScore" INT NOT NULL DEFAULT 0,
        "acceptedAt" TIMESTAMP NULL,
        "completedAt" TIMESTAMP NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_duels_challenger" ON "duels" ("challengerId")',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_duels_opponent" ON "duels" ("opponentId")',
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP INDEX IF EXISTS "IDX_duels_opponent"');
    await queryRunner.query('DROP INDEX IF EXISTS "IDX_duels_challenger"');
    await queryRunner.query('DROP TABLE IF EXISTS "duels"');

    await queryRunner.query('DROP INDEX IF EXISTS "IDX_missions_unique"');
    await queryRunner.query('DROP TABLE IF EXISTS "missions"');

    await queryRunner.query(
      'DROP INDEX IF EXISTS "IDX_faction_memberships_faction"',
    );
    await queryRunner.query(
      'DROP INDEX IF EXISTS "IDX_faction_memberships_user_season"',
    );
    await queryRunner.query('DROP TABLE IF EXISTS "faction_memberships"');

    await queryRunner.query('DROP INDEX IF EXISTS "IDX_factions_key"');
    await queryRunner.query('DROP TABLE IF EXISTS "factions"');

    await queryRunner.query(
      'DROP INDEX IF EXISTS "IDX_season_stats_user_season"',
    );
    await queryRunner.query('DROP TABLE IF EXISTS "season_stats"');

    await queryRunner.query(
      'ALTER TABLE "territories" ALTER COLUMN "ownerId" SET NOT NULL',
    );
    await queryRunner.query(
      'ALTER TABLE "territories" DROP COLUMN IF EXISTS "decayedAt"',
    );
    await queryRunner.query(
      'ALTER TABLE "territories" DROP COLUMN IF EXISTS "lastDefendedAt"',
    );
    await queryRunner.query(
      'ALTER TABLE "territories" DROP COLUMN IF EXISTS "strength"',
    );

    await queryRunner.query(
      'DROP INDEX IF EXISTS "IDX_users_cityNormalized"',
    );
    await queryRunner.query(
      'ALTER TABLE "users" DROP COLUMN IF EXISTS "cityNormalized"',
    );
    await queryRunner.query('ALTER TABLE "users" DROP COLUMN IF EXISTS "city"');
  }
}
