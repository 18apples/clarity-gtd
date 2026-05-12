# CLARITY — GTD System Spec
> Living document. Update after every build session.
> Paste this at the start of each Claude session to restore full context.

---

## 1. What is Clarity?

A personal GTD (Getting Things Done) web application for Aparna. Built as a single-file HTML app connected to a Supabase backend. Designed to replace a Notion-based GTD setup that enabled procrastination through easy date nudging and manual metadata entry.

**Core philosophy:**
- Capture everything, decide later
- Every task must have an action verb (enforced)
- Rescheduling requires a reason — no silent date nudging
- Cancelling requires a reason
- AI auto-tags metadata on capture
- The system surfaces neglected areas automatically

---

## 2. User Context

- **User:** Aparna — solo user for now, may add husband later
- **Workspace:** Personal (Work to be added as a separate workspace later)
- **Stack:** Single-file HTML app + Supabase (PostgreSQL) backend
- **Access:** Downloaded HTML file opened locally in Chrome, or hosted on Netlify
- **Auth:** Supabase Auth (email + password). Aparna is the super user / admin.
- **Calendar:** Google Calendar integration planned (not yet built)
- **AI:** Anthropic API for auto-tagging (optional, requires API key + credits)

---

## 3. Database Schema

### Current status: WIPED CLEAN. Ready to rebuild from scratch.

### 3.1 Tables

#### `workspaces`
Top-level container. Personal now, Work later. Every table carries `workspace_id`.
```
id            uuid pk
name          text
color         text
created_at    timestamptz
```
**On creation:** auto-seeds one domain "Uncategorized" and one category "General" as catch-all defaults.

---

#### `domains`
Simple label/grouping for categories. Nothing else links to domains directly except categories. No review intervals, no pause logic, no foreign keys from tasks or projects.
```
id            uuid pk
workspace_id  uuid fk → workspaces
name          text
icon          text (emoji)
color         text
sort_order    integer
created_at    timestamptz
```

---

#### `categories`
Belong to one domain. Every task and project should have at least one category. A default "General" category under "Uncategorized" domain acts as catch-all.
```
id                   uuid pk
workspace_id         uuid fk → workspaces
domain_id            uuid fk → domains
name                 text
description          text
review_interval_days integer (default 30)
is_paused            boolean (default false)
paused_until         date (nullable)
pause_reason         text (nullable)
sort_order           integer
created_at           timestamptz
```
**Review logic:** if `now() - last_activity > review_interval_days` and not paused, a review task is auto-generated. `last_activity` is computed from task activity, never stored.

---

#### `projects`
Not linked to a domain. Linked to one or more categories via junction table. Must have at least one next action task to be created. Manually marked complete — never auto-completed.
```
id                   uuid pk
workspace_id         uuid fk → workspaces
name                 text
outcome              text (what does done look like?)
status               project_status enum
priority             project_priority enum
deadline             date (nullable)
review_interval_days integer (default 30)
on_hold_until        date (nullable)
on_hold_reason       text (nullable)
created_at           timestamptz
completed_at         timestamptz (nullable)
```
**Enums:**
- `project_status`: active, on_hold, complete, cancelled
- `project_priority`: high, medium, low

---

#### `tasks`
Core table. Every action, idea, review, and recurring instance lives here.
```
id                   uuid pk
workspace_id         uuid fk → workspaces
project_id           uuid fk → projects (nullable)
recurrence_id        uuid fk → recurrences (nullable — set if type = recurring)

name                 text (action verb enforced for task/recurring/review types)
notes                text (nullable)
type                 task_type enum
status               task_status enum

importance_speed     importance_speed enum (nullable)
context              text (nullable — @phone, @computer, @errands, @home)

due_date             date (nullable)
revisit_date         date (nullable — for someday items, surfaces back to inbox on this date)
completed_at         timestamptz (nullable)
cancelled_at         timestamptz (nullable)
cancellation_reason  text (nullable — required when status = cancelled)

estimated_mins       integer (nullable)
actual_mins          integer (nullable)

reschedule_count     integer (default 0)
reschedule_reasons   text[] (default {})

-- Recurring instance fields (only used when type = recurring)
current_count        integer (default 0 — for x_per_day counter)
target_count         integer (nullable — copied from recurrence template)

-- AI metadata
ai_suggestions       jsonb (default {} — per-field: {suggested, accepted, overridden_to})

created_at           timestamptz
```

**Enums:**
- `task_type`: task, recurring, review, idea
- `task_status`: inbox, next, waiting, someday, reference, done, cancelled
- `importance_speed`: important_urgent, important_not_urgent, not_important_urgent, not_important_not_urgent

**Key rules:**
- `task` and `recurring` types require action verb in name (enforced at app level)
- `idea` type: no verb enforced, no status pipeline, optional everything
- `review` type: auto-generated by system, links back to the category/project that triggered it via `review_for_entity_type` and `review_for_entity_id`
- Cancelling requires `cancellation_reason`
- `revisit_date` only meaningful for `someday` status — resurfaces to inbox on that date

---

#### `recurrences`
Master template for recurring tasks. Stores all pattern settings. Task instances are generated from this template and link back via `recurrence_id`.
```
id                     uuid pk
workspace_id           uuid fk → workspaces
project_id             uuid fk → projects (nullable)

name                   text
notes                  text (nullable)
importance_speed       importance_speed enum (nullable)
context                text (nullable)
estimated_mins         integer (nullable)

recur_mode             recur_mode enum
recur_pattern          recur_pattern enum
recur_interval_value   integer (nullable — X in "every X weeks/months")
recur_days_of_week     integer[] (nullable — [0=Sun..6=Sat] for x_per_week)
recur_times_per_day    integer (nullable — target for x_per_day)
counter_reset_mode     counter_reset_mode enum (nullable — only for x_per_day)
recur_random_min_days  integer (nullable)
recur_random_max_days  integer (nullable)
recur_anchor_date      date (nullable — fixed anchor for monthly/yearly)
recur_anchor_day       integer (nullable — 0-6 for weekly fixed anchor)

is_active              boolean (default true)
last_occurrence        date (nullable)
next_occurrence        date (nullable)
last_generated_at      timestamptz (nullable)

created_at             timestamptz
```

**Enums:**
- `recur_mode`: fixed, relative
- `recur_pattern`: x_per_day, daily, x_per_week, weekly, fortnightly, every_x_weeks, monthly, every_x_months, quarterly, every_6_months, yearly, random, adhoc
- `counter_reset_mode`: daily_reset, carry_over

**Recurrence modes explained:**
- `fixed` — next occurrence always on fixed calendar schedule, never drifts (e.g. rent always on 1st)
- `relative` — next occurrence calculated from completion date (e.g. clean fan 3 weeks after last cleaned)

**Counter reset modes (x_per_day only):**
- `daily_reset` — counter always starts fresh next day regardless of whether target was hit (e.g. medication)
- `carry_over` — deficit carries forward if target not hit (e.g. 10 pages/day reading — missed 3 yesterday, need 13 today)

---

#### `project_categories` (junction)
```
project_id    uuid fk → projects (on delete cascade)
category_id   uuid fk → categories (on delete cascade)
PRIMARY KEY (project_id, category_id)
```

#### `task_categories` (junction)
```
task_id       uuid fk → tasks (on delete cascade)
category_id   uuid fk → categories (on delete cascade)
PRIMARY KEY (task_id, category_id)
```

#### `recurrence_categories` (junction)
```
recurrence_id uuid fk → recurrences (on delete cascade)
category_id   uuid fk → categories (on delete cascade)
PRIMARY KEY (recurrence_id, category_id)
```

---

#### `analytics_events`
Append-only log. Every meaningful action writes a row here. Powers all stats without polluting main tables. Never deleted.
```
id            uuid pk
workspace_id  uuid fk → workspaces
entity_type   text (task, project, category, recurrence)
entity_id     uuid
event_type    analytics_event_type enum
metadata      jsonb (flexible payload per event)
created_at    timestamptz
```

**Enum — `analytics_event_type`:**
task_created, task_completed, task_cancelled, task_rescheduled, task_status_changed, project_created, project_completed, project_cancelled, review_generated, review_completed, idea_promoted, recurring_generated

---

### 3.2 Computed / Views (not stored)

- **Category last activity** — computed from task activity in that category
- **Project last activity** — computed from task activity in that project
- **Neglect detection** — surfaces categories and projects overdue for review

---

### 3.3 Key Functions

- `calculate_next_occurrence()` — returns next due date based on recur mode + pattern
- `generate_next_recurring_instance()` — called when recurring task is completed; creates next task instance from template
- `roll_past_blackouts()` — placeholder for future blackout period feature
- `generate_review_tasks()` — daily cron; checks neglected categories/projects and creates review tasks
- `surface_recurring_tasks()` — daily cron; sets status = next for recurring tasks whose next_occurrence = today

---

### 3.4 Not Yet Built (future)

- `blackout_periods` — date ranges where user is unavailable; due dates auto-roll past them
- `people` — contacts for delegation and waiting-for tracking
- Full-text search index on tasks
- Notion CSV import tool

---

## 4. App Structure

### Current status: NOT YET BUILT. SQL first.

### 4.1 Views planned
1. **Daily Focus** — today's tasks, overdue, inbox items
2. **Projects** — grouped, filterable by status, project detail view
3. **Life Areas** — domains and categories, expandable, editable
4. **Ideas** — idea type tasks, promotable to task or project
5. **Someday** — parked items, with revisit dates
6. **Reference** — searchable filing cabinet
7. **Settings** — profile, workspace, password, locked admin panel

### 4.2 Task Capture (single unified form)
- Action verb enforced for task/recurring/review types
- Domain shown for reference only (not stored on task)
- Category picker (multi-select, required — defaults to General)
- Importance/Speed (Eisenhower matrix)
- Context (@phone, @computer, @errands, @home)
- Due date (calendar picker)
- Estimated time
- Project link (optional)
- Recurring toggle — expands inline with all pattern options
- AI auto-tagging — fires after 600ms pause in typing if API key configured
- Notes

### 4.3 Recurring Task UI
- Created via toggle in standard capture form — no separate tab/view
- 🔄 indicator on task cards
- X-per-day shows tap counter in Daily Focus
- Completing generates next instance from template automatically
- Ad-hoc prompts for next date
- Editing asks: "Just this instance" or "This and all future occurrences"

### 4.4 Settings
- Profile (email display, super user badge)
- Workspace name (editable)
- Password change
- Admin panel — visible but locked; re-enter credentials to unlock; unlocks for 1 hour with countdown timer; contains Supabase URL, anon key, Anthropic API key

### 4.5 Anti-Procrastination Rules (enforced in UI)
- Action verb required on task name
- Rescheduling requires selecting a reason from a list
- Cancelling requires a reason
- Projects require a first next action to be created
- Inbox items surface as an alert until processed

---

## 5. Key Design Decisions & Why

| Decision | Why |
|---|---|
| Single-file HTML app | Portable, no build step, works locally or hosted |
| Supabase backend | Free tier generous, PostgreSQL, built-in auth, real-time capable |
| Junctions for categories | Data integrity, query performance, future analytics |
| Ideas as a task type | Avoids forcing ideas into task pipeline prematurely |
| Cancelled status with reason | Makes procrastination and decision patterns visible in analytics |
| Two-table recurring design | Template separate from instances keeps history clean |
| counter_reset_mode | Different tasks have different rules for missed counts |
| revisit_date on someday | Prevents someday from becoming a black hole |
| AI suggestions as jsonb | Tracks which suggestions were accepted vs overridden per field |
| Domains are labels only | Avoids rigid hierarchy that doesn't reflect real life |
| No domain on tasks/projects | Tasks and projects belong to categories, not domains |
| Blackout periods deferred | Build when needed, schema slot reserved |
| People table deferred | Solo user for now, easy to add later |

---

## 6. Open Questions / Deferred Decisions

- [ ] What counts as "complete" for x_per_day — carry_over behaviour in detail
- [ ] Someday revisit_date — how does it resurface exactly (inbox or notification?)
- [ ] Google Calendar sync — approach and timing
- [ ] Notion CSV import — build after core app is working
- [ ] People/delegation — when husband is added as second user
- [ ] Blackout periods — build when lifestyle tracking feature is ready
- [ ] Work workspace — separate workspace, daily focus merges across both

---

## 7. Session Log

| Session | What was decided / built |
|---|---|
| Sessions 1-N | Designed full schema, built initial app, wiped and restarting clean |
| Current | Finalising schema decisions before writing clean SQL |

---

## 8. How to Use This Document

**At the start of each session:**
Paste this document into the Claude conversation and say:
*"Here is the Clarity spec. Today I want to [goal]."*

**At the end of each session:**
Ask Claude to update the relevant sections and download the new version.

**File lives alongside:**
- `gtd_schema.sql` — the clean Supabase schema
- `gtd-app.html` — the single-file app
- `gtd_drop_all.sql` — wipe script for starting over
