# CLARITY GTD — Feature & Bug Tracker
> Last updated: July 2026
> Single source of truth. Keep in GitHub alongside index.html and the SQL files.
> Upload at the start of any session to restore context.

---

## 🧭 CURRENT MODEL (post-redesign)

**Task statuses:** `active` · `waiting` · `parked` · `delegated` · `skipped` · `inbox` · `done` · `cancelled`
- `active` — I need to do this (default for all new tasks; was `next`)
- `waiting` — blocked on a person/entity; tracks `waiting_for` + `follow_up_date`
- `parked` — not now, optional revisit date (was `someday`)
- `delegated` — handed off; status exists, full view deferred to multi-user
- `skipped` — a recurring occurrence was skipped; next instance generated
- `inbox` — only from bulk imports / direct DB inserts now
- `reference` — **dropped** (used other tools)

**Task types:** `task` · `recurring` · `review` · `idea`  (`purchase` planned — see #77)

**Navigation:**
- Primary: **Focus · Projects · Life Areas · Search · Calendar**
- More ▾: **Waiting · Parked · Ideas · Analytics**
- Icons: 🔍 global search overlay · ⚙️ settings

**Focus view:** overdue + today merged, grouped by Eisenhower quadrant
(🔴 IU → 🟢 INU → 🟡 NIU → 🔵 NINU → ⚪ Untagged), sorted by estimated time asc within each,
per-quadrant minute totals, capacity planner on top, 📋 Review button in the capture bar.

---

## ✅ COMPLETED

### Core
Auth & session · first-time Supabase setup · app shell & nav · Settings (6 sub-tabs:
Account / Workspace / Contexts / Blackout Periods / Users & Permissions / Admin) · task capture
(all fields) · inline category picker · recurring tasks (13 patterns + day presets) · complete +
next instance · reschedule w/ reason · cancel w/ reason · calendar (week/month, blackout highlights) ·
Notion import (one-time) · projects (create/edit/list/detail) · project on-hold/reactivate/complete/cancel ·
Life Areas (domains + categories) · contexts (DB + Settings) · blackout periods · x_per_day carry-over ·
subtasks (reorder, progress badge, blocks completion) · idea→parked auto-promotion · status change on cards ·
global search overlay · pg_cron jobs · default 30-min estimate · action-verb warning (non-blocking) ·
card color declutter · complete-from-edit · done/cancelled visual treatment · project completed-tasks collapse.

### This redesign cycle
- **Remove inbox processing** — new tasks default to `active`; inbox only for bulk imports.
- **#38 Analytics** — Eisenhower bar chart; Completed / Yet-to-Complete toggle; Day/Week/Month;
  green=done, grey=cancelled; untagged noted; insight text.
- **#73 Undo last action** — toast w/ Undo (5s) on Complete (non-recurring), Cancel, Reschedule.
- **#75 Bulk daily task review** — full-screen triage; triggers: first-login-of-day (via
  `workspaces.last_review_date`, cross-device once-only), 8AM/12PM/10PM if >10 tasks, on-demand 📋 button;
  grouped by quadrant, sorted by time; per-task Keep/Move/Skip(recurring)/Done/Cancel; batched Apply-all;
  summary toast. Recurring handled correctly (done→`finishRecurringQuiet`, skip→`generateNextAfterSkip`,
  move→also patches recurrence `next_occurrence`).
- **#76 Subtask due dates** — `subtasks.due_date`; inherit parent date; parent-change syncs only
  subtasks still on old date; on save, parent due = earliest undone subtask date; date field per row.
- **Phase 1** — status rename (`next`→`active`, `someday`→`parked`, drop `reference`, add `delegated`/`skipped`);
  nav restructure; Search added to primary bar; Inbox removed from nav.
- **Phase 2** — Focus quadrant grouping + time sort.
- **Phase 3** — Search view (empty default; filters: Status/Importance/Life Area/Type/Missing fields;
  collapsible panel w/ active-count badge; "⚠ X missing key info" badge; Life Areas chips deep-link here pre-filtered).
- **Phase 4** — Waiting view redesign (shows `waiting_for` + `follow_up_date`, sorted by follow-up,
  overdue banner, ⚡ back-to-active; edit form reveals Waiting-for + Follow-up date when status=waiting).
- **Performance fix** — `loadTasks` collapsed from 3 sequential Supabase round-trips to 1 nested join
  (`tasks?select=...,task_categories(category_id),subtasks(id,is_done,due_date)`), ~1.5–2s faster.
- **Smart reschedule → Waiting** — reschedule reason `waiting_on_someone` auto-sets status=waiting,
  reveals Waiting-for + Follow-up date (defaults to due date, warns if follow-up > due date); undo restores all.
- **LastPass autofill** — attributes added everywhere; ultimately fixed via the LastPass site setting
  "disable autofill on this site."

---

## 🐛 KNOWN BUGS

| # | Bug | Status |
|---|---|---|
| B23 | Same-name tasks appear multiple times | **Data issue, not code.** Real duplicate rows in Supabase. |

Find duplicates:
```sql
select name, count(*) as count, array_agg(id::text) as ids
from tasks where status != 'cancelled'
group by name having count(*) > 1 order by count desc;
```
Note: `[B23]` diagnostic `console.log`s still in code — remove in a future cleanup.

---

## 🔜 YET TO BUILD

### 🟢 Small
**#65 — Skip blackout periods on recurring tasks.** Logic + `skip_blackouts` column exist; UI broke
twice inside the recurring modal. Needs a fresh approach (separate modal, or isolate root cause).
**#67 — Setup Guide (SETUP_GUIDE.md).** Docs only — non-technical setup on Supabase + GitHub Pages.
**#72 — Completed tasks history view.** All done/cancelled tasks, sortable by completion date, reopen action.

### 🟡 Small–Medium
**#69 — Pull forward tasks with extra capacity.** "I have capacity" button in Focus surfaces near-term
upcoming tasks; selecting sets due date to today, logged "Pulled forward — extra capacity." Session-only.

**#78 — Recurring cadence review (rules-based, no AI).** *(♢ Enhances — zero API cost)* An occasional,
on-demand bulk review of recurring tasks that flags cadences worth adjusting, using data already stored
(`reschedule_count`, `reschedule_reasons`, skips, completions) — no AI required.
- Trigger: on-demand button (e.g. in Settings or the recurring/analytics area); not automatic.
- Rule signal (starting point): if the last N instances of a recurrence were each rescheduled ≥1 time,
  suggest lengthening the interval (e.g. quarterly → every 4 months). Inverse: consistently completed
  early/on time with room to spare → could tighten. Tune thresholds during build.
- Output: a list of "consider changing X from A → B" suggestions; user accepts (updates the recurrence)
  or dismisses per item. Nothing changes without confirmation.
- Explicitly rules-based; an optional AI "explain the pattern / seasonal nuance" layer can sit on top later
  (would then be ⚡ AI-only and gated by the master switch — see AI section).

### 🟠 Medium
**#59 — Project close: bulk task review.** Review step on project close with bulk + per-task actions.
**#62 — Calendar drag-and-drop reschedule.** Drag chip → reason modal pre-filled. Desktop drag API;
mobile long-press (500ms). Needs the calendar overhaul to feel good on mobile.
**#68 — Local storage / no-backend mode.** Zero-setup via browser storage; optional Supabase sync.
**#70 — Hard vs Soft deadlines.** `deadline_type` + `expires_on` (already in setup v2). Hard tasks flag
"⚠ Expired — still relevant?" past cutoff; recurring can expire; no auto-cancel. Reschedule UX for hard
deadlines deferred.
**#77 — To Buy.** *(spec locked)* New `purchase` task type for non-grocery purchase intents.
- Capture: Type gains 🛒 To Buy; prompt "Add purchase checklist?" (Yes pre-fills, No stays clean);
  subtasks undated or inherit parent date.
- Default checklist (editable in Settings → To Buy): 1) Research brand/type/where 2) Discuss w/ family 3) Purchase.
- Ticking **Purchase** prompts "Add a check/return follow-up?" → spins off a **separate active task** with a
  due date (surfaces in Focus). No column changes; return is NOT a subtask.
- ✓ Bought auto-ticks remaining subtasks, sets done, moves to collapsed Purchased section.
- View in More ▾: 🛒 To Buy, grouped by category. Actions: ✓ Bought · → Make it a task · ✕ Remove.
- Excluded from Focus, bulk review, analytics. "Make it a project" deferred.
- SQL (run alone, before any UPDATE): `alter type task_type add value if not exists 'purchase';`

### 🔴 Medium–Large
**#74 — Task sequencing, Phase 1 dependency tracker.** *(spec locked)* "Blocked by / Blocks," no offsets,
multi-predecessor, triggers on reschedule + due-date edit, confirmation modal on cascading shifts (apply/skip
per task), 🔗 badge. No Gantt/critical-path/auto-cascade in Phase 1. `task_dependencies` table SQL ready
(commented in setup v2 Step 9).

### ⚫ Large / Very Large / Massive
**#41 — Family multi-user.** Per-member accounts/views, multiple workspaces, delegation, scoped RLS.
Unlocks the full **Delegated** view. *(Very Large)*
**#42 — Multi-tenant + social ecosystem.** Isolated instances per family; long-term social linking. *(Massive, future)*

### ⚪ Unsized / TBD
**#61 — Time planning / time blocks (Morning / Anytime / After-Hours).** Partly addressed by Focus quadrants,
but the time-of-day dimension isn't built. Tied to AI + Google Calendar direction.
**#49 — Life Areas task-count visual polish.** Deferred to a visual pass.
**Calendar design overhaul.** Current calendar not user-friendly; redesign needed before daily use.

### 🔮 Deferred directions (not yet specced)
- **Google Calendar sync** — real free/busy blocks, drag tasks onto the calendar.

---

## 🤖 AI FRAMEWORK (agreed principles — not yet built)

**Core principle — the "unplug test":** the app must remain fully functional with AI OFF. Every AI
feature is tagged:
- **♢ Enhances** — works fully without AI; AI just supercharges it. (Baseline intact.)
- **⚡ AI-only** — doesn't exist without AI; turning AI off makes it disappear cleanly without
  removing/breaking any pre-existing flow.
- **✗ Breaks** — turning AI off would strand a flow. **Do not build** these; redesign until they pass.
AI is always additive, never load-bearing for something the manual flow depended on. Run this test
out loud before speccing any AI feature.

**AI settings scaffolding (to build):**
- New **Settings → AI** sub-tab.
- **Master switch** — one toggle gating all AI; off = zero API calls.
- **API spend calculator** — running usage/cost estimate (Anthropic key already in Admin).
- **Per-feature toggles** — added as each AI feature ships; granularity TBD.
- Each AI feature documents a **cost profile**: tokens/call (small/medium/large) · trigger frequency
  (per capture / per day / on-demand) · initiator (automatic vs. user-tapped).
  Cheap = on-demand + user-initiated + small. Expensive = automatic + per-capture + large.

**AI feature ideas (parked, cost-profiled):**
- *Day planning by time block* — match today's tasks + available Morning/Anytime/After-Hours blocks →
  proposed plan. Ties to #61. ⚡ AI-only · large · on-demand. (Headline use.) **Staged — see #79.**
- *Bulk review assistant* — AI drafts keep/move/skip suggestions inside #75. ♢ Enhances · medium · on-demand.
- *Capture enrichment* — propose category/importance/time estimate at capture. ♢ Enhances · small · per-capture.
  **Specced — see #80.**
- *Recurrence "explain the pattern"* — optional nuance layer on top of #78. ⚡ AI-only · small–medium · on-demand.

---

## 🗓 #61 / #79 — TIME BLOCKS & DAY PLANNING (staged)

The day-planning ambition breaks into layers. Build bottom-up; each lower layer works without the one above,
and the AI layer only sits on top once the free layers function. **2a is the true prerequisite** — nothing
time-of-day-smart can happen until contexts actually drive Focus.

**#61 / 2a — Context drives Focus (rules, no AI).** *(♢ · free — PREREQUISITE)*
Make @home / @out-and-about / @laptop / after-hours *do something*: group or filter Focus by context and
time-of-day block (Morning / Anytime / After-Hours), so Focus can show "what's doable given where I am."
Today contexts are tagged but don't surface anywhere. This is the long-deferred #61 work and the foundation
for everything below. **Needs a proper spec next.**

**#79 / 2b — Capacity-aware planning (rules, no AI).** *(♢ · free)*
User already enters capacity per block. Rules pass: "you have 30 min this morning → here are the ≤30-min
tasks that fit." Fitting tasks into a time budget is arithmetic, not AI.

**#79 / 2c — AI day plan.** *(⚡ AI-only · large · on-demand, user-initiated)*
Given today's tasks (times, contexts, importance) + available blocks, propose an *ordered* plan across
Morning/Anytime/After-Hours — sequencing and trade-offs, what to defer. "Plan my day" button; never automatic.
Unplug test passes cleanly: turning AI off leaves 2a + 2b fully working, the AI plan just vanishes.

**#80 — Capture enrichment (importance + time estimate suggestions).** *(♢ Enhances)*
On-demand "✨ suggest" per field at capture — you pull help when a task is ambiguous, skip it when obvious.
- *1a Importance/urgency* — propose a quadrant from name/notes. ⚡ AI-only slice · small · on-demand.
- *1b Time estimate* — propose a duration instead of the 30-min default. **Rules first:** verb→duration
  lookup ("call"→5, "email"→10, "buy/shop"→45) handles common cases free; AI only for ambiguous ones.
- Unplug test: ♢ Enhances — fields are pre-filled *suggestions* you accept/override; AI off → type them
  yourself as today. On-demand (button) chosen over auto-fire-per-capture to control cost.

---

## 📋 SQL FILES

| File | Purpose | Status |
|---|---|---|
| `clarity_full_setup_v2.sql` | COMPLETE fresh-reset setup (current model: enums, tables, funcs, seed, cron) | Use for clean reset |
| `clarity_catchup_migration.sql` | Incremental migration for existing DB — **6 sections, run separately** | Applied |
| `clarity_fix_waiting_status.sql` | One-time sweep: active tasks w/ `waiting_on_someone` reason → status=waiting (SELECT preview first) | One-time |
| `clarity_add_review_fields.sql` | `skipped_at` on tasks, `last_review_date` on workspaces | Applied |
| `clarity_add_subtask_dates.sql` | `subtasks.due_date` | Applied |
| `clarity_add_waiting_fields.sql` | `waiting_for`, `follow_up_date` on tasks | Applied |
| `clarity_add_contexts.sql` / `_blackouts` / `_subtasks` / `_skip_blackouts` / `_schedule_cron` | Earlier add-ons | Applied |
| `IMPORT_TEMPLATE.md` | Spreadsheet → SQL format for project task imports | Reference |

Pending SQL to run when their features are built: `task_type` +`purchase` (#77), `task_dependencies` table (#74).
`deadline_type`/`expires_on` are already in setup v2 (#70).

---

## 🏗 DATABASE TABLES

workspaces (+`last_review_date`) · domains · categories · contexts · blackout_periods · projects ·
recurrences (+`skip_blackouts`, `expires_on`) · tasks (+`waiting_for`, `follow_up_date`, `skipped_at`,
`deadline_type`, `expires_on`) · subtasks (+`due_date`) · project_categories · task_categories ·
recurrence_categories · analytics_events · **task_dependencies (planned, #74 — not yet created).**

---

## 🔁 DEPLOYMENT

1. Upload `index.html` to GitHub `18apples/clarity-gtd`.
2. GitHub Pages auto-deploys (~60s; occasionally slow/flaky — re-run the Action or push a trivial change).
3. Hard refresh (Cmd/Ctrl+Shift+R).
4. Live: https://18apples.github.io/clarity-gtd/
- Commit messages **under 50 chars**.
- New DB tables always need the grant + RLS + policy block.

---

## 🧠 RECURRING LESSONS
- **Python `str.replace()` silently fails** when anchor text doesn't match exactly (has dropped bulk-review JS,
  `cStatusGroup`, waiting fields). Always `grep`-verify elements/functions exist after an edit; use the
  `str_replace` tool directly. Keep backtick count even; no duplicate functions.
- **Postgres enums:** `ALTER TYPE ... ADD VALUE` must commit in a **separate execution** from any `UPDATE`
  using the new value (error 55P04). Run enum changes and data migration as separate steps.
- **File health:** index.html ~5,400 lines / ~277 KB — fine for GitHub Pages (1 GB limit) and browsers.
  Backups / global error handler discussed, deferred — revisit in a few weeks.

---

## 🗒 SESSION HYGIENE
- **Start:** upload this tracker (and `CLARITY_SPEC.md` if used); state today's goal.
- **End:** ask Claude to update this tracker; replace the file in GitHub.
