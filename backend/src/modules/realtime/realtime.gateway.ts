import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private connectedUsers = new Map<string, string>(); // socketId -> userId
  constructor(private jwtService: JwtService) {}

  handleConnection(client: Socket) {
    const token =
      client.handshake.auth?.token ||
      client.handshake.headers?.authorization?.toString().replace('Bearer ', '');

    if (!token) {
      console.log(`Client missing auth token: ${client.id}`);
      client.disconnect(true);
      return;
    }

    try {
      const payload = this.jwtService.verify(token);
      const userId = payload?.sub;
      if (!userId) {
        throw new Error('Invalid token payload');
      }
      client.data.userId = userId;
      this.connectedUsers.set(client.id, userId);
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

  @SubscribeMessage('user:connect')
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

  @SubscribeMessage('territory:captured')
  handleTerritoryCaptured(
    @MessageBody() data: { userId: string; hexId: string; lat: number; lng: number },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    if (!userId) return;
    // Broadcast to all other clients
    client.broadcast.emit('territory:contested', {
      ...data,
      userId,
    });
  }

  @SubscribeMessage('location:update')
  handleLocationUpdate(
    @MessageBody() data: { userId: string; lat: number; lng: number; speed: number },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    if (!userId) return;
    // Broadcast location to other clients (for multiplayer features)
    client.broadcast.emit('user:location', {
      ...data,
      userId,
    });
  }

  // Server methods to emit events
  emitLeaderboardUpdate(leaderboard: any[]) {
    this.server.emit('leaderboard:update', leaderboard);
  }

  emitAchievementUnlocked(userId: string, achievement: any) {
    // Find user's socket and emit to them
    for (const [socketId, uid] of this.connectedUsers.entries()) {
      if (uid === userId) {
        this.server.to(socketId).emit('achievement:unlocked', achievement);
        break;
      }
    }
  }
}
