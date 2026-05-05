-- =====================================================================
-- File: 2026-05-05-w8-patterson-curry-WALLPAPER.sql
-- Bucket: w8 Patterson-Curry — wire wallpaperUrl to committed PNG
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-05
-- Purpose: Set w8.wallpaperUrl to the freshly rendered iPhone lock
--          screen wallpaper PNG that now lives at
--          /weddings/patterson_curry_timeline_wallpaper.png
--
-- Pattern: jsonb_agg + CASE — surgically patch only the w8 entry
-- in projects.data.weddings, leaving every other wedding untouched.
-- This is the canonical "wire wallpaperUrl after PNG commit" idiom.
-- =====================================================================

UPDATE projects
SET data = jsonb_set(
  data,
  '{weddings}',
  (
    SELECT jsonb_agg(
      CASE WHEN w->>'id' = 'w8'
        THEN w || jsonb_build_object('wallpaperUrl', '/weddings/patterson_curry_timeline_wallpaper.png')
        ELSE w
      END
    )
    FROM jsonb_array_elements(data->'weddings') w
  )
),
updated_at = NOW()
WHERE id = 'tmw_weddings';

-- Verify after run:
-- SELECT w->>'id' AS id, w->>'client' AS client, w->>'wallpaperUrl' AS wallpaper
-- FROM projects, jsonb_array_elements(data->'weddings') w
-- WHERE id = 'tmw_weddings' AND w->>'id' = 'w8';
