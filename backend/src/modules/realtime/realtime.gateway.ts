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

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private connectedUsers = new Map<string, string>(); // socketId -> userId

  handleConnection(client: Socket) {
    console.log(`Client connected: ${client.id}`);
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
    this.connectedUsers.set(client.id, data.userId);
    console.log(`User ${data.userId} connected with socket ${client.id}`);
  }

  @SubscribeMessage('territory:captured')
  handleTerritoryCaptured(
    @MessageBody() data: { userId: string; hexId: string; lat: number; lng: number },
    @ConnectedSocket() client: Socket,
  ) {
    // Broadcast to all other clients
    client.broadcast.emit('territory:contested', data);
  }

  @SubscribeMessage('location:update')
  handleLocationUpdate(
    @MessageBody() data: { userId: string; lat: number; lng: number; speed: number },
    @ConnectedSocket() client: Socket,
  ) {
    // Broadcast location to other clients (for multiplayer features)
    client.broadcast.emit('user:location', data);
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
