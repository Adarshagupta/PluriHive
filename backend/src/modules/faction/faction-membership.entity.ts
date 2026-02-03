import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  BeforeInsert,
  Index,
  ManyToOne,
} from "typeorm";
import { User } from "../user/user.entity";
import { Faction } from "./faction.entity";

@Entity("faction_memberships")
@Index(["userId", "seasonId"], { unique: true })
@Index(["factionId"])
export class FactionMembership {
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

  @Column({ type: "uuid" })
  factionId: string;

  @ManyToOne(() => Faction, (faction) => faction.id, { onDelete: "CASCADE" })
  faction: Faction;

  @Column({ type: "varchar", length: 32 })
  seasonId: string;

  @CreateDateColumn()
  joinedAt: Date;
}
