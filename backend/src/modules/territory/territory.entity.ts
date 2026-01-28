import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  Index,
  BeforeInsert,
} from "typeorm";
import { User } from "../user/user.entity";

@Entity("territories")
@Index(["hexId"])
@Index(["ownerId"])
export class Territory {
  @PrimaryColumn("uuid")
  id: string;

  @BeforeInsert()
  generateId() {
    if (!this.id) {
      this.id = crypto.randomUUID();
    }
    if (!this.capturedAt) {
      this.capturedAt = new Date();
    }
  }

  @Column({ unique: true })
  hexId: string; // Used as unique identifier for the territory

  @Column({ type: "decimal", precision: 10, scale: 7 })
  latitude: number; // Center point latitude

  @Column({ type: "decimal", precision: 10, scale: 7 })
  longitude: number; // Center point longitude

  @Column({ type: "jsonb", nullable: true })
  routePoints: { lat: number; lng: number }[]; // Actual loop path

  @Column({ type: "uuid" })
  ownerId: string;

  @ManyToOne(() => User, (user) => user.territories)
  owner: User;

  @Column({ default: 1 })
  captureCount: number; // How many times captured

  @Column({ default: 50 })
  points: number; // Points earned

  @Column({ type: "varchar", length: 64, nullable: true })
  lastCaptureSessionId?: string;

  @Column({ type: "timestamp", nullable: true })
  lastBattleAt: Date;

  @CreateDateColumn()
  capturedAt: Date;
}
