import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, IsNull, MoreThan } from "typeorm";
import { MapDrop } from "./entities/map-drop.entity";
import { MapDropBoost } from "./entities/map-drop-boost.entity";
import { PoiMissionEntity } from "./entities/poi-mission.entity";
import { RewardUnlock } from "./entities/reward-unlock.entity";
import { User } from "../user/user.entity";
import { UserService } from "../user/user.service";
import { RealtimeGateway } from "../realtime/realtime.gateway";
import * as https from "https";

type RewardType = "marker" | "badge";

type RewardCatalogItem = {
  id: string;
  type: RewardType;
  cost: number;
};

type PoiItem = {
  id: string;
  name: string;
  category: string;
  lat: number;
  lng: number;
};

const REWARD_CATALOG: RewardCatalogItem[] = [
  { id: "marker_azure", type: "marker", cost: 0 },
  { id: "marker_ember", type: "marker", cost: 250 },
  { id: "marker_lush", type: "marker", cost: 450 },
  { id: "marker_pulse", type: "marker", cost: 700 },
  { id: "badge_trail", type: "badge", cost: 120 },
  { id: "badge_drop", type: "badge", cost: 300 },
  { id: "badge_conquer", type: "badge", cost: 600 },
];

@Injectable()
export class EngagementService {
  private readonly maxActiveDrops = 3;
  private readonly spawnCooldownMs = 6 * 60 * 1000;
  private readonly dropLifetimeMs = 12 * 60 * 1000;
  private readonly defaultBoostSeconds = 120;

  private readonly poiRadiusMeters = 2500;
  private readonly poiVisitRadiusMeters = 40;
  private readonly poiTargetCount = 3;
  private readonly poiRewardPoints = 150;

  constructor(
    @InjectRepository(MapDrop)
    private readonly dropRepository: Repository<MapDrop>,
    @InjectRepository(MapDropBoost)
    private readonly boostRepository: Repository<MapDropBoost>,
    @InjectRepository(PoiMissionEntity)
    private readonly poiMissionRepository: Repository<PoiMissionEntity>,
    @InjectRepository(RewardUnlock)
    private readonly rewardUnlockRepository: Repository<RewardUnlock>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly userService: UserService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

  async syncDrops(userId: string, lat: number, lng: number) {
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new BadRequestException("Invalid coordinates");
    }

    const now = new Date();
    const activeDrops = await this.dropRepository.find({
      where: {
        userId,
        pickedAt: IsNull(),
        expiresAt: MoreThan(now),
      },
      order: { createdAt: "DESC" },
    });

    const lastCreated = await this.dropRepository.findOne({
      where: { userId },
      order: { createdAt: "DESC" },
    });

    if (
      activeDrops.length < this.maxActiveDrops &&
      (!lastCreated ||
        now.getTime() - lastCreated.createdAt.getTime() > this.spawnCooldownMs)
    ) {
      const slots = this.maxActiveDrops - activeDrops.length;
      const spawnCount = Math.min(2, Math.max(1, slots));
      const newDrops = [];
      for (let i = 0; i < spawnCount; i += 1) {
        newDrops.push(
          this.dropRepository.create(
            this.buildDrop(userId, lat, lng, now),
          ),
        );
      }
      const saved = await this.dropRepository.save(newDrops);
      activeDrops.push(...saved);
    }

    const pickedDrops: MapDrop[] = [];
    for (const drop of activeDrops) {
      const distance = this.haversineDistanceMeters(
        lat,
        lng,
        Number(drop.latitude),
        Number(drop.longitude),
      );
      if (distance <= drop.radiusMeters) {
        drop.pickedAt = now;
        pickedDrops.push(drop);
      }
    }

    if (pickedDrops.length > 0) {
      await this.dropRepository.save(pickedDrops);
      await this.extendBoost(userId, pickedDrops, now);
    }

    const remainingDrops = activeDrops.filter(
      (drop) => !pickedDrops.some((picked) => picked.id === drop.id),
    );
    const boost = await this.getActiveBoost(userId, now);

    return {
      drops: remainingDrops.map((drop) => this.serializeDrop(drop)),
      pickedDrops: pickedDrops.map((drop) => this.serializeDrop(drop)),
      boost,
      serverTime: now.toISOString(),
    };
  }

  async getPoiMission(userId: string, lat: number, lng: number) {
    const mission = await this.ensurePoiMission(userId, lat, lng);
    return { mission: this.serializeMission(mission) };
  }

  async visitPoiMission(userId: string, lat: number, lng: number) {
    const mission = await this.ensurePoiMission(userId, lat, lng);

    const visited = new Set<string>(mission.visitedPoiIds || []);
    const newlyVisited: PoiItem[] = [];

    for (const poi of mission.poiList || []) {
      if (visited.has(poi.id)) continue;
      const distance = this.haversineDistanceMeters(
        lat,
        lng,
        poi.lat,
        poi.lng,
      );
      if (distance <= this.poiVisitRadiusMeters) {
        visited.add(poi.id);
        newlyVisited.push(poi);
      }
    }

    let completedNow = false;
    let rewardGrantedNow = false;

    if (newlyVisited.length > 0) {
      mission.visitedPoiIds = Array.from(visited);
    }

    const isCompleted = visited.size >= (mission.poiList?.length || 0);
    if (isCompleted && !mission.completedAt) {
      mission.completedAt = new Date();
      completedNow = true;
    }

    if (isCompleted && !mission.rewardGrantedAt) {
      mission.rewardGrantedAt = new Date();
      rewardGrantedNow = true;
      await this.userService.updateStats(
        userId,
        { points: mission.rewardPoints },
        { notify: true },
      );
    }

    if (newlyVisited.length > 0 || rewardGrantedNow) {
      await this.poiMissionRepository.save(mission);
    }

    return {
      mission: this.serializeMission(mission),
      newlyVisited,
      completedNow,
      rewardGrantedNow,
    };
  }

  async getRewardsState(userId: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException("User not found");
    }

    const unlocks = await this.rewardUnlockRepository.find({ where: { userId } });
    const unlockedIds = new Set<string>(
      unlocks.map((unlock) => unlock.rewardId),
    );
    for (const item of REWARD_CATALOG) {
      if (item.cost === 0) {
        unlockedIds.add(item.id);
      }
    }

    return {
      unlockedIds: Array.from(unlockedIds),
      selectedMarkerId: user.selectedMarkerId || null,
      selectedBadgeId: user.selectedBadgeId || null,
      spentPoints: user.rewardPointsSpent || 0,
    };
  }

  async unlockReward(userId: string, rewardId: string) {
    const reward = this.getRewardItem(rewardId);
    if (!reward) {
      throw new BadRequestException("Unknown reward");
    }

    const existing = await this.rewardUnlockRepository.findOne({
      where: { userId, rewardId },
    });
    if (existing || reward.cost === 0) {
      return this.getRewardsState(userId);
    }

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException("User not found");
    }

    const available = (user.totalPoints || 0) - (user.rewardPointsSpent || 0);
    if (available < reward.cost) {
      throw new BadRequestException("Not enough points");
    }

    const unlock = this.rewardUnlockRepository.create({
      userId,
      rewardId,
      rewardType: reward.type,
      cost: reward.cost,
    });
    await this.rewardUnlockRepository.save(unlock);

    user.rewardPointsSpent = (user.rewardPointsSpent || 0) + reward.cost;
    if (reward.type === "marker" && !user.selectedMarkerId) {
      user.selectedMarkerId = rewardId;
    }
    if (reward.type === "badge" && !user.selectedBadgeId) {
      user.selectedBadgeId = rewardId;
    }
    await this.userRepository.save(user);

    return this.getRewardsState(userId);
  }

  async selectReward(userId: string, rewardId: string) {
    const reward = this.getRewardItem(rewardId);
    if (!reward) {
      throw new BadRequestException("Unknown reward");
    }

    const isUnlocked =
      reward.cost === 0 ||
      (await this.rewardUnlockRepository.findOne({
        where: { userId, rewardId },
      }));
    if (!isUnlocked) {
      throw new BadRequestException("Reward not unlocked");
    }

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException("User not found");
    }

    if (reward.type === "marker") {
      user.selectedMarkerId = rewardId;
    } else {
      user.selectedBadgeId = rewardId;
    }
    await this.userRepository.save(user);

    return this.getRewardsState(userId);
  }

  private async ensurePoiMission(userId: string, lat: number, lng: number) {
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new BadRequestException("Invalid coordinates");
    }

    const now = new Date();
    const { start, end } = this.getDayRange(now);
    let mission = await this.poiMissionRepository
      .createQueryBuilder("mission")
      .where("mission.userId = :userId", { userId })
      .andWhere("mission.createdAt >= :start AND mission.createdAt < :end", {
        start,
        end,
      })
      .orderBy("mission.createdAt", "DESC")
      .getOne();

    if (mission) return mission;

    const pois = await this.loadPois(lat, lng);
    const selected = this.pickPois(pois, this.poiTargetCount);

    mission = this.poiMissionRepository.create({
      userId,
      poiList: selected,
      visitedPoiIds: [],
      rewardPoints: this.poiRewardPoints,
    });

    return this.poiMissionRepository.save(mission);
  }

  private serializeDrop(drop: MapDrop) {
    return {
      id: drop.id,
      lat: Number(drop.latitude),
      lng: Number(drop.longitude),
      expiresAt: drop.expiresAt?.toISOString?.() ?? drop.expiresAt,
      boostMultiplier: drop.boostMultiplier,
      boostSeconds: drop.boostSeconds,
      radiusMeters: drop.radiusMeters,
      pickedAt: drop.pickedAt ? drop.pickedAt.toISOString() : null,
    };
  }

  private serializeMission(mission: PoiMissionEntity) {
    const visited = mission.visitedPoiIds || [];
    const poiList = mission.poiList || [];
    const completed =
      !!mission.completedAt || visited.length >= poiList.length;
    const rewardGranted = !!mission.rewardGrantedAt;
    return {
      id: mission.id,
      createdAt: mission.createdAt?.toISOString?.() ?? mission.createdAt,
      pois: poiList,
      visited,
      rewardPoints: mission.rewardPoints,
      completed,
      rewardGranted,
    };
  }

  private async extendBoost(
    userId: string,
    pickedDrops: MapDrop[],
    now: Date,
  ) {
    const totalSeconds = pickedDrops.reduce(
      (sum, drop) => sum + (drop.boostSeconds || this.defaultBoostSeconds),
      0,
    );
    if (totalSeconds <= 0) return;

    let boost = await this.boostRepository.findOne({ where: { userId } });
    const baseTime =
      boost && boost.endsAt && boost.endsAt > now ? boost.endsAt : now;
    const endsAt = new Date(baseTime.getTime() + totalSeconds * 1000);

    if (!boost) {
      boost = this.boostRepository.create({
        userId,
        multiplier: pickedDrops[0]?.boostMultiplier || 2,
        endsAt,
      });
    } else {
      boost.multiplier = pickedDrops[0]?.boostMultiplier || boost.multiplier;
      boost.endsAt = endsAt;
    }
    await this.boostRepository.save(boost);
    this.realtimeGateway.emitBoostUpdated(userId, {
      boost: {
        multiplier: boost.multiplier,
        endsAt: boost.endsAt.toISOString(),
      },
      serverTime: new Date().toISOString(),
    });
  }

  private async getActiveBoost(userId: string, now: Date) {
    const boost = await this.boostRepository.findOne({ where: { userId } });
    if (!boost || !boost.endsAt || boost.endsAt <= now) {
      return null;
    }
    return {
      multiplier: boost.multiplier,
      endsAt: boost.endsAt.toISOString(),
    };
  }

  private buildDrop(userId: string, lat: number, lng: number, now: Date) {
    const bearing = Math.random() * Math.PI * 2;
    const distanceMeters = 200 + Math.random() * 1200;
    const offset = this.offsetByMeters(lat, lng, distanceMeters, bearing);
    return {
      userId,
      latitude: offset.lat,
      longitude: offset.lng,
      radiusMeters: 45,
      boostMultiplier: 2,
      boostSeconds: this.defaultBoostSeconds,
      expiresAt: new Date(now.getTime() + this.dropLifetimeMs),
      pickedAt: null,
    };
  }

  private offsetByMeters(
    lat: number,
    lng: number,
    meters: number,
    bearingRad: number,
  ) {
    const latRad = (lat * Math.PI) / 180;
    const dLat = (meters * Math.cos(bearingRad)) / 111000.0;
    const dLng = (meters * Math.sin(bearingRad)) / (111000.0 * Math.cos(latRad));
    return { lat: lat + dLat, lng: lng + dLng };
  }

  private haversineDistanceMeters(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ) {
    const R = 6371000;
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private getRewardItem(id: string) {
    return REWARD_CATALOG.find((item) => item.id === id);
  }

  private async loadPois(lat: number, lng: number) {
    const fetched = await this.fetchPoisFromOverpass(lat, lng);
    if (fetched.length > 0) return fetched;
    return this.generateFallbackPois(lat, lng);
  }

  private async fetchPoisFromOverpass(lat: number, lng: number) {
    const radius = Math.round(this.poiRadiusMeters);
    const query = `
[out:json][timeout:12];
(
  node["amenity"~"cafe|restaurant|park|gym|library|fast_food"](around:${radius},${lat},${lng});
  node["tourism"~"museum|attraction|viewpoint|gallery"](around:${radius},${lat},${lng});
  node["leisure"~"park|pitch|sports_centre"](around:${radius},${lat},${lng});
  node["historic"~"monument|memorial"](around:${radius},${lat},${lng});
);
out 25;
`;

    try {
      const data = await this.postOverpassQuery(query);
      if (!data) return [];
      const elements = Array.isArray(data?.elements) ? data.elements : [];
      const pois: PoiItem[] = [];
      for (const element of elements) {
        const tags = element?.tags || {};
        const name = tags?.name;
        if (!name) continue;
        const category =
          tags?.amenity ||
          tags?.tourism ||
          tags?.leisure ||
          tags?.historic ||
          "landmark";
        const poiLat = Number(element?.lat);
        const poiLng = Number(element?.lon);
        if (!Number.isFinite(poiLat) || !Number.isFinite(poiLng)) continue;
        pois.push({
          id: element?.id?.toString?.() || `${poiLat}_${poiLng}`,
          name,
          category,
          lat: poiLat,
          lng: poiLng,
        });
      }
      return pois;
    } catch (_) {
      return [];
    }
  }

  private async postOverpassQuery(query: string): Promise<any | null> {
    const payload = new URLSearchParams({ data: query }).toString();

    return new Promise((resolve) => {
      const req = https.request(
        "https://overpass-api.de/api/interpreter",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "Content-Length": Buffer.byteLength(payload),
          },
        },
        (res) => {
          let body = "";
          res.on("data", (chunk) => {
            body += chunk.toString();
          });
          res.on("end", () => {
            if (!res.statusCode || res.statusCode < 200 || res.statusCode >= 300) {
              resolve(null);
              return;
            }
            try {
              resolve(JSON.parse(body));
            } catch (_) {
              resolve(null);
            }
          });
        },
      );

      req.on("error", () => resolve(null));
      req.write(payload);
      req.end();
    });
  }

  private generateFallbackPois(lat: number, lng: number) {
    const labels = [
      "Local Park",
      "Neighborhood Cafe",
      "Community Library",
      "City Point",
      "Waterfront",
      "Playground",
      "Market Square",
    ];
    const pois: PoiItem[] = [];
    for (let i = 0; i < 6; i += 1) {
      const bearing = Math.random() * Math.PI * 2;
      const distanceMeters = 600 + Math.random() * 1800;
      const offset = this.offsetByMeters(lat, lng, distanceMeters, bearing);
      pois.push({
        id: `fallback_${i}`,
        name: labels[i % labels.length],
        category: "landmark",
        lat: offset.lat,
        lng: offset.lng,
      });
    }
    return pois;
  }

  private pickPois(pois: PoiItem[], count: number) {
    if (pois.length <= count) return pois;
    const shuffled = [...pois].sort(() => Math.random() - 0.5);
    return shuffled.slice(0, count);
  }

  private getDayRange(date: Date) {
    const start = new Date(
      Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
    );
    const end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 1);
    return { start, end };
  }
}
