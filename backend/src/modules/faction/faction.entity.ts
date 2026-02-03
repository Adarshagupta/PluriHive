import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  BeforeInsert,
  Index,
} from "typeorm";

@Entity("factions")
@Index(["key"], { unique: true })
export class Faction {
  @PrimaryColumn("uuid")
  id: string;

  @BeforeInsert()
  generateId() {
    if (!this.id) {
      this.id = crypto.randomUUID();
    }
  }

  @Column({ type: "varchar", length: 32 })
  key: string;

  @Column({ type: "varchar", length: 64 })
  name: string;

  @Column({ type: "varchar", length: 16 })
  color: string;

  @CreateDateColumn()
  createdAt: Date;
}
