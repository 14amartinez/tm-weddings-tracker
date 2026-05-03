-- =====================================================================
-- File: 2026-05-02-seed-build-plan.sql
-- Bucket: Build Calendar Dashboard (owner-only production planning)
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-02
-- Purpose: Seed the tmw_build_plan key in the projects table with the
--          current roadmap (buckets, ship dates, status, dependencies,
--          notes, hours estimates) so the new /dashboard/build-calendar/
--          page has data to render. Read-only from the dashboard;
--          updates flow through chat-with-COO.
--
-- Design notes:
-- - Lives in the existing `projects` key-value store (id text + data jsonb).
--   No new table — consistent with tmw_weddings, tmw_team_members, etc.
-- - Schema:
--     {
--       updated_at: ISO date,
--       anchors: [ {label, date, kind} ],   -- launch dates, caps, season peaks
--       buckets: [ {
--         id: 'b2_5',
--         name: 'RLS Hardening Pass',
--         category: 'security' | 'foundation' | 'feature' | 'integration' | 'polish' | 'launch',
--         status: 'shipped' | 'in_progress' | 'queued' | 'on_hold',
--         priority: 1 | 2 | 3,            -- 1 = top of queue
--         quarter: 'Q2-2026' | 'Q3-2026' | 'Q4-2026' | 'Q1-2027',
--         target_date: '2026-05-15' | null,
--         shipped_date: '2026-04-29' | null,
--         estimated_hours: 4.5,
--         dependencies: ['b2_6'],
--         notes: 'free text',
--       } ]
--     }
--
-- RLS notes:
-- - projects table already has RLS enabled with {authenticated} permissive
--   policies. No new policies needed. Owner-only visibility is enforced
--   in the JS layer on the dashboard page (per CLAUDE.md rule #3).
-- =====================================================================

INSERT INTO projects (id, data, updated_at)
VALUES (
  'tmw_build_plan',
  $json${
    "updated_at": "2026-05-02",
    "anchors": [
      {"label": "EmailJS quota cap", "date": "2026-05-09", "kind": "risk"},
      {"label": "Peak season starts", "date": "2026-05-15", "kind": "season"},
      {"label": "App Store submit deadline", "date": "2026-08-18", "kind": "deadline"},
      {"label": "Public launch — 2027 bookings", "date": "2026-09-01", "kind": "launch"},
      {"label": "Season wind-down", "date": "2026-10-15", "kind": "season"},
      {"label": "Off-season build window opens", "date": "2027-01-05", "kind": "build"},
      {"label": "First 2027 weddings shoot", "date": "2027-04-15", "kind": "season"}
    ],
    "buckets": [
      {
        "id": "b1",
        "name": "Initial Portal",
        "category": "foundation",
        "status": "shipped",
        "priority": 1,
        "quarter": "Q1-2026",
        "target_date": null,
        "shipped_date": "2026-04-15",
        "estimated_hours": null,
        "dependencies": [],
        "notes": "Original team.tmweddings.com build — base portal, post-prod tracker, shooter SOPs."
      },
      {
        "id": "b2",
        "name": "RLS + JWT Lockdown",
        "category": "security",
        "status": "shipped",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": null,
        "shipped_date": "2026-04-29",
        "estimated_hours": null,
        "dependencies": ["b1"],
        "notes": "All Supabase calls routed through tmwSbFetch with JWT. Permissive {authenticated} RLS."
      },
      {
        "id": "b3_1",
        "name": "Team Referral Tracker",
        "category": "feature",
        "status": "shipped",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": null,
        "shipped_date": "2026-04-29",
        "estimated_hours": null,
        "dependencies": ["b2"],
        "notes": "Dashboard, log form, lifecycle/payout tracking. Dylan’s $250 backfilled. First Cowork-validated build."
      },
      {
        "id": "w7_intake",
        "name": "w7 Zee & Maggie Haroon Intake",
        "category": "feature",
        "status": "shipped",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": null,
        "shipped_date": "2026-05-02",
        "estimated_hours": 0.5,
        "dependencies": [],
        "notes": "Full wedding populate + 94-shot dynamic shot caller + index.html Loading bug fixed + auto-wire shotCallerUrl on new weddings."
      },
      {
        "id": "emailjs_decision",
        "name": "EmailJS Quota Decision",
        "category": "polish",
        "status": "queued",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": "2026-05-09",
        "shipped_date": null,
        "estimated_hours": 0.5,
        "dependencies": [],
        "notes": "Caps May 9 at 200/mo, ~80 used. Upgrade tier OR migrate to Resend/Postmark. Notifications are load-bearing — don't lapse."
      },
      {
        "id": "volume_check",
        "name": "Post-Prod Volume Readiness Check",
        "category": "polish",
        "status": "queued",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": "2026-05-10",
        "shipped_date": null,
        "estimated_hours": 0.5,
        "dependencies": [],
        "notes": "Render times, filter performance, query patterns at projected 25+ active project load before season hits hard."
      },
      {
        "id": "b2_5",
        "name": "RLS Hardening — Owner Checks at DB",
        "category": "security",
        "status": "queued",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": "2026-05-22",
        "shipped_date": null,
        "estimated_hours": 1.5,
        "dependencies": ["b2"],
        "notes": "Promote OWNER_EMAILS JS checks to RLS via auth.email(). Recommended combined with b2_6."
      },
      {
        "id": "b2_6",
        "name": "Role-Based Access Control",
        "category": "security",
        "status": "queued",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": "2026-05-22",
        "shipped_date": null,
        "estimated_hours": 3,
        "dependencies": ["b2_5"],
        "notes": "Owner > Admin > Editor > Shooter hierarchy. Role-check helper in tmw-auth.js. UI hiding + page redirects + RLS extension. Combine with b2_5 for one ~4-5hr Cowork session."
      },
      {
        "id": "build_calendar",
        "name": "Build Calendar Dashboard",
        "category": "feature",
        "status": "in_progress",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": "2026-05-02",
        "shipped_date": null,
        "estimated_hours": 1.5,
        "dependencies": [],
        "notes": "Owner-only production planning view. Roadmap quarters + kanban. Read-only; updates flow through chat. THIS DASHBOARD."
      },
      {
        "id": "referrals_emailjs_template",
        "name": "Referrals-specific EmailJS Template",
        "category": "polish",
        "status": "queued",
        "priority": 2,
        "quarter": "Q2-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 0.2,
        "dependencies": [],
        "notes": "Clone template_p1hyj87, rename, swap ID in referrals/new.html + referrals/detail.html. No code change."
      },
      {
        "id": "owner_emails_consolidate",
        "name": "Consolidate OWNER_EMAILS",
        "category": "polish",
        "status": "queued",
        "priority": 2,
        "quarter": "Q2-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 0.5,
        "dependencies": [],
        "notes": "Move from per-file arrays to single export in tmw-auth.js. Likely absorbed into b2_5/b2_6."
      },
      {
        "id": "sentry",
        "name": "Sentry Error Tracking",
        "category": "polish",
        "status": "queued",
        "priority": 2,
        "quarter": "Q2-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 0.75,
        "dependencies": [],
        "notes": "Production error visibility. Becomes critical once client-facing app ships."
      },
      {
        "id": "b3_2",
        "name": "Shared tmw-core.js Consolidation",
        "category": "foundation",
        "status": "queued",
        "priority": 2,
        "quarter": "Q2-2026",
        "target_date": "2026-06-15",
        "shipped_date": null,
        "estimated_hours": 2,
        "dependencies": ["b2_5", "b2_6"],
        "notes": "Consolidate fetch wrappers, auth helpers, common UI patterns. Pays back every feature after it."
      },
      {
        "id": "leaderboard",
        "name": "Referrals Leaderboard / Gamification",
        "category": "feature",
        "status": "queued",
        "priority": 3,
        "quarter": "Q2-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 2,
        "dependencies": ["b2_6"],
        "notes": "Hero card #4 on team home. Open design questions: scoring, time window, visibility, badges. Better after RBAC."
      },
      {
        "id": "b3_3",
        "name": "HoneyBook → Portal CSV Importer",
        "category": "integration",
        "status": "queued",
        "priority": 1,
        "quarter": "Q2-2026",
        "target_date": "2026-06-25",
        "shipped_date": null,
        "estimated_hours": 3,
        "dependencies": ["b3_2"],
        "notes": "HoneyBook has no public API. Manual CSV pipeline. Unblocks client app data flow."
      },
      {
        "id": "b3_4",
        "name": "Gmail Integration",
        "category": "integration",
        "status": "queued",
        "priority": 3,
        "quarter": "Q3-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 4,
        "dependencies": ["b3_2"],
        "notes": "Sync client emails into project records."
      },
      {
        "id": "b3_5",
        "name": "Google Drive Integration",
        "category": "integration",
        "status": "queued",
        "priority": 3,
        "quarter": "Q3-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 3,
        "dependencies": ["b3_2"],
        "notes": "Auto-link gallery folders into project pages."
      },
      {
        "id": "b3_6",
        "name": "Financial Dashboard",
        "category": "feature",
        "status": "queued",
        "priority": 3,
        "quarter": "Q4-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 4,
        "dependencies": ["b3_3"],
        "notes": "Revenue, payouts, package mix, referral ROI. Off-season fit."
      },
      {
        "id": "b4",
        "name": "Internal AI Chatbot (RAG)",
        "category": "feature",
        "status": "queued",
        "priority": 1,
        "quarter": "Q3-2026",
        "target_date": "2026-07-15",
        "shipped_date": null,
        "estimated_hours": 12,
        "dependencies": ["b3_2"],
        "notes": "Claude API + RAG over SOPs, shot lists, post-prod docs. Internal-first to surface doc gaps before client AI."
      },
      {
        "id": "b5",
        "name": "Client App MVP",
        "category": "feature",
        "status": "queued",
        "priority": 1,
        "quarter": "Q3-2026",
        "target_date": "2026-08-10",
        "shipped_date": null,
        "estimated_hours": 30,
        "dependencies": ["b3_3", "b2_6"],
        "notes": "Couple-facing: dashboard, timeline, contracts, payments, questionnaire, gallery hand-off, vendors, comms. The moat."
      },
      {
        "id": "b6",
        "name": "Client AI Chatbot",
        "category": "feature",
        "status": "queued",
        "priority": 2,
        "quarter": "Q3-2026",
        "target_date": "2026-08-20",
        "shipped_date": null,
        "estimated_hours": 6,
        "dependencies": ["b4", "b5"],
        "notes": "Couple-facing FAQ/timeline/package bot. Same RAG foundation as b4."
      },
      {
        "id": "b7",
        "name": "Day-of + Post-Wedding + Twilio SMS",
        "category": "feature",
        "status": "queued",
        "priority": 1,
        "quarter": "Q3-2026",
        "target_date": "2026-08-25",
        "shipped_date": null,
        "estimated_hours": 8,
        "dependencies": ["b5"],
        "notes": "Real-time day-of status, post-wedding flow, SMS via Twilio for time-sensitive comms."
      },
      {
        "id": "b8",
        "name": "Capacitor Wrap → iOS + Android",
        "category": "launch",
        "status": "queued",
        "priority": 1,
        "quarter": "Q3-2026",
        "target_date": "2026-08-18",
        "shipped_date": null,
        "estimated_hours": 10,
        "dependencies": ["b5", "b7"],
        "notes": "Native shell, push notifications, App Store + Play Store submission. SUBMIT BY 8/18 for 2-week Apple buffer."
      },
      {
        "id": "team_members_relational",
        "name": "Proper team_members Relational Table",
        "category": "foundation",
        "status": "queued",
        "priority": 2,
        "quarter": "Q3-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 4,
        "dependencies": ["b2_6"],
        "notes": "Migrate from JSON-in-JSONB to real table. Becomes urgent at 25+ team members. Bundle with b8 prep."
      },
      {
        "id": "b9",
        "name": "Public Launch — 2027 Bookings",
        "category": "launch",
        "status": "queued",
        "priority": 1,
        "quarter": "Q3-2026",
        "target_date": "2026-09-01",
        "shipped_date": null,
        "estimated_hours": 4,
        "dependencies": ["b5", "b6", "b7", "b8"],
        "notes": "ANCHOR DATE. New tiers go live: Essentials $3,500 / Signature $6,000 / Heirloom $9,500+. App in sales pitch."
      },
      {
        "id": "post_season_retro",
        "name": "Post-2026-Season Retro + SOP Refresh",
        "category": "polish",
        "status": "queued",
        "priority": 2,
        "quarter": "Q4-2026",
        "target_date": "2026-10-30",
        "shipped_date": null,
        "estimated_hours": 4,
        "dependencies": ["b9"],
        "notes": "Cross-area retro (pre-pro, day-of, post-pro). Address SOP gaps surfaced by AI chatbot during summer."
      },
      {
        "id": "client_app_v1_1",
        "name": "Client App v1.1 (Real-Use Fixes)",
        "category": "feature",
        "status": "queued",
        "priority": 2,
        "quarter": "Q4-2026",
        "target_date": "2026-12-01",
        "shipped_date": null,
        "estimated_hours": 8,
        "dependencies": ["b9"],
        "notes": "Bug fixes + QoL from real 2027-booked-client usage."
      },
      {
        "id": "album_workflow",
        "name": "Album Design + Revision Workflow",
        "category": "feature",
        "status": "queued",
        "priority": 2,
        "quarter": "Q4-2026",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 6,
        "dependencies": [],
        "notes": "Winter is album season. Refine the design + revision loop with clients."
      },
      {
        "id": "off_season_build",
        "name": "Off-Season Strategic Build (TBD)",
        "category": "feature",
        "status": "queued",
        "priority": 2,
        "quarter": "Q1-2027",
        "target_date": null,
        "shipped_date": null,
        "estimated_hours": 20,
        "dependencies": ["b9"],
        "notes": "Pick from: marketing site refresh, vendor portal, advanced analytics, second AI feature, in-portal album tool. Decide based on what 2026 season teaches."
      },
      {
        "id": "2027_season_prep",
        "name": "2027 Season Prep",
        "category": "polish",
        "status": "queued",
        "priority": 1,
        "quarter": "Q1-2027",
        "target_date": "2027-03-15",
        "shipped_date": null,
        "estimated_hours": 6,
        "dependencies": [],
        "notes": "Contracts + questionnaires updated. Shooter onboarding refresh. Gear/logistics audit before April."
      }
    ]
  }$json$::jsonb,
  NOW()
)
ON CONFLICT (id) DO UPDATE
SET data = EXCLUDED.data,
    updated_at = NOW();
