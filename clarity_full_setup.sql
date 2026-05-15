-- ============================================================
-- CLARITY GTD — COMPLETE SETUP SQL
-- ============================================================
-- Run this entire file in Supabase SQL Editor.
-- It will:
--   1. Drop everything (clean slate)
--   2. Create all enums, tables, indexes, RLS, grants
--   3. Create views and functions
--   4. Seed your workspace, domains, and categories
--   5. Confirm with a summary
-- ============================================================


-- ── STEP 1: DROP EVERYTHING ──────────────────────────────

drop function if exists generate_review_tasks() cascade;
drop function if exists generate_next_recurring_instance(uuid, date, date) cascade;
drop function if exists surface_recurring_tasks() cascade;
drop function if exists surface_someday_tasks() cascade;
drop function if exists calculate_next_occurrence(recur_mode, recur_pattern, integer, integer[], date, integer, integer, integer, date) cascade;

drop view if exists neglected_entities cascade;
drop view if exists category_last_active cascade;
drop view if exists project_last_active cascade;

drop table if exists analytics_events      cascade;
drop table if exists recurrence_categories cascade;
drop table if exists task_categories       cascade;
drop table if exists project_categories    cascade;
drop table if exists tasks                 cascade;
drop table if exists recurrences           cascade;
drop table if exists projects              cascade;
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
    where jobname in ('surface-recurring','surface-someday','generate-reviews');
  end if;
end $$;


-- ── STEP 2: EXTENSIONS ───────────────────────────────────

create extension if not exists "uuid-ossp";


-- ── STEP 3: ENUMS ────────────────────────────────────────

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
  'inbox',     -- captured, not yet processed
  'next',      -- ready to act on
  'waiting',   -- blocked on someone/something external
  'someday',   -- parked, not now
  'reference', -- not actionable, kept for info
  'done',      -- completed
  'cancelled'  -- deliberately dropped, reason required
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
  'daily_reset', -- counter always starts fresh next day
  'carry_over'   -- deficit carries forward if target not hit
);

create type analytics_event_type as enum (
  'task_created',
  'task_completed',
  'task_cancelled',
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


-- ── STEP 4: TABLES ───────────────────────────────────────

-- WORKSPACES
create table workspaces (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  color       text,
  created_at  timestamptz not null default now()
);

-- DOMAINS
-- Simple labels for grouping categories.
-- Nothing links to domains except categories.
create table domains (
  id            uuid primary key default uuid_generate_v4(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  name          text not null,
  icon          text,
  color         text,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);

-- CATEGORIES
-- Belong to one domain.
-- Tasks and projects link to categories via junction tables.
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

-- PROJECTS
-- Not linked to a domain directly.
-- Linked to categories via junction table.
-- Must have at least one next action (enforced at app level).
create table projects (
  id                   uuid primary key default uuid_generate_v4(),
  workspace_id         uuid not null references workspaces(id) on delete cascade,
  name                 text not null,
  outcome              text,
  status               project_status not null default 'active',
  priority             project_priority not null default 'medium',
  deadline             date,
  review_interval_days integer not null default 30,
  on_hold_until        date,
  on_hold_reason       text,
  created_at           timestamptz not null default now(),
  completed_at         timestamptz
);

-- RECURRENCES
-- Master template for recurring tasks.
-- Task instances link back via recurrence_id.
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
  recur_anchor_day      integer,
  is_active             boolean not null default true,
  last_occurrence       date,
  next_occurrence       date,
  last_generated_at     timestamptz,
  created_at            timestamptz not null default now()
);

-- TASKS
-- Core table. Every action, idea, review, and recurring instance lives here.
create table tasks (
  id                      uuid primary key default uuid_generate_v4(),
  workspace_id            uuid not null references workspaces(id) on delete cascade,
  project_id              uuid references projects(id) on delete set null,
  recurrence_id           uuid references recurrences(id) on delete set null,
  name                    text not null,
  notes                   text,
  type                    task_type not null default 'task',
  status                  task_status not null default 'inbox',
  importance_speed        importance_speed,
  context                 text,
  due_date                date,
  revisit_date            date,
  completed_at            timestamptz,
  cancelled_at            timestamptz,
  cancellation_reason     text,
  estimated_mins          integer,
  actual_mins             integer,
  reschedule_count        integer not null default 0,
  reschedule_reasons      text[] not null default '{}',
  current_count           integer not null default 0,
  target_count            integer,
  recur_pattern           recur_pattern,
  review_for_entity_type  text,
  review_for_entity_id    uuid,
  ai_suggestions          jsonb not null default '{}',
  created_at              timestamptz not null default now()
);

-- JUNCTION TABLES
create table project_categories (
  project_id   uuid not null references projects(id) on delete cascade,
  category_id  uuid not null references categories(id) on delete cascade,
  primary key (project_id, category_id)
);

create table task_categories (
  task_id      uuid not null references tasks(id) on delete cascade,
  category_id  uuid not null references categories(id) on delete cascade,
  primary key (task_id, category_id)
);

create table recurrence_categories (
  recurrence_id  uuid not null references recurrences(id) on delete cascade,
  category_id    uuid not null references categories(id) on delete cascade,
  primary key (recurrence_id, category_id)
);

-- ANALYTICS EVENTS
-- Append-only log. Never deleted. Powers all stats.
create table analytics_events (
  id            uuid primary key default uuid_generate_v4(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  entity_type   text not null,
  entity_id     uuid not null,
  event_type    analytics_event_type not null,
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now()
);


-- ── STEP 5: INDEXES ──────────────────────────────────────

create index idx_domains_workspace           on domains(workspace_id);
create index idx_categories_workspace        on categories(workspace_id);
create index idx_categories_domain           on categories(domain_id);
create index idx_projects_workspace          on projects(workspace_id);
create index idx_projects_status             on projects(status);
create index idx_recurrences_workspace       on recurrences(workspace_id);
create index idx_recurrences_active          on recurrences(next_occurrence) where is_active = true;
create index idx_tasks_workspace             on tasks(workspace_id);
create index idx_tasks_status                on tasks(status);
create index idx_tasks_type                  on tasks(type);
create index idx_tasks_project               on tasks(project_id);
create index idx_tasks_recurrence            on tasks(recurrence_id);
create index idx_tasks_due_date              on tasks(due_date);
create index idx_tasks_revisit_date          on tasks(revisit_date) where revisit_date is not null;
create index idx_tasks_review_entity         on tasks(review_for_entity_type, review_for_entity_id);
create index idx_project_categories_project  on project_categories(project_id);
create index idx_project_categories_cat      on project_categories(category_id);
create index idx_task_categories_task        on task_categories(task_id);
create index idx_task_categories_cat         on task_categories(category_id);
create index idx_recurrence_categories_rec   on recurrence_categories(recurrence_id);
create index idx_analytics_workspace         on analytics_events(workspace_id);
create index idx_analytics_entity            on analytics_events(entity_type, entity_id);
create index idx_analytics_created           on analytics_events(created_at);


-- ── STEP 6: ROW LEVEL SECURITY ───────────────────────────

alter table workspaces            enable row level security;
alter table domains               enable row level security;
alter table categories            enable row level security;
alter table projects              enable row level security;
alter table recurrences           enable row level security;
alter table tasks                 enable row level security;
alter table project_categories    enable row level security;
alter table task_categories       enable row level security;
alter table recurrence_categories enable row level security;
alter table analytics_events      enable row level security;

create policy "authenticated access" on workspaces            for all to authenticated using (true);
create policy "authenticated access" on domains               for all to authenticated using (true);
create policy "authenticated access" on categories            for all to authenticated using (true);
create policy "authenticated access" on projects              for all to authenticated using (true);
create policy "authenticated access" on recurrences           for all to authenticated using (true);
create policy "authenticated access" on tasks                 for all to authenticated using (true);
create policy "authenticated access" on project_categories    for all to authenticated using (true);
create policy "authenticated access" on task_categories       for all to authenticated using (true);
create policy "authenticated access" on recurrence_categories for all to authenticated using (true);
create policy "authenticated access" on analytics_events      for all to authenticated using (true);


-- ── STEP 7: GRANTS ───────────────────────────────────────
-- Required by Supabase's new policy (enforced Oct 30, 2026)

grant select, insert, update, delete on public.workspaces            to authenticated;
grant select, insert, update, delete on public.domains               to authenticated;
grant select, insert, update, delete on public.categories            to authenticated;
grant select, insert, update, delete on public.projects              to authenticated;
grant select, insert, update, delete on public.recurrences           to authenticated;
grant select, insert, update, delete on public.tasks                 to authenticated;
grant select, insert, update, delete on public.project_categories    to authenticated;
grant select, insert, update, delete on public.task_categories       to authenticated;
grant select, insert, update, delete on public.recurrence_categories to authenticated;
grant select, insert, update, delete on public.analytics_events      to authenticated;

grant select on public.workspaces  to anon;
grant select on public.domains     to anon;
grant select on public.categories  to anon;

grant select, insert, update, delete on public.workspaces            to service_role;
grant select, insert, update, delete on public.domains               to service_role;
grant select, insert, update, delete on public.categories            to service_role;
grant select, insert, update, delete on public.projects              to service_role;
grant select, insert, update, delete on public.recurrences           to service_role;
grant select, insert, update, delete on public.tasks                 to service_role;
grant select, insert, update, delete on public.project_categories    to service_role;
grant select, insert, update, delete on public.task_categories       to service_role;
grant select, insert, update, delete on public.recurrence_categories to service_role;
grant select, insert, update, delete on public.analytics_events      to service_role;


-- ── STEP 8: VIEWS ────────────────────────────────────────

create or replace view category_last_active as
select
  c.id                     as category_id,
  c.workspace_id,
  c.name,
  c.is_paused,
  c.paused_until,
  c.review_interval_days,
  max(greatest(t.created_at, t.completed_at)) as last_active_at
from categories c
left join task_categories tc on tc.category_id = c.id
left join tasks t on t.id = tc.task_id
group by c.id, c.workspace_id, c.name, c.is_paused, c.paused_until, c.review_interval_days;

create or replace view project_last_active as
select
  p.id                     as project_id,
  p.workspace_id,
  p.name,
  p.status,
  p.on_hold_until,
  p.review_interval_days,
  max(greatest(t.created_at, t.completed_at)) as last_active_at
from projects p
left join tasks t on t.project_id = p.id
group by p.id, p.workspace_id, p.name, p.status, p.on_hold_until, p.review_interval_days;

create or replace view neglected_entities as

select
  'category'               as entity_type,
  category_id              as entity_id,
  workspace_id,
  name,
  last_active_at,
  review_interval_days,
  (now() - last_active_at) as time_since_active
from category_last_active
where not is_paused
  and last_active_at is not null
  and (now() - last_active_at) > (review_interval_days || ' days')::interval
  and not exists (
    select 1 from tasks rt
    where rt.review_for_entity_type = 'category'
      and rt.review_for_entity_id   = category_id
      and rt.status not in ('done', 'cancelled')
  )

union all

select
  'project'                as entity_type,
  project_id               as entity_id,
  workspace_id,
  name,
  last_active_at,
  review_interval_days,
  (now() - last_active_at) as time_since_active
from project_last_active
where status = 'active'
  and last_active_at is not null
  and (now() - last_active_at) > (review_interval_days || ' days')::interval
  and not exists (
    select 1 from tasks rt
    where rt.review_for_entity_type = 'project'
      and rt.review_for_entity_id   = project_id
      and rt.status not in ('done', 'cancelled')
  );


-- ── STEP 9: FUNCTIONS ────────────────────────────────────

create or replace function calculate_next_occurrence(
  p_mode                recur_mode,
  p_pattern             recur_pattern,
  p_interval_value      integer,
  p_days_of_week        integer[],
  p_anchor_date         date,
  p_anchor_day          integer,
  p_random_min_days     integer,
  p_random_max_days     integer,
  p_completed_date      date
)
returns date language plpgsql as $$
declare
  v_next         date;
  v_today        date := coalesce(p_completed_date, current_date);
  v_random_range integer;
begin
  case p_pattern
    when 'x_per_day', 'daily' then
      v_next := v_today + interval '1 day';
    when 'x_per_week' then
      v_next := v_today + interval '1 day';
      while not (extract(dow from v_next)::integer = any(p_days_of_week)) loop
        v_next := v_next + interval '1 day';
      end loop;
    when 'weekly' then
      if p_mode = 'fixed' and p_anchor_day is not null then
        v_next := v_today + interval '1 day';
        while extract(dow from v_next)::integer != p_anchor_day loop
          v_next := v_next + interval '1 day';
        end loop;
      else
        v_next := v_today + interval '7 days';
      end if;
    when 'fortnightly' then
      v_next := v_today + interval '14 days';
    when 'every_x_weeks' then
      v_next := v_today + (coalesce(p_interval_value, 2) * interval '7 days');
    when 'monthly' then
      if p_mode = 'fixed' and p_anchor_date is not null then
        v_next := date_trunc('month', v_today + interval '1 month')
                  + (extract(day from p_anchor_date) - 1) * interval '1 day';
      else
        v_next := v_today + interval '1 month';
      end if;
    when 'every_x_months' then
      v_next := v_today + (coalesce(p_interval_value, 2) * interval '1 month');
    when 'quarterly' then
      v_next := v_today + interval '3 months';
    when 'every_6_months' then
      v_next := v_today + interval '6 months';
    when 'yearly' then
      if p_mode = 'fixed' and p_anchor_date is not null then
        v_next := make_date(
          extract(year from v_today + interval '1 year')::integer,
          extract(month from p_anchor_date)::integer,
          extract(day from p_anchor_date)::integer
        );
      else
        v_next := v_today + interval '1 year';
      end if;
    when 'random' then
      v_random_range := coalesce(p_random_max_days, 30) - coalesce(p_random_min_days, 7);
      v_next := v_today + coalesce(p_random_min_days, 7)
                + (floor(random() * greatest(v_random_range, 1)))::integer;
    when 'adhoc' then
      return null;
    else
      v_next := v_today + interval '7 days';
  end case;
  return v_next;
end;
$$;


create or replace function generate_next_recurring_instance(
  p_recurrence_id  uuid,
  p_completed_date date default current_date,
  p_adhoc_date     date default null
)
returns uuid language plpgsql as $$
declare
  v_rec       recurrences%rowtype;
  v_next_date date;
  v_new_id    uuid;
begin
  select * into v_rec from recurrences where id = p_recurrence_id;
  if not found then raise exception 'Recurrence not found: %', p_recurrence_id; end if;

  if v_rec.recur_pattern = 'adhoc' then
    v_next_date := p_adhoc_date;
    if v_next_date is null then raise exception 'adhoc requires p_adhoc_date'; end if;
  else
    v_next_date := calculate_next_occurrence(
      v_rec.recur_mode, v_rec.recur_pattern, v_rec.recur_interval_value,
      v_rec.recur_days_of_week, v_rec.recur_anchor_date, v_rec.recur_anchor_day,
      v_rec.recur_random_min_days, v_rec.recur_random_max_days, p_completed_date
    );
  end if;

  insert into tasks (
    workspace_id, project_id, recurrence_id,
    name, notes, type, status,
    importance_speed, context, estimated_mins,
    due_date, current_count, target_count, recur_pattern,
    reschedule_count, reschedule_reasons, ai_suggestions
  ) values (
    v_rec.workspace_id, v_rec.project_id, p_recurrence_id,
    v_rec.name, v_rec.notes, 'recurring', 'next',
    v_rec.importance_speed, v_rec.context, v_rec.estimated_mins,
    v_next_date, 0, v_rec.recur_times_per_day, v_rec.recur_pattern,
    0, '{}', '{}'
  ) returning id into v_new_id;

  insert into task_categories (task_id, category_id)
  select v_new_id, category_id from recurrence_categories
  where recurrence_id = p_recurrence_id;

  update recurrences
  set last_occurrence = p_completed_date, next_occurrence = v_next_date, last_generated_at = now()
  where id = p_recurrence_id;

  insert into analytics_events (workspace_id, entity_type, entity_id, event_type, metadata)
  values (v_rec.workspace_id, 'recurrence', p_recurrence_id, 'recurring_generated',
    jsonb_build_object('new_task_id', v_new_id, 'next_due', v_next_date, 'pattern', v_rec.recur_pattern));

  return v_new_id;
end;
$$;


create or replace function generate_review_tasks()
returns void language plpgsql as $$
declare entity record; v_cat_id uuid;
begin
  for entity in select * from neglected_entities loop
    if entity.entity_type = 'category' then v_cat_id := entity.entity_id;
    else select id into v_cat_id from categories where workspace_id = entity.workspace_id limit 1;
    end if;
    insert into tasks (workspace_id, type, status, name, notes, importance_speed,
      review_for_entity_type, review_for_entity_id, reschedule_count, reschedule_reasons, ai_suggestions)
    values (entity.workspace_id, 'review', 'next', 'Review: ' || entity.name,
      'Auto-generated: not active in ' || extract(day from entity.time_since_active)::int || ' days.',
      'important_not_urgent', entity.entity_type, entity.entity_id, 0, '{}', '{}');
    insert into analytics_events (workspace_id, entity_type, entity_id, event_type, metadata)
    values (entity.workspace_id, entity.entity_type, entity.entity_id, 'review_generated',
      jsonb_build_object('days_since_active', extract(day from entity.time_since_active)::int,
                         'review_interval_days', entity.review_interval_days));
  end loop;
end;
$$;


create or replace function surface_recurring_tasks()
returns void language plpgsql as $$
begin
  update tasks set status = 'next'
  where type = 'recurring' and status not in ('done','cancelled','next') and due_date <= current_date;
end;
$$;


create or replace function surface_someday_tasks()
returns void language plpgsql as $$
begin
  update tasks set status = 'inbox', revisit_date = null
  where status = 'someday' and revisit_date is not null and revisit_date <= current_date;
end;
$$;


-- ── STEP 10: SEED DATA ────────────────────────────────────

do $$
declare
  v_ws   uuid;
  d_career    uuid; d_family  uuid; d_health  uuid;
  d_home      uuid; d_edu     uuid; d_proj    uuid;
  d_travel    uuid; d_social  uuid; d_admin   uuid;
  d_someday   uuid; d_uncat   uuid;
begin

  -- Workspace
  insert into workspaces (name, color)
  values ('Personal', '#6366f1')
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
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Someday',                '💭', 10) returning id into d_someday;
  insert into domains (workspace_id, name, icon, sort_order) values (v_ws, 'Uncategorized',          '📌', 99) returning id into d_uncat;

  -- Categories
  -- Career
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_career, 'Job Hunting',         1),
    (v_ws, d_career, 'Professional Growth', 2);

  -- Family & Relationships
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_family, 'For S',      1),
    (v_ws, d_family, 'For V',          2),
    (v_ws, d_family, 'Gifts & Other Items', 3);

  -- Health & Fitness
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_health, 'Health & Fitness', 1);

  -- Home
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_home, 'Home Decor & Improvements', 1),
    (v_ws, d_home, 'Cleaning & Organizing',      2),
    (v_ws, d_home, 'Car',                        3);

  -- Education
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_edu, 'Education', 1);

  -- Personal Projects
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_proj, 'Personal Projects', 1),
    (v_ws, d_proj, 'Food & Cooking',    2);

  -- Travel
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_travel, 'Travel Planning', 1);

  -- Social
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_social, 'Entertainment', 1),
    (v_ws, d_social, 'Social Events',  2);

  -- Official & Admin
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_admin, 'Finances',    1),
    (v_ws, d_admin, 'Government',  2),
    (v_ws, d_admin, 'Immigration', 3);

  -- Someday
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_someday, 'Digital KonMari', 1),
    (v_ws, d_someday, 'Someday Ideas',   2);

  -- Uncategorized (catch-all)
  insert into categories (workspace_id, domain_id, name, sort_order) values
    (v_ws, d_uncat, 'General', 1);

  raise notice 'Seed data inserted successfully.';
end $$;


-- ── STEP 11: PG_CRON (uncomment after enabling extension) ─
-- select cron.schedule('surface-recurring', '0 6 * * *', 'select surface_recurring_tasks()');
-- select cron.schedule('surface-someday',   '0 6 * * *', 'select surface_someday_tasks()');
-- select cron.schedule('generate-reviews',  '0 7 * * *', 'select generate_review_tasks()');


-- ── STEP 12: CONFIRM ─────────────────────────────────────
select
  (select count(*) from workspaces)    as workspaces,
  (select count(*) from domains)       as domains,
  (select count(*) from categories)    as categories,
  (select count(*) from tasks)         as tasks,
  (select count(*) from projects)      as projects,
  (select count(*) from recurrences)   as recurrences,
  (select count(*) from analytics_events) as analytics_events,
  'Setup complete ✓' as status;
