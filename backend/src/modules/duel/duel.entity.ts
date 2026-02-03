import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  BeforeInsert,
  Index,
} from "typeorm";

export type DuelStatus = "pending" | "active" | "completed" | "declined" | "expired";
export type DuelRule = "territories" | "distance" | "steps" | "points";

@Entity("duels")
@Index(["challengerId"])
@Index(["opponentId"])
export class Duel {
  @PrimaryColumn("uuid")
  id: string;

  @BeforeInsert()
  generateId() {
    if (!this.id) {
      this.id = crypto.randomUUID();
    }
  }

  @Column({ type: "varchar" })
  challengerId: string;

  @Column({ type: "varchar" })
  opponentId: string;

  @Column({ type: "varchar", length: 16, default: "pending" })
  status: DuelStatus;

  @Column({ type: "varchar", length: 16, default: "territories" })
  rule: DuelRule;

  @Column({ type: "decimal", precision: 10, scale: 7 })
  centerLat: number;

  @Column({ type: "decimal", precision: 10, scale: 7 })
  centerLng: number;

  @Column({ type: "decimal", precision: 6, scale: 2, default: 1 })
  radiusKm: number;

  @Column({ type: "timestamp", nullable: true })
  startAt?: Date | null;

  @Column({ type: "timestamp", nullable: true })
  endAt?: Date | null;

  @Column({ default: 0 })
  challengerScore: number;

  @Column({ default: 0 })
  opponentScore: number;

  @Column({ type: "timestamp", nullable: true })
  acceptedAt?: Date | null;

  @Column({ type: "timestamp", nullable: true })
  completedAt?: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
