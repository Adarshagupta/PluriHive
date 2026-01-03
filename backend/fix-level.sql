-- Fix existing users with level 0
-- Run this against your database to update existing users

UPDATE users SET level = 1 WHERE level = 0 OR level IS NULL;

-- Verify the update
SELECT id, email, level, "totalPoints" FROM users;
