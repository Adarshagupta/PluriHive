import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  BeforeInsert,
  Index,
} from "typeorm";
import { User } from "../../user/user.entity";

@Entity("map_drops")
@Index(["userId"])
@Index(["expiresAt"])
export class MapDrop {
  @PrimaryColumn("uuid")
  id: string;

  @BeforeInsert()
  generateId() {
    if (!this.id) {
      this.id = crypto.randomUUID();
    }
    if (!this.createdAt) {
      this.createdAt = new Date();
    }
  }

  @Column({ type: "varchar" })
  userId: string;

  @ManyToOne(() => User, (user) => user.id)
  user: User;

  @Column({ type: "decimal", precision: 10, scale: 7 })
  latitude: number;

  @Column({ type: "decimal", precision: 10, scale: 7 })
  longitude: number;

  @Column({ default: 45 })
  radiusMeters: number;

  @Column({ default: 2 })
  boostMultiplier: number;

  @Column({ default: 120 })
  boostSeconds: number;

  @Column({ type: "timestamp" })
  expiresAt: Date;

  @Column({ type: "timestamp", nullable: true })
  pickedAt?: Date | null;

  @CreateDateColumn()
  createdAt: Date;
}
