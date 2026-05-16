# Wedding Intake Playbook

Adding a new wedding to the TMW OS in one shot. This file exists because
the Marderness intake (w1747252200000, 5/14/2026 session) required too many
back-and-forths to get right. Everything Claude needs to ship the migration,
the wallpaper, and the deploy steps in a single response lives here.

This document is the SOURCE OF TRUTH for intake. If it conflicts with priors
or memory, this file wins. If it conflicts with CLAUDE.md on architecture
(schema shapes, RLS, SQL patterns), CLAUDE.md wins.

---

## Trigger phrases

When Tony says any of these, run this playbook end-to-end before asking
clarifying questions:

- "Add the [Lastname] wedding"
- "Add [Names] to the OS"
- "I need wedding day info for [Names]" + pasted project recap
- "Set up [Names] in the system"
- A pasted HoneyBook-style recap with couple names, date, venue, package

If a questionnaire PDF, Wedding Track Sheet screenshot, or project recap
is attached, that's the full input. Extract everything from it. Do not
ask Tony to retype what's already in the attachments.

---

## One-shot deliverables

Every intake produces, in a single response:

1. **SQL migration** — single block, copy-pasteable into the Supabase SQL editor
2. **Wallpaper PNG** — canonical template, presented via `present_files`
3. **SQL history file** — saved to `/sql-history/YYYY-MM-DD-<couple>-wedding-add.sql`
4. **Deploy steps** — exact git commands (cp, mv, add, commit, push)
5. **Smoke test list** — 4-5 concrete checks
6. **Outstanding items** — anything that didn't fit in OS data (shot list, welcome package, etc.)

If any input is genuinely ambiguous (e.g., couple lastname has multiple
spellings in the source), make one reasonable assumption, ship the
migration with it, and flag it as a one-line correction at the end.

---

## DO NOT produce unless explicitly asked

- Word docs for "wedding day info" (Tony has his own client-facing intake system)
- Updates to the legacy Wedding Track Sheet xlsx (it's reference only, OS is live)
- Per-wedding HTML pages (`/weddings/shot_caller_*.html` etc — those are legacy)
- `tmw_shotlist_<wid>` rows (Tony builds via shot-builder UI)
- Multiple wallpaper variants (one canonical PNG per wedding)

---

## The three OS rows to touch

A new wedding always touches `tmw_weddings`. It MAY also touch `tmw_state`,
`tmw_deliverables`, `tmw_photo`, and `tmw_content` depending on what TM is
covering. Decide based on the package + crew.

### Row 1: `tmw_weddings.data.weddings[]` — ALWAYS

Append a wedding object matching the EXACT shape used by `addWedding()`
in `/weddings/index.html`. Fields:

```
{
  "id": "w<epoch_ms>",
  "client": "First + First Lastname",            // matches addWedding's "Casey + Nick" format
  "date": "YYYY-MM-DD",
  "venue": "Primary venue",
  "venueAddress": "Full street, City, ST ZIP",
  "ceremonyVenue": "",                            // only if different from venue
  "package": "Photo + Video",                     // exact dropdown values below
  "package_code": "XX MMDD",                      // e.g. LJ0515
  "miles": 100,                                   // one-way miles, integer
  "team": {
    "leadPhoto": "", "secondPhoto": "", "photoShadow": "",
    "leadVideo": "", "secondVideo": "", "videoShadow": "",
    "contentCreator": "", "bts": ""
  },
  "vendors": [{ "name": "...", "role": "...", "contact": "..." }],
  "timeline": [{ "time": "1:45 PM", "event": "First look" }],
  "shotList": [],
  "notes": "TEAM-VISIBLE — see notes policy below",
  "deliverables": "freeform package summary string",
  "shotCallerUrl": "/shot-caller/?id=w<epoch_ms>",
  "wallpaperUrl": "/weddings/<lastname>_timeline_wallpaper.png"
}
```

Package dropdown values (exact strings, from `/weddings/index.html`):
`Photo + Video` · `Photo only` · `Video only` · `Photo + Video + Content` · `Content only`

Team values should be short first names only, matching `TMW.teamMembers`
in `tmw-core.js`: Tony, Brynn, Lexi, Zyara, Nick, Nathan, Luke, Zach, PJ,
Nolan, Isabella, Bella, Kaitlyn, Chris, Dylan.

### Row 2: `tmw_state.data.projects[]` — IF VIDEO IS BOOKED

This is the video post-prod queue (NOT `tmw_video` — that table does not exist).
Read by `/post-production/video/index.html`. Schema:

```
{
  "id": "<epoch_ms>",                             // string, same number as wedding minus 'w'
  "client": "First + First Lastname",             // match wedding.client
  "weddingDate": "YYYY-MM-DD",
  "editor": "Tony",                               // lead editor (Tony default unless told otherwise)
  "deliverables": [
    {
      "id": "<epoch_ms>1",
      "name": "10 min highlight",                 // exact options below
      "editor": "Tony",
      "dueDate": "YYYY-MM-DD",
      "stages": {
        "qnas": "not-started",
        "obtained": "not-started",
        "sync": "not-started",
        "edit": "not-started",
        "color": "not-started",
        "deliver": "not-started"
      }
    }
  ]
}
```

Deliverable name options (exact strings, from `DELIVERABLE_OPTIONS` in
`/post-production/video/index.html`):
- `2–3 min highlight`
- `5 min highlight`
- `10 min highlight`
- `30–60 min doc edit`
- `Video book`
- `Custom` (free text — avoid unless package is genuinely unusual)

Stage keys (from `TMW.videoStages.keys` in `tmw-core.js`):
`qnas` · `obtained` · `sync` · `edit` · `color` · `deliver`

Stage values (from `TMW.statusCycle`):
`not-started` · `in-progress` · `complete`

Editor pool (from `TMW.editors`):
`Tony` · `Lexi` · `Zyara` · `Nick` · `Nathan` · `Luke` · `Zach`

Default due dates (relative to wedding date):
- Highlight: **+6 weeks**
- Doc edit: **+6 weeks**
- Video book: **+13 weeks** (physical book turnaround is longer)

Standard deliverable bundle for a typical Highlight + Doc + Video Book package:
1. `10 min highlight` (or `5 min` / `2–3 min` matching the package wording)
2. `30–60 min doc edit`
3. `Video book`

### Row 3: `tmw_deliverables.data.clients[]` — IF ANY DELIVERABLE HAS A DUE DATE

Read by `/post-production/deliverables/index.html`. Calendar view, no
stages, just dates. Schema:

```
{
  "id": "<epoch_ms>",                              // same number as tmw_state project
  "name": "First + First Lastname",
  "weddingDate": "YYYY-MM-DD",
  "sneakPeek": "",                                 // YYYY-MM-DD or "" if N/A
  "photoGallery": "",
  "photoBook": "",
  "highlight": "",
  "doc": "",
  "videoBook": "",
  "contentCreation": ""
}
```

Photo fields stay empty strings on video-only bookings. Same for the inverse.

Defaults from `/post-production/deliverables/index.html` COLS config
(used by `addClient()`):
- sneakPeek: manual, no default
- photoGallery: +2 weeks
- photoBook: +2 weeks
- highlight: +6 weeks
- doc: +6 weeks
- videoBook: +6 weeks (override to +13 weeks for physical book)
- contentCreation: manual

### Row 4: `tmw_photo.data.projects[]` — IF TM IS SHOOTING PHOTO

Only seed `tmw_photo` if TM is the photographer. If photo is outsourced
(e.g. LeAnna Theresa on Marderness), DO NOT seed `tmw_photo`. Add the
outside photographer as a vendor in `tmw_weddings.vendors[]` instead.

Schema is documented in `CLAUDE.md`. Default deliverables for Photo + Video book:
`Sneak peek`, `Photo gallery`, `Photo book`.

### Row 5: `tmw_content.data.projects[]` — IF CONTENT CREATOR IS ASSIGNED

Only if `team.contentCreator` is set. See `/sql-history/2026-05-05-content-creator-stages-seed.sql`
for the canonical seed pattern. Three deliverables per wedding: `Reel 1`,
`Raw Files`, `Important Moments`.

---

## NOTES field policy — CRITICAL

The `notes` field on the wedding object is **TEAM-VISIBLE** at
`team.tmweddings.com/weddings/client.html`. Anyone with access to the
team portal can read it. Treat it like a shooter brief, not a CRM record.

### NEVER put in notes

- Financial totals, balances, payment status
- Welcome package mailing addresses (track these in office workflow)
- HoneyBook IDs or workspace references
- Internal contract dispute or risk-flag language meant for owners only
- Personally-identifying info beyond what the crew needs day-of

### DO put in notes

Capitalized section labels, paragraphs separated by `\n\n` for readability
on the rendered page. Standard sections in order:

1. **COVERAGE TYPE** — one-liner: "VIDEO ONLY booking..." / "PHOTO + VIDEO booking..."
2. **CREW** — roles and times
3. **GETTING READY LOCATIONS** — addresses for both parties
4. **AUDIO** — mic plan, confirmations, restrictions
5. **FLASH** — ceremony space permissions, individual photo notes
6. **STYLE** — couple's stated preferences for the edit
7. **MUST-HAVE MOMENTS** — list separated by commas
8. **FAMILY** — divorces, dynamics, sensitivities for formals planning
9. **SPECIAL NOTES** — discretion items (prior elopement, name changes, etc.)

If the package is multi-day or has unusual logistics, add a
**LOGISTICS** section before SPECIAL NOTES.

---

## Wallpaper canonical template

Match the existing wallpapers in `/weddings/` (DelVecchio, Maggie+Zee,
Patterson-Curry). Do NOT use the web brand teal `#4aacac` — that's the
portal palette, not the wallpaper palette. Wallpapers are print-style.

### Specs (don't deviate)

- **Output dimensions:** 1320 × 2868 (440 × 956 @ 3x device scale)
- **Top reserved area:** ~700px blank cream above the eyebrow (iOS clock + dynamic island overlay)
- **Bottom breathing room:** ~80px below the footer

### Palette

| Role | Hex |
|------|-----|
| Background (cream) | `#faf7f2` |
| Accent lines, eyebrow, sub-text, row-tint base | `#c9a48a` (dusty rose) |
| End times, event sub-descriptions | `#8b5e4a` (deep rose) |
| Event titles, start times, couple names | `#2c2420` (charcoal) |
| Highlight-row wash | `#f5ebe2` (very light dusty rose) |

### Typography

- **Cormorant Garamond Italic** — couple names (size ~112px)
- **DM Sans Medium** — event titles (~44px), eyebrow tracked (~26px),
  start times (~38px)
- **DM Sans Regular** — venue · date subtitle (~34px), end times (~30px),
  event sub-descriptions (~28px), footer tracked (~26px)

Font acquisition (one-time setup):

```bash
mkdir -p ~/work/fonts && cd ~/work
npm pack @fontsource/cormorant-garamond
npm pack @fontsource/dm-sans
# Extract package/files/*-latin-{400,700}-{normal,italic}.woff2
# Convert woff2 → ttf with fontTools:
python3 -c "
from fontTools.ttLib import TTFont
import sys
for woff in sys.argv[1:]:
    f = TTFont(woff); f.flavor = None; f.save(woff.replace('.woff2','.ttf'))
" fonts/*.woff2
```

### Layout

**Header block:**
1. `TM WEDDINGS` eyebrow, centered, dusty rose, ~14px tracked spacing
2. `First & First Lastname` in Cormorant Italic, centered, charcoal
3. `Venue   ·   Month Day, Year` in DM Sans regular, centered, dusty rose
4. Diamond divider: ▪ centered between two thin horizontal lines, ~880px wide

**Timeline block:**
- Two-column layout: time column (left ~230px wide) | event column (right)
- Vertical rule on the right edge of the time column spanning all rows
- Each row ~162px tall
- Times stacked: start time large + charcoal (DM Sans Medium 38), end time smaller + dusty rose (DM Sans Regular 30)
- Event column: title in charcoal (DM Sans Medium 44), optional sub-description below in deep rose (DM Sans Regular 28)
- Thin horizontal hairlines between rows in dusty rose
- Subtle dusty-tint wash background on couple-focused rows — typically rows 1 and 2 of the timeline (First look + Wedding party). Matches the DelVecchio rhythm.

**Footer block:**
- Diamond divider (same as header)
- `TMWEDDINGS.COM` tracked, dusty rose, centered

### Timeline content rules

- Condense the full schedule to 8 to 9 entries that fit in one wallpaper screen
- Each entry: `(start_time, end_time, title, sub_description_or_None)`
- Use the wedding's actual stop times — don't invent durations
- Standard rhythm:
  1. Getting ready
  2. First look + portraits (highlight)
  3. Wedding party / bridal party (highlight)
  4. Family photos
  5. Couple hidden away (capture details)
  6. Ceremony
  7. Cocktail hour
  8. Reception
  9. Sunset + wrap (optional, combine with reception if tight)

### NEVER on the wallpaper

- Taglines hinting at couple secrets (e.g. prior elopement). Tony's phone gets glimpsed by family.
- Financial details, balances, package prices.
- Vendor names or contacts (those live in the wedding object, not the wallpaper).
- Crew names (crew lives in the wedding object).

### Filename

`<lastname-lowercase>_timeline_wallpaper.png`. Commit to `/weddings/`.
Wire to `wallpaperUrl` on the wedding object.

For hyphenated couples: pick the more searchable lastname or join with
underscore (e.g. `patterson_curry_timeline_wallpaper.png`).

---

## ID conventions

Generate ONE epoch_ms timestamp near the current time and derive every
ID from it. This makes traceability across rows trivial.

```
base = 1747252200000   # current epoch ms (UTC), rounded to the minute is fine

wedding.id                    = "w" + base                # e.g. w1747252200000
tmw_state project.id          = str(base)                 # e.g. "1747252200000"
tmw_state deliverable[0].id   = str(base) + "1"           # e.g. "17472522000001"
tmw_state deliverable[1].id   = str(base) + "2"
tmw_state deliverable[2].id   = str(base) + "3"
tmw_deliverables client.id    = str(base)                 # e.g. "1747252200000"
tmw_photo project.id          = str(base)                 # if applicable
tmw_content project wid       = "w" + base                # references wedding.id
```

This matches the addWedding() / addProject() / addDeliverable() conventions
in the HTML files. Avoids collisions with existing simple IDs (w7, w8, w43)
and existing timestamp IDs.

---

## SQL pattern

Use one file per intake. Three to five UPDATE blocks, idempotent, with
verification queries at the bottom.

**Idempotent append pattern** (use this for every array append):

```sql
UPDATE projects
SET data = jsonb_set(
  data,
  '{<array_field>}',
  COALESCE(
    (
      SELECT jsonb_agg(x)
      FROM jsonb_array_elements(data->'<array_field>') AS x
      WHERE x->>'id' != '<new_id>'
    ),
    '[]'::jsonb
  ) || jsonb_build_array(
    $json${ "id": "<new_id>", ... }$json$::jsonb
  )
),
updated_at = NOW()
WHERE id = '<row_id>';
```

This filters out any existing row with the same id (no-op on first run)
and appends the new one. Safe to rerun.

**Dollar-quoting:** Use `$json$...$json$` for JSON literals. Use a
different tag like `$notes$...$notes$` for plain string fields that
contain apostrophes (avoids escape-hell when notes has contractions).

**Header comment block** on every SQL file:

```sql
-- =====================================================================
-- File: YYYY-MM-DD-<couple>-wedding-add.sql
-- Bucket: Wedding intake — <Names> (<date>)
-- Author: Tony Martinez (via embedded COO)
-- Date: YYYY-MM-DD
-- Purpose: <one-paragraph summary of which rows are touched and why>
--
-- ID convention: <epoch_ms used and derivation>
-- Coverage context: <video only / photo only / etc, outside vendors flagged>
-- Pattern: <idempotent append / partial merge / etc>
--
-- RLS notes: No changes. Existing {authenticated} permissive policy applies.
-- =====================================================================
```

**Verification queries** at the bottom — one SELECT per row touched,
confirming the new entry exists and key fields are populated, plus a
sanity-check counts query.

---

## Response template

Use this structure when responding to an intake request. Match the tone
of the Marderness response (5/14/2026): tight diagnosis, no narration of
the search process, direct delivery.

```
Diagnosis: <1-2 sentences confirming the plan>
- Three OS rows: tmw_weddings, tmw_state, tmw_deliverables
- Skipping tmw_photo because <reason> / tmw_content because <reason>
- Crew, package, miles, IDs

[Run the SQL block — full migration, copy-pasteable]

[Present wallpaper PNG via present_files]

[Present SQL file via present_files]

Files touched:
- /sql-history/YYYY-MM-DD-<couple>-wedding-add.sql (new)
- /weddings/<lastname>_timeline_wallpaper.png (new)

Deploy:
cp ~/Downloads/<lastname>_timeline_wallpaper.png weddings/
mv ~/Downloads/YYYY-MM-DD-<couple>-wedding-add.sql sql-history/
git add weddings/<lastname>_timeline_wallpaper.png sql-history/YYYY-MM-DD-<couple>-wedding-add.sql
git commit -m "Add <couple> wedding (<date>) + timeline wallpaper"
git push
Then run the SQL block in the Supabase SQL editor.

Smoke test:
1. /weddings/ — couple appears under Upcoming
2. Click in — wallpaper renders, timeline shows N entries, vendors listed
3. /post-production/video/ — pipeline has couple with N deliverables
4. /post-production/deliverables/ — calendar row shows due dates

Outstanding (not in OS):
- Shot list: populate via shot-builder when ready
- <any other office to-dos>

Flags to double-check:
- <any assumption made that needs Tony's confirmation>
```

---

## Anti-patterns from past sessions

1. **Don't go to the legacy xlsx first.** The Wedding Track Sheet is
   reference-only. Always go to the OS. If Tony pastes a screenshot of
   the xlsx, extract data from it but write the migration against the OS.

2. **Don't make a Word doc unless asked.** Tony has his own client-facing
   intake docs. Generating one wastes a turn.

3. **Don't use the web brand teal for the wallpaper.** Web brand `#4aacac`
   ≠ wallpaper brand. Wallpapers use the cream/rose print palette.

4. **Don't put financials in notes.** Page is team-visible.

5. **Don't ask 5 questions.** Ship with reasonable defaults flagged inline.
   Tony corrects in one pass.

6. **Don't guess at the data row.** Video lives in `tmw_state`, not
   `tmw_video`. Photo in `tmw_photo`. Content in `tmw_content`. Calendar
   in `tmw_deliverables`. Confirm in CLAUDE.md or the relevant HTML file
   before writing SQL.

7. **Don't pre-fetch the same schema info twice.** If `addWedding()` shape
   was already loaded earlier in the conversation, don't search for it
   again. Cache it in the response.

---

## Special cases

### Outside photographer (TM video-only)
- `team.leadPhoto` and `team.secondPhoto` blank
- Add outside photographer as a vendor with role "Photographer (outside TM)"
- Skip `tmw_photo` entirely
- `package` = "Video only"
- `tmw_deliverables` photo columns blank

### Outside videographer (TM photo-only)
- Inverse of above
- Skip `tmw_state` entirely
- `package` = "Photo only"
- `tmw_deliverables` video columns blank

### Content creator coverage
- Set `team.contentCreator` to the creator's short name (default "Lexi")
- Seed `tmw_content` row (see 2026-05-05 seed for canonical pattern)
- Reel deliverable carries a 24hr SLA via `deadline_hours` field

### Multi-day weddings
- Schema has single date/venue/ceremonyVenue fields
- Use the primary day (usually the larger event) as `date` and `venue`
- Use Day 1 venue as `ceremonyVenue` if it differs
- Put full multi-day breakdown in `notes` with `LOGISTICS:` section
- Timeline can span multiple days with `Fri TIME` / `Sat TIME` prefixes
- Reference: `/sql-history/2026-05-05-w8-patterson-curry-FIX.sql`

### Already-eloped couples (or other discretion items)
- Add `SPECIAL NOTES:` section in notes with the discretion ask
- Wallpaper MUST NOT include any tagline hinting at the secret
- Reference: Marderness (w1747252200000) for the canonical treatment

### Destination weddings (>200 miles)
- Flag overnight stay required in notes
- Note hotel arrangement if known
- Confirm coverage hours and travel package terms

---

## Worked example: Marderness intake (5/14/2026)

Inputs Tony provided:
- Couple names, date (Fri 5/15/2026), venue (Seashell Resort, Beach Haven NJ)
- Crew: Tony lead video, Nick S 2nd video, both 12-8pm
- Project recap pasted in chat
- Wedding questionnaire PDF
- Screenshot of legacy Wedding Track Sheet showing miles=227 and package code LJ0515

Decisions made automatically:
- Package = "Video only" (LeAnna Theresa is the photographer, outside TM)
- Skipped `tmw_photo` (no TM photo work)
- Skipped `tmw_content` (no contentCreator)
- Three video deliverables: 10 min highlight, 30–60 min doc edit, Video book
- Due dates: highlight 2026-06-26 (+6w), doc 2026-06-26 (+6w), videoBook 2026-08-14 (+13w)
- Wedding ID `w1747252200000` from epoch ms near the request time
- Notes excluded financials and welcome package address (those are office workflow)
- Wallpaper: 9 timeline rows, couple-focus tint on rows 1-2

Output produced in one response:
- SQL migration touching tmw_weddings, tmw_state, tmw_deliverables
- Wallpaper PNG: `marderness_timeline_wallpaper.png`
- Migration file: `2026-05-14-marderness-wedding-add.sql`
- Deploy steps (cp wallpaper, mv SQL, commit, push, then run SQL)
- 4-step smoke test

Tony's one correction: financials in notes needed redaction. Follow-up
migration: `2026-05-14-marderness-redact-financials.sql`. This file now
documents the notes policy so this won't happen again.

---

## When something doesn't fit this playbook

If the request genuinely falls outside intake (Tony's asking about a
build feature, a bug, a refactor, a schema change), drop the playbook
and respond per the standard TMW Architect rules in CLAUDE.md.

If the intake itself is unusual (single-day destination wedding for an
existing client, package change mid-engagement, etc.), use the playbook
defaults as a baseline and flag what's different inline.
