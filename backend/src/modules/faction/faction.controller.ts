import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  Request,
  UseGuards,
} from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { FactionService } from "./faction.service";

@Controller("factions")
export class FactionController {
  constructor(private factionService: FactionService) {}

  @Get()
  async listFactions() {
    return this.factionService.getFactions();
  }

  @UseGuards(JwtAuthGuard)
  @Get("me")
  async getMyFaction(@Request() req) {
    return this.factionService.getMembership(req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Post("join")
  async joinFaction(@Request() req, @Body() body: { factionId: string }) {
    if (!body?.factionId) {
      throw new BadRequestException("factionId is required");
    }
    return this.factionService.joinFaction(req.user.id, body.factionId);
  }
}
