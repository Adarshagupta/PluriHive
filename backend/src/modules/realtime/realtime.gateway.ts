import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from "@nestjs/websockets";
import { Server, Socket } from "socket.io";
import { JwtService } from "@nestjs/jwt";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { randomUUID } from "crypto";
import { Territory } from "../territory/territory.entity";

@WebSocketGateway({
  cors: {
    origin: "*",
  },
  perMessageDeflate: true,
})
export class RealtimeGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private connectedUsers = new Map<string, string>(); // socketId -> userId
  private readonly territoryGlobalRoom = "territory:global";
  private readonly territoryFlushDelayMs = 120;
  private readonly territoryEventBufferSize = 500;
  private readonly territorySnapshotMinRadiusKm = 0.2;
  private readonly territorySnapshotMaxRadiusKm = 75;
  private readonly territorySnapshotBatchMin = 150;
  private readonly territorySnapshotBatchMax = 1000;
  private readonly territorySnapshotDelayMs = 80;
  private readonly territorySnapshotRadiusDelayMs = 160;
  private readonly territorySnapshotHardLimit = 8000;
  private lastSnapshotErrorAt?: number;
  private territoryPendingByHex = new Map<string, any>();
  private territoryFlushTimer?: NodeJS.Timeout;
  private territoryEventBuffer: Array<{
    id: string;
    ts: number;
    territories: any[];
  }> = [];

  constructor(
    private jwtService: JwtService,
    @InjectRepository(Territory)
    private territoryRepository: Repository<Territory>,
  ) {}

  handleConnection(client: Socket) {
    const token =
      client.handshake.auth?.token ||
      client.handshake.headers?.authorization
        ?.toString()
        .replace("Bearer ", "");

    if (!token) {
      console.log(`Client missing auth token: ${client.id}`);
      client.disconnect(true);
      return;
    }

    try {
      const payload = this.jwtService.verify(token);
      const userId = payload?.sub;
      if (!userId) {
        throw new Error("Invalid token payload");
      }
      client.data.userId = userId;
      this.connectedUsers.set(client.id, userId);
      client.join(this.territoryGlobalRoom);
      console.log(`Client connected: ${client.id} (user ${userId})`);
    } catch (error) {
      console.log(`Client auth failed: ${client.id}`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    console.log(`Client disconnected: ${client.id}`);
    this.connectedUsers.delete(client.id);
  }

  @SubscribeMessage("user:connect")
  handleUserConnect(
    @MessageBody() data: { userId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId || data.userId;
    if (!userId) {
      return;
    }
    this.connectedUsers.set(client.id, userId);
    console.log(`User ${userId} connected with socket ${client.id}`);
  }

  @SubscribeMessage("territory:captured")
  handleTerritoryCaptured(
    @MessageBody()
    data: { userId: string; hexId: string; lat: number; lng: number },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    if (!userId) return;
    // Broadcast to all other clients
    client.broadcast.emit("territory:contested", {
      ...data,
      userId,
    });
  }

  @SubscribeMessage("location:update")
  handleLocationUpdate(
    @MessageBody()
    data: { userId: string; lat: number; lng: number; speed: number },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    if (!userId) return;
    if (typeof data.lat === "number" && typeof data.lng === "number") {
      const room = this.getTerritoryRoom(data.lat, data.lng);
      if (client.data.territoryRoom && client.data.territoryRoom !== room) {
        client.leave(client.data.territoryRoom);
      }
      client.join(room);
      client.data.territoryRoom = room;
    }
    // Broadcast location to other clients (for multiplayer features)
    const room = client.data.territoryRoom;
    if (room) {
      client.broadcast.to(room).emit("user:location", {
        ...data,
        userId,
      });
    } else {
      client.broadcast.emit("user:location", {
        ...data,
        userId,
      });
    }
  }

  // Server methods to emit events
  emitLeaderboardUpdate(leaderboard: any[]) {
    this.server.emit("leaderboard:update", leaderboard);
  }

  emitAchievementUnlocked(userId: string, achievement: any) {
    // Find user's socket and emit to them
    for (const [socketId, uid] of this.connectedUsers.entries()) {
      if (uid === userId) {
        this.server.to(socketId).emit("achievement:unlocked", achievement);
      }
    }
  }

  emitUserStatsUpdated(userId: string, payload?: any) {
    for (const [socketId, uid] of this.connectedUsers.entries()) {
      if (uid === userId) {
        this.server
          .to(socketId)
          .emit("user:stats:update", payload ?? { userId });
      }
    }
  }

  emitTerritoryDefenseAlert(userId: string, payload: any) {
    for (const [socketId, uid] of this.connectedUsers.entries()) {
      if (uid === userId) {
        this.server.to(socketId).emit("territory:defense_alert", payload);
      }
    }
  }

  emitDuelInvite(userId: string, payload: any) {
    for (const [socketId, uid] of this.connectedUsers.entries()) {
      if (uid === userId) {
        this.server.to(socketId).emit("duel:invite", payload);
      }
    }
  }

  emitDuelUpdated(userId: string, payload: any) {
    for (const [socketId, uid] of this.connectedUsers.entries()) {
      if (uid === userId) {
        this.server.to(socketId).emit("duel:update", payload);
      }
    }
  }

  emitBoostUpdated(userId: string, payload: any) {
    for (const [socketId, uid] of this.connectedUsers.entries()) {
      if (uid === userId) {
        this.server.to(socketId).emit("engagement:boost:update", payload);
      }
    }
  }

  emitTerritoriesCaptured(territories: any[]) {
    if (!territories || territories.length === 0) return;
    for (const territory of territories) {
      const hexId = territory?.hexId?.toString();
      if (!hexId) continue;
      this.territoryPendingByHex.set(hexId, territory);
    }

    if (this.territoryFlushTimer) {
      return;
    }

    this.territoryFlushTimer = setTimeout(() => {
      const batch = Array.from(this.territoryPendingByHex.values());
      this.territoryPendingByHex.clear();
      this.territoryFlushTimer = undefined;

      if (batch.length === 0) return;

      const event = {
        eventId: randomUUID(),
        ts: Date.now(),
        territories: batch,
      };

      this.territoryEventBuffer.push({
        id: event.eventId,
        ts: event.ts,
        territories: batch,
      });
      if (this.territoryEventBuffer.length > this.territoryEventBufferSize) {
        this.territoryEventBuffer.splice(
          0,
          this.territoryEventBuffer.length - this.territoryEventBufferSize,
        );
      }

      this.server.to(this.territoryGlobalRoom).emit("territory:captured", event);
    }, this.territoryFlushDelayMs);
  }

  @SubscribeMessage("territory:replay")
  handleTerritoryReplay(
    @MessageBody() data: { since?: number },
    @ConnectedSocket() client: Socket,
  ) {
    const since = data?.since ? Number(data.since) : 0;
    if (!since || this.territoryEventBuffer.length === 0) return;
    const replay = this.territoryEventBuffer.filter((event) => event.ts > since);
    for (const event of replay) {
      client.emit("territory:captured", {
        eventId: event.id,
        ts: event.ts,
        territories: event.territories,
        replay: true,
      });
    }
  }

  @SubscribeMessage("territory:ack")
  handleTerritoryAck(
    @MessageBody() data: { eventId?: string; ts?: number },
    @ConnectedSocket() client: Socket,
  ) {
    const ackTs = data?.ts ? Number(data.ts) : null;
    if (!ackTs) return;
    const current = client.data.territoryAckAt as number | undefined;
    if (!current || ackTs > current) {
      client.data.territoryAckAt = ackTs;
    }
  }

  @SubscribeMessage("territory:subscribe")
  async handleTerritorySubscribe(
    @MessageBody()
    data: {
      lat: number;
      lng: number;
      radiiKm?: number[];
      radiusKm?: number;
      batchSize?: number;
    },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      const lat = Number(data?.lat);
      const lng = Number(data?.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;

      const rawRadii =
        Array.isArray(data?.radiiKm) && data.radiiKm.length > 0
          ? data.radiiKm
          : [data?.radiusKm ?? 20];
      const radii = Array.from(
        new Set(
          rawRadii
            .map((radius) => Number(radius))
            .filter((radius) => Number.isFinite(radius) && radius > 0)
            .map((radius) =>
              this.clampNumber(
                radius,
                this.territorySnapshotMinRadiusKm,
                this.territorySnapshotMaxRadiusKm,
              ),
            ),
        ),
      ).sort((a, b) => a - b);
      if (radii.length === 0) return;

      const batchSize = this.clampNumber(
        Number(data?.batchSize ?? 450),
        this.territorySnapshotBatchMin,
        this.territorySnapshotBatchMax,
      );

      const requestId = randomUUID();
      client.data.territorySnapshotRequestId = requestId;

      const seenHex = new Set<string>();
      for (const radiusKm of radii) {
        if (!this.isSnapshotRequestActive(client, requestId)) return;
        const territories = await this.queryTerritoriesInRadius(
          lat,
          lng,
          radiusKm,
        );
        if (!this.isSnapshotRequestActive(client, requestId)) return;
        const filtered = territories.filter((territory) => {
          const hexId = territory?.hexId?.toString();
          if (!hexId || seenHex.has(hexId)) return false;
          seenHex.add(hexId);
          return true;
        });

        await this.emitSnapshotBatches(
          client,
          filtered,
          radiusKm,
          batchSize,
          requestId,
        );

        if (!this.isSnapshotRequestActive(client, requestId)) return;
        await this.sleep(this.territorySnapshotRadiusDelayMs);
      }
    } catch (error) {
      const now = Date.now();
      if (!this.lastSnapshotErrorAt || now - this.lastSnapshotErrorAt > 5000) {
        this.lastSnapshotErrorAt = now;
        console.log("territory snapshot failed:", error);
      }
    }
  }

  private getTerritoryRoom(lat: number, lng: number) {
    const tile = 0.02; // ~2km
    const latKey = Math.floor(lat / tile);
    const lngKey = Math.floor(lng / tile);
    return `territory:geo:${latKey}:${lngKey}`;
  }

  private async queryTerritoriesInRadius(
    lat: number,
    lng: number,
    radiusKm: number,
  ) {
    const latDelta = radiusKm / 111.0;
    const lngDelta = radiusKm / (111.0 * Math.cos((lat * Math.PI) / 180));

    return this.territoryRepository
      .createQueryBuilder("territory")
      .leftJoinAndSelect("territory.owner", "owner")
      .where("territory.latitude BETWEEN :minLat AND :maxLat", {
        minLat: lat - latDelta,
        maxLat: lat + latDelta,
      })
      .andWhere("territory.longitude BETWEEN :minLng AND :maxLng", {
        minLng: lng - lngDelta,
        maxLng: lng + lngDelta,
      })
      .orderBy("territory.capturedAt", "DESC")
      .limit(this.territorySnapshotHardLimit)
      .getMany();
  }

  private async emitSnapshotBatches(
    client: Socket,
    territories: any[],
    radiusKm: number,
    batchSize: number,
    requestId: string,
  ) {
    if (!territories || territories.length === 0) return;
    const batchCount = Math.ceil(territories.length / batchSize);

    for (let i = 0; i < territories.length; i += batchSize) {
      if (!this.isSnapshotRequestActive(client, requestId)) return;
      const batch = territories.slice(i, i + batchSize);
      client.emit("territory:snapshot", {
        eventId: randomUUID(),
        ts: Date.now(),
        radiusKm,
        batchIndex: Math.floor(i / batchSize) + 1,
        batchCount,
        territories: batch,
      });
      if (i + batchSize < territories.length) {
        await this.sleep(this.territorySnapshotDelayMs);
      }
    }
  }

  private isSnapshotRequestActive(client: Socket, requestId: string) {
    return (
      client.connected && client.data.territorySnapshotRequestId === requestId
    );
  }

  private clampNumber(value: number, min: number, max: number) {
    if (!Number.isFinite(value)) return min;
    return Math.min(Math.max(value, min), max);
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
