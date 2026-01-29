import { MigrationInterface, QueryRunner } from "typeorm";

export class AddLeaderboardSocial1769679000000 implements MigrationInterface {
  name = "AddLeaderboardSocial1769679000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastLatitude" decimal(10,7)',
    );
    await queryRunner.query(
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastLongitude" decimal(10,7)',
    );
    await queryRunner.query(
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastLocationAt" TIMESTAMP',
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "friendships" (
        "id" uuid PRIMARY KEY,
        "userId" VARCHAR(36) NOT NULL,
        "friendId" VARCHAR(36) NOT NULL,
        "status" VARCHAR(16) NOT NULL DEFAULT 'pending',
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "FK_friendships_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_friendships_friend" FOREIGN KEY ("friendId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      'CREATE UNIQUE INDEX IF NOT EXISTS "IDX_friendships_pair" ON "friendships" ("userId", "friendId")',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_friendships_user" ON "friendships" ("userId")',
    );
    await queryRunner.query(
      'CREATE INDEX IF NOT EXISTS "IDX_friendships_friend" ON "friendships" ("friendId")',
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP INDEX IF EXISTS "IDX_friendships_friend"');
    await queryRunner.query('DROP INDEX IF EXISTS "IDX_friendships_user"');
    await queryRunner.query('DROP INDEX IF EXISTS "IDX_friendships_pair"');
    await queryRunner.query('DROP TABLE IF EXISTS "friendships"');

    await queryRunner.query(
      'ALTER TABLE "users" DROP COLUMN IF EXISTS "lastLocationAt"',
    );
    await queryRunner.query(
      'ALTER TABLE "users" DROP COLUMN IF EXISTS "lastLongitude"',
    );
    await queryRunner.query(
      'ALTER TABLE "users" DROP COLUMN IF EXISTS "lastLatitude"',
    );
  }
}
