import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  BeforeInsert,
  Index,
} from "typeorm";
import { User } from "../../user/user.entity";

@Entity("map_drop_boosts")
@Index(["userId"], { unique: true })
export class MapDropBoost {
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

  @Column({ default: 2 })
  multiplier: number;

  @Column({ type: "timestamp" })
  endsAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
