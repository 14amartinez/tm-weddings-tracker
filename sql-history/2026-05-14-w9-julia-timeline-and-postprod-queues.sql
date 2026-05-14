-- =====================================================================
-- File: 2026-05-14-w9-julia-timeline-and-postprod-queues.sql
-- Bucket: wedding_intake (w9 update + post-prod queue patch)
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-14
-- Purpose: Update w9 Julia (5/16/26) with Saturday timeline from
--          photographer PDF, rename client to bride-and-groom convention,
--          set ceremony venue + shotCallerUrl, patch the existing
--          tmw_photo entry (p8) with wid/client/editor + deliverables,
--          fill the existing tmw_deliverables row for Julia (id="8")
--          with the three blank deliverable due dates, and seed
--          tmw_shotlist_w9 from the baseline template.
--
-- IMPORTANT — discovery during this session:
-- - tmw_photo already had a Julia entry at id="p8" (pre-wid-convention,
--   wid=null, client="Julia Swayser", weddingDate=2026-05-16). The
--   original BLOCK 2 (APPEND new project) correctly no-op'd via the
--   idempotency guard. Block was rewritten as a PATCH against p8.
-- - Existing tmw_deliverables row id="8" already had sneakPeek +
--   photoBook set. BLOCK 3 fills the three blanks.
--
-- Source:
-- - Photographer PDF "Julia & Ethan Gilbert 5.16.26-2 - Sheet1.pdf"
-- - Existing w9 in tmw_weddings (Brynn lead photo, Lexi 2nd photo,
--   Parque at Ridley Creek reception, 112mi, JE0516, Photo+Video)
-- - Baseline shot list = getBaselineTemplate() in dashboard/shot-builder.html
--
-- What's updated:
-- - tmw_weddings.w9:
--     client → "Julia & Ethan Gilbert"
--     ceremonyVenue → "Parque at Ridley Creek" (same as reception)
--     shotCallerUrl → "/shot-caller/?id=w9"
--     timeline → 9 blocks from PDF (single start times)
--     venueAddress: NOT set (not in PDF; fill when known)
--
-- - tmw_photo.projects[] (PATCH existing p8 — not append):
--     wid → "w9"
--     client → "Julia & Ethan Gilbert"
--     editor → "Brynn"
--     deliverables → 6 entries IFF current deliverables array is empty
--       (Sneak peek, Photo gallery, Photo book, Highlight, Doc, Video book)
--     Stage keys per tmw-core.js photoStages/bookStages/videoStages.
--     Photo editor = Brynn. Video editor = "" (no leadVideo assigned
--     2 days from shoot — KNOWN GAP, must be filled before 5/16).
--
-- - tmw_deliverables.clients[] (UPDATE existing id="8"):
--     name → "Julia & Ethan Gilbert"
--     highlight → "2026-06-29"
--     doc → "2026-06-29"
--     videoBook → "2026-07-30"
--     (sneakPeek + photoBook already correct, untouched)
--
-- - tmw_shotlist_w9 (NEW row): baseline template, 5 locations,
--     8 shot groups, 7 briefing cards. Timeline briefing card
--     pre-filled from the PDF blocks.
--
-- Skipped: tmw_content — w9 has no team.contentCreator assigned.
--
-- Idempotency:
-- - BLOCK 1: deterministic merge via jsonb `||`. Safe to re-run.
-- - BLOCK 2: PATCH against id="p8". Metadata patch is deterministic;
--   deliverables array only set when currently empty (so re-running
--   after manual stage progress won't blow it away).
-- - BLOCK 3: deterministic merge via jsonb `||`. Safe to re-run.
-- - BLOCK 4: ON CONFLICT DO NOTHING on PK. No-op on rerun.
--
-- RLS notes:
-- - No RLS changes. Existing {authenticated} permissive policy on
--   `projects` applies. Owner enforcement remains in JS per CLAUDE.md #3.
-- =====================================================================

-- ─── BLOCK 1 ── w9 wedding object: client, ceremonyVenue, timeline, shotCallerUrl
UPDATE projects
SET data = jsonb_set(data, '{weddings}', (
  SELECT jsonb_agg(
    CASE
      WHEN w->>'id' = 'w9' THEN w || $j${
        "client": "Julia & Ethan Gilbert",
        "ceremonyVenue": "Parque at Ridley Creek",
        "shotCallerUrl": "/shot-caller/?id=w9",
        "timeline": [
          {"time": "12:00 PM", "event": "Bride/groom details"},
          {"time": "12:30 PM", "event": "Getting ready / into dress"},
          {"time": "1:15 PM",  "event": "First look + couples photos"},
          {"time": "2:00 PM",  "event": "Bridal party (together + separate)"},
          {"time": "2:30 PM",  "event": "Family photos"},
          {"time": "3:00 PM",  "event": "Couple hidden pre-ceremony"},
          {"time": "3:30 PM",  "event": "Ceremony"},
          {"time": "4:00 PM",  "event": "Cocktail hour — extended family / missed photos; couple takes a break"},
          {"time": "5:00 PM",  "event": "Reception (until 8:00 PM)"}
        ]
      }$j$::jsonb
      ELSE w
    END
  )
  FROM jsonb_array_elements(data->'weddings') w
)),
updated_at = NOW()
WHERE id = 'tmw_weddings';

-- ─── BLOCK 2 (REWRITTEN) ── PATCH existing tmw_photo entry p8
--      Sets metadata (wid/client/editor) and adds deliverables IFF
--      p8.deliverables is currently empty/missing.
UPDATE projects
SET data = jsonb_set(data, '{projects}', (
  SELECT jsonb_agg(
    CASE
      WHEN p->>'id' = 'p8' THEN
        p
        || $j${"wid":"w9","client":"Julia & Ethan Gilbert","editor":"Brynn"}$j$::jsonb
        || jsonb_build_object(
             'deliverables',
             CASE
               WHEN jsonb_array_length(COALESCE(p->'deliverables','[]'::jsonb)) = 0
                 THEN $j$[
                   {"id":"p8_d1","name":"Sneak peek","editor":"Brynn",
                    "stages":{"qnas":"not-started","obtained":"not-started","cull":"not-started","edit":"not-started","export":"not-started","deliver":"not-started"}},
                   {"id":"p8_d2","name":"Photo gallery","editor":"Brynn",
                    "stages":{"qnas":"not-started","obtained":"not-started","cull":"not-started","edit":"not-started","export":"not-started","deliver":"not-started"}},
                   {"id":"p8_d3","name":"Photo book","editor":"Brynn",
                    "stages":{"qnas":"not-started","obtained":"not-started","selections":"not-started","design":"not-started","ordered":"not-started"}},
                   {"id":"p8_d4","name":"Highlight","editor":"",
                    "stages":{"qnas":"not-started","obtained":"not-started","sync":"not-started","edit":"not-started","color":"not-started","deliver":"not-started"}},
                   {"id":"p8_d5","name":"Doc","editor":"",
                    "stages":{"qnas":"not-started","obtained":"not-started","sync":"not-started","edit":"not-started","color":"not-started","deliver":"not-started"}},
                   {"id":"p8_d6","name":"Video book","editor":"",
                    "stages":{"qnas":"not-started","obtained":"not-started","sync":"not-started","edit":"not-started","color":"not-started","deliver":"not-started"}}
                 ]$j$::jsonb
               ELSE p->'deliverables'
             END
           )
      ELSE p
    END
  )
  FROM jsonb_array_elements(data->'projects') p
)),
updated_at = NOW()
WHERE id = 'tmw_photo';

-- ─── BLOCK 3 ── UPDATE existing Julia row in tmw_deliverables (id="8")
UPDATE projects
SET data = jsonb_set(data, '{clients}', (
  SELECT jsonb_agg(
    CASE
      WHEN c->>'id' = '8' OR c->>'name' ILIKE 'Julia%' THEN c || $j${
        "name": "Julia & Ethan Gilbert",
        "highlight": "2026-06-29",
        "doc":       "2026-06-29",
        "videoBook": "2026-07-30"
      }$j$::jsonb
      ELSE c
    END
  )
  FROM jsonb_array_elements(data->'clients') c
)),
updated_at = NOW()
WHERE id = 'tmw_deliverables';

-- ─── BLOCK 4 ── Seed tmw_shotlist_w9 from baseline template
INSERT INTO projects (id, data, updated_at)
VALUES (
  'tmw_shotlist_w9',
  $j${
    "locations": [
      {"id":"hotel","name":"Hotel / Getting ready","color":"#c9a48a","time":"","note":"Bridal + groom prep, details, first looks with parents."},
      {"id":"venue_pre","name":"Venue — pre ceremony","color":"#9aac99","time":"","note":"Family formals + bridal party portraits before ceremony. Keep bride/groom sides separate if no first look."},
      {"id":"ceremony","name":"Ceremony","color":"#b8a9c9","time":"","note":"Processional, vows, recessional."},
      {"id":"cocktail","name":"Cocktail hour","color":"#8fa8a0","time":"","note":"Couple portraits + extended family while guests enjoy cocktail hour."},
      {"id":"reception","name":"Reception","color":"#d4a878","time":"","note":"Grand entrance through last dance."}
    ],
    "shotGroups": [
      {"group":"Bridal details","loc":"hotel","shots":[
        {"id":1,"name":"Wedding dress on hanger","must":true},
        {"id":2,"name":"Bride's shoes","must":true},
        {"id":3,"name":"Bride's jewelry","must":true},
        {"id":4,"name":"Engagement ring + wedding bands together","must":true},
        {"id":5,"name":"Bride's bouquet","must":true},
        {"id":6,"name":"Veil details","must":true},
        {"id":7,"name":"Invitation suite","must":false}
      ]},
      {"group":"Bride getting ready","loc":"hotel","shots":[
        {"id":10,"name":"Finishing touches — hair","must":true},
        {"id":11,"name":"Bride + bridesmaids in PJs/robes","must":true},
        {"id":12,"name":"Putting on the veil","must":true},
        {"id":13,"name":"Bridesmaids helping bride into dress","must":true},
        {"id":14,"name":"Mom helping with dress","must":true},
        {"id":15,"name":"Bride looking at herself in mirror","must":true},
        {"id":16,"name":"Bride + bridesmaids group shots","must":true}
      ]},
      {"group":"Groom details + getting ready","loc":"hotel","shots":[
        {"id":20,"name":"Suit + shoes","must":true},
        {"id":21,"name":"Watch + cufflinks","must":true},
        {"id":22,"name":"Boutonniere","must":true},
        {"id":23,"name":"Groom + groomsmen putting on suits","must":true},
        {"id":24,"name":"Groom fixing tie","must":true},
        {"id":25,"name":"Groomsmen group shots","must":true},
        {"id":26,"name":"Groom solo portraits","must":true}
      ]},
      {"group":"Family formals + bridal party","loc":"venue_pre","shots":[
        {"id":30,"name":"Bride + bridesmaids posed","must":true},
        {"id":31,"name":"Groom + groomsmen posed","must":true},
        {"id":32,"name":"Bride's immediate family","must":true},
        {"id":33,"name":"Groom's immediate family","must":true},
        {"id":34,"name":"Bride + grandparents","must":true},
        {"id":35,"name":"Groom + grandparents","must":true}
      ]},
      {"group":"Ceremony","loc":"ceremony","shots":[
        {"id":40,"name":"Front altar + decor wide","must":true},
        {"id":41,"name":"Guests being seated","must":true},
        {"id":42,"name":"Family processional — grandparents, parents","must":true},
        {"id":43,"name":"Bridal party processional","must":true},
        {"id":44,"name":"Groom's reaction seeing bride","must":true},
        {"id":45,"name":"Bride + dad walking down aisle","must":true},
        {"id":46,"name":"Vow exchange","must":true},
        {"id":47,"name":"Ring exchange","must":true},
        {"id":48,"name":"First kiss","must":true},
        {"id":49,"name":"Recessional","must":true}
      ]},
      {"group":"Couple + bridal party portraits","loc":"cocktail","shots":[
        {"id":60,"name":"Bride solo portraits","must":true},
        {"id":61,"name":"Groom solo portraits","must":true},
        {"id":62,"name":"Bride + groom traditional","must":true},
        {"id":63,"name":"Bride + groom candid","must":true},
        {"id":64,"name":"Bride + groom kissing","must":true},
        {"id":65,"name":"Full bridal party group","must":true},
        {"id":66,"name":"Bridal party candids","must":true}
      ]},
      {"group":"Extended family + couple portraits","loc":"cocktail","shots":[
        {"id":70,"name":"Bride + groom with both sets of parents","must":true},
        {"id":71,"name":"Bride + groom with siblings","must":true},
        {"id":72,"name":"Bride + groom with grandparents","must":true}
      ]},
      {"group":"Reception events","loc":"reception","shots":[
        {"id":80,"name":"Full room reception wide","must":true},
        {"id":81,"name":"Grand entrance","must":true},
        {"id":82,"name":"First dance","must":true},
        {"id":83,"name":"Father/daughter dance","must":true},
        {"id":84,"name":"Mother/son dance","must":true},
        {"id":85,"name":"Speeches/toasts","must":true},
        {"id":86,"name":"Cake cutting","must":true},
        {"id":87,"name":"Party dancing + candids","must":true},
        {"id":88,"name":"Dessert table","must":false}
      ]}
    ],
    "briefing": [
      {"label":"Timeline","color":"#c9a48a","text":"<strong>12:00 PM</strong> — Bride/groom details<br><strong>12:30 PM</strong> — Getting ready / into dress<br><strong>1:15 PM</strong> — First look + couples photos<br><strong>2:00 PM</strong> — Bridal party<br><strong>2:30 PM</strong> — Family photos<br><strong>3:00 PM</strong> — Couple hidden pre-ceremony<br><strong>3:30 PM</strong> — Ceremony<br><strong>4:00 PM</strong> — Cocktail hour<br><strong>5:00 PM</strong> — Reception<br><strong>8:00 PM</strong> — Photographers depart"},
      {"label":"Key people — bride side","color":"#9aac99","text":"<strong>Julia</strong> = bride<br><strong>[Father]</strong> = father of bride<br>..."},
      {"label":"Key people — groom side","color":"#9aac99","text":"<strong>Ethan</strong> = groom<br><strong>[Father]</strong> = father of groom<br>..."},
      {"label":"Bridal party","color":"#c9a48a","text":"<strong>Bridesmaids:</strong><br><strong>Groomsmen:</strong>"},
      {"label":"Ceremony entrance order","color":"#b8a9c9","text":"1. Officiant<br>2. Grandparents<br>3. Parents<br>4. ..."},
      {"label":"Reception order","color":"#d4a878","text":"Grand entrance order:<br>First dance song:<br>Parent dance songs:"},
      {"label":"Critical logistics","color":"#c9a48a","text":"· Day-of coordinator: [name + phone]<br>· Venue: Parque at Ridley Creek (112 mi)<br>· Lead Photo: Brynn · 2nd Photo: Lexi<br>· Lead Video: UNASSIGNED — confirm before 5/16"}
    ]
  }$j$::jsonb,
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- ─── VERIFY ── target p8 directly
SELECT
  (SELECT w.value->>'client'                              FROM projects, jsonb_array_elements(data->'weddings') w WHERE id='tmw_weddings'     AND w.value->>'id'='w9')          AS w9_client,
  (SELECT jsonb_array_length(w.value->'timeline')         FROM projects, jsonb_array_elements(data->'weddings') w WHERE id='tmw_weddings'     AND w.value->>'id'='w9')          AS w9_timeline_count,
  (SELECT w.value->>'shotCallerUrl'                       FROM projects, jsonb_array_elements(data->'weddings') w WHERE id='tmw_weddings'     AND w.value->>'id'='w9')          AS w9_shot_caller_url,
  (SELECT p.value->>'wid'                                 FROM projects, jsonb_array_elements(data->'projects') p WHERE id='tmw_photo'        AND p.value->>'id'='p8')          AS p8_wid,
  (SELECT p.value->>'client'                              FROM projects, jsonb_array_elements(data->'projects') p WHERE id='tmw_photo'        AND p.value->>'id'='p8')          AS p8_client,
  (SELECT jsonb_array_length(p.value->'deliverables')     FROM projects, jsonb_array_elements(data->'projects') p WHERE id='tmw_photo'        AND p.value->>'id'='p8')          AS p8_deliv_count,
  (SELECT c.value->>'name'                                FROM projects, jsonb_array_elements(data->'clients')  c WHERE id='tmw_deliverables' AND c.value->>'id'='8')           AS deliv_name,
  (SELECT c.value->>'videoBook'                           FROM projects, jsonb_array_elements(data->'clients')  c WHERE id='tmw_deliverables' AND c.value->>'id'='8')           AS deliv_videobook,
  (SELECT jsonb_array_length(data->'shotGroups')          FROM projects                                            WHERE id='tmw_shotlist_w9')                                   AS shotlist_groups;
-- Expect: "Julia & Ethan Gilbert" | 9 | "/shot-caller/?id=w9" | "w9" | "Julia & Ethan Gilbert" | 6 | "Julia & Ethan Gilbert" | "2026-07-30" | 8
