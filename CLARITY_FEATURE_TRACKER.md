# CLARITY GTD — Feature & Bug Tracker
> Last updated: May 2026
> Keep in GitHub alongside index.html and CLARITY_SPEC.md
> Upload to Claude at the start of any session to restore context

---

## ✅ COMPLETED FEATURES

| # | Feature | Notes |
|---|---|---|
| 1 | Auth — sign in / sign up / session refresh | |
| 2 | First-time Supabase setup | Config button on auth screen, disappears after setup |
| 3 | App shell + navigation | 10 tabs including Calendar |
| 4 | Settings modal — profile, workspace, password, admin panel | Admin locked, re-auth required, 1hr unlock |
| 5 | Task capture — all fields, verb enforcement | Name, type, categories, IQ, context, due date, est. time, project, recurring, notes |
| 6 | Inline category picker — grouped by domain | Tap to toggle, multi-select |
| 7 | Daily Focus — overdue + today only | Tasks without due dates go to Inbox only |
| 8 | Recurring tasks — 13 patterns | All patterns including x_per_day with counter |
| 9 | Complete task + recurring next instance | Ad-hoc prompts for next date |
| 10 | Reschedule — requires reason | Tracks reschedule_count and reschedule_reasons[] |
| 11 | Cancel task — requires reason | From task cards and from edit form |
| 12 | Calendar — week + month toggle | Week/month views, nav arrows, Today button |
| 13 | Notion inbox import — SQL | 162 tasks imported via clarity_notion_import.sql |
| 14 | Projects — create, edit, list, detail | Grouped by status, filter chips |
| 15 | Project on hold — tasks → waiting | Optional on-hold-until date + reason |
| 16 | Project reactivate, complete, cancel | Reactivate restores tasks to Next |
| 17 | Life Areas — domains + categories | Expandable accordion, one open at a time |
| 18 | Create / edit domain and category | Icon/emoji, review interval, pause/unpause |
| 19 | Delete domain/category — move tasks | Safety check: prompts to move linked tasks |
| 20 | Project task capture — inherits categories | Pre-selects project categories |
| 21 | Inbox view — full pipeline | Search + filters (domain, category, IQ, context, type, est. time, missing fields) |
| 22 | Next Actions view | Filterable by context, sorted by due date |
| 23 | Waiting view | Move to Next button |
| 24 | Someday view | Set revisit date, resurfaces to inbox automatically |
| 25 | Reference view | Live search by name and notes |
| 26 | Ideas view | Promote to task or project |
| 27 | Edit task | Full edit form, pre-fills all fields |
| 28 | Process task from Inbox | Assign status, due date, revisit date, or cancel |
| 29 | Task count → Inbox filter | Clicking count in Life Areas opens Inbox pre-filtered |
| 30 | Day capacity planner | Focus view. Visual bar: required vs available. Override per day. Default 3hrs in Settings |
| 31 | Contexts table + management | DB table, 4 seeded: @home @out-and-about @MuraliMama&Co @laptop. Managed in Settings |
| 32 | Inbox filters — context, type, est. time, missing | Full filter suite with persist + clear |
| 33 | Blackout periods | Settings section: add/edit/delete. Warning on cards + date field. Calendar highlight |
| 34 | x_per_day carry-over | Deficit carries forward to next instance target_count |
| 35 | Subtasks | Checklist in edit form. ☑ 2/4 badge on cards. Blocks completion until all done |
| 36 | Cancel button on edit form | Red Cancel Task shown only when editing existing tasks |

---

## 🐛 KNOWN BUGS

| # | Bug | Details | Status |
|---|---|---|---|
| B1 | Calendar month view not rendering | Clicking Month toggle may not switch from week view. Fix applied in last build — needs verification | Needs testing |
| B2 | Settings modal may break after patches | Caused by accumulated JS patches — fixed in last build | Needs testing |
| B3 | `sp is not defined` in renderCard | subtaskBadge variable used before defined. Fixed in last build | Fixed |
| B4 | Syntax error line 1603 | Broken quotes in task-check onclick. Fixed in last build | Fixed |

---

## 🔜 FEATURES NOT YET BUILT

### #37 — Settings Redesign (Full Page + Sub-tabs)
**Effort:** Medium
**Priority:** Next build
**Details:**
- Replace current modal popup with a full-page Settings tab in the nav
- Sub-tabs within the Settings page:
  - **Account** — profile display, email, password change
  - **Workspace** — workspace name, default daily capacity
  - **Contexts** — manage @context list (add, edit, toggle active/inactive)
  - **Blackout Periods** — manage unavailable date ranges
  - **Users & Permissions** — placeholder for now, family user management later
  - **Admin** — Supabase URL, anon key, Anthropic API key — stays locked behind re-auth
- Settings tab added to main nav alongside Focus, Projects etc.

---

### #38 — Analytics Dashboard
**Effort:** Large
**Details:**
- Completion rates over time (tasks done vs created)
- Procrastination patterns (reschedule count distribution, reasons breakdown)
- Domain/category balance (where are most tasks?)
- Cancelled task reasons breakdown
- Streaks and trends over time
- Powered by analytics_events table (already in DB, events logged throughout app)

---

### #39 — Google Calendar Sync
**Effort:** Large
**Details:**
- Two-way sync between Clarity tasks (with due dates) and Google Calendar
- Tasks with due dates appear as calendar events in Google Calendar
- Moving/resizing an event in Google Calendar updates task due date in Clarity
- Requires OAuth2 setup with Google Calendar API
- Deferred — complex OAuth flow, build after core is fully stable

---

### #40 — AI Auto-tagging
**Effort:** Medium
**Details:**
- Fires 600ms after typing stops in task name field
- Calls Anthropic API with task name + list of domains, categories, contexts, importance values
- Suggests: category, importance/speed, context, estimated time
- Suggestions shown as pre-fills — user can accept or change
- Tracks accepted vs overridden per field in ai_suggestions jsonb column (already in tasks table)
- Requires Anthropic API key configured in Admin Settings
- Infrastructure already exists — just needs the UI trigger and API call

---

### #41 — Family Multi-User
**Effort:** Very Large
**Phase:** 5
**Details:**

**Vision:** Each family member has their own account and their own complete view of the world.

**Confirmed decisions:**
- Each user gets their own Focus, Inbox, Next, Projects, Life Areas, Calendar etc.
- Each user can have multiple workspaces (Personal + Work, or Personal + School for kids)
- Family members cannot see each other's tasks unless specifically included on a task or project
- When you delegate a task to someone (e.g. Siddharth):
  - Task stays in YOUR view as **Waiting** status, tagged "delegated to Siddharth"
  - Task appears in SIDDHARTH's view so he can plan around it
  - How it lives in his view (copied vs referenced) — **TBD**
- No simplified UI for children — middle school age and above, same full UI
- Projects shared between family members — **TBD, to be refined**

**DB changes needed:**
- `users` table (beyond Supabase Auth) — name, family_id, role
- `families` table — top-level container above workspaces
- Delegations table or field linking tasks to other users
- RLS policies scoped to family_id

**Open questions:**
- Copied vs referenced: when a task is delegated, does it create a copy in the assignee's DB or just a pointer?
- Projects: can a project be co-owned? Who can add tasks to it?
- What happens when the assignee completes a delegated task — does the delegator's copy update?

---

### #42 — Multi-tenant + Social Ecosystem
**Effort:** Massive
**Phase:** Future ideas only — not building now
**Details:**

**Multi-tenant:** Friends can spin up their own completely isolated Clarity instance for their family. Two approaches:
- Same Supabase project, different family workspaces (careful RLS needed)
- Separate Supabase project per family (more isolated, more setup)

**Social ecosystem (long-term vision):** Families could optionally link to share things — a shared shopping list, a family event, a task delegated to a friend outside the family. Think of it as a lightweight family OS that can connect outward to a broader social graph.

**Not building now.** Revisit after multi-user is stable.

---

### #43 — Subtasks Enhancements
**Effort:** Small
**Details:**
- Drag to reorder subtasks within the edit form
- Subtask notes (optional, small text field)

---

### #44 — Blackout Periods — Calendar Stripe
**Effort:** Small
**Details:**
- Currently: individual blackout dates highlighted in orange tint
- Enhancement: show a continuous labelled stripe/band across multi-day blackout ranges
- Blackout label shown on first day of the range in month view

---

### #45 — Per-task Time Tracking
**Effort:** Medium
**Details:**
- Start/stop timer on task cards
- Fills actual_mins field (already in tasks table)
- Actual vs estimated comparison in analytics

---

### #46 — Full Text Search
**Effort:** Small
**Details:**
- Search bar accessible from header or dedicated view
- Searches across task names, notes, project names
- PostgreSQL tsvector index to add to tasks table
- Deferred — add when volume of tasks makes finding things harder

---

## 📋 SQL FILES IN GITHUB

| File | Purpose | Status |
|---|---|---|
| `clarity_full_setup.sql` | Complete DB setup — drop, create, grants, seed. Run once. | ✅ Run |
| `clarity_notion_import.sql` | Imports 162 tasks from Notion export | ✅ Run |
| `clarity_add_contexts.sql` | Adds contexts table + seeds 4 contexts | ✅ Run |
| `clarity_add_blackouts.sql` | Adds blackout_periods table | ✅ Run |
| `clarity_add_subtasks.sql` | Adds subtasks table | ✅ Run |

---

## 🏗 DATABASE TABLES (Live in Supabase)

| Table | Purpose |
|---|---|
| workspaces | Top-level container |
| domains | Life area labels (Career, Home, etc.) |
| categories | Grouped under domains |
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
- x_per_day deficit detail — show breakdown of how deficit built up over multiple days
- Someday revisit date — surface in more places across the app
- Blackout period calendar stripe — continuous band across multi-day ranges
- Subtask reordering — drag within edit form
- Per-task time tracking — start/stop timer, actual vs estimated
- Full text search — across tasks, notes, projects

---

## 🗒 HOW TO USE THIS FILE

**At the start of each Claude session:**
Upload `CLARITY_FEATURE_TRACKER.md` and `CLARITY_SPEC.md` together and say:
*"Here is the Clarity spec and feature tracker. Today I want to [goal]."*

**At the end of each session:**
Ask Claude to update the relevant sections and download the new version.
Replace the file in GitHub with the updated version.
