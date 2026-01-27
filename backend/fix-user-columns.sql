-- Quick fix SQL script to add missing User columns
-- Run this script directly in your PostgreSQL database

-- Add streak-related columns to users table
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "currentStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "longestStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastActiveDate" date;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "streakFreezes" integer NOT NULL DEFAULT 1;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastFreezeGrantDate" date;

-- Verify the columns were added
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name IN ('currentStreak', 'longestStreak', 'lastActiveDate', 'streakFreezes', 'lastFreezeGrantDate')
ORDER BY column_name;

-- Success message
SELECT 'User streak columns added successfully!' AS status;
