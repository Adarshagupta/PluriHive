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

@Entity("poi_missions")
@Index(["userId"])
@Index(["createdAt"])
export class PoiMissionEntity {
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

  @Column({ type: "jsonb" })
  poiList: Array<{
    id: string;
    name: string;
    category: string;
    lat: number;
    lng: number;
  }>;

  @Column({ type: "jsonb", default: () => "'[]'" })
  visitedPoiIds: string[];

  @Column({ default: 150 })
  rewardPoints: number;

  @Column({ type: "timestamp", nullable: true })
  completedAt?: Date | null;

  @Column({ type: "timestamp", nullable: true })
  rewardGrantedAt?: Date | null;

  @CreateDateColumn()
  createdAt: Date;
}
