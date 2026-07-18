# CLARITY GTD — Feature & Bug Tracker
> Last updated: July 2026 — AI strategy rewritten this session (see 🤖 AI STRATEGY)
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

### AI foundation (shipped — code was ahead of this tracker)
- **AI scaffolding** — `workspaces.ai_enabled` + `ai_feature_flags` (JSON); master switch; per-feature
  toggles; `aiFeatureOn(feature)` gate; Settings → AI sub-tab; 90-day API key rotation reminder
  (`clarity_ai_set_date` in localStorage, amber at 76 days, red at 90).
- **`callAI(feature, systemPrompt, userPrompt, maxTokens)`** — single call helper. Returns
  `{text, inTok, outTok}`, logs usage automatically, throws on error. All AI features go through this.
- **`ai_usage` table + spend panel** — logs model/tokens/est cost per call; Settings → AI shows
  month + all-time cost, call counts, per-model breakdown. **Informational, not a governor.**
- **#81 Task name cleanup** — ✨ button in capture bar; suggestion chip with accept/dismiss;
  "Looks good already ✓" when no change needed. First shipped AI feature.

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

**#78 — Recurring cadence review.** *(re-specced AI-native — see AI backlog Tier 3)* On-demand bulk
review of recurring tasks that flags cadences worth adjusting. Feed the model each recurrence's history
(`reschedule_count`, `reschedule_reasons`, skips, completion timing) and let it judge *and* explain —
including seasonality a rule can't see. Output: "consider changing X from A → B" with a reason;
accept (updates the recurrence) or dismiss per item. Nothing changes without confirmation.
Judgment tier (Sonnet).

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

## 🤖 AI STRATEGY (rewritten July 2026 — supersedes the earlier cost-cautious framing)

**The goal is not "add AI features." The goal is: less decision fatigue, less overwhelm.**
Clarity already captures and organises well. What it does not do is *think for me*. Every AI feature
is judged on one question: **does this remove a decision I currently have to make myself?**
If it only saves typing, it is low priority. If it saves deciding, it is high priority.

### What changed from the previous framing
The old section optimised for cost avoidance — rules-first, generators-before-interpreters,
on-demand-everything, per-feature cost profiles as gates. That doubled the build work (write the
rules engine *and* the AI layer) and produced timid features. **Dropped.** Cost is tracked in
Settings → AI for visibility, not used to decide what gets built.

Also dropped: the ♢ / ⚡ / ✗ tagging on every idea. It was a cost proxy. Replaced by one rule below.

### The one rule that stays: **don't brick**
If the API is down, the key is bad, or AI is toggled off, the app must still open, capture, and
complete tasks. Nothing on the critical path (create · view · complete · reschedule) may *require*
an AI response to work. AI can be the best path through the app; it can never be the only path.
Practically: every AI call needs a visible failure state and a manual way to do the same thing.
That's it — no other gating.

### Model tiering (new)
Haiku 4.5 is right for mechanical work. It is **not** right for judgment.
| Tier | Model | Use for |
|---|---|---|
| Mechanical | `claude-haiku-4-5` | name cleanup, time estimates, subtask drafting, duplicate detection |
| Judgment | `claude-sonnet-4-6` | triage, day planning, load rebalancing, parked resurfacing, decomposition |
`callAI()` needs a **model parameter** (currently hardcoded to `AI_MODEL`). Small refactor, do it
before the first judgment-tier feature.

### Interaction principle: propose, don't ask
Overwhelm comes from open questions. A blank "what should I do?" is the problem, not the interface.
So AI features should **arrive with an answer already filled in** that I accept, edit, or reject —
never a prompt box, never a menu of options to choose between. Pre-filled decisions in a review
shell (like #75) is the right shape. Chat is the wrong shape.

### Automatic is now allowed
The old rule was "never fire AI automatically, keep it on tapped buttons." That was cost fear.
Reversed: **daily-cadence automatic calls are fine.** Once-per-day triage on first login, once-per-day
plan generation — these are the whole point. Still avoid per-keystroke and per-page-load calls,
for latency and noise reasons, not cost.

---

## 🎯 #91 — AI TRIAGE ACROSS ALL TASKS  *(new headline feature — spec in progress)*

The backlog is where overwhelm actually lives. #75 bulk review only sees today + overdue; everything
older silently rots. #91 looks at **everything not done or cancelled** and comes back with decisions
already made.

**Shape:** same full-screen review shell as #75, but pre-filled by AI instead of defaulting to Keep.
Per task: a suggested action + a one-line reason. I sweep through accepting, override where wrong,
Apply-all at the end.

**Actions available:** Keep · Reschedule (with date) · Park · Cancel · Delegate · Move to Waiting ·
Break into subtasks (hands to #82) · Promote to today.

**Input per task:** name, notes, status, type, due date, created date, importance quadrant,
life area/category, project, estimated mins, `reschedule_count`, `reschedule_reasons`, subtask
progress, `waiting_for`/`follow_up_date`. Cheap to include everything — send it all.

**Cadence:** on-demand button + a monthly nudge. Not daily (that's #75's job).

**Open question to settle before building:** is triage's job to *clean up* (bias toward cancel/park —
shrink the list) or to *rescue* (bias toward "this still matters, pull it forward")? Different prompts,
different default actions. Leaning: **cleanup-biased, with a separate "worth reviving" section** so
rescue candidates surface without diluting the cull.

**Prerequisite:** `callAI()` model parameter (see tiering above). Sonnet tier.

---

## 🤖 AI FEATURE BACKLOG (reprioritised by decision-relief, not cost)

### Tier 1 — build these, in this order
**#91 — AI triage across all tasks.** See above. The backlog cull. *Spec in progress.*
  Prereq: `callAI()` model parameter.
**#79 / 2c — AI day plan.** "Plan my day" → ordered plan across Morning / Anytime / After-Hours using
today's tasks, contexts, importance, and entered capacity. Automatic on first login is now allowed.
**Note:** 2a (contexts drive Focus) is still a real prerequisite — AI can't plan around time-of-day
if contexts don't surface anywhere. See #61.
**#88 — Natural-language capture.** "Call plumber about the leak next Tuesday afternoon, urgent" →
parses name/date/importance/context/life area in one shot. Kills the multi-field capture form as the
default path. Highest-frequency decision relief in the app. Manual form stays as the fallback path.
**#82 — Subtask generation.** ✨ on a task → proposed subtasks. Feeds #91's "break into subtasks"
action and #77's checklist. Mechanical tier.
**#85 — Parked/Ideas resurfacing.** "3 of your 40 parked items are worth revisiting now." Without
this, Parked is a graveyard — and #91 will make Parked much bigger. Build alongside or just after #91.

### Tier 2 — clear value, after Tier 1 lands
**#89 — "What should I do right now?"** Given time of day, context, and free minutes, surface the best
1–2 things. Impulse cousin of #79. Cheap to add once #79's plan logic exists.
**#86 — Project decomposition.** "Plan Japan trip" → full project structure. Bigger sibling of #82.
**#90 — Weekly load rebalancing.** Tuesday overloaded / Thursday empty → proposes moves.
**#87 — Waiting follow-up drafting.** Follow-up date arrives → drafts the chase message.
**#83 — Weekly reflection summary.** Narrates analytics ("23 done, 6 cancelled, most reschedules were
quarterly recurring"). Low effort, good weekly ritual anchor.

### Tier 3 — absorbed or downgraded
**#80 — Capture enrichment.** *(Tier 3 — largely absorbed by #88)* Per-field ✨ suggestions at capture
(importance quadrant, time estimate). Once #88 natural-language capture parses these inline, this is
redundant on the primary path. Keep only as polish on the manual fallback form. The verb→duration lookup
table originally planned here is **dropped** — AI handles it.

---

## 🗓 #61 / #79 — TIME BLOCKS & DAY PLANNING (staged)

The day-planning ambition breaks into layers. Build bottom-up. **2a is the true prerequisite** — nothing
time-of-day-smart can happen until contexts actually drive Focus, AI included. 2a and 2b are deterministic
because dates and minutes must be exact; 2c is where judgment enters.

**#61 / 2a — Context drives Focus (deterministic — PREREQUISITE, blocks #79 and #89).**
Make @home / @out-and-about / @laptop / after-hours *do something*: group or filter Focus by context and
time-of-day block (Morning / Anytime / After-Hours), so Focus can show "what's doable given where I am."
Today contexts are tagged but don't surface anywhere. This is the long-deferred #61 work and the foundation
for everything below. **Needs a proper spec next.**

**#79 / 2b — Capacity-aware planning (deterministic).**
User already enters capacity per block. Rules pass: "you have 30 min this morning → here are the ≤30-min
tasks that fit." Fitting tasks into a time budget is arithmetic, not AI.

**#79 / 2c — AI day plan.** *(Tier 1 — judgment tier / Sonnet)*
Given today's tasks (times, contexts, importance) + available blocks, propose an *ordered* plan across
Morning/Anytime/After-Hours — sequencing and trade-offs, what to defer. "Plan my day" button **plus automatic generation on first login of the day** — the plan should be
waiting for me, not something I have to ask for. 2a + 2b keep working if the call fails; the plan is
just absent, replaced by the normal Focus view.

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
