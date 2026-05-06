-- File:    sql-history/2026-05-06-fix-greg-email-alias.sql
-- Bucket:  Auth / team member management
-- Author:  Tony Martinez
-- Date:    2026-05-06
-- Purpose:
--   Greg Bagshaw was originally onboarded with email alias `greg@fearlessmedialv.com`,
--   but Google OAuth normalizes the JWT email to the canonical mailbox
--   `greg.bagshaw@fearlessmedialv.com`. As a result both auth gates rejected him —
--   the alias never matched the JWT subject. Fix: replace the alias with the
--   canonical email in `tmw_team_members.data.members`. Companion change in
--   `auth/callback.html` updates the APPROVED_EMAILS list to match.
--
-- Design notes:
--   - jsonb_array_elements + jsonb_agg with a CASE expression replaces the email
--     in-place without touching other member rows or fields (preserves roles,
--     active flag, name, etc.).
--   - Using $json$ dollar-quoting elsewhere in this repo for JSON literals; not
--     needed here since we're constructing a small inline JSON value as text.
--   - Verification SELECT at the bottom confirms the canonical email is present
--     and the alias is gone. Should return exactly 1 row.
--
-- RLS notes:
--   No policy changes. `projects` table has the standard {authenticated} RLS
--   with USING (true) / WITH CHECK (true). Owner-only enforcement remains in
--   JS (per current pattern, until Bucket 2.5 consolidation).
--
-- Rollback (if ever needed):
--   UPDATE projects SET data = jsonb_set(...) reversing the canonical → alias
--   substitution. Not committed here; the alias was wrong anyway.

UPDATE projects
SET data = jsonb_set(
  data,
  '{members}',
  (
    SELECT jsonb_agg(
      CASE 
        WHEN m->>'email' = 'greg@fearlessmedialv.com'
        THEN jsonb_set(m, '{email}', '"greg.bagshaw@fearlessmedialv.com"'::jsonb)
        ELSE m
      END
    )
    FROM jsonb_array_elements(data->'members') AS m
  )
),
updated_at = now()
WHERE id = 'tmw_team_members';

-- Verification: should return exactly one row with the canonical email
SELECT 
  member->>'email' AS email,
  member->>'name'  AS name,
  member->>'active' AS active,
  member->'roles' AS roles
FROM projects,
     jsonb_array_elements(data->'members') AS member
WHERE id = 'tmw_team_members'
  AND (
    member->>'email' = 'greg.bagshaw@fearlessmedialv.com'
    OR member->>'email' = 'greg@fearlessmedialv.com'
  );
