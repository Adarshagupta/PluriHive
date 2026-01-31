import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddTerritoryName1769900000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "territories" ADD COLUMN IF NOT EXISTS "name" VARCHAR(40)',
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "territories" DROP COLUMN IF EXISTS "name"',
    );
  }
}
