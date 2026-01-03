import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, Index } from 'typeorm';
import { User } from '../user/user.entity';

@Entity('territories')
@Index(['hexId'])
@Index(['ownerId'])
export class Territory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  hexId: string; // H3 hex ID or custom grid ID

  @Column({ type: 'decimal', precision: 10, scale: 7 })
  latitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 7 })
  longitude: number;

  @Column({ type: 'uuid' })
  ownerId: string;

  @ManyToOne(() => User, user => user.territories)
  owner: User;

  @Column({ default: 1 })
  captureCount: number; // How many times captured

  @Column({ default: 50 })
  points: number; // Points earned

  @Column({ type: 'timestamp', nullable: true })
  lastBattleAt: Date;

  @CreateDateColumn()
  capturedAt: Date;
}
