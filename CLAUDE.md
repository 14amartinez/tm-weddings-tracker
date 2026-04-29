# TM Weddings Portal — Claude Context

## What this is
Internal post-production portal for TM Weddings (wedding photo/video co.,
Lehigh Valley PA). Live at team.tmweddings.com. Used by photo editors
(Tony, Brynn) and video editors (full team).

## Stack
- Frontend: vanilla HTML/CSS/JS, no framework
- Backend: Supabase (Postgres + Auth + RLS) — project ref `rafygjaemcjhnououmwn`
- Auth: Supabase Auth via `auth.tmweddings.com` (custom domain, JWT-based)
- Hosting: Vercel auto-deploy from `main`
- Notifications: EmailJS (service `service_qoodzdb`, template `template_p1hyj87`)
  - NOTE: `template_p1hyj87` was originally a post-production stage template.
    The referrals feature reuses it by mapping fields. A dedicated referrals
    template is on the polish list.
- Repo: github.com/14amartinez/tm-weddings-tracker

## Architecture rules — DO NOT VIOLATE

1. All Supabase calls go through `tmwSbFetch` (in `tmw-auth.js`). Never the
   raw publishable key for data operations. JWT-aware path only.

2. RLS posture: all policies are `{authenticated}`-only with `USING (true)`
   / `WITH CHECK (true)` (permissive within authenticated). Owner-level
   restrictions (Tony + Brynn) are enforced in the JS layer via the
   `OWNER_EMAILS` array, NOT at the database level.

   Future Bucket 2.5 task: promote owner enforcement from JS to RLS via
   `auth.email()` checks across all tables. Until then, this is the agreed
   pattern. Do NOT introduce database-level owner checks for new tables —
   keep them consistent with the JS-layer pattern, then upgrade everything
   together.

3. Owner notification rule: Tony AND Brynn must be notified on ALL stage
   completions and significant events. No exceptions.

4. Every new table needs RLS enabled before first row is written.

5. Schema changes are run manually in the Supabase dashboard SQL editor
   (no migration files yet — that's a planned Bucket 3 item). When you
   propose schema changes, output the SQL as a copy-pasteable block with
   a clear "Run this in Supabase SQL editor" header. Also save a copy to
   `/sql-history/YYYY-MM-DD-description.sql` in the repo with a full
   header comment block (File / Bucket / Author / Date / Purpose / Design
   notes / RLS notes) for the manual paper trail until proper migrations
   land.

6. Owner emails are currently hardcoded as `OWNER_EMAILS` arrays in
   individual HTML files (`detail.html`, `new.html`). Future Bucket 2.5
   task: consolidate to a single exported constant in `tmw-auth.js`. Keep
   them in sync manually for now.

## File layout

Root files:
- `CLAUDE.md` — this file
- `README.md`
- `index.html` — Team Resources home (the team hub)
- `login.html`
- `tmw-auth.js`, `tmw-core.js` — shared foundations
- `.gitignore`

Directories:
- `/auth/` — callback.html (OAuth callback handler)
- `/dashboard/` — admin views (index, team-members, setup-team-members, shot-builder)
- `/weddings/` — wedding project list + detail (index, client.html, timeline wallpapers)
- `/post-production/` — index, plus subfolders photo/, video/, deliverables/
- `/shot-caller/` — shot list builder
- `/shooter-sop/` — shooter SOPs
- `/referrals/` — Bucket 3.1: index (dashboard), new (form), detail (edit/lifecycle)
- `/sql-history/` — manual SQL paper trail

## Owner identifiers
- Tony Martinez — tonyellismartinez@gmail.com
- Brynn Weller — brynn.weller95@gmail.com

## Team members storage
Team data is stored as a JSON array inside `projects.data.members` where
`projects.id = 'tmw_team_members'`. Each member object has at minimum
`name`, `email`, and `active` fields. There is NO separate `team_members`
table — that's a future Bucket 8 (proper relational schema) item.

When code needs to look up a team member (e.g., the referrals on-behalf
override, notification mechanic), query:
`tmwSbFetch('projects?id=eq.tmw_team_members&select=data')` and read
`data.members[]`.

Team admin UI lives at `/dashboard/team-members.html` — use this for
edits, not direct SQL.

## Active work

Completed buckets:
- Bucket 1: Initial portal (pre-2026-04-29)
- Bucket 2: RLS + JWT lockdown (completed 2026-04-29)
- Bucket 3.1: Team Referral Tracker (completed 2026-04-29)

Currently in: Bucket 3 (integrations + team ops). See chat with embedded
COO for current priorities. Next likely items:
- Bucket 2.5 (RLS hardening pass — promote owner checks to database)
- Bucket 3.2 (shared tmw-core.js consolidation)
- Bucket 3.x (Referrals leaderboard — gamification dashboard)

## Don't
- Don't introduce new frameworks (React, Vue, etc.) without asking.
- Don't bypass `tmwSbFetch` for data operations.
- Don't add public/anon RLS policies.
- Don't introduce database-level owner checks until Bucket 2.5 (consistency
  matters more than partial security upgrades).
- Don't commit secrets — keys in `.env.local` only.
- Don't auto-push to main; let Tony review the diff first.
- Don't run schema changes silently. Always surface SQL for Tony to review
  and run in the Supabase dashboard, plus save to `/sql-history/`.
- Don't create new top-level nav links on team home — entry points go
  inside the General column of the Quick Access grid on `/index.html`.
- Don't assume a `team_members` table exists. It doesn't. Team data is
  in JSON inside `projects.data.members`.