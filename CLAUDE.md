# TM Weddings Portal — Claude Context

## Audience

This file is loaded into multiple Claude projects. Behave according to the
project you're in:

- **Coding-Claude (TMW Architect):** All architecture rules, schemas, and
  Don'ts apply. Treat the "Wedding intake workflow" and similar operator
  workflow sections as informational context — they describe what
  COO-Claude does, not what you do.
- **COO-Claude:** All sections apply, including operator workflows. For
  wedding intake specifically, defer to `WEDDING_INTAKE.md` at the repo
  root — it's the canonical playbook and wins on intake details.
- **Other Claude projects:** Read for context, defer to your own project
  instructions for behavior.

When this file conflicts with hardcoded constants in HTML files (e.g.
`OWNER_EMAILS` arrays), **this file is the source of truth** — update the
HTML to match.

When this file conflicts with `WEDDING_INTAKE.md` on intake specifics
(deliverable defaults, exact ID conventions, package strings, response
template), `WEDDING_INTAKE.md` wins. For architecture (schema shapes, RLS,
SQL patterns), this file wins.

## What this is

Internal post-production portal for TM Weddings (wedding photo/video co.,
Lehigh Valley PA). Live at team.tmweddings.com. Used by photo editors
(Tony, Brynn), video editors (full team), shooters, content creators,
and marketing-role users.

## Stack

- Frontend: vanilla HTML/CSS/JS, no framework, no bundler, no build step
- Each route is a self-contained `.html` with inline `<style>` and
  `<script>`; imports are `tmw-auth.js` and `tmw-core.js` only
- Backend: Supabase (Postgres + Auth + RLS) — project ref `rafygjaemcjhnououmwn`
- Auth: Supabase Auth via `auth.tmweddings.com` (custom domain, JWT-based)
- Hosting: Vercel auto-deploy from `main`
- Notifications: EmailJS (service `service_qoodzdb`, template `template_p1hyj87`)
  - NOTE: `template_p1hyj87` was originally a post-production stage template.
    The referrals feature reuses it by mapping fields. A dedicated referrals
    template is on the polish list.
- Repo: github.com/14amartinez/tm-weddings-tracker
- Related docs at repo root: `WEDDING_INTAKE.md` (intake playbook),
  `AUDIT-2026-05-16.md` (point-in-time architecture audit)

## Architecture rules — DO NOT VIOLATE

1. All Supabase calls go through `tmwSbFetch` (in `tmw-auth.js`). Never the
   raw publishable key for data operations. JWT-aware path only.

2. Any data fetch on a page must wait for auth to populate before firing.
   The codebase exposes `window.TMW_USER` once auth is loaded. The standard
   pattern is:

   ```js
   async function waitForUser(timeoutMs = 4000) {
     const start = Date.now();
     while (Date.now() - start < timeoutMs) {
       if (window.TMW_USER) return window.TMW_USER;
       await new Promise(r => setTimeout(r, 50));
     }
     return window.TMW_USER || null;
   }
   ```

   Reference implementation: the `waitForUser()` function inside the
   `<script>` block of `dashboard/build-calendar/index.html`.

3. **Auth idioms — TWO valid patterns coexist** (DRY violation, will be
   reconciled in Bucket 2.6):

   **Pattern A — direct property checks (most common today):**
   ```js
   if (TMW_USER.isOwner)  { ... }
   if (TMW_USER.isAdmin)  { ... }
   if (TMW_USER.isEditor) { ... }
   ```

   **Pattern B — helper functions (defined in `tmw-auth.js`):**
   ```js
   if (tmwHasRole('owner'))      { ... }
   if (tmwHasRole('admin'))      { ... }
   if (tmwCanAccess('editor'))   { ... }
   ```

   Both check the same underlying role data. When adding new code, **match
   the pattern of the surrounding file** rather than introducing the
   other one. Bucket 2.6 will pick one and migrate everything. Do NOT
   introduce a third idiom.

   **Name-collision warning:** `tmwIsAdmin(sessionKey)` exists in
   `tmw-core.js` but does NOT check user roles. It checks a sessionStorage
   flag for whether the legacy admin-password UI is unlocked on a given
   page. Don't use it as a role check. Bucket 2.6 will rename or remove it.

   **Legacy admin password:** `TMW.admin.password` in `tmw-core.js` gates
   "admin mode" in several post-prod pages. Visible in DevTools to anyone
   who opens Source. Provides no real security — the actual gate is
   `TMW_USER.isOwner`. Scheduled for removal in Bucket 2.6.

4. RLS posture: all policies are `{authenticated}`-only with `USING (true)`
   / `WITH CHECK (true)` (permissive within authenticated). Owner-level
   restrictions (Tony + Brynn) are enforced in the JS layer via the
   auth idioms above, NOT at the database level.

   Future Bucket 2.5 task: promote owner enforcement from JS to RLS via
   `auth.email()` checks across all tables. Until then, this is the agreed
   pattern. Do NOT introduce database-level owner checks for new tables —
   keep them consistent with the JS-layer pattern, then upgrade everything
   together.

5. Owner notification rule: Tony AND Brynn must be notified on ALL stage
   completions and significant events. No exceptions.

   **Current implementation reality (per 2026-05-16 audit):** `tmwNotify()`
   in `tmw-core.js` exists as the centralized helper but is called zero
   times. Every post-prod page reimplements `emailjs.send` inline with its
   own (inconsistent) recipient list. Bucket 2.6/2.7 task: consolidate.
   Until then, if you add a notification, verify the inline implementation
   in the relevant page actually includes both Tony and Brynn.

6. Every new table needs RLS enabled before first row is written.

7. Schema changes are run manually in the Supabase dashboard SQL editor
   (no migration files yet — that's a planned Bucket 3 item). When you
   propose schema changes, output the SQL as a copy-pasteable block with
   a clear "Run this in Supabase SQL editor" header. Also save a copy to
   `/sql-history/YYYY-MM-DD-description.sql` in the repo with a full
   header comment block (File / Bucket / Author / Date / Purpose / Design
   notes / RLS notes / Rollback notes) for the manual paper trail until
   proper migrations land.

8. **Allowlists and owner emails — multiple sources, must be kept in sync:**

   Today, owner/team allowlists are scattered. Audit 2026-05-16 confirmed
   the full inventory:

   - `tmw-auth.js` — `EMERGENCY_OWNERS` (Tony + Brynn, fallback only)
   - `auth/callback.html` — `APPROVED_EMAILS` (full team, ~16 emails;
     **de-facto login gate** that runs before `tmw-auth.js` ever sees the
     user). New teammates require an edit here + a Supabase row + a deploy.
   - `tmw-core.js` — `TMW.notify.{tony,brynn,lexi}`
   - 7 feature pages, each with their own `OWNER_EMAILS` /
     `TMW_OWNER_EMAILS` / `EDITOR_EMAILS` constants:
     `post-production/photo/index.html`, `post-production/video/index.html`,
     `post-production/deliverables/index.html`,
     `post-production/content/index.html`,
     `dashboard/build-calendar/index.html`, `referrals/new.html`,
     `referrals/detail.html`

   Bucket 2.5 consolidates everything into exports from `tmw-auth.js`
   backed by live `tmw_team_members` lookups. Until then: keep them in
   sync manually. **If a hardcoded `OWNER_EMAILS` array disagrees with
   the Owner identifiers section of this file, this file is the source
   of truth — update the HTML.**

9. **Folder = feature.** New features get their own top-level folder
   (e.g. `/referrals/`, `/shot-caller/`, `/marketing/`,
   `/post-production/content/`). Don't nest features under existing
   folders unless they're sub-views of that feature.

## File layout

Root files:
- `CLAUDE.md` — this file
- `WEDDING_INTAKE.md` — canonical wedding intake playbook (for COO-Claude)
- `AUDIT-2026-05-16.md` — point-in-time architecture audit snapshot
- `README.md`
- `index.html` — Team Resources home (the team hub)
- `login.html`
- `tmw-auth.js`, `tmw-core.js` — shared foundations
- `.gitignore`

Directories:
- `/auth/` — `callback.html` (OAuth callback handler; contains the
  de-facto login allowlist — see rule #8)
- `/dashboard/` — admin views
  - `index.html` — admin dashboard home
  - `team-members.html`, `setup-team-members.html`, `shot-builder.html`
  - `build-calendar/index.html` — owner-only TMW OS production planning dashboard
- `/marketing/` — `index.html` — marketing onboarding hub (~1.9k lines);
  gated to marketing-role users via path-restriction redirect
- `/weddings/` — wedding project list + detail
  - `index.html` — wedding list + admin (canonical `addWedding()` schema)
  - `client.html` — per-wedding detail view
  - `shot_caller_<descriptive>.html` — legacy static shot callers (being
    migrated to dynamic)
  - `<descriptive>_timeline_wallpaper.png` — per-couple lock-screen renders
- `/post-production/`
  - `index.html` — post-prod hub
  - `photo/index.html`
  - `video/index.html` — reads `tmw_state` (yes, video lives in
    `tmw_state` — see "The `projects` table" section)
  - `deliverables/index.html` — client-facing due-date calendar
  - `content/index.html` — content creator workflow (shipped 5/5)
- `/shot-caller/` — `index.html` — dynamic shot list builder (`?id=<wid>`)
- `/shooter-sop/` — `index.html` — role-by-role shooter SOPs
- `/referrals/`
  - `index.html` — dashboard
  - `new.html` — submission form
  - `detail.html` — edit/lifecycle
  - `program.html` — public-facing program description
- `/sql-history/` — manual SQL paper trail (idempotent UPDATE patterns,
  one file per session/change)
- `/tm-reels/` — Remotion project (separate stack; not currently wired
  into the portal; pending decision: integrate or extract to its own repo)

## The `projects` table — key-value app store

The `projects` table is a key-value store, NOT a relational projects list.
Schema: `id text PRIMARY KEY, data jsonb, updated_at timestamptz`. Each
row represents a different app section/module:

- `tmw_weddings` — master wedding list (array of weddings inside `data.weddings[]`)
- `tmw_team_members` — team roster (array inside `data.members[]`)
- `tmw_shotlist_<wid>` — per-wedding dynamic shot caller (one row per wedding)
- `tmw_photo` — photo post-prod state (read by `/post-production/photo/`)
- `tmw_state` — **video post-prod state** (read by `/post-production/video/`).
  Row is misleadingly named `tmw_state` — it stores the video projects
  queue with the same shape as `tmw_photo`. Planned cleanup: destructive
  rename to `tmw_video`, queued but not yet scheduled. Until then, all
  code expects `tmw_state` — any SQL or fetch must use the current name.
- `tmw_content` — content creator post-prod state (read by
  `/post-production/content/`; shipped 5/5; see its data architecture
  section below). Mirrors `tmw_photo` shape with two important
  differences: foreign-key field is `wid` (direct wedding ID), and stages
  are nested status objects, not flat strings.
- `tmw_deliverables` — client-facing due-date ledger (per-client deliverable dates)
- `tmw_build_plan` — Build Calendar dashboard data (buckets, anchors, cost model)

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

**Canonical wedding object shape:** see the `addWedding()` function in
`/weddings/index.html`. Field names are camelCase: `leadPhoto`,
`secondPhoto`, `contentCreator`, `bts`, etc. — NOT snake_case. If you're
writing SQL that creates a new wedding, open that function first and
copy the shape verbatim. `WEDDING_INTAKE.md` documents it for reference,
but the HTML is the source of truth.

## tmw_photo data architecture

`tmw_photo` holds photo post-production state. Structure:

```
tmw_photo.data = {
  "projects": [
    {
      "id": "p1",
      "client": "Casey Gruver",
      "editor": "Brynn",
      "weddingDate": "2026-04-11",
      "deliverables": [
        {
          "id": "p1d1",
          "name": "Sneak peek",
          "editor": "Brynn",
          "stages": { "qnas": "complete", "obtained": "complete", ... }
        },
        {
          "id": "p1d2",
          "name": "Photo gallery",
          "editor": "Brynn",
          "stages": { "qnas": "complete", "edit": "complete", ... }
        },
        {
          "id": "p1d3",
          "name": "Photo book",
          "editor": "Brynn",
          "stages": { "qnas": "complete", "design": "complete", ... }
        }
      ]
    },
    ...
  ]
}
```

**Key facts about this row:**
- Projects are array elements keyed by `id` (e.g. `p1`, `p2`)
- Each project has a `deliverables` array
- Deliverables are keyed by `name` (e.g. "Sneak peek", "Photo gallery", "Photo book")
- **There is NO `type` field on deliverables** — filter by `name`
- Stages live inside a `stages` sub-object on each deliverable
- Stage values are strings: `"complete"`, `"in-progress"`, `"not-started"`
- Stage keys are short identifiers — exact lists:
  - Photo (sneak peek + gallery + anything that isn't a book):
    `qnas`, `obtained`, `cull`, `edit`, `export`, `deliver`
  - Photo book: `qnas`, `obtained`, `selections`, `design`, `ordered`
- Labels are mapped in the `TMW.photoStages` / `TMW.bookStages` constants
  in `tmw-core.js` AND in the `PHOTO_STAGES`/`BOOK_STAGES` constants in
  `post-production/photo/index.html` (see "Stage labels" section)
- **No `wid` field.** Links to weddings only by `client` string match.
  Renaming a client in `tmw_weddings` breaks the link silently. Fix-it
  ticket: add `wid` to `tmw_photo` and `tmw_state` (bundled with Bucket 8).

To query a specific deliverable:
```sql
SELECT d.value
FROM projects p,
     jsonb_array_elements(p.data->'projects') proj,
     jsonb_array_elements(proj->'deliverables') d
WHERE p.id = 'tmw_photo'
  AND proj->>'client' = 'Casey Gruver'
  AND d.value->>'name' = 'Photo book';
```

## tmw_state (video) data architecture

`tmw_state` is the video post-prod queue. Same shape as `tmw_photo`,
different stage keys and deliverable names. Structure:

```
tmw_state.data = {
  "projects": [
    {
      "id": "<epoch_ms>",
      "client": "First + First Lastname",
      "weddingDate": "YYYY-MM-DD",
      "editor": "Tony",
      "deliverables": [
        {
          "id": "<epoch_ms>1",
          "name": "10 min highlight",
          "editor": "Tony",
          "dueDate": "YYYY-MM-DD",
          "stages": {
            "qnas":     "not-started",
            "obtained": "not-started",
            "sync":     "not-started",
            "edit":     "not-started",
            "color":    "not-started",
            "deliver":  "not-started"
          }
        }
      ]
    }
  ]
}
```

**Stage keys** (from `TMW.videoStages.keys` in `tmw-core.js`):
`qnas` · `obtained` · `sync` · `edit` · `color` · `deliver`

**Deliverable name options** (from `DELIVERABLE_OPTIONS` in
`/post-production/video/index.html`): `2–3 min highlight` ·
`5 min highlight` · `10 min highlight` · `30–60 min doc edit` ·
`Video book` · `Custom`

**Editor pool** (from `TMW.editors`): `Tony` · `Lexi` · `Zyara` · `Nick`
· `Nathan` · `Luke` · `Zach`

Same `client`-string-match limitation as `tmw_photo` — no `wid` foreign key.

## tmw_deliverables data architecture

DIFFERENT from `tmw_photo` and `tmw_state`. This is the **client-facing
due-date ledger**, not stage tracking. Structure:

```
tmw_deliverables.data = {
  "clients": [
    {
      "id": "1",
      "name": "Casey Gruver",
      "weddingDate": "2026-04-11",
      "sneakPeek": "2026-04-12",
      "photoGallery": "2026-04-27",
      "highlight": "2026-05-25",
      "doc": "2026-05-25",
      "photoBook": "2026-05-27",
      "videoBook": "2026-06-25",
      "contentCreation": ""
    },
    ...
  ]
}
```

Each client object has fields for each deliverable type with the **due date**
(or empty string if not applicable for that package). This is what powers
the `/post-production/deliverables/` calendar view. **It does NOT track
stages or completion** — only dates.

## tmw_content data architecture

NEW row, shipped 2026-05-05. Different from `tmw_photo` and `tmw_state`
in two important ways:

1. **Foreign key:** has a `wid` field that links directly to
   `tmw_weddings.data.weddings[].id`. No client-string-match required.
2. **Stage shape:** stages are nested objects with audit metadata, not
   flat strings.

Structure:

```
tmw_content.data = {
  "projects": [
    {
      "wid": "w7",
      "client": "Maggie + Zee Haroon",
      "date": "2026-05-03",
      "editor": "Lexi",
      "deliverables": [
        {
          "name": "Reel 1",
          "type": "reel",
          "flow": "quick_turn",
          "received_at": null,
          "deadline_hours": 24,
          "stages": {
            "edit":      { "status": "pending", "completed_at": null, "completed_by": null },
            "approved":  { "status": "pending", "completed_at": null, "completed_by": null },
            "delivered": { "status": "pending", "completed_at": null, "completed_by": null }
          }
        },
        {
          "name": "Raw Files",
          "type": "raw",
          "stages": {
            "received":   { "status": "pending", "completed_at": null, "completed_by": null },
            "organizing": { "status": "pending", "completed_at": null, "completed_by": null },
            "delivered":  { "status": "pending", "completed_at": null, "completed_by": null }
          }
        },
        {
          "name": "Important Moments",
          "type": "moments",
          "stages": {
            "received":  { "status": "pending", "completed_at": null, "completed_by": null },
            "curating":  { "status": "pending", "completed_at": null, "completed_by": null },
            "delivered": { "status": "pending", "completed_at": null, "completed_by": null }
          }
        }
      ]
    }
  ]
}
```

**Stage status values:** `pending`, `complete` (different vocab from
photo/video, which use `not-started` / `in-progress` / `complete`). Don't
mix the two.

**Deliverable types:** `reel` (quick_turn flow with 24hr SLA), `raw`,
`moments`. Hardcoded in `/post-production/content/index.html` — not yet
in `tmw-core.js`.

**24hr SLA on reels:** the `deadline_hours: 24` field combined with the
`received_at` timestamp drives the deadline-pulse UI (yellow at 18hr,
red+pulsing past 24hr).

To query a single content project:
```sql
SELECT p.value
FROM projects, jsonb_array_elements(data->'projects') p
WHERE id = 'tmw_content' AND p.value->>'wid' = 'w7';
```

When seeding new content projects, see
`/sql-history/2026-05-05-content-creator-stages-seed.sql` for the
canonical idempotent append pattern (BLOCK 2 in that file).

**Schema convergence target:** Bucket 3.2 + the eventual relational split
(Bucket 8) will harmonize `tmw_photo`, `tmw_state`, and `tmw_content` on
the `tmw_content` shape (nested status objects with `completed_at` /
`completed_by` audit fields, `wid` foreign keys). Don't introduce more
flat-string stage data on new tables.

## Stage labels — hardcoded in JS

Stage display labels for photo and video live in **three places** (DRY
violation, will be consolidated in Bucket 3.2):

1. The `TMW.photoStages` / `TMW.bookStages` / `TMW.videoStages` constants
   in `tmw-core.js` — central config (`.keys` and `.labels` arrays)
2. The `PHOTO_STAGES` / `PHOTO_STAGE_KEYS` / `BOOK_STAGES` /
   `BOOK_STAGE_KEYS` constants in `post-production/photo/index.html`
3. The `STAGES` / `STAGE_KEYS` constants in
   `post-production/video/index.html`

Content stages are separate and live ONLY in
`/post-production/content/index.html` (not yet in `tmw-core.js`).

When changing photo or video stage names, ALL three sites must be updated
together AND the underlying short keys in `tmw_photo` / `tmw_state` may
need migration. Do NOT ship label changes without a coordinated data
migration.

## Shot caller conventions

Two patterns coexist:

**Dynamic (default for new weddings):** `/shot-caller/?id=<wid>` — reads
`tmw_shotlist_<wid>` from the database. The `addWedding()` function in
`/weddings/index.html` auto-wires `shotCallerUrl` to this on every new
wedding. No HTML file build required.

**Static (legacy / special builds):** `/weddings/shot_caller_<descriptive>.html`
— hand-built HTML file committed to the repo. Used for early weddings
(Maggie+Zee Haroon) and one-off special cases. Migration target: move
all of these to dynamic over time.

When in doubt, build dynamic.

## Wallpaper conventions

Per-couple iPhone lock screen timeline wallpapers are committed as
PNGs to `/weddings/<descriptive>_timeline_wallpaper.png` and wired
into the wedding object via `wallpaperUrl`.

**Render specs (use Playwright):**
- Viewport: `440 × 956` at `device_scale_factor=3`
- Output dimensions: `1320 × 2868` PNG
- Top `295px` reserved for iOS lock-screen clock overlay (no critical content)
- Wait `2000ms` before screenshot (web fonts must load)
- Source template: `/home/claude/timeline_wallpaper.html`

**Visual style:**
- Palette: cream `#faf7f2`, dusty rose `#c9a48a`, deep rose `#8b5e4a`,
  charcoal `#2c2420`
- Typography: Cormorant Garamond italic (display) + DM Sans (body)
- Flex rows fill remaining vertical space below the reserved 295px

Currently a manual step per wedding (PNG render → commit → admin sets
`wallpaperUrl`). Auto-wire is a queued roadmap item.

## Owner identifiers
- Tony Martinez — tonyellismartinez@gmail.com
- Brynn Weller — brynn.weller95@gmail.com

These are the OWNERS. Additional team members with login access live in
`tmw_team_members.data.members[]` AND (until Bucket 2.5 consolidation
lands) also in the `APPROVED_EMAILS` array in `auth/callback.html`. The
callback allowlist is broader than this owners list — it covers the full
authorized team, not just owners.

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

**Onboarding friction (until Bucket 2.5 lands):** Adding a new teammate
requires THREE actions, not one:
1. Add row in `tmw_team_members` via `/dashboard/team-members.html`
2. Add email to `APPROVED_EMAILS` in `auth/callback.html`
3. Commit + push (Vercel auto-deploys)

The page lies about step 1 being sufficient. Bucket 2.5 fixes this by
making `callback.html` fetch `tmw_team_members` live.

## Build Calendar dashboard

Owner-only TMW OS production planning view at `/dashboard/build-calendar/`.
Reads from `projects` row with id = `tmw_build_plan`. **This dashboard is
the source of truth for current bucket status, roadmap, and project
value.** Do NOT maintain a parallel "Active Work" list elsewhere — query
the dashboard or the `tmw_build_plan` row directly.

**Schema of `tmw_build_plan.data`:**
```js
{
  updated_at: "ISO date",
  cost_model: {
    rates: { high: 450, mid: 300, low: 175 },  // $/hr
    agency_multiplier: 2.5,                     // PM/QA/revisions overhead
    monthly_actual_cost_usd: 56,
    build_started_month: "2026-01",
    narrative: "..."
  },
  anchors: [
    { label, date: "ISO", kind: "launch"|"deadline"|"risk"|"season"|"build" }
  ],
  buckets: [
    {
      id: "stable_short_id",
      name: "...",
      category: "security"|"foundation"|"feature"|"integration"|"polish"|"launch",
      rate_tier: "high"|"mid"|"low",
      status: "shipped"|"in_progress"|"queued"|"on_hold",
      priority: 1|2|3,
      quarter: "Q2-2026"|"Q3-2026"|"Q4-2026"|"Q1-2027",
      target_date: "ISO" | null,
      shipped_date: "ISO" | null,
      estimated_hours: number,
      dependencies: ["other_bucket_id", ...],
      notes: "free text"
    }
  ]
}
```

**Updates flow through chat-with-COO.** Tony tells COO what changed, COO
generates UPDATE SQL + sql-history file. Dashboard is read-only.

**Cost calculation:** dashboard renders `hours × rate × multiplier` per
bucket. Tier rates and multiplier come from `cost_model` in the data row.

## Wedding intake workflow

**Canonical source: `WEDDING_INTAKE.md` at the repo root.** That file is
the SOURCE OF TRUTH for intake — exact field shapes, deliverable
defaults, package strings, ID conventions, multi-day patterns, response
template, and worked examples. If anything below conflicts, that file wins.

High-level summary: new weddings and updates flow through chat-with-COO
(NOT Cowork — Cowork is overkill for structured data entry). Tony pastes
intake, COO returns SQL + wallpaper PNG + `/sql-history/` file. ~30
seconds end-to-end per wedding.

The bulk freeform intake admin page is a queued roadmap item that will
eventually replace this flow with a single-step UI.

## Verification queries

When you doubt the schema or want to confirm state, run these in the
Supabase SQL editor before guessing:

```sql
-- Confirm the projects key-value pattern and list all rows
SELECT id, jsonb_typeof(data) AS data_type, updated_at
FROM projects
ORDER BY id;

-- Count weddings
SELECT jsonb_array_length(data->'weddings') AS wedding_count
FROM projects WHERE id = 'tmw_weddings';

-- Count photo projects
SELECT jsonb_array_length(data->'projects') AS photo_project_count
FROM projects WHERE id = 'tmw_photo';

-- Count video projects (lives in tmw_state, not tmw_video)
SELECT jsonb_array_length(data->'projects') AS video_project_count
FROM projects WHERE id = 'tmw_state';

-- Count content projects
SELECT jsonb_array_length(data->'projects') AS content_project_count
FROM projects WHERE id = 'tmw_content';

-- Count team members
SELECT jsonb_array_length(data->'members') AS member_count
FROM projects WHERE id = 'tmw_team_members';

-- Count build buckets by status
SELECT
  bucket->>'status' AS status,
  COUNT(*) AS n
FROM projects, jsonb_array_elements(data->'buckets') bucket
WHERE id = 'tmw_build_plan'
GROUP BY 1
ORDER BY 1;

-- List all per-wedding shot list rows
SELECT id, updated_at FROM projects WHERE id LIKE 'tmw_shotlist_%';

-- Inspect RLS on a table
SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'projects';
```

If a query disagrees with what this file says, the database wins. Open
a question with Tony before writing code that assumes either side.

## Common breakages / troubleshooting

- **Blank page after login** → auth not populated. Page is fetching data
  before `window.TMW_USER` exists. Wrap fetches in `await waitForUser()`.
- **`401` from Supabase on a request** → JWT expired or missing.
  Refresh the page, or re-login at `/login.html`.
- **`403` from Supabase on a request that should work** → RLS rejecting
  the call. Confirm the policy is `{authenticated}` not `{public}`, and
  that the user has a valid session.
- **"Cannot read property X of undefined" on a wedding object** →
  Either a wedding ID typo or the wedding hasn't been added to
  `tmw_weddings.data.weddings[]` yet. Verify with the wedding count
  query above.
- **New teammate can't log in** → likely missing from `APPROVED_EMAILS`
  in `auth/callback.html`. Check there first, then `tmw_team_members`.
  Both are required until Bucket 2.5 ships.
- **Stage value not rendering correctly in `/post-production/photo/`** →
  Likely a label/key mismatch. Check the three places labels are defined
  (see "Stage labels" section). The data uses short keys; the UI maps
  to display labels.
- **Stage updates silently disappear** → lost-update bug. Every post-prod
  page PATCHes the entire `projects.data` array on every edit. Concurrent
  edits (two people on the same row within ~30s) silently overwrite.
  Workaround until Bucket 2.5: don't edit the same client simultaneously
  with another editor. Real fix: `If-Match` on `updated_at` (cheap) or
  per-entity rows (Bucket 8, expensive).
- **EmailJS notification didn't send** → Check that both Tony and Brynn
  were in the recipient list (rule #5). Check EmailJS dashboard for the
  service quota — `service_qoodzdb` has a monthly cap. Remember:
  `tmwNotify()` in `tmw-core.js` is NOT the actual notification path
  today; check the inline `emailjs.send` call in the relevant page.
- **Vercel didn't auto-deploy after push** → Confirm push hit `main`
  branch, not a feature branch. Check Vercel dashboard for build errors.

## Don't

**Architectural:**
- Don't introduce new frameworks (React, Vue, etc.) without asking.
- Don't bypass `tmwSbFetch` for data operations.
- Don't add public/anon RLS policies.
- Don't introduce database-level owner checks until Bucket 2.5 (consistency
  matters more than partial security upgrades).
- Don't introduce a third auth-checking idiom. Match the existing file's
  pattern (Pattern A or Pattern B). Don't use `tmwIsAdmin()` from
  `tmw-core.js` as a role check — it's the legacy sessionStorage flag,
  not a role helper.
- Don't fetch data without waiting for `window.TMW_USER` to populate.
- Don't build static shot caller HTML for new weddings — use dynamic.
- Don't change stage labels in `tmw-core.js` or post-production HTML
  without a coordinated data migration of stage keys in `tmw_photo` /
  `tmw_state`.
- Don't add new deliverable types using flat-string stage values. New
  stage data should use the `tmw_content` shape (nested
  `{status, completed_at, completed_by}` objects).
- Don't introduce new `OWNER_EMAILS` / `EDITOR_EMAILS` constants in new
  files. Wait for Bucket 2.5 or extend an existing one and document the
  duplicate in this file.

**Data assumptions:**
- Don't assume a `team_members` table exists. It doesn't. Team data is
  in JSON inside `projects.data.members`.
- Don't assume weddings are separate rows. They're array elements inside
  `tmw_weddings.data.weddings[]`.
- Don't assume photo books / galleries / sneak peeks are top-level rows.
  They're deliverables inside `tmw_photo.projects[].deliverables[]`,
  filtered by `name`.
- Don't assume video lives in a `tmw_video` row. It lives in `tmw_state`
  for historical reasons; rename is queued, not shipped.
- Don't assume `tmw_photo` and `tmw_state` link to weddings by `wid` —
  they only link by `client` string match today. Renaming a client
  silently breaks the link.

**Process:**
- Don't commit secrets — keys in `.env.local` only. The EmailJS public
  key is fine; service-role keys are not.
- Don't auto-push to main; let Tony review the diff first.
- Don't run schema changes silently. Always surface SQL for Tony to review
  and run in the Supabase dashboard, plus save to `/sql-history/`.
- Don't create new top-level nav links on team home — entry points go
  inside the General column of the Quick Access grid on `/index.html`.
- Don't maintain a parallel "active work" or "roadmap" list outside of
  `tmw_build_plan` — that row is the source of truth.
- Don't invent schema. Open the relevant HTML/JS file (e.g.
  `addWedding()` in `/weddings/index.html` for wedding shape) and copy
  the field names verbatim. CamelCase, not snake_case.
