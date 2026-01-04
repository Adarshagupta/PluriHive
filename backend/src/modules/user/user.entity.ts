import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { Territory } from '../territory/territory.entity';
import { Activity } from '../tracking/activity.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column({ nullable: true })
  name: string;

  @Column()
  password: string;

  @Column({ nullable: true })
  profilePicture: string;

  // Physical stats
  @Column({ type: 'decimal', nullable: true })
  weight: number;

  @Column({ type: 'decimal', nullable: true })
  height: number;

  @Column({ nullable: true })
  age: number;

  @Column({ nullable: true })
  gender: string;

  // Onboarding status - default to true for backward compatibility
  @Column({ default: true })
  hasCompletedOnboarding: boolean;

  // Game stats
  @Column({ default: 0 })
  totalPoints: number;

  @Column({ default: 1 })
  level: number;

  @Column({ type: 'decimal', default: 0 })
  totalDistanceKm: number;

  @Column({ default: 0 })
  totalSteps: number;

  @Column({ default: 0 })
  totalTerritoriesCaptured: number;

  @Column({ default: 0 })
  totalWorkouts: number;

  // User Settings
  @Column({ type: 'jsonb', nullable: true })
  settings: {
    units?: 'metric' | 'imperial';
    gpsAccuracy?: 'high' | 'medium' | 'low';
    hapticFeedback?: boolean;
    pushNotifications?: boolean;
    emailNotifications?: boolean;
    streakReminders?: boolean;
    darkMode?: boolean;
    language?: string;
  };

  // Relationships
  @OneToMany(() => Territory, territory => territory.owner)
  territories: Territory[];

  @OneToMany(() => Activity, activity => activity.user)
  activities: Activity[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
