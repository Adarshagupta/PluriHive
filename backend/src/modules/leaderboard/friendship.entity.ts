import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  BeforeInsert,
  Index,
} from "typeorm";

@Entity("friendships")
@Index(["userId", "friendId"], { unique: true })
export class Friendship {
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

  @Column({ type: "varchar" })
  friendId: string;

  @Column({ type: "varchar", length: 16, default: "pending" })
  status: "pending" | "accepted" | "blocked";

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
