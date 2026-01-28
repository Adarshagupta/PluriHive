import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUserAvatarColumns1769550000000 implements MigrationInterface {
  name = 'AddUserAvatarColumns1769550000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "avatarModelUrl" text`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "avatarImageUrl" text`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "avatarImageUrl"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "avatarModelUrl"`,
    );
  }
}
