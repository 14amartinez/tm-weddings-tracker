-- ============================================================================
-- 2026-05-06: Add Greg (ad manager) with new 'marketing' role + progress row
-- ============================================================================
-- Onboarding Greg Erwin (greg@fearlessmedialv.com) as TM Weddings' first
-- external partner with a non-internal role. Adds him to tmw_team_members
-- with role 'marketing' (active) and creates the tmw_marketing_progress row
-- that the new /marketing/index.html page uses to persist per-user checkbox
-- state for the onboarding checklist.
--
-- Path-restriction is enforced in tmw-auth.js: users whose only role is
-- 'marketing' are confined to /marketing/* and cannot navigate to internal
-- wedding/post-production routes.
-- ============================================================================

-- ─── 1. Add Greg to tmw_team_members ────────────────────────────────────────
-- Append a new member object to the existing members[] array.
UPDATE projects
SET data = jsonb_set(
  data,
  '{members}',
  (data->'members') || jsonb_build_array(
    jsonb_build_object(
      'email',  'greg@fearlessmedialv.com',
      'name',   'Greg Erwin',
      'roles',  jsonb_build_array('marketing'),
      'active', true
    )
  )
),
updated_at = NOW()
WHERE id = 'tmw_team_members';


-- ─── 2. Create tmw_marketing_progress row ───────────────────────────────────
-- Row is created empty; the page lazily creates per-user entries on first
-- checkbox toggle. ON CONFLICT no-ops if it already exists.
INSERT INTO projects (id, data, updated_at)
VALUES (
  'tmw_marketing_progress',
  jsonb_build_object(
    'schema_version', 1,
    'users',          '{}'::jsonb
  ),
  NOW()
)
ON CONFLICT (id) DO NOTHING;


-- ─── 3. Verify ───────────────────────────────────────────────────────────────
-- Confirm Greg is in the team list with the marketing role
SELECT m
FROM projects, jsonb_array_elements(data->'members') m
WHERE id = 'tmw_team_members'
  AND m->>'email' = 'greg@fearlessmedialv.com';

-- Confirm the progress row exists
SELECT id, jsonb_pretty(data) AS data, updated_at
FROM projects
WHERE id = 'tmw_marketing_progress';

-- Confirm total active member count incremented
SELECT
  jsonb_array_length(data->'members') AS total_members,
  (SELECT COUNT(*)
   FROM jsonb_array_elements(data->'members') m
   WHERE (m->>'active')::boolean = true) AS active_members
FROM projects WHERE id = 'tmw_team_members';
