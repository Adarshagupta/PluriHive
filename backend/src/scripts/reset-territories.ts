import dataSource from '../data-source';
import { Territory } from '../modules/territory/territory.entity';
import { Activity } from '../modules/tracking/activity.entity';

async function main() {
  await dataSource.initialize();

  const territoryRepo = dataSource.getRepository(Territory);
  const activityRepo = dataSource.getRepository(Activity);

  const territoryResult = await territoryRepo
    .createQueryBuilder()
    .delete()
    .from(Territory)
    .execute();

  const activityResult = await activityRepo
    .createQueryBuilder()
    .update(Activity)
    .set({
      capturedHexIds: null,
      capturedAreaSqMeters: null,
      territoriesCaptured: 0,
    })
    .execute();

  console.log(
    `[reset] Territories deleted: ${territoryResult.affected ?? 0}`,
  );
  console.log(
    `[reset] Activities cleared: ${activityResult.affected ?? 0}`,
  );
}

main()
  .catch((error) => {
    console.error('[reset] Failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  });
