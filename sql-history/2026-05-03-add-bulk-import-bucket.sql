-- =====================================================================
-- File: 2026-05-03-add-bulk-import-bucket.sql
-- Bucket: Build Calendar — Add bulk_wedding_import bucket
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-03
-- Purpose: Add a P1 bucket to bulk-import the 35+ missing 2026 weddings
--          + 14 missing 2027 weddings from the master spreadsheet
--          (Wedding Track Sheet → Full Breakdown tab) into TMW OS.
--
-- Context (surfaced 2026-05-03 ~9:25pm by COO reading tab 1):
-- - Portal currently has 10 clients in tmw_deliverables.
-- - Master spreadsheet has 45 weddings booked for 2026 (35-wedding gap)
--   plus 14 weddings booked for 2027 already (zero in portal).
-- - Most urgent: Matthew Patterson-Curry, 5/8-5/10/2026, 264 miles
--   (destination wedding, multi-day) — 5 days from now, no portal entry.
-- - Tony will manually intake Matthew tomorrow with full info from the
--   couple/files. This bucket covers the systematic bulk-import for
--   everyone else.
--
-- Design notes:
-- - Idempotent: filters out any existing bucket with this id before
--   appending.
-- - Hours estimate (16h boutique scope): includes spreadsheet parse,
--   schema mapping, dedup logic, validation, dry-run, actual import,
--   verification of all 49 records (35 + 14). Each wedding object
--   needs to land in tmw_weddings.data.weddings[] AND get matching
--   entries in tmw_deliverables and tmw_photo where applicable.
-- - Sequencing: this should run BEFORE bulk_freeform_intake_page
--   (Q3) becomes urgent. Once 49 weddings are loaded, future intake
--   is one-at-a-time as engagements land.
-- - Possible fast path: build a Python script that parses the .xlsx,
--   maps to TMW OS schema, and emits the UPDATE SQL. Cowork could 
--   handle this in one task.
--
-- RLS notes:
-- - No RLS changes. Existing {authenticated} permissive policy on
--   projects table continues. Owner gating in JS layer.
-- =====================================================================

UPDATE projects
SET data = jsonb_set(
  data,
  '{buckets}',
  (
    SELECT jsonb_agg(b ORDER BY ord)
    FROM (
      SELECT b, ord
      FROM jsonb_array_elements(data->'buckets') WITH ORDINALITY AS arr(b, ord)
      WHERE b->>'id' != 'bulk_wedding_import'

      UNION ALL

      SELECT
        $json${
          "id": "bulk_wedding_import",
          "name": "Bulk Import 2026 + 2027 Weddings from Master Spreadsheet",
          "category": "feature",
          "rate_tier": "mid",
          "status": "queued",
          "priority": 1,
          "quarter": "Q2-2026",
          "target_date": "2026-05-15",
          "shipped_date": null,
          "estimated_hours": 16,
          "dependencies": [],
          "notes": "Master Wedding Track Sheet has 45 weddings booked for 2026 (portal has 10 = 35-wedding gap) + 14 weddings booked for 2027 (zero in portal). Most urgent: Matthew Patterson-Curry destination wedding 5/8-5/10/2026 (5 days out from May 3). Tony will hand-intake Matthew separately with full info from couple/files; this bucket covers systematic bulk import of remaining 48 records. Suggested approach: Cowork-built Python script parses .xlsx → maps to TMW OS schema (tmw_weddings.data.weddings[] + tmw_deliverables + tmw_photo) → emits UPDATE SQL → dry-run → verify → execute. Targeting 5/15 to clear the gap before peak season really hits. CRITICAL: 17+ weddings between June and December 2026 currently invisible to portal — Brynn cannot prep, editors have no queue, no notifications fire."
        }$json$::jsonb AS b,
        9999 AS ord
    ) ordered
  )
),
updated_at = NOW()
WHERE id = 'tmw_build_plan';
