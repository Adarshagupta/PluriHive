import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  BeforeInsert,
  BeforeUpdate,
} from 'typeorm';
import { User } from '../user/user.entity';

@Entity('routes')
export class RouteEntity {
  @PrimaryColumn('text')
  id: string;

  @BeforeInsert()
  generateId() {
    if (!this.id) {
      this.id = crypto.randomUUID();
    }
    const now = new Date();
    this.createdAt = now;
    this.updatedAt = now;
  }

  @BeforeUpdate()
  updateTimestamp() {
    this.updatedAt = new Date();
  }

  @Column({ type: 'text' })
  userId: string;

  @ManyToOne(() => User, user => user.routes)
  user: User;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ default: false })
  isPublic: boolean;

  @Column({ type: 'jsonb' })
  routePoints: Array<{ lat: number; lng: number }>;

  @Column({ type: 'float', default: 0 })
  distanceKm: number;

  @Column({ type: 'float', nullable: true })
  elevationGain?: number;

  @Column({ type: 'float' })
  minLat: number;

  @Column({ type: 'float' })
  maxLat: number;

  @Column({ type: 'float' })
  minLng: number;

  @Column({ type: 'float' })
  maxLng: number;

  @Column({ type: 'float' })
  centerLat: number;

  @Column({ type: 'float' })
  centerLng: number;

  @Column({ default: 0 })
  usageCount: number;

  @Column({ type: 'timestamp', nullable: true })
  lastUsedAt?: Date;

  @Column({ type: 'text' })
  routeHash: string;

  @Column({ type: 'jsonb', nullable: true })
  h3Path?: string[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
