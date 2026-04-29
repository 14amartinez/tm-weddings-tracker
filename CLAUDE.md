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
- Repo: github.com/14amartinez/tm-weddings-tracker

## Architecture rules — DO NOT VIOLATE
1. All Supabase calls go through `tmwSbFetch` (in `tmw-auth.js`). Never the
   raw publishable key. JWT-aware path only.
2. All RLS policies are `{authenticated}`-only. No anon access. Owners
   (Tony + Brynn) get elevated privileges via email check or custom claim.
3. Owner notification rule: Tony AND Brynn must be notified on ALL stage
   completions and significant events. No exceptions.
4. Every new table needs RLS enabled before first row is written.
5. Schema changes are run manually in the Supabase dashboard SQL editor
   (no migration files yet — that's a planned Bucket 3 item). When you
   propose schema changes, output the SQL as a copy-pasteable block with
   a clear "Run this in Supabase SQL editor" header. Also save a copy to
   `/sql-history/YYYY-MM-DD-description.sql` in the repo so we have a
   manual paper trail until proper migrations land.

## File layout
- `/dashboard/` — admin views (team mgmt, shot builder)
- `/weddings/` — wedding project list + detail
- `/shot-caller/` — shot list builder
- `/post-production/photo/` — photo edit queue
- `/post-production/video/` — video edit queue
- `/post-production/deliverables/` — gallery/album delivery
- `tmw-auth.js`, `tmw-core.js` — shared foundations
- `/sql-history/` — manual SQL paper trail (created on first schema change)

## Owner identifiers
- Tony Martinez — tonyellismartinez@gmail.com
- Brynn Weller — brynn.weller95@gmail.com

## Active work
See chat with embedded COO for current bucket priorities. Bucket 2 (RLS +
JWT lockdown) complete as of 2026-04-29. Currently entering Bucket 3.
First Bucket 3 build: Team Referral Tracker.

## Don't
- Don't introduce new frameworks (React, Vue, etc.) without asking.
- Don't bypass `tmwSbFetch`.
- Don't add public/anon RLS policies.
- Don't commit secrets — keys in `.env.local` only.
- Don't auto-push to main; let me review the diff first.
- Don't run schema changes silently. Always surface SQL for me to review
  and run in the Supabase dashboard.
