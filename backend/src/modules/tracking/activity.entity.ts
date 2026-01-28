import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  BeforeInsert,
  Index,
} from "typeorm";
import { User } from "../user/user.entity";

@Entity("activities")
@Index(["userId", "clientId"], { unique: true })
export class Activity {
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

  @Column({ type: "uuid" })
  userId: string;

  @Column({ type: "varchar", length: 64, nullable: true })
  clientId?: string;

  @ManyToOne(() => User, (user) => user.activities)
  user: User;

  // Route data
  @Column({ type: "jsonb" })
  routePoints: Array<{
    latitude: number;
    longitude: number;
    timestamp: Date;
    altitude?: number;
  }>;

  @Column({ type: "text", nullable: true })
  routeMapSnapshot: string; // Base64 encoded map screenshot

  // Metrics
  @Column({ type: "decimal", precision: 10, scale: 2 })
  distanceMeters: number;

  @Column({
    type: "interval",
    transformer: {
      to: (value: string) => value, // Store as-is
      from: (value: any) => {
        // PostgreSQL returns interval as object, convert to string
        if (typeof value === "object" && value !== null) {
          // Extract seconds from PostgreSQL interval object
          const seconds = value.seconds || 0;
          const minutes = value.minutes || 0;
          const hours = value.hours || 0;
          const days = value.days || 0;
          const totalSeconds =
            seconds + minutes * 60 + hours * 3600 + days * 86400;
          return `${totalSeconds} seconds`;
        }
        return value;
      },
    },
  })
  duration: string;

  @Column({ type: "decimal", precision: 5, scale: 2, nullable: true })
  averageSpeed: number;

  @Column({ default: 0 })
  steps: number;

  @Column({ default: 0 })
  caloriesBurned: number;

  // Game data
  @Column({ default: 0 })
  territoriesCaptured: number;

  @Column({ default: 0 })
  pointsEarned: number;

  @Column({ type: "decimal", nullable: true })
  capturedAreaSqMeters: number;

  @Column({ type: "jsonb", nullable: true })
  capturedHexIds: string[];

  @Column({ type: "timestamp" })
  startTime: Date;

  @Column({ type: "timestamp" })
  endTime: Date;

  @CreateDateColumn()
  createdAt: Date;
}
