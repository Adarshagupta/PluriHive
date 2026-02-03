import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Duel, DuelRule } from "./duel.entity";
import { RealtimeGateway } from "../realtime/realtime.gateway";

const DEFAULT_DUEL_HOURS = 24;

@Injectable()
export class DuelService {
  constructor(
    @InjectRepository(Duel)
    private duelRepository: Repository<Duel>,
    private realtimeGateway: RealtimeGateway,
  ) {}

  async createDuel(params: {
    challengerId: string;
    opponentId: string;
    centerLat: number;
    centerLng: number;
    radiusKm?: number;
    rule?: DuelRule;
  }) {
    if (params.challengerId === params.opponentId) {
      throw new BadRequestException("Cannot duel yourself");
    }

    const duel = this.duelRepository.create({
      challengerId: params.challengerId,
      opponentId: params.opponentId,
      centerLat: params.centerLat,
      centerLng: params.centerLng,
      radiusKm: params.radiusKm ?? 1,
      rule: params.rule ?? "territories",
      status: "pending",
    });

    const saved = await this.duelRepository.save(duel);
    this.realtimeGateway.emitDuelInvite(params.opponentId, {
      duelId: saved.id,
      challengerId: saved.challengerId,
      centerLat: saved.centerLat,
      centerLng: saved.centerLng,
      radiusKm: saved.radiusKm,
      rule: saved.rule,
    });
    return saved;
  }

  async acceptDuel(duelId: string, userId: string) {
    const duel = await this.duelRepository.findOne({ where: { id: duelId } });
    if (!duel) throw new NotFoundException("Duel not found");
    if (duel.opponentId !== userId) {
      throw new BadRequestException("Only the opponent can accept");
    }
    if (duel.status !== "pending") {
      return duel;
    }

    const now = new Date();
    const durationHours = this.parseNumber(
      process.env.DUEL_DURATION_HOURS,
      DEFAULT_DUEL_HOURS,
    );

    duel.status = "active";
    duel.startAt = now;
    duel.endAt = new Date(now.getTime() + durationHours * 3600 * 1000);
    duel.acceptedAt = now;

    const saved = await this.duelRepository.save(duel);
    this.realtimeGateway.emitDuelUpdated(duel.challengerId, saved);
    this.realtimeGateway.emitDuelUpdated(duel.opponentId, saved);
    return saved;
  }

  async declineDuel(duelId: string, userId: string) {
    const duel = await this.duelRepository.findOne({ where: { id: duelId } });
    if (!duel) throw new NotFoundException("Duel not found");
    if (duel.opponentId !== userId) {
      throw new BadRequestException("Only the opponent can decline");
    }
    if (duel.status !== "pending") {
      return duel;
    }
    duel.status = "declined";
    duel.completedAt = new Date();
    const saved = await this.duelRepository.save(duel);
    this.realtimeGateway.emitDuelUpdated(duel.challengerId, saved);
    this.realtimeGateway.emitDuelUpdated(duel.opponentId, saved);
    return saved;
  }

  async listDuels(userId: string, status?: string) {
    const query = this.duelRepository
      .createQueryBuilder("duel")
      .where("duel.challengerId = :userId OR duel.opponentId = :userId", {
        userId,
      });

    if (status) {
      query.andWhere("duel.status = :status", { status });
    }

    const duels = await query.orderBy("duel.createdAt", "DESC").getMany();
    await this.refreshExpiredDuels(duels);
    return duels;
  }

  async registerTerritoryCaptures(
    userId: string,
    coordinates: Array<{ lat: number; lng: number }>,
    occurredAt: Date = new Date(),
  ) {
    if (!coordinates || coordinates.length === 0) return;

    const duels = await this.duelRepository.find({
      where: [
        { challengerId: userId, status: "active" },
        { opponentId: userId, status: "active" },
      ],
    });

    if (duels.length === 0) return;

    const updates: Duel[] = [];

    for (const duel of duels) {
      if (!this.isActiveDuring(duel, occurredAt)) {
        continue;
      }
      if (duel.rule !== "territories") {
        continue;
      }

      const inRangeCount = coordinates.reduce((count, coord) => {
        const distanceKm = this.haversineKm(
          coord.lat,
          coord.lng,
          Number(duel.centerLat),
          Number(duel.centerLng),
        );
        return distanceKm <= Number(duel.radiusKm) ? count + 1 : count;
      }, 0);

      if (inRangeCount <= 0) continue;

      if (duel.challengerId === userId) {
        duel.challengerScore += inRangeCount;
      } else {
        duel.opponentScore += inRangeCount;
      }
      updates.push(duel);
    }

    if (updates.length === 0) return;

    const saved = await this.duelRepository.save(updates);
    for (const duel of saved) {
      this.realtimeGateway.emitDuelUpdated(duel.challengerId, duel);
      this.realtimeGateway.emitDuelUpdated(duel.opponentId, duel);
    }
  }

  private async refreshExpiredDuels(duels: Duel[]) {
    const now = new Date();
    const expired: Duel[] = [];
    for (const duel of duels) {
      if (duel.status === "pending" && duel.createdAt) {
        const pendingHours = this.parseNumber(
          process.env.DUEL_PENDING_HOURS,
          48,
        );
        if (
          duel.createdAt.getTime() + pendingHours * 3600 * 1000 <
          now.getTime()
        ) {
          duel.status = "expired";
          duel.completedAt = now;
          expired.push(duel);
        }
      }
      if (duel.status === "active" && duel.endAt && duel.endAt < now) {
        duel.status = "completed";
        duel.completedAt = now;
        expired.push(duel);
      }
    }

    if (expired.length > 0) {
      await this.duelRepository.save(expired);
    }
  }

  private isActiveDuring(duel: Duel, when: Date) {
    if (duel.status !== "active") return false;
    if (duel.startAt && when < duel.startAt) return false;
    if (duel.endAt && when > duel.endAt) return false;
    return true;
  }

  private haversineKm(lat1: number, lng1: number, lat2: number, lng2: number) {
    const R = 6371;
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private parseNumber(value: string | undefined, fallback: number) {
    if (!value) return fallback;
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
}
