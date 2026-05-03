-- =====================================================================
-- File: 2026-05-03-premium-cost-model.sql
-- Bucket: Build Calendar — Premium Cost Model Upgrade
-- Author: Tony Martinez (via embedded COO)
-- Date: 2026-05-03
-- Purpose: Replace the conservative cost model with premium boutique
--          product studio rates. Hours adjusted to reflect real agency
--          scope (not solo-dev hours). New baseline going forward.
--
-- Premium rate model:
--   high = $450/hr  (security, AI/RAG, integrations, mobile native)
--   mid  = $300/hr  (features, foundation, launches)
--   low  = $175/hr  (polish, ops, docs, small fixes)
--
--   Agency multiplier: 2.5x  (discovery, design, PM, QA, revisions,
--                              deployment, post-launch support)
--
--   Blended effective rates:
--     high = $1,125/hr
--     mid  = $750/hr
--     low  = $437.50/hr
--
-- Hour adjustments rationale:
-- - Original hours were "solo-Tony-with-Claude" hours: pure coding time.
-- - Premium hours are "boutique-studio-team" hours: discovery, design
--   comps, requirements docs, PM overhead, code review, QA cycles,
--   deployment, post-launch support, revision rounds.
-- - This is what an agency would actually log against an invoice.
--
-- Expected totals after this migration:
--   Shipped value:    ~$274,500
--   Queued value:     ~$546,688
--   Total project:    ~$821,188
--   Real cost (5 mo): ~$280
--   Saved so far:     ~$274,220
--
-- Design notes:
-- - Idempotent: rerunning overwrites with same shape.
-- - Dashboard code requires no changes. It reads cost_model + hours
--   from this row and recalculates on render.
-- - All anchors, statuses, dependencies, and notes preserved.
-- - This is the canonical baseline going forward. Future bucket adds
--   should use these tier rates and boutique-scoped hour estimates.
--
-- RLS notes:
-- - No RLS changes. Existing {authenticated} policy on projects table
--   continues. Owner gating in JS layer.
-- =====================================================================

UPDATE projects
SET data = $json${
  "updated_at": "2026-05-03",
  "cost_model": {
    "rates": {
      "high": 450,
      "mid": 300,
      "low": 175
    },
    "agency_multiplier": 2.5,
    "monthly_actual_cost_usd": 56,
    "build_started_month": "2026-01",
    "narrative": "Built solo with Claude. Boutique product studio rates: $300–$450/hr × 2.5x for full agency invoice load. Real cost: $56/mo."
  },
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
      "rate_tier": "mid",
      "status": "shipped",
      "priority": 1,
      "quarter": "Q1-2026",
      "target_date": null,
      "shipped_date": "2026-04-15",
      "estimated_hours": 280,
      "dependencies": [],
      "notes": "Original team.tmweddings.com — base portal, auth flow, post-prod tracker scaffolding, shooter SOPs, weddings module, shot caller pages, deliverables tracking. At boutique-studio scope: discovery, IA, design comps, full implementation, QA cycles."
    },
    {
      "id": "b2",
      "name": "RLS + JWT Lockdown",
      "category": "security",
      "rate_tier": "high",
      "status": "shipped",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": "2026-04-29",
      "estimated_hours": 32,
      "dependencies": ["b1"],
      "notes": "Routed all Supabase calls through tmwSbFetch with JWT. Established {authenticated} permissive RLS pattern across all tables. Custom auth domain via auth.tmweddings.com. Security architecture work — high tier."
    },
    {
      "id": "b3_1",
      "name": "Team Referral Tracker",
      "category": "feature",
      "rate_tier": "mid",
      "status": "shipped",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": "2026-04-29",
      "estimated_hours": 28,
      "dependencies": ["b2"],
      "notes": "Dashboard, log form, lifecycle/payout tracking, owner override, EmailJS integration. First Cowork-validated build."
    },
    {
      "id": "w7_intake",
      "name": "w7 Zee & Maggie Haroon Intake + Loading Bug Fix",
      "category": "feature",
      "rate_tier": "mid",
      "status": "shipped",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": "2026-05-02",
      "estimated_hours": 4,
      "dependencies": [],
      "notes": "Wedding populated, 94-shot dynamic shot caller, index.html Loading bug fixed (whenUserReady gate established), shotCallerUrl auto-wires for new weddings."
    },
    {
      "id": "build_calendar",
      "name": "Build Calendar Dashboard",
      "category": "feature",
      "rate_tier": "mid",
      "status": "shipped",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": "2026-05-02",
      "estimated_hours": 6,
      "dependencies": [],
      "notes": "Owner-only production planning dashboard. Anchors + roadmap quarters + kanban + agency cost tracker. Read-only; updates flow through chat-with-COO. Includes auth gate via tmwHasRole('owner')."
    },
    {
      "id": "emailjs_decision",
      "name": "EmailJS Quota Decision",
      "category": "polish",
      "rate_tier": "low",
      "status": "queued",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": "2026-05-09",
      "shipped_date": null,
      "estimated_hours": 2,
      "dependencies": [],
      "notes": "Caps May 9 at 200/mo, ~80 used. Upgrade tier OR migrate to Resend/Postmark. Notifications are load-bearing — don't lapse."
    },
    {
      "id": "volume_check",
      "name": "Post-Prod Volume Readiness Check",
      "category": "polish",
      "rate_tier": "low",
      "status": "queued",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": "2026-05-10",
      "shipped_date": null,
      "estimated_hours": 3,
      "dependencies": [],
      "notes": "Render times, filter performance, query patterns at projected 25+ active project load before season hits hard."
    },
    {
      "id": "b2_5",
      "name": "RLS Hardening — Owner Checks at DB",
      "category": "security",
      "rate_tier": "high",
      "status": "queued",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": "2026-05-22",
      "shipped_date": null,
      "estimated_hours": 8,
      "dependencies": ["b2"],
      "notes": "Promote OWNER_EMAILS JS checks to RLS via auth.email(). Recommended combined with b2_6."
    },
    {
      "id": "b2_6",
      "name": "Role-Based Access Control",
      "category": "security",
      "rate_tier": "high",
      "status": "queued",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": "2026-05-22",
      "shipped_date": null,
      "estimated_hours": 16,
      "dependencies": ["b2_5"],
      "notes": "Owner > Admin > Editor > Shooter hierarchy. Role-check helpers (tmwHasRole, tmwIsAdmin) already exist in tmw-core.js — needs consistent application across pages + RLS extension. Combine with b2_5."
    },
    {
      "id": "photobook_stages_v2",
      "name": "Photo Book Stage Redefinition",
      "category": "feature",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 2,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 4,
      "dependencies": [],
      "notes": "Replace 5-stage Photo Book flow with 4-stage: Client selections made / Book design begun / Design finalized / Book ordered and shipped. Apply to all existing books."
    },
    {
      "id": "referrals_emailjs_template",
      "name": "Referrals-specific EmailJS Template",
      "category": "polish",
      "rate_tier": "low",
      "status": "queued",
      "priority": 2,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 1,
      "dependencies": [],
      "notes": "Clone template_p1hyj87, rename, swap ID in referrals/new.html + referrals/detail.html."
    },
    {
      "id": "owner_emails_consolidate",
      "name": "Consolidate OWNER_EMAILS",
      "category": "polish",
      "rate_tier": "low",
      "status": "queued",
      "priority": 2,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 2,
      "dependencies": [],
      "notes": "Move from per-file arrays to single export. Likely absorbed into b2_5/b2_6."
    },
    {
      "id": "sentry",
      "name": "Sentry Error Tracking",
      "category": "polish",
      "rate_tier": "low",
      "status": "queued",
      "priority": 2,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 3,
      "dependencies": [],
      "notes": "Production error visibility. Becomes critical once client-facing app ships."
    },
    {
      "id": "b3_2",
      "name": "Shared tmw-core.js Consolidation",
      "category": "foundation",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 2,
      "quarter": "Q2-2026",
      "target_date": "2026-06-15",
      "shipped_date": null,
      "estimated_hours": 12,
      "dependencies": ["b2_5", "b2_6"],
      "notes": "Consolidate fetch wrappers, auth helpers, common UI patterns. Pays back every feature after it."
    },
    {
      "id": "leaderboard",
      "name": "Referrals Leaderboard / Gamification",
      "category": "feature",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 3,
      "quarter": "Q2-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 10,
      "dependencies": ["b2_6"],
      "notes": "Hero card #4 on team home. Open design questions: scoring, time window, visibility, badges. Better after RBAC."
    },
    {
      "id": "b3_3",
      "name": "HoneyBook → Portal CSV Importer",
      "category": "integration",
      "rate_tier": "high",
      "status": "queued",
      "priority": 1,
      "quarter": "Q2-2026",
      "target_date": "2026-06-25",
      "shipped_date": null,
      "estimated_hours": 18,
      "dependencies": ["b3_2"],
      "notes": "HoneyBook has no public API. Manual CSV pipeline. Unblocks client app data flow."
    },
    {
      "id": "b3_4",
      "name": "Gmail Integration",
      "category": "integration",
      "rate_tier": "high",
      "status": "queued",
      "priority": 3,
      "quarter": "Q3-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 22,
      "dependencies": ["b3_2"],
      "notes": "Sync client emails into project records. OAuth flow + scoped permissions + thread mapping."
    },
    {
      "id": "b3_5",
      "name": "Google Drive Integration",
      "category": "integration",
      "rate_tier": "high",
      "status": "queued",
      "priority": 3,
      "quarter": "Q3-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 16,
      "dependencies": ["b3_2"],
      "notes": "Auto-link gallery folders into project pages."
    },
    {
      "id": "b3_6",
      "name": "Financial Dashboard",
      "category": "feature",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 3,
      "quarter": "Q4-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 20,
      "dependencies": ["b3_3"],
      "notes": "Revenue, payouts, package mix, referral ROI. Off-season fit."
    },
    {
      "id": "b4",
      "name": "Internal AI Chatbot (RAG)",
      "category": "feature",
      "rate_tier": "high",
      "status": "queued",
      "priority": 1,
      "quarter": "Q3-2026",
      "target_date": "2026-07-15",
      "shipped_date": null,
      "estimated_hours": 60,
      "dependencies": ["b3_2"],
      "notes": "Claude API + RAG over SOPs, shot lists, post-prod docs. Vector embeddings, retrieval pipeline, prompt engineering, eval harness. AI work is high tier."
    },
    {
      "id": "b5",
      "name": "Client App MVP",
      "category": "feature",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 1,
      "quarter": "Q3-2026",
      "target_date": "2026-08-10",
      "shipped_date": null,
      "estimated_hours": 140,
      "dependencies": ["b3_3", "b2_6"],
      "notes": "Couple-facing: dashboard, timeline, contracts, payments, questionnaire, gallery hand-off, vendors, comms. The moat. Boutique-studio scope: full UX design phase, accessibility, multi-device QA."
    },
    {
      "id": "b6",
      "name": "Client AI Chatbot",
      "category": "feature",
      "rate_tier": "high",
      "status": "queued",
      "priority": 2,
      "quarter": "Q3-2026",
      "target_date": "2026-08-20",
      "shipped_date": null,
      "estimated_hours": 30,
      "dependencies": ["b4", "b5"],
      "notes": "Couple-facing FAQ/timeline/package bot. Same RAG foundation as b4 with content-safety guardrails for client-facing surface."
    },
    {
      "id": "b7",
      "name": "Day-of + Post-Wedding + Twilio SMS",
      "category": "feature",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 1,
      "quarter": "Q3-2026",
      "target_date": "2026-08-25",
      "shipped_date": null,
      "estimated_hours": 36,
      "dependencies": ["b5"],
      "notes": "Real-time day-of status, post-wedding flow, SMS via Twilio for time-sensitive comms. Twilio integration + delivery tracking + opt-out compliance."
    },
    {
      "id": "b8",
      "name": "Capacitor Wrap → iOS + Android",
      "category": "launch",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 1,
      "quarter": "Q3-2026",
      "target_date": "2026-08-18",
      "shipped_date": null,
      "estimated_hours": 50,
      "dependencies": ["b5", "b7"],
      "notes": "Native shell, push notifications, App Store + Play Store submission. SUBMIT BY 8/18 for 2-week Apple buffer. Includes app icons, splash screens, store listings, screenshots, privacy disclosures."
    },
    {
      "id": "team_members_relational",
      "name": "Proper team_members Relational Table",
      "category": "foundation",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 2,
      "quarter": "Q3-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 18,
      "dependencies": ["b2_6"],
      "notes": "Migrate from JSON-in-JSONB to real table. Schema design + migration + dual-read period + cutover."
    },
    {
      "id": "b9",
      "name": "Public Launch — 2027 Bookings",
      "category": "launch",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 1,
      "quarter": "Q3-2026",
      "target_date": "2026-09-01",
      "shipped_date": null,
      "estimated_hours": 20,
      "dependencies": ["b5", "b6", "b7", "b8"],
      "notes": "ANCHOR DATE. New tiers go live: Essentials $3,500 / Signature $6,000 / Heirloom $9,500+. Marketing copy, sales enablement, monitoring + on-call."
    },
    {
      "id": "post_season_retro",
      "name": "Post-2026-Season Retro + SOP Refresh",
      "category": "polish",
      "rate_tier": "low",
      "status": "queued",
      "priority": 2,
      "quarter": "Q4-2026",
      "target_date": "2026-10-30",
      "shipped_date": null,
      "estimated_hours": 12,
      "dependencies": ["b9"],
      "notes": "Cross-area retro (pre-pro, day-of, post-pro). Address SOP gaps surfaced by AI chatbot during summer."
    },
    {
      "id": "client_app_v1_1",
      "name": "Client App v1.1 (Real-Use Fixes)",
      "category": "feature",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 2,
      "quarter": "Q4-2026",
      "target_date": "2026-12-01",
      "shipped_date": null,
      "estimated_hours": 32,
      "dependencies": ["b9"],
      "notes": "Bug fixes + QoL from real 2027-booked-client usage. User research synthesis + prioritization + execution."
    },
    {
      "id": "album_workflow",
      "name": "Album Design + Revision Workflow",
      "category": "feature",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 2,
      "quarter": "Q4-2026",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 28,
      "dependencies": [],
      "notes": "Winter is album season. Refine the design + revision loop with clients."
    },
    {
      "id": "off_season_build",
      "name": "Off-Season Strategic Build (TBD)",
      "category": "feature",
      "rate_tier": "mid",
      "status": "queued",
      "priority": 2,
      "quarter": "Q1-2027",
      "target_date": null,
      "shipped_date": null,
      "estimated_hours": 80,
      "dependencies": ["b9"],
      "notes": "Pick from: marketing site refresh, vendor portal, advanced analytics, second AI feature, in-portal album tool. Decide based on what 2026 season teaches."
    },
    {
      "id": "2027_season_prep",
      "name": "2027 Season Prep",
      "category": "polish",
      "rate_tier": "low",
      "status": "queued",
      "priority": 1,
      "quarter": "Q1-2027",
      "target_date": "2027-03-15",
      "shipped_date": null,
      "estimated_hours": 18,
      "dependencies": [],
      "notes": "Contracts + questionnaires updated. Shooter onboarding refresh. Gear/logistics audit before April."
    }
  ]
}$json$::jsonb,
updated_at = NOW()
WHERE id = 'tmw_build_plan';

-- Verify after run:
-- SELECT
--   (data->'cost_model'->>'agency_multiplier')::numeric AS multiplier,
--   data->'cost_model'->'rates' AS rates,
--   jsonb_array_length(data->'buckets') AS bucket_count,
--   (
--     SELECT SUM((b->>'estimated_hours')::numeric)
--     FROM jsonb_array_elements(data->'buckets') b
--     WHERE b->>'status' = 'shipped'
--   ) AS shipped_hours,
--   (
--     SELECT SUM((b->>'estimated_hours')::numeric)
--     FROM jsonb_array_elements(data->'buckets') b
--     WHERE b->>'status' != 'shipped'
--   ) AS remaining_hours
-- FROM projects
-- WHERE id = 'tmw_build_plan';
