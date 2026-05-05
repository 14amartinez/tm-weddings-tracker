-- =====================================================================
-- File: 2026-05-05-bulk-fill-important-data.sql
-- Bucket: bulk_wedding_import (subset — important data only)
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-05
-- Purpose: Fill in HIGH-IMPORTANCE gaps in tmw_weddings, sourced from
--          Wedding Track Sheet (Full Breakdown tab).
--
-- Scope (deliberately tight per Tony's "important data only" directive):
--
--   FULL FILL (3 stub weddings — were just client names + nothing else):
--     w50 Kristina Beyer & Corey Feist  (2027-06-11, Woodmont Manor, 60mi, KC0612)
--     w52 Samantha Lanza & Ricky Abate  (2027-06-25, Lace by Epicurean, 164mi, SR0626) — OVERNIGHT
--     w54 Ashley Arroyo & Elvin          (2027-09-18, Woodmont Manor, 60mi, AE0918)
--
--   PACKAGE CODE ONLY (codes exist in master sheet, just never landed):
--     w43 Alympia          (AT1107)
--     w44 Briana Arrabito  (JB1210)
--     w51 Dria Benjamin    (DC0619)
--
-- Pattern: jsonb_agg with CASE merge. Each matched wedding gets its
-- existing object || (concatenated with) a partial JSON patch. The ||
-- operator on jsonb merges objects with right-side wins on conflicts.
-- All other weddings pass through unchanged.
--
-- Why no addresses: sheet's "Address" column is client mailing
-- addresses, not venue addresses. Doesn't fit `venueAddress` semantically.
--
-- RLS notes:
-- - No RLS changes. Existing {authenticated} permissive policy applies.
-- =====================================================================

UPDATE projects
SET data = jsonb_set(data, '{weddings}', (
  SELECT jsonb_agg(
    CASE

      -- w50: Full fill (was client-name-only stub)
      WHEN w->>'id' = 'w50' THEN w || $j${
        "client": "Kristina Beyer & Corey Feist",
        "date": "2027-06-11",
        "venue": "Woodmont Manor",
        "miles": 60,
        "package_code": "KC0612"
      }$j$::jsonb

      -- w52: Full fill — OVERNIGHT WEDDING flagged
      WHEN w->>'id' = 'w52' THEN w || $j${
        "client": "Samantha Lanza & Ricky Abate",
        "date": "2027-06-25",
        "venue": "Lace by Epicurean",
        "miles": 164,
        "package_code": "SR0626",
        "notes": "OVERNIGHT WEDDING — 164 miles, hotel stay required. Confirm coverage hours and lodging before locking team."
      }$j$::jsonb

      -- w54: Full fill
      WHEN w->>'id' = 'w54' THEN w || $j${
        "client": "Ashley Arroyo & Elvin",
        "date": "2027-09-18",
        "venue": "Woodmont Manor",
        "miles": 60,
        "package_code": "AE0918"
      }$j$::jsonb

      -- w43: Package code only
      WHEN w->>'id' = 'w43' THEN w || $j${"package_code": "AT1107"}$j$::jsonb

      -- w44: Package code only
      WHEN w->>'id' = 'w44' THEN w || $j${"package_code": "JB1210"}$j$::jsonb

      -- w51: Package code only
      WHEN w->>'id' = 'w51' THEN w || $j${"package_code": "DC0619"}$j$::jsonb

      ELSE w
    END
  )
  FROM jsonb_array_elements(data->'weddings') w
))
WHERE id = 'tmw_weddings';

-- Verify after run:
-- SELECT
--   w->>'id' AS id,
--   w->>'client' AS client,
--   w->>'date' AS date,
--   w->>'venue' AS venue,
--   (w->>'miles')::int AS miles,
--   w->>'package_code' AS code
-- FROM projects, jsonb_array_elements(data->'weddings') w
-- WHERE id = 'tmw_weddings'
--   AND w->>'id' IN ('w43','w44','w50','w51','w52','w54')
-- ORDER BY w->>'id';
