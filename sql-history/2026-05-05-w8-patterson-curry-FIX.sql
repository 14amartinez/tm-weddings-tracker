-- =====================================================================
-- File: 2026-05-05-w8-patterson-curry-FIX.sql
-- Bucket: w8 Matthew Patterson-Curry — schema-correct rewrite
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-05
-- Purpose: REPLACE w8 wedding object with one matching the EXACT schema
--          used by /weddings/index.html addWedding() function.
--
-- Schema reference (from addWedding() in /weddings/index.html):
--   id, client, date, venue, venueAddress, ceremonyVenue,
--   package, miles,
--   team: { leadPhoto, secondPhoto, photoShadow, leadVideo,
--           secondVideo, videoShadow, contentCreator, bts },
--   vendors: [], timeline: [], shotList: [],
--   notes, deliverables, package_code,
--   shotCallerUrl, wallpaperUrl
--
-- Multi-day handling:
--   Schema has only single date/venue/ceremonyVenue fields. For
--   Matthew's 2-day wedding we use:
--   - date = "2026-05-08" (Friday, primary day for sorting)
--   - ceremonyVenue = "MacEachron Waterfront Park" (Day 1 ceremony)
--   - venue = "Chemistry Creative" (Day 2 reception, the bigger event)
--   - venueAddress = Day 2 reception address
--   - notes carries the full multi-day breakdown including Day 1
--     dinner, Day 2 getting ready, hotel, drive distance, contract,
--     and risk flags
--   - timeline[] has 7 entries spanning both days
--
-- Hotel: Marriott AC Hotel New York Downtown,
--        151 Maiden Lane, New York, NY 10038
--
-- Pattern note: Uses jsonb_agg + || (array concat) instead of
-- UNION ALL with WITH ORDINALITY — the latter pattern caused a
-- "missing FROM-clause entry" error on first attempt because
-- of an alias mismatch. This version is cleaner and works.
--
-- RLS notes:
-- - No RLS changes. Existing {authenticated} permissive policy on
--   projects table continues to apply.
-- =====================================================================

UPDATE projects
SET data = jsonb_set(
  data,
  '{weddings}',
  COALESCE(
    (
      SELECT jsonb_agg(w)
      FROM jsonb_array_elements(data->'weddings') AS w
      WHERE w->>'id' != 'w8'
    ),
    '[]'::jsonb
  ) || jsonb_build_array(
    $json${
      "id": "w8",
      "client": "Matthew & Michi Patterson-Curry",
      "date": "2026-05-08",
      "venue": "Chemistry Creative",
      "venueAddress": "305 Ten Eyck St, Brooklyn, NY 11206",
      "ceremonyVenue": "MacEachron Waterfront Park",
      "package": "Photo only",
      "package_code": "PHOTO-CUSTOM",
      "miles": 264,
      "team": {
        "leadPhoto": "Tony",
        "secondPhoto": "",
        "photoShadow": "",
        "leadVideo": "",
        "secondVideo": "",
        "videoShadow": "",
        "contentCreator": "",
        "bts": ""
      },
      "vendors": [],
      "timeline": [
        { "time": "Fri 4:00 PM", "event": "Day 1 — Arrive at MacEachron Waterfront Park (100 River St, Hastings-On-Hudson)" },
        { "time": "Fri 4:30 PM", "event": "Day 1 — Ceremony" },
        { "time": "Fri evening", "event": "Day 1 — Dinner at Harvest on Hudson — Tony eats with party, pulls couple for sunset portraits, then departs" },
        { "time": "Sat TBC", "event": "Day 2 — Getting ready at 202 Cornelia St, Brooklyn" },
        { "time": "Sat 6:00 PM", "event": "Day 2 — Reception party begins at Chemistry Creative (305 Ten Eyck St, Brooklyn)" },
        { "time": "Sat 7:00 PM", "event": "Day 2 — Ceremonial bits at reception" },
        { "time": "Sat TBD", "event": "Day 2 — Coverage end (hours TBD)" }
      ],
      "shotList": [],
      "notes": "MULTI-DAY DESTINATION WEDDING — Solo coverage, Tony only.\n\nDAY 1 (Fri 5/8): Ceremony at MacEachron Waterfront Park, 100 River St, Hastings-On-Hudson NY 10706. Arrive 4pm, ceremony 4:30pm. Dinner at Harvest on Hudson — Tony eats with party, pulls couple for sunset portraits, then departs.\n\nDAY 2 (Sat 5/9): Getting ready at 202 Cornelia St, Brooklyn (time TBC from couple). Reception at Chemistry Creative aka 305 Ten Eyck St, Brooklyn 11206 — same venue, 6pm party start, 7pm ceremonial bits.\n\nHOTEL: Marriott AC Hotel New York Downtown, 151 Maiden Lane, New York, NY 10038\n\nDRIVE: 264 miles each direction.\n\nCONTRACT: Signed Feb 26 2026, retainer paid. HoneyBook workspace 69a06038075b11002367f9f2.\n\nCLIENT EMAIL: mpc@proptronix.com\n\nRISK FLAGS: Solo coverage on multi-day destination. No second shooter. Two separate venue regions. Day 2 coverage end time not locked.",
      "deliverables": "Standard digital gallery delivery only. No photo book. No raw files. No video. No content creator. Photo only per signed contract.",
      "shotCallerUrl": "/shot-caller/?id=w8",
      "wallpaperUrl": ""
    }$json$::jsonb
  )
),
updated_at = NOW()
WHERE id = 'tmw_weddings';

-- Verify after run:
-- SELECT
--   w->>'client' AS client,
--   w->>'date' AS date,
--   w->>'venue' AS venue,
--   w->'team'->>'leadPhoto' AS lead_photo,
--   jsonb_array_length(w->'timeline') AS timeline_count
-- FROM projects, jsonb_array_elements(data->'weddings') w
-- WHERE id = 'tmw_weddings' AND w->>'id' = 'w8';