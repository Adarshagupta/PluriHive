import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  BeforeInsert,
  BeforeUpdate,
} from "typeorm";
import { Territory } from "../territory/territory.entity";
import { Activity } from "../tracking/activity.entity";
import { RouteEntity } from "../routes/route.entity";

@Entity("users")
export class User {
  @PrimaryColumn("uuid")
  id: string;

  @BeforeInsert()
  generateId() {
    if (!this.id) {
      this.id = crypto.randomUUID();
    }
    const now = new Date();
    this.createdAt = now;
    this.updatedAt = now;
  }

  @BeforeUpdate()
  updateTimestamp() {
    this.updatedAt = new Date();
  }

  @Column({ unique: true })
  email: string;

  @Column({ nullable: true })
  name: string;

  @Column({ select: false })
  password: string;

  @Column({ nullable: true })
  profilePicture: string;

  // Physical stats
  @Column({ type: "decimal", nullable: true })
  weight: number;

  @Column({ type: "decimal", nullable: true })
  height: number;

  @Column({ nullable: true })
  age: number;

  @Column({ nullable: true })
  gender: string;

  // Onboarding status - MUST complete onboarding (non-negotiable)
  @Column({ default: false })
  hasCompletedOnboarding: boolean;

  // Game stats
  @Column({ default: 0 })
  totalPoints: number;

  @Column({ default: 1 })
  level: number;

  @Column({ type: "decimal", default: 0 })
  totalDistanceKm: number;

  @Column({ default: 0 })
  totalSteps: number;

  @Column({ default: 0 })
  totalTerritoriesCaptured: number;

  @Column({ default: 0 })
  totalWorkouts: number;

  // Streaks
  @Column({ default: 0 })
  currentStreak: number;

  @Column({ default: 0 })
  longestStreak: number;

  @Column({ type: "date", nullable: true })
  lastActiveDate: Date;

  @Column({ default: 1 })
  streakFreezes: number;

  @Column({ type: "date", nullable: true })
  lastFreezeGrantDate: Date;

  // User Settings
  @Column({ type: "jsonb", nullable: true })
  settings: {
    units?: "metric" | "imperial";
    gpsAccuracy?: "high" | "medium" | "low";
    hapticFeedback?: boolean;
    pushNotifications?: boolean;
    emailNotifications?: boolean;
    streakReminders?: boolean;
    darkMode?: boolean;
    language?: string;
  };

  // Relationships
  @OneToMany(() => Territory, (territory) => territory.owner)
  territories: Territory[];

  @OneToMany(() => Activity, (activity) => activity.user)
  activities: Activity[];

  @OneToMany(() => RouteEntity, (route) => route.user)
  routes: RouteEntity[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
