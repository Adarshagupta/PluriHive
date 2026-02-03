import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  BeforeInsert,
  Index,
  ManyToOne,
} from "typeorm";
import { User } from "../../user/user.entity";

export type MissionPeriod = "daily" | "weekly";
export type MissionType = "distance_meters" | "steps" | "territories" | "workouts";

@Entity("missions")
@Index(["userId", "period", "type", "periodStart"], { unique: true })
export class MissionEntity {
  @PrimaryColumn("uuid")
  id: string;

  @BeforeInsert()
  generateId() {
    if (!this.id) {
      this.id = crypto.randomUUID();
    }
  }

  @Column({ type: "varchar" })
  userId: string;

  @ManyToOne(() => User, (user) => user.id, { onDelete: "CASCADE" })
  user: User;

  @Column({ type: "varchar", length: 16 })
  period: MissionPeriod;

  @Column({ type: "varchar", length: 32 })
  type: MissionType;

  @Column({ default: 0 })
  goal: number;

  @Column({ default: 0 })
  progress: number;

  @Column({ default: 0 })
  rewardPoints: number;

  @Column({ type: "date" })
  periodStart: Date;

  @Column({ type: "timestamp", nullable: true })
  completedAt?: Date | null;

  @Column({ type: "timestamp", nullable: true })
  rewardGrantedAt?: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
