import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne } from 'typeorm';
import { User } from '../user/user.entity';

@Entity('activities')
export class Activity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, user => user.activities)
  user: User;

  // Route data
  @Column({ type: 'jsonb' })
  routePoints: Array<{
    latitude: number;
    longitude: number;
    timestamp: Date;
    altitude?: number;
  }>;

  @Column({ type: 'text', nullable: true })
  routeMapSnapshot: string; // Base64 encoded map screenshot

  // Metrics
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  distanceMeters: number;

  @Column({ type: 'interval' })
  duration: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  averageSpeed: number;

  @Column({ default: 0 })
  steps: number;

  @Column({ default: 0 })
  caloriesBurned: number;

  // Game data
  @Column({ default: 0 })
  territoriesCaptured: number;

  @Column({ default: 0 })
  pointsEarned: number;

  @Column({ type: 'decimal', nullable: true })
  capturedAreaSqMeters: number;

  @Column({ type: 'jsonb', nullable: true })
  capturedHexIds: string[];

  @Column({ type: 'timestamp' })
  startTime: Date;

  @Column({ type: 'timestamp' })
  endTime: Date;

  @CreateDateColumn()
  createdAt: Date;
}
