# 🚨 START HERE - Fix Database Error

## The Problem
Your backend is failing with this error:
```
error: column User.currentStreak does not exist
```

## The Solution (Pick ONE - They all do the same thing)

### ✅ Option 1: Double-Click Batch File (EASIEST for Windows)
1. Navigate to: `C:\Users\adasg\OneDrive\Pictures\Rugged\backend`
2. Double-click: **`FIX_DATABASE.bat`**
3. Wait for it to complete
4. Restart your backend with `npm start`

### ✅ Option 2: Run PowerShell Script
1. Open PowerShell in the backend folder
2. Run: `.\FIX_DATABASE.ps1`
3. Restart your backend with `npm start`

### ✅ Option 3: Use NPM Command
Open Command Prompt or PowerShell in the backend folder:
```bash
npm run fix-db
```

### ✅ Option 4: Run TypeORM Migration
```bash
npm run migration:run
```

### ✅ Option 5: Manual SQL (If you have pgAdmin or psql)
Open your PostgreSQL client and run:
```sql
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "currentStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "longestStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastActiveDate" date;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "streakFreezes" integer NOT NULL DEFAULT 1;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastFreezeGrantDate" date;
```

## After Running the Fix

1. **Stop your backend** (if it's running)
2. **Start it again:**
   ```bash
   npm start
   ```
3. **Test login** from your Flutter app
4. ✅ **Success!** No more errors

## Why This Happened

The code was updated to add streak tracking features (daily streaks, longest streaks, etc.) to the User model. These new columns exist in the TypeORM entity code but not yet in your PostgreSQL database. Running any of the above fixes will add these 5 missing columns.

## Need Help?

- See `QUICK_START.md` for more details
- See `DATABASE_FIX.md` for comprehensive troubleshooting
- Check that PostgreSQL is running
- Check your `.env` file has correct database credentials

## What Gets Added

5 new columns to the `users` table:
- `currentStreak` - Current day streak count
- `longestStreak` - Best streak ever achieved  
- `lastActiveDate` - Last activity date
- `streakFreezes` - Number of freeze tokens available
- `lastFreezeGrantDate` - When last freeze was granted

---

## Quick Test

After fixing, verify with this SQL:
```sql
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('currentStreak', 'longestStreak', 'lastActiveDate', 'streakFreezes', 'lastFreezeGrantDate');
```

Should return 5 rows. If yes, you're all set! 🎉