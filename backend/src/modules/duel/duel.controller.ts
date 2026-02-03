import { Body, Controller, Get, Param, Post, Query, Request, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { DuelService } from "./duel.service";

@Controller("duels")
@UseGuards(JwtAuthGuard)
export class DuelController {
  constructor(private duelService: DuelService) {}

  @Get()
  async listDuels(@Request() req, @Query("status") status?: string) {
    return this.duelService.listDuels(req.user.id, status);
  }

  @Post()
  async createDuel(
    @Request() req,
    @Body()
    body: {
      opponentId: string;
      centerLat: number;
      centerLng: number;
      radiusKm?: number;
      rule?: "territories" | "distance" | "steps" | "points";
    },
  ) {
    return this.duelService.createDuel({
      challengerId: req.user.id,
      opponentId: body.opponentId,
      centerLat: body.centerLat,
      centerLng: body.centerLng,
      radiusKm: body.radiusKm,
      rule: body.rule,
    });
  }

  @Post(":id/accept")
  async acceptDuel(@Request() req, @Param("id") id: string) {
    return this.duelService.acceptDuel(id, req.user.id);
  }

  @Post(":id/decline")
  async declineDuel(@Request() req, @Param("id") id: string) {
    return this.duelService.declineDuel(id, req.user.id);
  }
}
