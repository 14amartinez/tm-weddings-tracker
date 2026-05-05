# TM Weddings Portal — Claude Context

## Audience

This file is loaded into multiple Claude projects. Behave according to the
project you're in:

- **Coding-Claude (TMW Architect):** All architecture rules, schemas, and
  Don'ts apply. Treat the "Wedding intake workflow" and similar operator
  workflow sections as informational context — they describe what
  COO-Claude does, not what you do.
- **COO-Claude:** All sections apply, including operator workflows.
- **Other Claude projects:** Read for context, defer to your own project
  instructions for behavior.

When this file conflicts with hardcoded constants in HTML files (e.g.
`OWNER_EMAILS` arrays), **this file is the source of truth** — update the
HTML to match.

## What this is
Internal post-production portal for TM Weddings (wedding photo/video co.,
Lehigh Valley PA). Live at team.tmweddings.com. Used by photo editors
(Tony, Brynn) and video editors (full team), plus shooters and content
creators day-of.

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
    template is on the polish list. Field mapping for the reused template
    is not yet documented here — TODO in next polish pass.
- Repo: github.com/14amartinez/tm-weddings-tracker

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

   **Pattern A — direct property checks (used in `index.html` General column):**
   ```js
   if (TMW_USER.isOwner) { ... }
   if (TMW_USER.isAdmin) { ... }
   ```

   **Pattern B — helper functions (defined in `tmw-core.js`):**
   ```js
   if (tmwIsAdmin()) { ... }
   if (tmwHasRole('owner')) { ... }
   if (tmwHasRole('admin')) { ... }
   ```

   Both check the same underlying state. When adding new code, **match
   the pattern of the surrounding file** rather than introducing the
   other one. Bucket 2.6 will pick one and migrate everything. Do NOT
   introduce a third idiom.

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

6. Every new table needs RLS enabled before first row is written.

7. Schema changes are run manually in the Supabase dashboard SQL editor
   (no migration files yet — that's a planned Bucket 3 item). When you
   propose schema changes, output the SQL as a copy-pasteable block with
   a clear "Run this in Supabase SQL editor" header. Also save a copy to
   `/sql-history/YYYY-MM-DD-description.sql` in the repo with a full
   header comment block (File / Bucket / Author / Date / Purpose / Design
   notes / RLS notes) for the manual paper trail until proper migrations
   land.

8. Owner emails are currently hardcoded as `OWNER_EMAILS` arrays in
   individual HTML files (e.g. `referrals/detail.html`, `referrals/new.html`,
   `dashboard/build-calendar/index.html`). Future Bucket 2.5 task:
   consolidate to a single exported constant in `tmw-auth.js`. Keep them
   in sync manually for now. **If a hardcoded `OWNER_EMAILS` array
   disagrees with the Owner identifiers section of this file, this file
   is the source of truth — update the HTML.**

9. **Folder = feature.** New features get their own top-level folder
   (e.g. `/referrals/`, `/shot-caller/`). Don't nest features under
   existing folders unless they're sub-views of that feature.

## File layout

Root files:
- `CLAUDE.md` — this file
- `README.md`
- `index.html` — Team Resources home (the team hub)
- `login.html`
- `tmw-auth.js`, `tmw-core.js` — shared foundations
- `.gitignore`

Directories:
- `/auth/` — `callback.html` (OAuth callback handler)
- `/dashboard/` — admin views
  - `index.html` — admin dashboard home
  - `team-members.html`, `setup-team-members.html`, `shot-builder.html`
  - `build-calendar/index.html` — owner-only TMW OS production planning dashboard
- `/weddings/` — wedding project list + detail (index, client.html, per-couple shot callers + timeline wallpapers)
- `/post-production/` — index, plus subfolders `photo/`, `video/`, `deliverables/`
- `/shot-caller/` — dynamic shot list builder (`?id=<wid>`)
- `/shooter-sop/` — shooter SOPs
- `/referrals/` — index (dashboard), `new.html` (form), `detail.html` (edit/lifecycle)
- `/sql-history/` — manual SQL paper trail

## The `projects` table — key-value app store

The `projects` table is a key-value store, NOT a relational projects list.
Schema: `id text PRIMARY KEY, data jsonb, updated_at timestamptz`. Each
row represents a different app section/module:

- `tmw_weddings` — master wedding list (array of weddings inside `data.weddings[]`)
- `tmw_team_members` — team roster (array inside `data.members[]`)
- `tmw_shotlist_<wid>` — per-wedding dynamic shot caller (one row per wedding)
- `tmw_photo` — photo + content creator post-prod state (see structure below)
- `tmw_deliverables` — client-facing due-date ledger (per-client deliverable dates)
- `tmw_state` — misc app state
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
- Stage keys are short identifiers (e.g. `qnas`, `obtained`, `edit`, `cull`,
  `export`, `deliver`, `design`, `selections`, `order`) — NOT the human-
  readable labels. Labels are mapped in the `STAGES` constant in
  `tmw-core.js` and in the `PHOTO_STAGES`/`BOOK_STAGES` constants in
  `post-production/photo/index.html`.

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

## tmw_deliverables data architecture

DIFFERENT from `tmw_photo`. This is the **client-facing due-date ledger**,
not stage tracking. Structure:

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

## Stage labels — hardcoded in JS

Stage display labels live in **three places** (DRY violation, will be
consolidated in Bucket 3.2):

1. The `STAGES` constant in `tmw-core.js` — central config object
2. The `PHOTO_STAGES` and `BOOK_STAGES` constants in `post-production/photo/index.html`
3. The `STAGES` constant in `post-production/video/index.html`

When changing stage names, ALL of these must be updated together AND
the underlying short keys in `tmw_photo` data may need migration. Do NOT
ship label changes without coordinated data migration.

## Shot caller conventions

Two patterns coexist:

**Dynamic (default for new weddings):** `/shot-caller/?id=<wid>` — reads
`tmw_shotlist_<wid>` from the database. The `addWedding()` function in
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

New weddings and wedding updates flow through chat-with-COO (the COO
project), NOT Cowork. Cowork is overkill for structured data entry.

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
- **Stage value not rendering correctly in `/post-production/photo/`** →
  Likely a label/key mismatch. Check the three places labels are defined
  (see "Stage labels" section). The data uses short keys; the UI maps
  to display labels.
- **EmailJS notification didn't send** → Check that both Tony and Brynn
  were in the recipient list (rule #5). Check EmailJS dashboard for the
  service quota — `service_qoodzdb` has a monthly cap.
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
  pattern (Pattern A or Pattern B).
- Don't fetch data without waiting for `window.TMW_USER` to populate.
- Don't build static shot caller HTML for new weddings — use dynamic.
- Don't change stage labels in `tmw-core.js` or post-production HTML
  without a coordinated data migration of stage keys in `tmw_photo`.

**Data assumptions:**
- Don't assume a `team_members` table exists. It doesn't. Team data is
  in JSON inside `projects.data.members`.
- Don't assume weddings are separate rows. They're array elements inside
  `tmw_weddings.data.weddings[]`.
- Don't assume photo books / galleries / sneak peeks are top-level rows.
  They're deliverables inside `tmw_photo.projects[].deliverables[]`,
  filtered by `name`.

**Process:**
- Don't commit secrets — keys in `.env.local` only.
- Don't auto-push to main; let Tony review the diff first.
- Don't run schema changes silently. Always surface SQL for Tony to review
  and run in the Supabase dashboard, plus save to `/sql-history/`.
- Don't create new top-level nav links on team home — entry points go
  inside the General column of the Quick Access grid on `/index.html`.
- Don't maintain a parallel "active work" or "roadmap" list outside of
  `tmw_build_plan` — that row is the source of truth.