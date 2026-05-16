# CLARITY — GTD System Spec
> Living document. Update after every build session.
> Upload to Claude at the start of each session to restore full context.

---

## 1. What is Clarity?

A personal GTD (Getting Things Done) web application for Aparna. Built as a single-file HTML app connected to a Supabase backend. Designed to replace a Notion-based GTD setup that enabled procrastination through easy date nudging and manual metadata entry.

**Core philosophy:**
- Capture everything, decide later
- Every task should start with an action verb (soft warning, not blocking)
- Rescheduling requires a reason — no silent date nudging
- Cancelling requires a reason
- The system surfaces neglected areas automatically via review cadence

---

## 2. User Context

- **User:** Aparna — solo user for now, family members to be added in Phase 5
- **Workspace:** Personal (Work to be added later as separate workspace)
- **Stack:** Single-file HTML app (`index.html`) + Supabase (PostgreSQL) backend
- **Hosting:** GitHub Pages — https://18apples.github.io/clarity-gtd/
- **Auth:** Supabase Auth (email + password). Aparna is super user / admin.
- **Calendar:** Google Calendar integration planned (Phase 5)
- **AI:** Anthropic API for auto-tagging (planned Phase 5)

---

## 3. Files in the Repository

| File | Purpose |
|---|---|
| `index.html` | The entire app — single file, upload to GitHub to deploy |
| `clarity_full_setup.sql` | Complete DB setup: drop → create → grants → seed. Run once. |
| `clarity_add_contexts.sql` | Adds contexts table + seeds 4 contexts |
| `clarity_add_blackouts.sql` | Adds blackout_periods table |
| `clarity_add_subtasks.sql` | Adds subtasks table |
| `clarity_schedule_cron.sql` | Schedules 3 pg_cron daily jobs |
| `clarity_notion_import.sql` | One-time import of 162 Notion tasks |
| `CLARITY_SPEC.md` | This document |
| `CLARITY_FEATURE_TRACKER.md` | Full feature and bug tracker |

---

## 4. Database Schema

### 4.1 Domains and Categories (seeded)

| Icon | Domain | Categories |
|---|---|---|
| 💼 | Career | Job Hunting, Professional Growth |
| 🧡 | Family & Relationships | For Siddharth, For Vikram, Gifts & Other Items |
| ❤️ | Health & Fitness | Health & Fitness |
| 🏠 | Home | Home Decor & Improvements, Cleaning & Organizing, Car |
| 📚 | Education | Education |
| 🌱 | Personal Projects | Personal Projects, Food & Cooking |
| ✈️ | Travel | Travel Planning |
| 🎉 | Social | Entertainment, Social Events |
| 🏛 | Official & Admin | Finances, Government, Immigration |
| 💭 | Someday | Digital KonMari, Someday Ideas |
| 📌 | Uncategorized | General (catch-all) |

### 4.2 Tables

#### `workspaces` — `domains` — `categories`
Simple hierarchy. Domains are labels only — nothing links to them directly except categories.
Categories have `review_interval_days` (default 30), `is_paused`, `paused_until`, `pause_reason`.

#### `projects`
Linked to categories via junction. Must have at least one next action. Manually marked complete.
`status`: active / on_hold / complete / cancelled
`priority`: high / medium / low
On hold → all open tasks → waiting. Reactivate → tasks go back to next.

#### `tasks`
Core table. Every action, idea, recurring instance, and review task lives here.
```
type:   task | recurring | review | idea
status: inbox | next | waiting | someday | reference | done | cancelled
importance_speed: important_urgent | important_not_urgent | not_important_urgent | not_important_not_urgent
```
Key fields: `due_date`, `revisit_date`, `recurrence_id`, `recur_pattern`,
`current_count`, `target_count` (x_per_day), `estimated_mins`, `actual_mins`,
`reschedule_count`, `reschedule_reasons[]`, `cancellation_reason`, `ai_suggestions (jsonb)`

**Idea behaviour:**
- No category → stays as idea, status = inbox
- Has category → auto-promoted to status = someday
- Ideas view shows only uncategorised ideas

#### `recurrences`
Master template for recurring tasks. 13 patterns:
`x_per_day, daily, x_per_week, weekly, fortnightly, every_x_weeks, monthly, every_x_months, quarterly, every_6_months, yearly, random, adhoc`

`recur_mode`: fixed (calendar-anchored) vs relative (completion-anchored)
`counter_reset_mode`: daily_reset vs carry_over (x_per_day only)

**4 edit scenarios handled:**
1. New recurring — creates template + task
2. Edit existing recurring — updates template
3. Convert non-recurring → recurring — creates new template
4. Convert recurring → non-recurring — deactivates template, clears recurrence_id

#### `subtasks`
Checklist inside a task. One level only. `id, task_id, name, is_done, sort_order, created_at`
- Available on both new task capture and edit
- Reorderable with up/down arrows
- Blocks parent task completion until all subtasks done
- Progress badge ☑ 2/4 on parent task card

#### `contexts`
@context values managed in Settings. 4 seeded: @home, @out-and-about, @MuraliMama&Co, @laptop
Fields: `id, workspace_id, name, icon, sort_order, is_active`

#### `blackout_periods`
Date ranges when unavailable. Managed in Settings.
Fields: `id, workspace_id, label, start_date, end_date, created_at`
- Warning badge on task cards whose due date falls in a blackout
- Warning on due date field when picking a blackout date
- Calendar highlights blackout days in orange tint

#### Junction tables
`project_categories`, `task_categories`, `recurrence_categories`

#### `analytics_events`
Append-only log. Never deleted. Powers future analytics.
Event types: task_created, task_completed, task_cancelled, task_rescheduled, task_status_changed, project_created, project_completed, project_cancelled, review_generated, review_completed, idea_promoted, recurring_generated

### 4.3 Views
- `category_last_active` — last task activity per category
- `project_last_active` — last task activity per project
- `neglected_entities` — categories and projects overdue for review

### 4.4 Functions + Cron Jobs
- `calculate_next_occurrence()` — returns next due date from recurrence settings
- `generate_next_recurring_instance()` — creates next task instance on completion
- `generate_review_tasks()` — creates review tasks for neglected areas → runs 7AM daily
- `surface_recurring_tasks()` — surfaces recurring tasks due today → runs 6AM daily
- `surface_someday_tasks()` — returns someday items whose revisit_date arrived → runs 6AM daily

### 4.5 Security
RLS enabled on all tables. Policy: authenticated users can read/write all rows.
Explicit GRANTs for `authenticated`, `anon`, `service_role` on all tables.

---

## 5. App Structure

### 5.1 Navigation
10 tabs: Focus · Projects · Life Areas · Inbox · Next · Waiting · Someday · Reference · Ideas · Calendar
Plus: 🔍 global search button (opens overlay, searches all tasks, keyboard: `/` or `Cmd+K`)

**Note:** Navigation redesign planned (#53) — current horizontal scroll is cluttered.

### 5.2 Daily Focus View
- Day capacity planner — visual bar showing required vs available mins
  - Default 3hrs, overridable per day (resets next day)
  - Only counts tasks due today/overdue with estimated_mins filled
  - Shows minutes to free up if over capacity
  - Default configurable in Settings
- Quick capture bar — type + Enter
- Inbox alert — count of unprocessed inbox items (excludes ideas)
- Overdue section — tasks past their due date (red)
- Today section — tasks due today

### 5.3 Task Capture / Edit Form
Single unified modal for both new tasks and editing.
Fields: name (action verb soft warning), type, categories, importance/speed, context, due date + blackout warning, estimated time (default 30 mins), project, recurring toggle, notes, subtasks.

**New task:** subtask input available immediately. Save creates task + subtasks in one step.
**Edit task:** subtasks load from DB. Shows "Cancel Task" button.
**Cancel button:** closes form and opens cancel modal (requires reason).

**Recurring toggle behaviour:**
- Toggle ON → hides top-level due date, shows recurring section with First Due Date
- Toggle OFF → restores due date field
- Editing recurring task → toggle shows ON, fields pre-populated from template

### 5.4 Inbox View
- Search bar — filters by name and notes in real time
- Collapsible filter panel (collapsed by default, shows "X active" badge when filters on)
- Filters: Domain / Category / Importance / Context / Task Type (All/Recurring/Regular/Ideas) / Estimated Time (≥/≤) / Missing Fields
- Life Areas task count chips link here with pre-applied filters
- Process modal: assign status, due date, revisit date, or cancel

### 5.5 Pipeline Views
- **Next:** all status=next, filterable by context
- **Waiting:** blocked tasks, move to Next button
- **Someday:** parked items, set revisit date, move to Next
- **Reference:** searchable info store
- **Ideas:** uncategorised ideas only, promote to task or project

### 5.6 Task Cards
Every task card has: checkbox, name, notes snippet, tags (type/IQ/context/categories/due date/blackout warning/subtask progress/estimated time)
Actions: ↕ status change · ↻ reschedule · ✎ edit · ✕ cancel
Task actions always visible on mobile.

### 5.7 Projects View
List grouped by status with filter chips. Project cards show name, outcome, priority, deadline, categories, next action, task count.
Project detail: all linked tasks, status actions (on hold / reactivate / complete / cancel).

### 5.8 Life Areas View
All domains expandable (one open at a time). Each domain shows task breakdown chips per category:
📋 Tasks / 🔄 Recurring / 💡 Ideas / 📥 Inbox / ⚡ Next / ⏳ Waiting / 🌙 Someday
Each chip links to Inbox pre-filtered by that domain/category + type/status.
Create/edit/delete domains and categories inline.

### 5.9 Calendar View
Week view (7 columns) and Month view (grid) with toggle.
Blackout days highlighted in orange. Task chips clickable → opens edit.
Nav arrows + Today button.

### 5.10 Global Search
Opens as overlay from 🔍 nav button or keyboard shortcut.
Searches ALL tasks regardless of status or type — name and notes.
Results show status icon, category tags, due date. Click → opens edit form.

### 5.11 Settings (current — modal)
Profile, workspace name, default daily capacity, contexts management, blackout periods management, password change, admin panel (Supabase URL/keys — locked, re-auth required).

**Note:** Settings redesign planned (#37) — full page with sub-tabs.

---

## 6. Key Design Decisions & Why

| Decision | Why |
|---|---|
| Single-file HTML app | Portable, no build step, GitHub Pages hosting |
| Supabase backend | Free tier, PostgreSQL, built-in auth |
| Junctions for categories | Data integrity, query performance, future analytics |
| Ideas auto-promote to someday when categorised | Categorised = committed, links to category review cadence |
| Cancelled/rescheduled require reason | Makes procrastination patterns visible in analytics |
| Two-table recurring design | Template separate from instances keeps history clean |
| counter_reset_mode | Different tasks have different rules for missed counts |
| revisit_date on someday | Prevents someday from becoming a black hole |
| Domains are labels only | Avoids rigid hierarchy — tasks belong to categories not domains |
| Subtasks available on first capture | No need to save and reopen — save handles everything in one step |
| Action verb warning — soft, not blocking | Informational nudge, not a gate |
| Default 30 mins estimated time | Encourages time awareness without requiring manual entry |
| Explicit SQL GRANTs | Future-proofs against Supabase policy enforcement (Oct 2026) |

---

## 7. Open Questions / Deferred Decisions

- [ ] Projects shared between family members — how does co-ownership work?
- [ ] Delegated tasks — copied vs referenced in assignee's view?
- [ ] Work workspace — separate workspace, Focus merges both
- [ ] Google Calendar sync — approach and timing
- [ ] Task card color coding — strip to one signal, decide which one (#56)
- [ ] Idea vs Someday edge cases — needs more real-world use
- [ ] x_per_day carry-over deficit — breakdown display when deficit accumulates over multiple days

---

## 8. Session Log

| Period | What was built |
|---|---|
| Foundation | Schema, auth, app shell, settings, task capture |
| Phase 2 | Daily Focus, recurring tasks, complete/reschedule/cancel, calendar |
| Phase 3 | Projects, Life Areas, domain/category CRUD, Notion import |
| Phase 4 | All pipeline views, edit task, inbox search+filters, capacity planner |
| Phase 4 cont. | Contexts (DB + settings), blackout periods, x_per_day carry-over, subtasks |
| Phase 4 cont. | Idea→someday promotion, life areas breakdown, collapsible inbox filters |
| Bug fixes | Calendar month view, category pause, recurring toggle, mobile fixes |
| Phase 4 cont. | Recurring edit (all 4 scenarios), global search, status change, subtask reorder |
| Latest | B21 B22 fixed, #43 #51 #52 #55 built, docs updated |

---

## 9. Deployment Workflow

1. Claude provides updated `index.html`
2. Upload to GitHub `clarity-gtd` repo
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

## 10. How to Use This Document

**At the start of each Claude session:**
Upload `CLARITY_SPEC.md` AND `CLARITY_FEATURE_TRACKER.md` together and say:
*"Here is the Clarity spec and feature tracker. Today I want to [goal]."*

**At the end of each session:**
Ask Claude to update both documents and download new versions.
Replace both files in GitHub with the updated versions.
