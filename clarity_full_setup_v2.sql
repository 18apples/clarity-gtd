-- ============================================================
-- CLARITY GTD — COMPLETE SETUP SQL v2
-- Updated: July 2026
-- ============================================================
-- Run this ENTIRE file in Supabase SQL Editor for a clean setup.
-- It will:
--   1. Drop everything (clean slate)
--   2. Create all enums, tables, indexes, RLS, grants
--   3. Create views and functions
--   4. Seed workspace, domains, categories, contexts
--   5. Schedule pg_cron jobs
--   6. Confirm with a summary
--
-- CHANGES FROM v1:
--   - task_status enum updated: next→active, someday→parked,
--     added delegated, skipped; removed reference
--   - tasks table: added waiting_for, follow_up_date, skipped_at,
--     deadline_type, expires_on
--   - subtasks table: added due_date
--   - workspaces table: added last_review_date
--   - recurrences table: added skip_blackouts, expires_on
--   - new tables: subtasks, contexts, blackout_periods
-- ============================================================


-- ── STEP 1: DROP EVERYTHING ──────────────────────────────────────

drop function if exists generate_review_tasks()                                                         cascade;
drop function if exists generate_next_recurring_instance(uuid, date, date)                              cascade;
drop function if exists surface_recurring_tasks()                                                       cascade;
drop function if exists surface_someday_tasks()                                                         cascade;
drop function if exists surface_parked_tasks()                                                          cascade;
drop function if exists calculate_next_occurrence(recur_mode, recur_pattern, integer, integer[], date, integer, integer, integer, date) cascade;

drop view if exists neglected_entities    cascade;
drop view if exists category_last_active  cascade;
drop view if exists project_last_active   cascade;

drop table if exists analytics_events      cascade;
drop table if exists recurrence_categories cascade;
drop table if exists task_categories       cascade;
drop table if exists project_categories    cascade;
drop table if exists subtasks              cascade;
drop table if exists tasks                 cascade;
drop table if exists recurrences           cascade;
drop table if exists projects              cascade;
drop table if exists blackout_periods      cascade;
drop table if exists contexts              cascade;
drop table if exists categories            cascade;
drop table if exists domains               cascade;
drop table if exists workspaces            cascade;

drop type if exists analytics_event_type cascade;
drop type if exists counter_reset_mode   cascade;
drop type if exists recur_pattern        cascade;
drop type if exists recur_mode           cascade;
drop type if exists importance_speed     cascade;
drop type if exists task_status          cascade;
drop type if exists task_type            cascade;
drop type if exists project_priority     cascade;
drop type if exists project_status       cascade;

-- Remove pg_cron jobs if they exist
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobname) from cron.job
    where jobname like 'clarity-%';
  end if;
end $$;


-- ── STEP 2: EXTENSIONS ───────────────────────────────────────────

create extension if not exists "uuid-ossp";
create extension if not exists pg_cron;


-- ── STEP 3: ENUMS ────────────────────────────────────────────────

create type project_status as enum (
  'active', 'on_hold', 'complete', 'cancelled'
);

create type project_priority as enum (
  'high', 'medium', 'low'
);

create type task_type as enum (
  'task',      -- regular one-off action
  'recurring', -- instance generated from a recurrence template
  'review',    -- auto-generated when category/project is neglected
  'idea'       -- a thought, no action required, no verb enforced
);

create type task_status as enum (
  'inbox',      -- captured, needs review (bulk imports only in normal flow)
  'active',     -- ready to act on (replaces 'next')
  'waiting',    -- blocked on someone/something external
  'parked',     -- not now, intentionally deferred (replaces 'someday')
  'delegated',  -- handed off to someone else
  'skipped',    -- recurring occurrence skipped, next generated
  'done',       -- completed
  'cancelled'   -- deliberately dropped, reason required
);

create type importance_speed as enum (
  'important_urgent',
  'important_not_urgent',
  'not_important_urgent',
  'not_important_not_urgent'
);

create type recur_mode as enum (
  'fixed',   -- calendar-anchored, never drifts
  'relative' -- completion-anchored, calculated from done date
);

create type recur_pattern as enum (
  'x_per_day',
  'daily',
  'x_per_week',
  'weekly',
  'fortnightly',
  'every_x_weeks',
  'monthly',
  'every_x_months',
  'quarterly',
  'every_6_months',
  'yearly',
  'random',
  'adhoc'
);

create type counter_reset_mode as enum (
  'daily_reset',  -- counter resets each day regardless of completion
  'carry_over'    -- missed counts carry forward to next day
);

create type analytics_event_type as enum (
  'task_created',
  'task_completed',
  'task_cancelled',
  'task_skipped',
  'task_rescheduled',
  'task_status_changed',
  'project_created',
  'project_completed',
  'project_cancelled',
  'review_generated',
  'review_completed',
  'idea_promoted',
  'recurring_generated'
);


-- ── STEP 4: TABLES ───────────────────────────────────────────────

-- WORKSPACES
create table workspaces (
  id                uuid primary key default uuid_generate_v4(),
  name              text not null,
  color             text,
  last_review_date  date,       -- cross-device bulk review tracking
  created_at        timestamptz not null default now()
);

-- DOMAINS (Life Areas)
create table domains (
  id            uuid primary key default uuid_generate_v4(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  name          text not null,
  icon          text,
  color         text,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);
create index idx_domains_workspace on domains(workspace_id);

-- CATEGORIES (grouped under domains)
create table categories (
  id                   uuid primary key default uuid_generate_v4(),
  workspace_id         uuid not null references workspaces(id) on delete cascade,
  domain_id            uuid not null references domains(id) on delete restrict,
  name                 text not null,
  description          text,
  review_interval_days integer not null default 30,
  is_paused            boolean not null default false,
  paused_until         date,
  pause_reason         text,
  sort_order           integer not null default 0,
  created_at           timestamptz not null default now()
);
create index idx_categories_workspace on categories(workspace_id);
create index idx_categories_domain    on categories(domain_id);

-- CONTEXTS (@context values)
create table contexts (
  id            uuid primary key default uuid_generate_v4(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  name          text not null,
  icon          text,
  sort_order    integer not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);
create index idx_contexts_workspace on contexts(workspace_id);

-- BLACKOUT PERIODS (unavailable dates)
create table blackout_periods (
  id            uuid primary key default uuid_generate_v4(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  label         text not null,
  start_date    date not null,
  end_date      date not null,
  created_at    timestamptz not null default now(),
  constraint valid_date_range check (end_date >= start_date)
);
create index idx_blackouts_workspace on blackout_periods(workspace_id);
create index idx_blackouts_dates     on blackout_periods(start_date, end_date);

-- PROJECTS
create table projects (
  id                   uuid primary key default uuid_generate_v4(),
  workspace_id         uuid not null references workspaces(id) on delete cascade,
  name                 text not null,
  outcome              text,
  status               project_status not null default 'active',
  priority             project_priority not null default 'medium',
  deadline             date,
  on_hold_reason       text,
  on_hold_until        date,
  completed_at         timestamptz,
  cancelled_at         timestamptz,
  cancellation_reason  text,
  created_at           timestamptz not null default now()
);
create index idx_projects_workspace on projects(workspace_id);
create index idx_projects_status    on projects(status);

-- RECURRENCES (master templates)
create table recurrences (
  id                    uuid primary key default uuid_generate_v4(),
  workspace_id          uuid not null references workspaces(id) on delete cascade,
  project_id            uuid references projects(id) on delete set null,
  name                  text not null,
  notes                 text,
  importance_speed      importance_speed,
  context               text,
  estimated_mins        integer,
  recur_mode            recur_mode not null default 'fixed',
  recur_pattern         recur_pattern not null,
  recur_interval_value  integer,
  recur_days_of_week    integer[],
  recur_times_per_day   integer,
  counter_reset_mode    counter_reset_mode,
  recur_random_min_days integer,
  recur_random_max_days integer,
  recur_anchor_date     date,
  next_occurrence       date,
  last_occurrence       date,
  last_generated_at     timestamptz,
  skip_blackouts        boolean not null default false,
  expires_on            date,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now()
);
create index idx_recurrences_workspace   on recurrences(workspace_id);
create index idx_recurrences_active      on recurrences(is_active);
create index idx_recurrences_next_occur  on recurrences(next_occurrence);

-- TASKS (all tasks, ideas, recurring instances, reviews)
create table tasks (
  id                   uuid primary key default uuid_generate_v4(),
  workspace_id         uuid not null references workspaces(id) on delete cascade,
  project_id           uuid references projects(id) on delete set null,
  recurrence_id        uuid references recurrences(id) on delete set null,
  name                 text not null,
  notes                text,
  type                 task_type not null default 'task',
  status               task_status not null default 'active',
  importance_speed     importance_speed,
  context              text,
  due_date             date,
  revisit_date         date,
  deadline_type        text not null default 'soft',   -- 'hard' | 'soft'
  expires_on           date,                           -- hard deadline cutoff
  recur_pattern        recur_pattern,
  current_count        integer not null default 0,
  target_count         integer,
  estimated_mins       integer,
  actual_mins          integer,
  reschedule_count     integer not null default 0,
  reschedule_reasons   text[] not null default '{}',
  waiting_for          text,                           -- who/what blocking
  follow_up_date       date,                           -- when to follow up
  completed_at         timestamptz,
  cancelled_at         timestamptz,
  cancellation_reason  text,
  skipped_at           timestamptz,                    -- for recurring skips
  ai_suggestions       jsonb not null default '{}',
  created_at           timestamptz not null default now()
);
create index idx_tasks_workspace      on tasks(workspace_id);
create index idx_tasks_status         on tasks(status);
create index idx_tasks_due_date       on tasks(due_date);
create index idx_tasks_project        on tasks(project_id);
create index idx_tasks_recurrence     on tasks(recurrence_id);
create index idx_tasks_type           on tasks(type);
create index idx_tasks_created        on tasks(created_at desc);

-- SUBTASKS (checklist items inside tasks)
create table subtasks (
  id          uuid primary key default uuid_generate_v4(),
  task_id     uuid not null references tasks(id) on delete cascade,
  name        text not null,
  is_done     boolean not null default false,
  sort_order  integer not null default 0,
  due_date    date,                    -- individual subtask due date (#76)
  created_at  timestamptz not null default now()
);
create index idx_subtasks_task on subtasks(task_id);

-- JUNCTION TABLES
create table project_categories (
  project_id   uuid not null references projects(id)   on delete cascade,
  category_id  uuid not null references categories(id) on delete cascade,
  primary key (project_id, category_id)
);

create table task_categories (
  task_id     uuid not null references tasks(id)      on delete cascade,
  category_id uuid not null references categories(id) on delete cascade,
  primary key (task_id, category_id)
);

create table recurrence_categories (
  recurrence_id uuid not null references recurrences(id) on delete cascade,
  category_id   uuid not null references categories(id)  on delete cascade,
  primary key (recurrence_id, category_id)
);

-- ANALYTICS EVENTS (append-only log)
create table analytics_events (
  id            uuid primary key default uuid_generate_v4(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  entity_type   text not null,
  entity_id     uuid,
  event_type    analytics_event_type not null,
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now()
);
create index idx_analytics_workspace on analytics_events(workspace_id);
create index idx_analytics_created   on analytics_events(created_at desc);
create index idx_analytics_entity    on analytics_events(entity_id);


-- ── STEP 5: RLS + GRANTS ─────────────────────────────────────────

do $$ declare
  tbl text;
begin
  foreach tbl in array array[
    'workspaces','domains','categories','contexts','blackout_periods',
    'projects','recurrences','tasks','subtasks',
    'project_categories','task_categories','recurrence_categories',
    'analytics_events'
  ] loop
    execute format('alter table public.%I enable row level security', tbl);
    execute format('
      create policy "authenticated access" on public.%I
      for all to authenticated using (true)', tbl);
    execute format('
      grant select, insert, update, delete on public.%I
      to authenticated, service_role', tbl);
    execute format('grant select on public.%I to anon', tbl);
  end loop;
end $$;


-- ── STEP 6: VIEWS ────────────────────────────────────────────────

create or replace view category_last_active as
select
  tc.category_id,
  max(t.created_at) filter (where t.status not in ('done','cancelled')) as last_active_at
from task_categories tc
join tasks t on t.id = tc.task_id
group by tc.category_id;

create or replace view project_last_active as
select
  p.id as project_id,
  max(t.created_at) filter (where t.status not in ('done','cancelled')) as last_active_at
from projects p
left join tasks t on t.project_id = p.id
group by p.id;

create or replace view neglected_entities as
-- Neglected categories
select
  'category'   as entity_type,
  c.id         as entity_id,
  c.workspace_id,
  c.name,
  c.review_interval_days,
  coalesce(cla.last_active_at, c.created_at) as last_active_at,
  now() - coalesce(cla.last_active_at, c.created_at) as idle_duration
from categories c
left join category_last_active cla on cla.category_id = c.id
where c.is_paused = false
  and now() - coalesce(cla.last_active_at, c.created_at) > (c.review_interval_days || ' days')::interval
  and not exists (
    select 1 from tasks t
    join task_categories tc on tc.task_id = t.id
    where tc.category_id = c.id
      and t.type = 'review'
      and t.status not in ('done','cancelled')
  )

union all

-- Neglected projects
select
  'project'    as entity_type,
  p.id         as entity_id,
  p.workspace_id,
  p.name,
  30           as review_interval_days,
  coalesce(pla.last_active_at, p.created_at) as last_active_at,
  now() - coalesce(pla.last_active_at, p.created_at) as idle_duration
from projects p
left join project_last_active pla on pla.project_id = p.id
where p.status = 'active'
  and now() - coalesce(pla.last_active_at, p.created_at) > interval '30 days'
  and not exists (
    select 1 from tasks t
    where t.project_id = p.id
      and t.type = 'review'
      and t.status not in ('done','cancelled')
  );


-- ── STEP 7: FUNCTIONS ────────────────────────────────────────────

-- Calculate next occurrence date
create or replace function calculate_next_occurrence(
  p_recur_mode           recur_mode,
  p_recur_pattern        recur_pattern,
  p_interval_value       integer,
  p_days_of_week         integer[],
  p_anchor_date          date,
  p_random_min_days      integer,
  p_random_max_days      integer,
  p_times_per_day        integer,
  p_last_occurrence      date
) returns date language plpgsql as $$
declare
  v_next date := p_last_occurrence + 1;
  v_dow  integer;
  v_found boolean := false;
begin
  case p_recur_pattern
    when 'daily' then
      return p_last_occurrence + 1;
    when 'weekly' then
      if p_recur_mode = 'fixed' and p_anchor_date is not null then
        v_next := p_anchor_date;
        while v_next <= p_last_occurrence loop v_next := v_next + 7; end loop;
        return v_next;
      else return p_last_occurrence + 7;
      end if;
    when 'fortnightly' then return p_last_occurrence + 14;
    when 'every_x_weeks' then
      return p_last_occurrence + (p_interval_value * 7);
    when 'monthly' then
      if p_recur_mode = 'fixed' and p_anchor_date is not null then
        v_next := (date_trunc('month', p_last_occurrence) + interval '1 month')::date
                  + (extract(day from p_anchor_date)::integer - 1);
        return v_next;
      else return (p_last_occurrence + interval '1 month')::date;
      end if;
    when 'every_x_months' then
      return (p_last_occurrence + (p_interval_value || ' months')::interval)::date;
    when 'quarterly' then
      return (p_last_occurrence + interval '3 months')::date;
    when 'every_6_months' then
      return (p_last_occurrence + interval '6 months')::date;
    when 'yearly' then
      if p_recur_mode = 'fixed' and p_anchor_date is not null then
        v_next := make_date(
          extract(year from p_last_occurrence)::integer + 1,
          extract(month from p_anchor_date)::integer,
          extract(day from p_anchor_date)::integer
        );
        return v_next;
      else return (p_last_occurrence + interval '1 year')::date;
      end if;
    when 'x_per_week' then
      if p_days_of_week is null or array_length(p_days_of_week, 1) = 0 then
        return p_last_occurrence + 1;
      end if;
      while not v_found loop
        v_dow := extract(dow from v_next)::integer;
        if v_dow = any(p_days_of_week) then v_found := true;
        else v_next := v_next + 1;
        end if;
      end loop;
      return v_next;
    when 'x_per_day' then
      return p_last_occurrence + 1;
    when 'random' then
      return p_last_occurrence + floor(random() * (p_random_max_days - p_random_min_days + 1) + p_random_min_days)::integer;
    when 'adhoc' then return null;
    else return p_last_occurrence + 1;
  end case;
end;
$$;

-- Generate next recurring task instance on completion
create or replace function generate_next_recurring_instance(
  p_task_id       uuid,
  p_completed_at  date,
  p_anchor_date   date default null
) returns uuid language plpgsql as $$
declare
  v_task    tasks%rowtype;
  v_tmpl    recurrences%rowtype;
  v_next    date;
  v_new_id  uuid;
  v_cat_ids uuid[];
begin
  select * into v_task from tasks where id = p_task_id;
  if not found or v_task.recurrence_id is null then return null; end if;
  select * into v_tmpl from recurrences where id = v_task.recurrence_id;
  if not found or not v_tmpl.is_active then return null; end if;

  -- Check if recurrence has expired
  if v_tmpl.expires_on is not null and p_completed_at >= v_tmpl.expires_on then
    update recurrences set is_active = false where id = v_tmpl.id;
    return null;
  end if;

  v_next := calculate_next_occurrence(
    v_tmpl.recur_mode, v_tmpl.recur_pattern,
    v_tmpl.recur_interval_value, v_tmpl.recur_days_of_week,
    coalesce(p_anchor_date, v_tmpl.recur_anchor_date),
    v_tmpl.recur_random_min_days, v_tmpl.recur_random_max_days,
    v_tmpl.recur_times_per_day,
    coalesce(p_completed_at, current_date)
  );

  insert into tasks (
    workspace_id, project_id, recurrence_id, name, notes, type, status,
    importance_speed, context, estimated_mins, recur_pattern,
    due_date, current_count, target_count
  ) values (
    v_task.workspace_id, v_task.project_id, v_task.recurrence_id,
    v_tmpl.name, v_tmpl.notes, 'recurring', 'active',
    v_tmpl.importance_speed, v_tmpl.context, v_tmpl.estimated_mins,
    v_tmpl.recur_pattern, v_next, 0, v_tmpl.recur_times_per_day
  ) returning id into v_new_id;

  -- Copy categories
  insert into task_categories (task_id, category_id)
  select v_new_id, rc.category_id
  from recurrence_categories rc
  where rc.recurrence_id = v_tmpl.id;

  update recurrences set
    last_occurrence   = p_completed_at,
    next_occurrence   = v_next,
    last_generated_at = now()
  where id = v_tmpl.id;

  return v_new_id;
end;
$$;

-- Surface recurring tasks due today or overdue
create or replace function surface_recurring_tasks() returns void language plpgsql as $$
begin
  update tasks set status = 'active'
  where type = 'recurring'
    and status = 'inbox'
    and due_date <= current_date;
end;
$$;

-- Surface parked tasks whose revisit date has arrived
create or replace function surface_parked_tasks() returns void language plpgsql as $$
begin
  update tasks set status = 'inbox'
  where status = 'parked'
    and revisit_date is not null
    and revisit_date <= current_date;
end;
$$;

-- Generate review tasks for neglected categories/projects
create or replace function generate_review_tasks() returns integer language plpgsql as $$
declare
  v_entity  record;
  v_count   integer := 0;
begin
  for v_entity in select * from neglected_entities loop
    insert into tasks (
      workspace_id, type, status, name,
      importance_speed, due_date
    ) values (
      v_entity.workspace_id, 'review', 'active',
      'Review: ' || v_entity.name,
      'important_not_urgent', current_date
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;


-- ── STEP 8: SEED DATA ─────────────────────────────────────────────

do $$ declare
  v_ws       uuid;
  d_career   uuid; d_family  uuid; d_health uuid; d_home    uuid;
  d_edu      uuid; d_proj    uuid; d_travel uuid; d_social  uuid;
  d_admin    uuid; d_parked  uuid; d_uncat  uuid;
begin
  -- Workspace
  insert into workspaces (name, color)
  values ('Personal', '#b8f060')
  returning id into v_ws;

  -- Domains
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Career',                 '💼', 1)  returning id into d_career;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Family & Relationships', '🧡', 2)  returning id into d_family;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Health & Fitness',       '❤️', 3)  returning id into d_health;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Home',                   '🏠', 4)  returning id into d_home;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Education',              '📚', 5)  returning id into d_edu;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Personal Projects',      '🌱', 6)  returning id into d_proj;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Travel',                 '✈️', 7)  returning id into d_travel;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Social',                 '🎉', 8)  returning id into d_social;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Official & Admin',       '🏛', 9)  returning id into d_admin;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Parked Ideas',           '💭', 10) returning id into d_parked;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Uncategorized',          '📌', 99) returning id into d_uncat;

  -- Categories
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_career, 'Job Hunting', 1),
    (v_ws, d_career, 'Professional Growth', 2);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_family, 'For Siddharth', 1),
    (v_ws, d_family, 'For Vikram', 2),
    (v_ws, d_family, 'Gifts & Other Items', 3);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_health, 'Health & Fitness', 1);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_home, 'Home Decor & Improvements', 1),
    (v_ws, d_home, 'Cleaning & Organizing', 2),
    (v_ws, d_home, 'Car', 3);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_edu, 'Education', 1);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_proj, 'Personal Projects', 1),
    (v_ws, d_proj, 'Food & Cooking', 2);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_travel, 'Travel Planning', 1);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_social, 'Entertainment', 1),
    (v_ws, d_social, 'Social Events', 2);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_admin, 'Finances', 1),
    (v_ws, d_admin, 'Government', 2),
    (v_ws, d_admin, 'Immigration', 3);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_parked, 'Digital KonMari', 1),
    (v_ws, d_parked, 'Parked Ideas', 2);

  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_uncat, 'General', 1);

  -- Seed contexts
  insert into contexts (workspace_id, name, icon, sort_order) values
    (v_ws, '@home',           '🏠', 1),
    (v_ws, '@out-and-about',  '🚗', 2),
    (v_ws, '@MuraliMama&Co',  '👨‍👩‍👧', 3),
    (v_ws, '@laptop',         '💻', 4);

end $$;


-- ── STEP 9: TASK DEPENDENCY TABLE (Phase 2 — #74) ────────────────
-- Uncomment when ready to build task sequencing feature

-- create table task_dependencies (
--   id                  uuid primary key default uuid_generate_v4(),
--   predecessor_task_id uuid not null references tasks(id) on delete cascade,
--   dependent_task_id   uuid not null references tasks(id) on delete cascade,
--   created_at          timestamptz not null default now(),
--   unique(predecessor_task_id, dependent_task_id)
-- );
-- grant select, insert, update, delete on public.task_dependencies to authenticated, service_role;
-- alter table public.task_dependencies enable row level security;
-- create policy "authenticated access" on public.task_dependencies for all to authenticated using (true);


-- ── STEP 10: SCHEDULE PG_CRON JOBS ───────────────────────────────

select cron.schedule('clarity-surface-recurring', '0 6 * * *', 'select surface_recurring_tasks()');
select cron.schedule('clarity-surface-parked',    '0 6 * * *', 'select surface_parked_tasks()');
select cron.schedule('clarity-generate-reviews',  '0 7 * * *', 'select generate_review_tasks()');


-- ── STEP 11: CONFIRM ─────────────────────────────────────────────

select 'Setup complete ✓' as status;

select table_name, 
  (select count(*) from information_schema.columns c 
   where c.table_name = t.table_name 
   and c.table_schema = 'public') as column_count
from information_schema.tables t
where table_schema = 'public' 
  and table_type = 'BASE TABLE'
order by table_name;

select 'task_status values:' as info, array_agg(enumlabel order by enumsortorder) as values
from pg_enum e join pg_type t on t.oid = e.enumtypid
where t.typname = 'task_status'
group by t.typname;
