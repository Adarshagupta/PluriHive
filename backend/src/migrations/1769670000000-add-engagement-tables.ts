import { MigrationInterface, QueryRunner } from "typeorm";

export class AddEngagementTables1769670000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "rewardPointsSpent" INT NOT NULL DEFAULT 0',
    );
    await queryRunner.query(
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "selectedMarkerId" VARCHAR(64)',
    );
    await queryRunner.query(
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "selectedBadgeId" VARCHAR(64)',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "map_drops" (
        "id" uuid PRIMARY KEY,
        "userId" VARCHAR(36) NOT NULL,
        "latitude" decimal(10,7) NOT NULL,
        "longitude" decimal(10,7) NOT NULL,
        "radiusMeters" INT NOT NULL DEFAULT 45,
        "boostMultiplier" INT NOT NULL DEFAULT 2,
        "boostSeconds" INT NOT NULL DEFAULT 120,
        "expiresAt" TIMESTAMP NOT NULL,
        "pickedAt" TIMESTAMP NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "FK_map_drops_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_map_drops_user" ON "map_drops" ("userId")',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_map_drops_expires" ON "map_drops" ("expiresAt")',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "map_drop_boosts" (
        "id" uuid PRIMARY KEY,
        "userId" VARCHAR(36) NOT NULL UNIQUE,
        "multiplier" INT NOT NULL DEFAULT 2,
        "endsAt" TIMESTAMP NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "FK_map_drop_boosts_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "poi_missions" (
        "id" uuid PRIMARY KEY,
        "userId" VARCHAR(36) NOT NULL,
        "poiList" jsonb NOT NULL,
        "visitedPoiIds" jsonb NOT NULL DEFAULT '[]',
        "rewardPoints" INT NOT NULL DEFAULT 150,
        "completedAt" TIMESTAMP NULL,
        "rewardGrantedAt" TIMESTAMP NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "FK_poi_missions_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_poi_missions_user" ON "poi_missions" ("userId")',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_poi_missions_created" ON "poi_missions" ("createdAt")',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "reward_unlocks" (
        "id" uuid PRIMARY KEY,
        "userId" VARCHAR(36) NOT NULL,
        "rewardId" VARCHAR(64) NOT NULL,
        "rewardType" VARCHAR(20) NOT NULL,
        "cost" INT NOT NULL DEFAULT 0,
        "unlockedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "FK_reward_unlocks_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      'CREATE UNIQUE INDEX IF NOT EXISTS "IDX_reward_unlocks_user_reward" ON "reward_unlocks" ("userId", "rewardId")',
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'DROP INDEX IF EXISTS "IDX_reward_unlocks_user_reward"',
    );
    await queryRunner.query('DROP TABLE IF EXISTS "reward_unlocks"');

    await queryRunner.query(
      'DROP INDEX IF EXISTS "IDX_poi_missions_created"',
    );
    await queryRunner.query('DROP INDEX IF EXISTS "IDX_poi_missions_user"');
    await queryRunner.query('DROP TABLE IF EXISTS "poi_missions"');

    await queryRunner.query('DROP TABLE IF EXISTS "map_drop_boosts"');

    await queryRunner.query('DROP INDEX IF EXISTS "IDX_map_drops_expires"');
    await queryRunner.query('DROP INDEX IF EXISTS "IDX_map_drops_user"');
    await queryRunner.query('DROP TABLE IF EXISTS "map_drops"');

    await queryRunner.query(
      'ALTER TABLE "users" DROP COLUMN IF EXISTS "selectedBadgeId"',
    );
    await queryRunner.query(
      'ALTER TABLE "users" DROP COLUMN IF EXISTS "selectedMarkerId"',
    );
    await queryRunner.query(
      'ALTER TABLE "users" DROP COLUMN IF EXISTS "rewardPointsSpent"',
    );
  }
}
