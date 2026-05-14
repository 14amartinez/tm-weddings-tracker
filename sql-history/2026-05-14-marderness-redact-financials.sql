-- =====================================================================
-- File: 2026-05-14-marderness-redact-financials.sql
-- Bucket: Wedding intake — Lauren + Justin Marderness (5/15/2026) follow-up
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-14
-- Purpose: Remove the FINANCIALS paragraph from w1747252200000's notes
--          field. Financial state (total, paid status, box sent,
--          welcome package address) should not live on the team-visible
--          wedding info page (team.tmweddings.com/weddings/client.html).
--
-- Supersedes:
-- - The notes field set by 2026-05-14-marderness-wedding-add.sql.
--   That earlier migration is now stale on the notes field only; all
--   other fields it wrote remain authoritative. If the earlier file is
--   rerun, this file must be rerun after it to re-redact.
--
-- Outstanding items NO LONGER tracked in notes (move to office workflow):
-- - Welcome package outstanding to 268 W Main St, Reinholds PA 17569.
-- - $5,553.35 paid in full, box sent (financial record kept in HoneyBook
--   / accounting, not in tmw_weddings).
--
-- Pattern: jsonb_agg with CASE merge. Wedding object || partial JSON
-- patch — || operator on jsonb merges objects with right-side wins.
-- Idempotent: rerunning writes the same notes value.
--
-- RLS notes:
-- - No RLS changes. Existing {authenticated} permissive policy applies.
-- =====================================================================

UPDATE projects
SET data = jsonb_set(data, '{weddings}', (
  SELECT jsonb_agg(
    CASE
      WHEN w->>'id' = 'w1747252200000'
        THEN w || jsonb_build_object('notes', $notes$VIDEO ONLY booking. LeAnna Theresa is the photographer (outside TM); coordinate logistics with her.

CREW: Tony lead video, Nick Stewart 2nd video. Both 12pm to 8pm.

GETTING READY LOCATIONS: Guys on site at Seashell (10 S Atlantic Ave). Girls at airbnb (214 Engleside Ave, one block from venue).

AUDIO: Both groom and bride mic'd. Bride uses small white lav inside dress, routed to skin-colored thigh strap. Confirmed ok.

FLASH: Welcome in ceremony space. Note: Lauren blinks often, photographer's discretion (relevant for sync).

STYLE: Voiceovers, dedicated moment for bride's dress, rings paired with invites. Open to creative direction.

MUST-HAVE MOMENTS: First look, vows, first kiss, cake cutting, speeches, garter + flower toss, reception entrance, first dance + parent dances, aerial shot of venue with palm trees.

FAMILY: Lauren's parents (Cyndi Vanmiddlesworth + Shawn Herman) are divorced, not cordial, both bringing partners. Plan family formals accordingly.

SPECIAL NOTES: Couple eloped 12/31/24 already. Some family + friends do not know. Be discreet about any reference to a previous ceremony. Couple has never seen venue in person. Couple describes themselves as impulsive, lean into spontaneous moments.$notes$)
      ELSE w
    END
  )
  FROM jsonb_array_elements(data->'weddings') w
)),
updated_at = NOW()
WHERE id = 'tmw_weddings';


-- Verify FINANCIALS string is gone
SELECT
  w->>'id' AS id,
  (w->>'notes' ~* 'financial|\$5,553|paid in full') AS has_financial_terms,
  length(w->>'notes') AS notes_length
FROM projects, jsonb_array_elements(data->'weddings') w
WHERE id = 'tmw_weddings'
  AND w->>'id' = 'w1747252200000';
-- Expect: has_financial_terms = false
