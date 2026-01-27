/**
 * Database Fix Script
 *
 * This script automatically adds missing columns to the users table.
 * Run this with: node fix-database.js
 */

require('dotenv').config();
const { Client } = require('pg');

async function fixDatabase() {
  const client = new Client({
    host: process.env.DATABASE_HOST || 'localhost',
    port: parseInt(process.env.DATABASE_PORT || '5432', 10),
    user: process.env.DATABASE_USER || 'postgres',
    password: process.env.DATABASE_PASSWORD,
    database: process.env.DATABASE_NAME || 'plurihive',
    ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
  });

  try {
    console.log('🔌 Connecting to database...');
    await client.connect();
    console.log('✅ Connected to database');

    console.log('\n📋 Checking current schema...');

    // Check which columns are missing
    const checkQuery = `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'users'
      AND column_name IN ('currentStreak', 'longestStreak', 'lastActiveDate', 'streakFreezes', 'lastFreezeGrantDate');
    `;

    const existingColumns = await client.query(checkQuery);
    const existingColumnNames = existingColumns.rows.map(row => row.column_name);

    const requiredColumns = ['currentStreak', 'longestStreak', 'lastActiveDate', 'streakFreezes', 'lastFreezeGrantDate'];
    const missingColumns = requiredColumns.filter(col => !existingColumnNames.includes(col));

    if (missingColumns.length === 0) {
      console.log('✅ All columns already exist! No fixes needed.');
      return;
    }

    console.log(`⚠️  Missing columns: ${missingColumns.join(', ')}`);
    console.log('\n🔧 Adding missing columns...');

    // Add missing columns
    const queries = [
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "currentStreak" integer NOT NULL DEFAULT 0',
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "longestStreak" integer NOT NULL DEFAULT 0',
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastActiveDate" date',
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "streakFreezes" integer NOT NULL DEFAULT 1',
      'ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastFreezeGrantDate" date',
    ];

    for (const query of queries) {
      await client.query(query);
    }

    console.log('✅ Database schema updated successfully!');

    // Verify the fix
    console.log('\n🔍 Verifying columns...');
    const verifyQuery = `
      SELECT column_name, data_type, column_default, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'users'
      AND column_name IN ('currentStreak', 'longestStreak', 'lastActiveDate', 'streakFreezes', 'lastFreezeGrantDate')
      ORDER BY column_name;
    `;

    const result = await client.query(verifyQuery);

    console.log('\n📊 Column Details:');
    console.table(result.rows);

    if (result.rows.length === 5) {
      console.log('\n✨ SUCCESS! All columns are now present.');
      console.log('You can now restart your backend server.');
    } else {
      console.log('\n⚠️  Warning: Expected 5 columns but found', result.rows.length);
    }

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('\nPlease check:');
    console.error('1. Database is running');
    console.error('2. Database credentials in .env are correct');
    console.error('3. Database "plurihive" exists');
    console.error('4. User has ALTER TABLE permissions');
    process.exit(1);
  } finally {
    await client.end();
    console.log('\n🔌 Database connection closed');
  }
}

// Run the fix
console.log('🚀 Database Fix Script\n');
fixDatabase()
  .then(() => {
    console.log('\n✅ Done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  });
