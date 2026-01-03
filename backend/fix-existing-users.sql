-- Quick fix: Update all existing users to have completed onboarding
-- This is needed because the field was added after users were created

-- Update existing users to mark onboarding as complete
UPDATE "user"
SET "hasCompletedOnboarding" = true
WHERE "hasCompletedOnboarding" = false OR "hasCompletedOnboarding" IS NULL;

-- Verify the update
SELECT id, email, name, "hasCompletedOnboarding" 
FROM "user";
