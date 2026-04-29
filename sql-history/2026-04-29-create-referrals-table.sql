-- ════════════════════════════════════════════════════════════════════════
-- Run this in Supabase SQL editor — manual migration
-- ════════════════════════════════════════════════════════════════════════
-- File:    2026-04-29-create-referrals-table.sql
-- Bucket:  3.1 — Team Referral Tracker (first Bucket 3 build)
-- Author:  Tony Martinez (via embedded COO)
-- Date:    2026-04-29
--
-- PURPOSE
--   Creates public.referrals to track team-member referrals through their
--   lifecycle: lead → inquiry → booked → payout. Replaces "tracked in
--   Tony's head" with "tracked in Supabase."
--
-- DESIGN NOTES
--   referrer_id (text, no FK)
--     Stores the EMAIL of the team member who made the referral. Matches
--     projects.data.members[].email in the existing JSON team store
--     (projects WHERE id = 'tmw_team_members'). Email is the de facto
--     unique key in that JSON; names can change, emails don't. A real
--     team_members table is on the roadmap (Bucket 8) — when it lands,
--     we'll add an FK then.
--
--   project_id (text, no FK)
--     Matches public.projects.id, which uses text identifiers (e.g.
--     'tmw_photo'), not uuids. No FK constraint to keep this loose
--     until the projects table itself is normalized.
--
-- RLS
--   Four policies, all {authenticated}-only, all permissive.
--   Owner-only enforcement (status changes, payout marking) lives in
--   the JS layer for now — same pattern as public.projects. A future
--   Bucket 2.5 task will add owner-level RLS across all tables.
-- ════════════════════════════════════════════════════════════════════════

CREATE TABLE public.referrals (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id     text NOT NULL,
    -- email from projects.data.members[].email; no FK (see header)
  referred_name   text NOT NULL,
  referred_email  text,
  referred_phone  text,
  source_notes    text,
  status          text NOT NULL DEFAULT 'lead'
                  CHECK (status IN ('lead','inquiry','booked','lost')),
  inquiry_date    date,
  booked_date     date,
  wedding_date    date,
  project_id      text,
    -- matches public.projects.id (text); no FK (see header)
  payout_amount   numeric(10,2) DEFAULT 250,
  payout_status   text DEFAULT 'pending'
                  CHECK (payout_status IN ('pending','paid','forfeited')),
  payout_date     date,
  payout_method   text CHECK (
                    payout_method IN ('venmo','check','cash','zelle')
                    OR payout_method IS NULL
                  ),
  payout_notes    text,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

-- ── RLS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "referrals_select_authenticated"
  ON public.referrals
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "referrals_insert_authenticated"
  ON public.referrals
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "referrals_update_authenticated"
  ON public.referrals
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "referrals_delete_authenticated"
  ON public.referrals
  FOR DELETE
  TO authenticated
  USING (true);

-- ── Auto-update updated_at on row change ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.referrals_set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER referrals_updated_at
  BEFORE UPDATE ON public.referrals
  FOR EACH ROW
  EXECUTE FUNCTION public.referrals_set_updated_at();
