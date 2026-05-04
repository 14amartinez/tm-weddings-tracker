-- =====================================================================
-- File: 2026-05-03-end-of-day-updates.sql
-- Bucket: Build Calendar — End-of-day session updates (May 3, 2026)
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-03
-- Purpose: Two changes to tmw_build_plan in one transaction:
--          1. ADD new bucket: content_creator_module (P1, Q2-2026)
--          2. ENSURE photobook_stages_v2 is on_hold with recon notes
--             (idempotent — safe to rerun)
--
-- Context:
-- - Surfaced today: post-production hub has Video / Client Deliverables /
--   Photo cards but NO content creator workflow. Lexi shoots iPhone
--   content for couples, three deliverable types: postable reel(s),
--   raw files, important moments folder. 24hr SLA on reels.
-- - Photo book stages migration paused after recon revealed
--   tmw_photo.projects[].deliverables[] structure with stages sub-object.
--   Pending Cowork code analysis on tmw-core.js:54 +
--   post-production/photo/index.html:217 BOOK_STAGES.
--
-- Design notes:
-- - Single jsonb_agg pass handles both: modifies photobook_stages_v2
--   AND filters out any existing content_creator_module (in case rerun),
--   then appends the new content_creator_module bucket.
-- - Cost model is unchanged — premium tiers still apply.
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
      SELECT
        CASE
          WHEN b->>'id' = 'photobook_stages_v2'
            THEN b
              || jsonb_build_object('status', 'on_hold')
              || jsonb_build_object('notes', 'Recon complete — Photo book deliverables live in tmw_photo.projects[].deliverables[] keyed by name="Photo book". Stages live inside d.value->stages sub-object. PENDING: Cowork code analysis on tmw-core.js:54 BOOK config + post-production/photo/index.html:217 BOOK_STAGES to confirm exact stored stage keys before writing destructive migration.')
          ELSE b
        END AS b,
        ord
      FROM jsonb_array_elements(data->'buckets') WITH ORDINALITY AS arr(b, ord)
      WHERE b->>'id' != 'content_creator_module'

      UNION ALL

      SELECT
        $json${
          "id": "content_creator_module",
          "name": "Content Creator Post-Production Module",
          "category": "feature",
          "rate_tier": "mid",
          "status": "queued",
          "priority": 1,
          "quarter": "Q2-2026",
          "target_date": null,
          "shipped_date": null,
          "estimated_hours": 28,
          "dependencies": [],
          "notes": "4th card on /post-production/ hub. Three deliverable types per wedding: Postable reel(s), Raw files, Important moments folder. Editor always = Lexi. 24hr SLA on reels — dashboard must surface deadline-approaching reels visually (red pulse on reels >18hr). Per-reel flag: quick_turn (3 stages: Edit → Approved → Delivered) vs full_flow (6 stages: Files received → Edited → Music/captions → Preview → Approved → Delivered) depending on package. Real-time urgency UI is the primary design constraint. Mirrors photo/video card pattern on hub."
        }$json$::jsonb AS b,
        9999 AS ord
    ) ordered
  )
),
updated_at = NOW()
WHERE id = 'tmw_build_plan';
