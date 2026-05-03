# TM Weddings Portal — Claude Context

## What this is
Internal post-production portal for TM Weddings (wedding photo/video co.,
Lehigh Valley PA). Live at team.tmweddings.com. Used by photo editors
(Tony, Brynn) and video editors (full team), plus shooters and content
creators day-of.

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

2. Any data fetch on a page must `await whenUserReady()` before firing.
   RLS requires the JWT to be loaded, and racing the auth load causes
   silent "Loading..." hangs. This is the precedent set by the index.html
   fix on 2026-05-02.

3. RLS posture: all policies are `{authenticated}`-only with `USING (true)`
   / `WITH CHECK (true)` (permissive within authenticated). Owner-level
   restrictions (Tony + Brynn) are enforced in the JS layer via the
   `OWNER_EMAILS` array, NOT at the database level.

   Future Bucket 2.5 task: promote owner enforcement from JS to RLS via
   `auth.email()` checks across all tables. Until then, this is the agreed
   pattern. Do NOT introduce database-level owner checks for new tables —
   keep them consistent with the JS-layer pattern, then upgrade everything
   together.

4. Owner notification rule: Tony AND Brynn must be notified on ALL stage
   completions and significant events. No exceptions.

5. Every new table needs RLS enabled before first row is written.

6. Schema changes are run manually in the Supabase dashboard SQL editor
   (no migration files yet — that's a planned Bucket 3 item). When you
   propose schema changes, output the SQL as a copy-pasteable block with
   a clear "Run this in Supabase SQL editor" header. Also save a copy to
   `/sql-history/YYYY-MM-DD-description.sql` in the repo with a full
   header comment block (File / Bucket / Author / Date / Purpose / Design
   notes / RLS notes) for the manual paper trail until proper migrations
   land.

7. Owner emails are currently hardcoded as `OWNER_EMAILS` arrays in
   individual HTML files (`detail.html`, `new.html`). Future Bucket 2.5
   task: consolidate to a single exported constant in `tmw-auth.js`. Keep
   them in sync manually for now.

## The `projects` table — key-value app store

The `projects` table is a key-value store, NOT a relational projects list.
Schema: `id text PRIMARY KEY, data jsonb, updated_at timestamptz`. Each
row represents a different app section/module:

- `tmw_weddings` — master wedding list (array of weddings inside `data.weddings[]`)
- `tmw_team_members` — team roster (array inside `data.members[]`)
- `tmw_shotlist_<wid>` — per-wedding dynamic shot caller (one row per wedding)
- `tmw_photo` — photo post-prod state
- `tmw_deliverables` — deliverables tracker
- `tmw_state` — misc app state

When code needs data from a section, query by exact id:
`tmwSbFetch('projects?id=eq.tmw_weddings&select=data')`.

## Wedding data architecture

Weddings are array elements inside `tmw_weddings.data.weddings[]`, NOT
separate rows. Each wedding object is keyed by `id` (e.g. `w6`, `w7`).

To query a single wedding from SQL:
```sql
SELECT w.value
FROM projects, jsonb_array_elements(data->'weddings') w
WHERE id = 'tmw_weddings' AND w.value->>'id' = 'w7';
```

To update a single wedding (preserves all other weddings):
```sql
UPDATE projects
SET data = jsonb_set(
  data,
  '{weddings}',
  (
    SELECT jsonb_agg(
      CASE WHEN w.value->>'id' = 'w7'
        THEN w.value || '<merge_object>'::jsonb
        ELSE w.value
      END
    )
    FROM jsonb_array_elements(data->'weddings') w
  )
)
WHERE id = 'tmw_weddings';
```

Use PostgreSQL dollar-quoting (`$json$...$json$`) for JSON literals to
avoid escape-hell in the Supabase SQL editor.

Per-wedding shot lists live in their own row: `tmw_shotlist_<wid>` (e.g.
`tmw_shotlist_w7`). Do NOT nest shot lists inside the wedding object —
they're large and have their own update cadence.

## Shot caller conventions

Two patterns coexist:

**Dynamic (default for new weddings):** `/shot-caller/?id=<wid>` — reads
`tmw_shotlist_<wid>` from the database. `addWedding()` in
`/weddings/index.html` auto-wires `shotCallerUrl` to this on every new
wedding. No HTML file build required.

**Static (legacy / special builds):** `/weddings/shot_caller_<descriptive>.html`
— hand-built HTML file committed to the repo. Used for early weddings
(Mallory standard) and one-off special cases. Migration target: move
all of these to dynamic over time.

When in doubt, build dynamic.

## Wallpaper conventions

Per-couple iPhone lock screen timeline wallpapers are committed as
PNGs to `/weddings/<descriptive>_timeline_wallpaper.png` and wired
into the wedding object via `wallpaperUrl`. Rendered with Playwright
(`device_scale_factor=3`, viewport `440×956`, `wait 2000ms`).

Currently a manual step per wedding (PNG render → commit → admin sets
`wallpaperUrl`). Auto-wire is a queued roadmap item.

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
- `/weddings/` — wedding project list + detail (index, client.html, per-couple shot callers + timeline wallpapers)
- `/post-production/` — index, plus subfolders photo/, video/, deliverables/
- `/shot-caller/` — dynamic shot list builder (`?id=<wid>`)
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

## Wedding intake workflow

New weddings and wedding updates flow through chat-with-COO (this Claude
context), NOT Cowork. Cowork is overkill for structured data entry.

**Format Tony pastes:**
```
Wedding: <id>
Couple: <names>
Date: <YYYY-MM-DD>
Coverage: <start>-<end>
Team: lead photo=X, 2nd photo=Y, lead video=Z, content=W
Venue (ceremony): ...
Venue (reception): ...
Timeline: <freeform>
Notes: <anything else>
```

**COO returns:**
- Preview SQL (read what's already there)
- UPDATE SQL (ready-to-paste merge)
- `/sql-history/YYYY-MM-DD-<description>.sql` file content for the paper trail

~30 seconds end-to-end per wedding update. The bulk freeform intake
page is a queued roadmap item that will eventually replace this flow.

## Active work

Completed buckets:
- Bucket 1: Initial portal (pre-2026-04-29)
- Bucket 2: RLS + JWT lockdown (completed 2026-04-29)
- Bucket 3.1: Team Referral Tracker (completed 2026-04-29)

Recently shipped (2026-05-02):
- w7 Zee & Maggie Haroon wedding added (May 3 shoot, single crew, 94-shot dynamic shot caller)
- index.html "Loading..." bug fixed (raw fetch → tmwSbFetch + whenUserReady gate)
- /weddings/index.html: shotCallerUrl auto-wires to dynamic shot caller on every new wedding

Currently in: Bucket 3 (integrations + team ops). Next likely items:
- Bucket 2.5 (RLS hardening — promote owner checks to database)
- Bucket 2.6 (role-based access control — Owner > Admin > Editor > Shooter)
- Bucket 3.2 (shared tmw-core.js consolidation)
- Bucket 3.x (Referrals leaderboard — gamification dashboard)
- Calendar dashboard in /dashboard/ for owner preview of wedding dates + post-prod stages

Queued (non-urgent):
- Migrate static shot callers to dynamic (eliminate per-wedding HTML)
- Bulk freeform wedding intake page (~1.5 hrs)
- Wallpaper hosting auto-suggest in admin UI
- Auto-set wallpaperUrl on file commit (Vercel build hook or convention)
- Wilbur Mansion venueAddress backfill

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
- Don't assume weddings are separate rows. They're array elements inside
  `tmw_weddings.data.weddings[]`.
- Don't fetch data without `await whenUserReady()` first.
- Don't build static shot caller HTML for new weddings — use dynamic.