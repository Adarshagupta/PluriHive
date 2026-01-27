# Database Schema Fix Guide

## Problem
The error `column User.currentStreak does not exist` indicates that your database schema is out of sync with the TypeORM entities.

## Quick Fix Options

### Option 1: Run the SQL Script Directly (Fastest)

1. Connect to your PostgreSQL database using any client (pgAdmin, DBeaver, or psql CLI)

2. Run the SQL script:
   ```bash
   psql -U postgres -d plurihive -f fix-user-columns.sql
   ```

   Or copy and paste the contents of `fix-user-columns.sql` into your database client.

### Option 2: Run TypeORM Migrations

1. Stop your backend server if it's running

2. Run the migration:
   ```bash
   npm run migration:run
   ```

3. Restart your backend server:
   ```bash
   npm start
   ```

### Option 3: Enable Auto-Synchronization (Development Only)

If you're in development mode, the TypeORM `synchronize: true` option should automatically create missing columns when you start the server.

1. Make sure `NODE_ENV` is NOT set to `production`

2. Stop and restart your backend server:
   ```bash
   npm start
   ```

3. TypeORM will automatically synchronize the schema on startup

⚠️ **Warning:** Never use `synchronize: true` in production! It can cause data loss.

## Verify the Fix

After applying any of the above options, verify the columns exist:

```sql
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name IN ('currentStreak', 'longestStreak', 'lastActiveDate', 'streakFreezes', 'lastFreezeGrantDate')
ORDER BY column_name;
```

You should see 5 rows returned:
- `currentStreak` (integer, default 0)
- `lastActiveDate` (date, nullable)
- `lastFreezeGrantDate` (date, nullable)
- `longestStreak` (integer, default 0)
- `streakFreezes` (integer, default 1)

## Manual SQL (If All Else Fails)

If you need to run the SQL manually, copy and paste this:

```sql
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "currentStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "longestStreak" integer NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastActiveDate" date;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "streakFreezes" integer NOT NULL DEFAULT 1;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastFreezeGrantDate" date;
```

## Future Prevention

To avoid this issue in the future:

1. **Always run migrations** after pulling new code that includes entity changes:
   ```bash
   npm run migration:run
   ```

2. **Create migrations** when you change entities:
   ```bash
   npm run migration:generate -- src/migrations/YourMigrationName
   ```

3. **Use `synchronize: false`** in production and rely only on migrations

4. **Keep migrations in version control** so all team members have the same schema

## Troubleshooting

### Issue: "Migration already exists"
If you see this error, the migration has already been recorded in the database but the columns weren't created.

Solution:
- Run the SQL script manually (Option 1 above)
- Or drop the migration record and re-run:
  ```sql
  DELETE FROM migrations WHERE name = 'AddUserStreakColumns1760000000000';
  ```
  Then run `npm run migration:run`

### Issue: "Cannot connect to database"
Make sure your `.env` file has the correct database credentials:
```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=your_password
DATABASE_NAME=plurihive
```

### Issue: Columns still not appearing
1. Clear TypeORM metadata cache (restart the server)
2. Check if you're connected to the correct database
3. Verify the user has permissions to ALTER TABLE

## Need More Help?

Check these files:
- `src/modules/user/user.entity.ts` - Entity definition
- `src/migrations/1760000000000-add-user-streak-columns.ts` - Migration file
- `src/data-source.ts` - Database connection configuration
- `src/app.module.ts` - TypeORM module configuration

## Success!

Once the columns are added, your backend should start without errors and the authentication flow should work correctly.