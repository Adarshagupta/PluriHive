import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Faction } from "./faction.entity";
import { FactionMembership } from "./faction-membership.entity";
import { SeasonService } from "../season/season.service";

const DEFAULT_FACTIONS = [
  { key: "aurum", name: "Aurum", color: "#F6C453" },
  { key: "verdant", name: "Verdant", color: "#3BB273" },
  { key: "ember", name: "Ember", color: "#F97360" },
];

@Injectable()
export class FactionService {
  constructor(
    @InjectRepository(Faction)
    private factionRepository: Repository<Faction>,
    @InjectRepository(FactionMembership)
    private membershipRepository: Repository<FactionMembership>,
    private seasonService: SeasonService,
  ) {}

  async getFactions(): Promise<Faction[]> {
    await this.ensureSeeded();
    return this.factionRepository.find({ order: { name: "ASC" } });
  }

  async getMembership(userId: string) {
    const seasonId = this.seasonService.getCurrentSeasonId();
    const membership = await this.membershipRepository.findOne({
      where: { userId, seasonId },
      relations: ["faction"],
    });
    return membership ?? null;
  }

  async joinFaction(userId: string, factionId: string) {
    await this.ensureSeeded();
    const seasonId = this.seasonService.getCurrentSeasonId();
    const faction = await this.factionRepository.findOne({
      where: { id: factionId },
    });
    if (!faction) {
      throw new NotFoundException("Faction not found");
    }

    let membership = await this.membershipRepository.findOne({
      where: { userId, seasonId },
    });

    if (!membership) {
      membership = this.membershipRepository.create({
        userId,
        factionId,
        seasonId,
      });
    } else {
      if (membership.factionId === factionId) {
        return this.getMembership(userId);
      }
      membership.factionId = factionId;
    }

    await this.membershipRepository.save(membership);
    return this.getMembership(userId);
  }

  private async ensureSeeded() {
    const count = await this.factionRepository.count();
    if (count > 0) return;

    const toInsert = DEFAULT_FACTIONS.map((item) =>
      this.factionRepository.create(item),
    );
    await this.factionRepository.save(toInsert);
  }
}
