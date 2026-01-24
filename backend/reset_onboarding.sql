-- Reset all users' onboarding status to false
-- This forces everyone (including existing users) to complete onboarding
UPDATE users SET "hasCompletedOnboarding" = false;

-- Verify the update
SELECT id, email, name, "hasCompletedOnboarding" FROM users;
