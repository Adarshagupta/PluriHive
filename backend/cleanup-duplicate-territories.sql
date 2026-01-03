-- Remove duplicate territories, keeping only the most recent one per hexId
-- This will reduce overlapping circles on the map

-- Step 1: Create a temporary table with the IDs to keep (most recent per hexId)
CREATE TEMP TABLE territories_to_keep AS
SELECT DISTINCT ON ("hexId") id
FROM territories
ORDER BY "hexId", "capturedAt" DESC;

-- Step 2: Delete all territories except the ones we want to keep
DELETE FROM territories
WHERE id NOT IN (SELECT id FROM territories_to_keep);

-- Step 3: Show summary
SELECT 
  COUNT(*) as remaining_territories,
  COUNT(DISTINCT "hexId") as unique_hexes,
  COUNT(DISTINCT "ownerId") as unique_owners
FROM territories;

-- Drop the temp table
DROP TABLE territories_to_keep;
