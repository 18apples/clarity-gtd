# CLARITY GTD — Feature & Bug Tracker
> Last updated: May 2026
> Keep in GitHub alongside index.html and CLARITY_SPEC.md
> Upload to Claude at the start of any session to restore context

---

## ✅ COMPLETED FEATURES

| # | Feature | Notes |
|---|---|---|
| 1 | Auth — sign in / sign up / session refresh | |
| 2 | First-time Supabase setup | Config button on auth screen |
| 3 | App shell + navigation | 10 tabs + 🔍 global search button |
| 4 | Settings modal — profile, workspace, password, admin | Admin locked, re-auth required, 1hr unlock |
| 5 | Task capture — all fields, verb enforcement | Name, type, categories, IQ, context, due date, est. time, project, recurring, notes |
| 6 | Inline category picker — grouped by domain | Tap to toggle, multi-select |
| 7 | Daily Focus — overdue + today only | Tasks without due dates go to Inbox only |
| 8 | Recurring tasks — 13 patterns | All patterns including x_per_day with counter |
| 9 | Complete task + recurring next instance | Ad-hoc prompts for next date |
| 10 | Reschedule — requires reason | Tracks reschedule_count and reschedule_reasons[] |
| 11 | Cancel task — requires reason | From task cards and from edit form |
| 12 | Calendar — week + month toggle | Week/month views, nav arrows, Today button, blackout highlights |
| 13 | Notion inbox import — SQL | 162 tasks imported via clarity_notion_import.sql |
| 14 | Projects — create, edit, list, detail | Grouped by status, filter chips |
| 15 | Project on hold — tasks → waiting | Optional on-hold-until date + reason |
| 16 | Project reactivate, complete, cancel | Reactivate restores tasks to Next |
| 17 | Life Areas — domains + categories | Expandable accordion, one open at a time |
| 18 | Create / edit domain and category | Icon/emoji, review interval, pause/unpause |
| 19 | Delete domain/category — move tasks | Safety check: prompts to move linked tasks |
| 20 | Project task capture — inherits categories | Pre-selects project categories |
| 21 | Inbox view — full pipeline | Search + filters (domain, category, IQ, context, type, est. time, missing fields) |
| 22 | Inbox filter panel collapsible | Collapsed by default, shows active filter count badge |
| 23 | Next Actions view | Filterable by context, sorted by due date |
| 24 | Waiting view | Move to Next button |
| 25 | Someday view | Set revisit date, resurfaces to inbox automatically |
| 26 | Reference view | Live search by name and notes |
| 27 | Ideas view | Shows only uncategorised ideas. Promote to task or project |
| 28 | Edit task | Full edit form, pre-fills all fields |
| 29 | Process task from Inbox | Assign status, due date, revisit date, or cancel |
| 30 | Task count → Inbox filter | Clicking domain/category in Life Areas opens Inbox pre-filtered |
| 31 | Life Areas task breakdown | Per domain/category: type and status breakdown chips, each clickable |
| 32 | Day capacity planner | Focus view. Visual bar: required vs available. Override per day. Default 3hrs in Settings |
| 33 | Contexts table + management | DB table, 4 seeded. Managed in Settings. Capture pulls from DB |
| 34 | Inbox filters — context, type, est. time, missing | Full filter suite with persist + clear + collapsible panel |
| 35 | Blackout periods | Settings section: add/edit/delete. Warning on cards + date field. Calendar highlight |
| 36 | x_per_day carry-over | Deficit carries forward to next instance target_count |
| 37 | Subtasks | Checklist in edit form AND new task capture. ☑ 2/4 badge on cards. Up/down reorder. Blocks completion until all done |
| 38 | Cancel button on edit form | Red Cancel Task shown only when editing existing tasks |
| 39 | Idea → Someday auto-promotion | Ideas with a category auto-set to someday status |
| 40 | Status change on task cards | ↕ button on every card opens status picker modal |
| 41 | Global task search | 🔍 in nav. Searches all tasks/statuses/types. Keyboard: / or Cmd+K |
| 42 | pg_cron jobs scheduled | surface_recurring, surface_someday, generate_review_tasks — all daily |
| 43 | Default 30 mins estimated time | New task capture pre-fills 30 mins |
| 44 | Recurring task edit — all 4 scenarios | New / edit existing / convert to recurring / convert to non-recurring |

---

## 🐛 KNOWN BUGS

| # | Bug | Status |
|---|---|---|
| B15 | Recurring toggle shows OFF for existing recurring tasks | Fixed — still testing |
| B18 | Converting task to recurring not saving | Fixed — still testing |

---

## 🔜 FEATURES NOT YET BUILT

### Navigation & Layout

**#37 — Settings Redesign (Full Page + Sub-tabs)**
**Effort:** Medium | **Priority:** Next major build
- Replace current modal popup with a full-page Settings tab in the nav
- Sub-tabs: Account / Workspace / Contexts / Blackout Periods / Users & Permissions / Admin
- Admin stays locked behind re-auth
- Build together with #53 (nav redesign)

**#53 — Navigation Bar Redesign**
**Effort:** Medium | **Build with #37**
- Current 10-tab horizontal scroll is cluttered and hard to use on mobile
- Proposed grouping: Primary (Focus, Inbox, Projects) + Pipeline dropdown (Next, Waiting, Someday, Reference, Ideas) + Explore (Calendar, Life Areas) + Settings
- Mobile: bottom tab bar or hamburger for secondary tabs

---

### Task Management

**#51 — Status Change — DONE ✅**
Built in last build.

**#54 — Action Verb Warning Less Intrusive**
**Effort:** Small
- Replace blocking confirm() dialog with a subtle inline hint
- Warning is informational only — does not block saving
- "Tip: starting with an action verb keeps tasks actionable"

**#56 — Task Card Color Coding Redesign**
**Effort:** Small | **Phase:** Future refinement
- Current coloring is too busy and not useful in practice
- Strip to one meaningful signal (e.g. domain color as left border stripe only)
- Everything else monochrome

---

### Views & Discovery

**#49 — Life Areas Task Count Visual Improvements**
**Effort:** Medium | **Deferred — visual improvements phase**
- Current breakdown chips work but need visual polish
- Better layout for the type/status breakdown within domain accordion

**#52 — Global Task Search — DONE ✅**
Built in last build.

---

### Ideas & Someday

**#47 — Idea → Someday Auto-promotion — DONE ✅**
Built and confirmed working.

**#57 — Idea vs Someday Refinement**
**Effort:** Small | **Phase:** Needs more real-world use before deciding
- Concepts currently overlap in some edge cases
- Current rule: idea + no category = stays as idea; idea + category = promoted to someday
- Revisit after more use to see if further distinction is needed

---

### Analytics

**#38 — Eisenhower Matrix Time Distribution Chart**
**Effort:** Medium | **Phase:** 5 — first analytics feature
- Chart showing completed task distribution across 4 Eisenhower quadrants
- Toggle: Day / Week / Month
- Data: completed tasks within period, uses estimated_mins as proxy for time
- Visual: donut or bar chart, percentage + total mins per quadrant
- Insight text: e.g. "68% of time was Important+Urgent — shift more to Important+Not Urgent"
- Tasks without importance_speed shown as "Untagged"

---

### Family & Multi-user

**#41 — Family Multi-User**
**Effort:** Very Large | **Phase:** 5
- Each family member has own account, own complete view (Focus, Inbox, Projects etc.)
- Each user can have multiple workspaces (Personal + Work/School)
- Family members cannot see each other's tasks unless specifically included
- Delegating a task → stays in your view as Waiting (delegated), appears in assignee's view
- Projects shared between family members — TBD
- How delegated tasks live (copied vs referenced) — TBD
- No simplified UI for children — middle school age and above, same full UI
- DB changes needed: users table, families table, delegations, RLS scoped to family_id

**#42 — Multi-tenant + Social Ecosystem**
**Effort:** Massive | **Phase:** Future only
- Friends can spin up own isolated Clarity instance
- Long-term: social linking between families
- Not building now

---

### Subtasks

**#43 — Subtask Reordering — DONE ✅**
Built in last build — up/down arrow buttons on each subtask.

---

## 📋 SQL FILES IN GITHUB

| File | Purpose | Status |
|---|---|---|
| `clarity_full_setup.sql` | Complete DB setup — drop, create, grants, seed. Run once. | ✅ Run |
| `clarity_notion_import.sql` | Imports 162 tasks from Notion export | ✅ Run |
| `clarity_add_contexts.sql` | Adds contexts table + seeds 4 contexts | ✅ Run |
| `clarity_add_blackouts.sql` | Adds blackout_periods table | ✅ Run |
| `clarity_add_subtasks.sql` | Adds subtasks table | ✅ Run |
| `clarity_schedule_cron.sql` | Schedules 3 pg_cron daily jobs | ✅ Run |

---

## 🏗 DATABASE TABLES (Live in Supabase)

| Table | Purpose |
|---|---|
| workspaces | Top-level container |
| domains | Life area labels (Career, Home, etc.) |
| categories | Grouped under domains, with review cadence |
| projects | Multi-step goals |
| tasks | All tasks, ideas, recurring instances, reviews |
| recurrences | Recurring task templates |
| subtasks | Checklist items inside tasks |
| contexts | @context values managed in Settings |
| blackout_periods | Date ranges when unavailable |
| project_categories | Junction: projects ↔ categories |
| task_categories | Junction: tasks ↔ categories |
| recurrence_categories | Junction: recurrences ↔ categories |
| analytics_events | Append-only activity log |

---

## 🔁 DEPLOYMENT WORKFLOW

1. Claude provides updated `index.html`
2. Upload to GitHub `clarity-gtd` repo as `index.html`
3. GitHub Pages auto-deploys in ~60 seconds
4. Hard refresh: `Cmd+Shift+R` (Mac) / `Ctrl+Shift+R` (Windows)
5. Live URL: https://18apples.github.io/clarity-gtd/

**Commit message rule:** Keep under 50 characters

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

- Calendar drag to reschedule — desktop only, triggers reason modal
- x_per_day deficit detail — show breakdown of how deficit built up over days
- Blackout period calendar stripe — continuous band across multi-day ranges in month view
- Per-task time tracking — start/stop timer, actual vs estimated
- Full text search — PostgreSQL tsvector index on tasks (global search currently in-memory)
- Task card color coding redesign — strip to one meaningful signal (#56)
- Someday revisit date — surface in more places across the app

---

## 🗒 HOW TO USE THIS FILE

**At the start of each Claude session:**
Upload `CLARITY_FEATURE_TRACKER.md` and `CLARITY_SPEC.md` together and say:
*"Here is the Clarity spec and feature tracker. Today I want to [goal]."*

**At the end of each session:**
Ask Claude to update the relevant sections and download the new version.
Replace the file in GitHub with the updated version.
