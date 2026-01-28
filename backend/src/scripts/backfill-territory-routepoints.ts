import dataSource from '../data-source';
import { Repository } from 'typeorm';
import { Territory } from '../modules/territory/territory.entity';
import { Activity } from '../modules/tracking/activity.entity';

const MIN_ROUTE_POINTS = 3;
const SAVE_BATCH_SIZE = 200;

type ActivityRoutePoint = {
  latitude: number | string;
  longitude: number | string;
};

function toTerritoryRoutePoints(points: ActivityRoutePoint[]) {
  return points
    .map((point) => {
      const lat = Number(point.latitude);
      const lng = Number(point.longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
        return null;
      }
      return { lat, lng };
    })
    .filter(
      (point): point is { lat: number; lng: number } => point !== null,
    );
}

async function saveInBatches(
  repo: Repository<Territory>,
  items: Territory[],
) {
  for (let i = 0; i < items.length; i += SAVE_BATCH_SIZE) {
    const batch = items.slice(i, i + SAVE_BATCH_SIZE);
    await repo.save(batch);
  }
}

async function main() {
  await dataSource.initialize();
  const territoryRepo = dataSource.getRepository(Territory);
  const activityRepo = dataSource.getRepository(Activity);

  const territories = await territoryRepo
    .createQueryBuilder('territory')
    .where('COALESCE(jsonb_array_length(territory.routePoints), 0) < :min', {
      min: MIN_ROUTE_POINTS,
    })
    .getMany();

  console.log(
    `[backfill] Territories missing routePoints: ${territories.length}`,
  );

  if (territories.length === 0) {
    return;
  }

  const territoriesByOwner = new Map<string, Territory[]>();
  for (const territory of territories) {
    const list = territoriesByOwner.get(territory.ownerId) ?? [];
    list.push(territory);
    territoriesByOwner.set(territory.ownerId, list);
  }

  let updated = 0;
  let unmatched = 0;
  let skipped = 0;

  for (const [ownerId, ownerTerritories] of territoriesByOwner.entries()) {
    const activities = await activityRepo
      .createQueryBuilder('activity')
      .where('activity.userId = :userId', { userId: ownerId })
      .andWhere('activity.capturedHexIds IS NOT NULL')
      .andWhere('jsonb_array_length(activity.routePoints) >= :min', {
        min: MIN_ROUTE_POINTS,
      })
      .orderBy('activity.endTime', 'DESC')
      .getMany();

    if (activities.length === 0) {
      unmatched += ownerTerritories.length;
      continue;
    }

    const hexToActivity = new Map<string, Activity>();
    for (const activity of activities) {
      const capturedHexIds = Array.isArray(activity.capturedHexIds)
        ? activity.capturedHexIds
        : [];
      for (const hexId of capturedHexIds) {
        if (!hexToActivity.has(hexId)) {
          hexToActivity.set(hexId, activity);
        }
      }
    }

    const toSave: Territory[] = [];
    for (const territory of ownerTerritories) {
      const match = hexToActivity.get(territory.hexId);
      if (!match) {
        unmatched++;
        continue;
      }

      const routePoints = toTerritoryRoutePoints(match.routePoints ?? []);
      if (routePoints.length < MIN_ROUTE_POINTS) {
        skipped++;
        continue;
      }

      territory.routePoints = routePoints;
      if (!territory.lastCaptureSessionId && match.clientId) {
        territory.lastCaptureSessionId = match.clientId;
      }
      toSave.push(territory);
      updated++;
    }

    if (toSave.length > 0) {
      await saveInBatches(territoryRepo, toSave);
    }
  }

  console.log(
    `[backfill] Updated: ${updated}, unmatched: ${unmatched}, skipped: ${skipped}`,
  );
}

main()
  .catch((error) => {
    console.error('[backfill] Failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  });
