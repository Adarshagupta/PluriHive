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

@Entity("reward_unlocks")
@Index(["userId", "rewardId"], { unique: true })
export class RewardUnlock {
  @PrimaryColumn("uuid")
  id: string;

  @BeforeInsert()
  generateId() {
    if (!this.id) {
      this.id = crypto.randomUUID();
    }
    if (!this.unlockedAt) {
      this.unlockedAt = new Date();
    }
  }

  @Column({ type: "varchar" })
  userId: string;

  @ManyToOne(() => User, (user) => user.id)
  user: User;

  @Column({ type: "varchar", length: 64 })
  rewardId: string;

  @Column({ type: "varchar", length: 20 })
  rewardType: string;

  @Column({ default: 0 })
  cost: number;

  @CreateDateColumn()
  unlockedAt: Date;
}
