import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { SeasonStats } from "./season-stats.entity";
import { RedisService } from "../redis/redis.service";

const DEFAULT_SEASON_WEEKS = 6;
const DEFAULT_EPOCH = "2024-01-01";

@Injectable()
export class SeasonService {
  private readonly seasonWeeks: number;
  private readonly epoch: Date;
  private readonly seasonKey = "season:current";
  private inMemorySeasonId?: string;

  constructor(
    @InjectRepository(SeasonStats)
    private seasonStatsRepository: Repository<SeasonStats>,
    private redisService: RedisService,
  ) {
    this.seasonWeeks = this.parseNumber(
      process.env.SEASON_LENGTH_WEEKS,
      DEFAULT_SEASON_WEEKS,
    );
    this.epoch = this.parseEpoch(process.env.SEASON_EPOCH ?? DEFAULT_EPOCH);
  }

  getCurrentSeason(now: Date = new Date()) {
    const lengthMs = this.seasonWeeks * 7 * 24 * 60 * 60 * 1000;
    const diff = now.getTime() - this.epoch.getTime();
    const index = diff >= 0 ? Math.floor(diff / lengthMs) : 0;
    const start = new Date(this.epoch.getTime() + index * lengthMs);
    const end = new Date(start.getTime() + lengthMs);
    return {
      id: `s${index}`,
      index,
      start,
      end,
      lengthWeeks: this.seasonWeeks,
    };
  }

  getSeasonIdForDate(date: Date) {
    return this.getCurrentSeason(date).id;
  }

  getCurrentSeasonId() {
    return this.getCurrentSeason().id;
  }

  async ensureSeasonRotation(): Promise<{ seasonId: string; rotated: boolean }> {
    const current = this.getCurrentSeasonId();
    let previous: string | null = null;

    if (this.redisService.isEnabled()) {
      previous = await this.redisService.get(this.seasonKey);
    } else if (this.inMemorySeasonId) {
      previous = this.inMemorySeasonId;
    }

    if (previous !== current) {
      if (this.redisService.isEnabled()) {
        await this.redisService.set(this.seasonKey, current);
      } else {
        this.inMemorySeasonId = current;
      }
      return { seasonId: current, rotated: true };
    }

    return { seasonId: current, rotated: false };
  }

  async updateSeasonStats(
    userId: string,
    stats: {
      distanceKm?: number;
      steps?: number;
      territories?: number;
      points?: number;
      workouts?: number;
    },
    occurredAt?: Date,
  ): Promise<SeasonStats> {
    const seasonId = this.getSeasonIdForDate(occurredAt ?? new Date());

    let seasonStats = await this.seasonStatsRepository.findOne({
      where: { userId, seasonId },
    });

    if (!seasonStats) {
      seasonStats = this.seasonStatsRepository.create({
        userId,
        seasonId,
      });
    }

    if (stats.distanceKm) {
      seasonStats.distanceKm =
        Number(seasonStats.distanceKm) + stats.distanceKm;
    }
    if (stats.steps) seasonStats.steps += stats.steps;
    if (stats.territories) seasonStats.territories += stats.territories;
    if (stats.points) seasonStats.points += stats.points;
    if (stats.workouts) seasonStats.workouts += stats.workouts;

    return this.seasonStatsRepository.save(seasonStats);
  }

  private parseEpoch(value: string) {
    const cleaned = value.trim();
    const parts = cleaned.split("-");
    if (parts.length === 3) {
      const year = parseInt(parts[0], 10);
      const month = parseInt(parts[1], 10);
      const day = parseInt(parts[2], 10);
      if (
        Number.isFinite(year) &&
        Number.isFinite(month) &&
        Number.isFinite(day)
      ) {
        return new Date(Date.UTC(year, month - 1, day));
      }
    }
    return new Date(Date.UTC(2024, 0, 1));
  }

  private parseNumber(value: string | undefined, fallback: number) {
    if (!value) return fallback;
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
}
