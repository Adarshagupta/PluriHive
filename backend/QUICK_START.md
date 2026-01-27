# Quick Start - Fix Database Error

## ⚠️ Current Issue
You're seeing this error:
```
error: column User.currentStreak does not exist
```

## 🚀 Quick Fix (Choose ONE)

### Option 1: Automated Script (Recommended)
```bash
npm run fix-db
```

This will automatically:
- Connect to your database
- Check which columns are missing
- Add the missing columns
- Verify the fix

### Option 2: Run TypeORM Migration
```bash
npm run migration:run
```

### Option 3: Manual SQL
Connect to your PostgreSQL database and run:
```bash
psql -U postgres -d plurihive -f fix-user-columns.sql
```

Or copy/paste this SQL:
```sql
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "currentStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "longestStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastActiveDate" date;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "streakFreezes" integer NOT NULL DEFAULT 1;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastFreezeGrantDate" date;
```

## ✅ After Fixing

1. Restart your backend server:
   ```bash
   npm start
   ```

2. Test by logging in from your Flutter app

## 📝 What Happened?

The User entity in TypeORM was updated to include streak tracking features:
- `currentStreak` - Days user has been active consecutively
- `longestStreak` - Longest streak ever achieved
- `lastActiveDate` - Last day user was active
- `streakFreezes` - Number of freeze tokens user has
- `lastFreezeGrantDate` - When last freeze was granted

These columns exist in the code but not in your database, causing the error.

## 🔍 Verify the Fix

Run this SQL to confirm all columns exist:
```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name IN ('currentStreak', 'longestStreak', 'lastActiveDate', 'streakFreezes', 'lastFreezeGrantDate')
ORDER BY column_name;
```

You should see 5 rows returned.

## 🆘 Still Having Issues?

1. **Database not running?**
   - Start PostgreSQL service
   - Check connection: `psql -U postgres -d plurihive`

2. **Wrong credentials?**
   - Check your `.env` file
   - Verify DATABASE_USER, DATABASE_PASSWORD, DATABASE_NAME

3. **Permission denied?**
   - Make sure your database user has ALTER TABLE permissions
   - Try connecting as `postgres` superuser

4. **Different database?**
   - Confirm you're connecting to the right database
   - Check DATABASE_NAME in `.env`

## 📚 More Details

See `DATABASE_FIX.md` for comprehensive troubleshooting and explanation.

## 🎉 Success!

Once fixed, your backend will start successfully and handle authentication without errors!