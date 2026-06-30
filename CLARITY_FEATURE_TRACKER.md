# CLARITY GTD — Feature & Bug Tracker
> Last updated: May 2026
> Keep in GitHub alongside index.html and CLARITY_SPEC.md
> Upload to Claude at the start of any session to restore context

---

## ✅ COMPLETED FEATURES

| # | Feature | Notes |
|---|---|---|
| 1 | Auth — sign in / sign up / session refresh | |
| 2 | First-time Supabase setup | |
| 3 | App shell + navigation | Primary tabs + More dropdown + 🔍 + ⚙️ |
| 4 | Settings — full page with 6 sub-tabs | Account / Workspace / Contexts / Blackout Periods / Users & Permissions / Admin |
| 5 | Task capture — all fields | Name, type, status, categories, IQ, context, due date, est. time, project, recurring, notes, subtasks |
| 6 | Inline category picker | Tap to toggle, grouped by domain, multi-select |
| 7 | Daily Focus — overdue + today only | No-date tasks excluded from Focus |
| 8 | Recurring tasks — 13 patterns | All patterns, day presets (Weekdays/MWF/etc.) |
| 9 | Complete task + recurring next instance | |
| 10 | Reschedule — requires reason | |
| 11 | Cancel task — requires reason | From cards and edit form |
| 12 | Calendar — week + month toggle | Blackout highlights, nav arrows |
| 13 | Notion inbox import — SQL | One-time 162 task import |
| 14 | Projects — create, edit, list, detail | |
| 15 | Project on hold / reactivate / complete / cancel | On hold puts all tasks to Waiting |
| 16 | Life Areas — domains + categories | Accordion, one open at a time, task breakdown chips |
| 17 | Create / edit / delete domain and category | Move tasks on delete |
| 18 | Inbox view | Search + full filter suite (collapsible) |
| 19 | Next / Waiting / Someday / Reference / Ideas views | All pipeline views built |
| 20 | Edit task | Full form, status field, subtasks, cancel/complete buttons |
| 21 | Task count → Inbox filter | Life Areas chips link to filtered Inbox |
| 22 | Day capacity planner | Focus view, visual bar, override per day |
| 23 | Contexts — DB table + Settings management | Fully manageable |
| 24 | Blackout periods | Settings, card warnings, calendar highlight, skip/keep choice on due date |
| 25 | x_per_day carry-over | Deficit carries forward |
| 26 | Subtasks | Capture + edit, reorder up/down, progress badge, blocks completion |
| 27 | Idea → Someday auto-promotion | Ideas with category → someday automatically |
| 28 | Status change on task cards | ↕ button opens status picker |
| 29 | Global task search | 🔍 nav button, all tasks/statuses, keyboard shortcut |
| 30 | pg_cron jobs scheduled | surface_recurring, surface_someday, generate_review_tasks |
| 31 | Default 30 mins estimated time | Pre-filled on new capture |
| 32 | Recurring edit — all 4 scenarios | New / edit / convert to recurring / convert to non-recurring |
| 33 | Action verb warning — non-blocking | Inline hint only, never blocks saving |
| 34 | Task card color declutter | Neutral tags, status-based left border stripe |
| 35 | Recurring day presets | Weekdays / Weekends / MWF / TTh / Every day / Clear |
| 36 | Complete task from edit view | ✓ Mark Complete button, checks subtasks first |
| 37 | Done/Cancelled visually distinct | ✓/✕ prefix, strikethrough, muted grey everywhere |
| 38 | Completed tasks collapsed in project view | "X completed ▶" toggle, collapsed by default |
| 39 | Blackout day handling on task creation | Skip to next day or keep — choice on due date pick |
| 40 | Status field in edit modal | Dropdown shows current status, editable, shows completion/cancellation info + reason |
| 41 | Settings full page + nav redesign | Primary bar + More dropdown, 6 settings sub-tabs |
| 42 | Remove inbox processing step | New tasks default to status=next; Inbox now only for bulk imports |

---

## 🐛 KNOWN BUGS

| # | Bug | Status |
|---|---|---|
| B23 | Tasks with same name appear multiple times | Data issue — not a code bug. Run SQL below to find and delete duplicate tasks in Supabase |

**SQL to find duplicate tasks:**
```sql
select name, count(*) as count, array_agg(id::text) as ids
from tasks
where status != 'cancelled'
group by name
having count(*) > 1
order by count desc;
```

**Note:** `[B23]` diagnostic console logs are still in the code — remove in a future cleanup build.

---

## 🔜 FEATURES NOT YET BUILT

### Task Management

**#59 — Project close: bulk task review**
**Effort:** Medium
When closing (completing or cancelling) a project with open tasks, show a review step:
- List all open tasks
- Bulk actions: Close All / Move All out of project / Cancel All
- Per-task: keep, move to status, or cancel individually
- Replaces the current simple "X tasks remain, close anyway?" confirm dialog

**#61 — Time planning / time blocks**
**Effort:** TBD — needs more thought
Concept of tasks assigned to Morning / Evening / Anytime blocks. Open questions:
- Does it affect Focus view ordering/grouping?
- Does it interact with Calendar?
- Field on task or assigned during daily planning?

**#62 — Calendar drag and drop to reschedule**
**Effort:** Medium
- Drag task chip from one day to another in week or month view
- On drop → reschedule reason modal with new date pre-filled
- Desktop: HTML5 drag API
- Mobile: long press (500ms) to initiate drag, then drag to target day
- Long press is not used anywhere else in the app — safe to use

**#65 — Skip blackout periods on recurring tasks**
**Effort:** Small (logic exists, UI needs rebuild)
- DB column `skip_blackouts` already exists on `recurrences` table
- Backend logic (`rollPastBlackouts`, `calcNextDate`) already in code
- UI checkbox was attempted twice and removed both times — click handling broke in the modal context
- **Needs a fresh approach next time** — consider a separate small modal instead of inline in the recurring form, or test in isolation outside the main capture modal first to isolate the root cause

**#69 — Pull forward tasks with extra capacity**
**Effort:** Small-Medium
- Button in Daily Focus: "I have capacity — show upcoming tasks"
- Shows up to 10 tasks from Next Actions with due dates in the next few days, swipeable/selectable
- Selecting a task updates due date to today — no reschedule reason modal, auto-logged as "Pulled forward — extra capacity"
- Unselected tasks stay where they are
- Session-only, not persistent

**#70 — Hard vs Soft deadlines**
**Effort:** Medium
- Hard deadline: task meaningless after a cutoff date (e.g. birthday video — due before, expires on the day)
- Soft deadline: current behavior, flexible (e.g. laundry)
- Two date fields: `due_date` (when you want it done) + `expires_on` (hard cutoff, may differ from due date)
- Recurring tasks can also have `expires_on` (e.g. antibiotic course — stops generating instances after course ends)
- No auto-cancel — task flagged "⚠ Expired — still relevant?" after expiry, user decides
- **Rescheduling experience for hard-deadline tasks — deferred, needs more thought** (warnings, blocking past expiry, special reasons — all parked)

**DB changes needed:**
```sql
alter table tasks add column if not exists deadline_type text default 'soft'; -- 'hard' | 'soft'
alter table tasks add column if not exists expires_on date;
alter table recurrences add column if not exists expires_on date;
```

**#71 — Remove inbox processing step — DONE ✅**
Built. New tasks default to status=next. Inbox view relabeled "Needs review," only populated by bulk imports/direct DB inserts now.

**#72 — Completed tasks history view**
**Effort:** Small-Medium
A dedicated view showing all done/cancelled tasks across the whole app, sortable by completion date, with ability to reopen (change status back). Currently the only ways to find a done task are global search or inside a specific project's collapsed "completed" section.

**#73 — Undo last action**
**Effort:** Small
A toast notification with an **Undo** button appears after completing a task (and possibly other destructive actions like cancel), disappearing after ~5 seconds. Would prevent accidental completions from requiring manual DB fixes.

**#74 — Task sequencing — Phase 1 dependency tracker**
**Effort:** Medium-Large
**Spec locked, ready to build.**

The bigger vision (multi-task parallel/sequential dependency management, e.g. buying a home with parallel and sequential steps) is being built incrementally. **Phase 1 is a lightweight "Blocked by / Blocks" tracker** — no visual graph, no Gantt chart.

**Confirmed Phase 1 behavior:**
- Primarily within a project, but standalone task dependencies also supported
- No date offset — dependency is purely "must finish after X," no gap math
- A task can depend on **multiple** predecessors (flexible — no strict "wait for latest" rule enforced, just surfaces all for the user to judge)
- Triggers on **both** reschedule (↻) and direct due date edit in the form
- When a predecessor's date changes, system checks for dependents → shows confirmation modal listing each affected task (old date → suggested new date, same date as predecessor, no offset) → user applies or skips per task — nothing shifts silently
- Task card shows a 🔗 indicator with count (e.g. "🔗 2 blocking") — click to expand inline list, no separate page

**Explicitly NOT in Phase 1** (future phases):
- No visual timeline/graph/Gantt view
- No automatic cascading without confirmation
- No critical-path calculation
- No circular-dependency detection beyond a basic guard

**DB change needed:**
```sql
create table task_dependencies (
  id uuid primary key default uuid_generate_v4(),
  predecessor_task_id uuid not null references tasks(id) on delete cascade,
  dependent_task_id   uuid not null references tasks(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(predecessor_task_id, dependent_task_id)
);

grant select, insert, update, delete on public.task_dependencies to authenticated;
grant select, insert, update, delete on public.task_dependencies to service_role;
alter table public.task_dependencies enable row level security;
create policy "authenticated access" on public.task_dependencies
  for all to authenticated using (true);
```

---

### Analytics

**#38 — Eisenhower Matrix Time Distribution Chart**
**Effort:** Medium | **Phase:** 5
- Chart: completed tasks across 4 Eisenhower quadrants
- Toggle: Day / Week / Month
- Uses estimated_mins as proxy for time spent
- Insight text below chart (e.g. "68% Important+Urgent — shift more to Important+Not Urgent")
- Untagged tasks shown separately

---

### Ideas & Someday

**#57 — Idea vs Someday Refinement**
**Effort:** Small | **Needs more real-world use**
Current rule works: idea + no category = idea, idea + category = someday. Revisit after more use.

---

### Navigation & Layout

**#49 — Life Areas task count visual improvements**
**Effort:** Medium | **Deferred — visual improvements phase**
Current breakdown chips work but need visual polish.

---

### Family & Multi-user

**#41 — Family Multi-User**
**Effort:** Very Large | **Phase:** 5
- Each family member: own account, own complete view
- Multiple workspaces per user (Personal/Work/School)
- Family members can't see each other's tasks unless included
- Delegate task → stays in your view as Waiting, appears in assignee's view
- Projects shared between family members — TBD
- No simplified UI for children — middle school+ uses full app
- DB changes: users table, families table, delegations, scoped RLS

**#42 — Multi-tenant + Social Ecosystem**
**Effort:** Massive | **Future only**
Friends can spin up own isolated Clarity instance. Long-term: social linking between families.

---

### Deployment & Access

**#67 — Setup Guide (SETUP_GUIDE.md)**
**Effort:** Small — documentation only
A plain-English step-by-step guide for a non-technical person to set up their own Clarity instance using Supabase + GitHub Pages.

**#68 — Local storage / no-backend mode**
**Effort:** Medium
Let people use Clarity with zero setup — data stored in browser localStorage or IndexedDB. Optional Supabase connection for sync and multi-device. Good for people whose IT blocks external databases (e.g. corporate Slack-based workflows).

**`IMPORT_TEMPLATE.md`** — created. Spreadsheet → SQL format for one-off project task imports directly into the tasks table, same pattern as the original Notion import.

---

## 📋 SQL FILES IN GITHUB

| File | Purpose | Status |
|---|---|---|
| `clarity_full_setup.sql` | Complete DB setup — drop, create, grants, seed | ✅ Run |
| `clarity_notion_import.sql` | One-time Notion import | ✅ Run |
| `clarity_add_contexts.sql` | Adds contexts table + seeds 4 contexts | ✅ Run |
| `clarity_add_blackouts.sql` | Adds blackout_periods table | ✅ Run |
| `clarity_add_subtasks.sql` | Adds subtasks table | ✅ Run |
| `clarity_schedule_cron.sql` | Schedules 3 pg_cron daily jobs | ✅ Run |
| `clarity_add_skip_blackouts.sql` | Adds skip_blackouts to recurrences | ✅ Run (UI not yet rebuilt — see #65) |
| `IMPORT_TEMPLATE.md` | Spreadsheet format guide for project task imports | Reference doc, not SQL |

---

## 🏗 DATABASE TABLES (Live in Supabase)

| Table | Purpose |
|---|---|
| workspaces | Top-level container |
| domains | Life area labels |
| categories | Grouped under domains, review cadence |
| projects | Multi-step goals |
| tasks | All tasks, ideas, recurring instances, reviews |
| recurrences | Recurring templates (includes skip_blackouts) |
| subtasks | Checklist items inside tasks |
| contexts | @context values |
| blackout_periods | Unavailable date ranges |
| project_categories | Junction |
| task_categories | Junction |
| recurrence_categories | Junction |
| analytics_events | Append-only activity log |
| task_dependencies | **Planned for #74** — not yet created |

---

## 🔁 DEPLOYMENT WORKFLOW

1. Upload `index.html` to GitHub `clarity-gtd` repo
2. GitHub Pages auto-deploys in ~60 seconds
3. Hard refresh: `Cmd+Shift+R` / `Ctrl+Shift+R`
4. Live URL: https://18apples.github.io/clarity-gtd/

**Commit message rule:** Under 50 characters

**When adding new DB tables always include:**
```sql
grant select, insert, update, delete on public.new_table to authenticated;
grant select, insert, update, delete on public.new_table to service_role;
alter table public.new_table enable row level security;
create policy "authenticated access" on public.new_table
  for all to authenticated using (true);
```

---

## 💡 DEFERRED IDEAS PARKING LOT

- x_per_day deficit detail — show breakdown of accumulated deficit over multiple days
- Blackout period calendar stripe — continuous band across multi-day ranges in month view
- Per-task time tracking — start/stop timer, actual vs estimated
- Full text search — PostgreSQL tsvector index (current search is in-memory)
- Someday revisit date — surface in more places across the app
- Self-hosted backend option (PocketBase/Turso) for corporate/no-Supabase users
- Task sequencing Phase 2+ — visual timeline/Gantt, critical path, auto-cascading

---

## 🗒 HOW TO USE THIS FILE

**At the start of each Claude session:**
Upload `CLARITY_FEATURE_TRACKER.md` and `CLARITY_SPEC.md` together and say:
*"Here is the Clarity spec and feature tracker. Today I want to [goal]."*

**At the end of each session:**
Ask Claude to update both documents and download new versions.
Replace both files in GitHub with the updated versions.
