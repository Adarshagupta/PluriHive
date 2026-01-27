ALTER TABLE users ADD COLUMN "currentStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN "longestStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN "lastActiveDate" date;
ALTER TABLE users ADD COLUMN "streakFreezes" integer NOT NULL DEFAULT 1;
ALTER TABLE users ADD COLUMN "lastFreezeGrantDate" date;
