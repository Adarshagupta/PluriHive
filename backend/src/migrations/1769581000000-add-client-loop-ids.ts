import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddClientLoopIds1769581000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "activities" ADD COLUMN IF NOT EXISTS "clientId" VARCHAR(64)',
    );
    await queryRunner.query(
      'CREATE UNIQUE INDEX IF NOT EXISTS "IDX_activities_user_client" ON "activities" ("userId", "clientId")',
    );
    await queryRunner.query(
      'ALTER TABLE "territories" ADD COLUMN IF NOT EXISTS "lastCaptureSessionId" VARCHAR(64)',
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "territories" DROP COLUMN IF EXISTS "lastCaptureSessionId"',
    );
    await queryRunner.query(
      'DROP INDEX IF EXISTS "IDX_activities_user_client"',
    );
    await queryRunner.query(
      'ALTER TABLE "activities" DROP COLUMN IF EXISTS "clientId"',
    );
  }
}
