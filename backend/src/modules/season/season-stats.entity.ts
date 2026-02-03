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
import { User } from "../user/user.entity";

@Entity("season_stats")
@Index(["userId", "seasonId"], { unique: true })
export class SeasonStats {
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

  @Column({ type: "varchar", length: 32 })
  seasonId: string;

  @Column({ default: 0 })
  points: number;

  @Column({ type: "decimal", precision: 10, scale: 2, default: 0 })
  distanceKm: number;

  @Column({ default: 0 })
  steps: number;

  @Column({ default: 0 })
  territories: number;

  @Column({ default: 0 })
  workouts: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
