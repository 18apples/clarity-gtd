-- ============================================================
-- CLARITY GTD — CATCH-UP MIGRATION
-- Run this if you already have the v1 DB set up and need to
-- apply all changes made since the original setup.
-- Safe to run in order — uses IF NOT EXISTS / IF EXISTS guards.
-- ============================================================
-- Run each SECTION separately in Supabase SQL Editor.
-- Wait for green checkmark before running the next section.
-- ============================================================


-- ── SECTION 1: Update task_status enum ───────────────────────────
-- Add new values first (must commit before using them)

alter type task_status add value if not exists 'active';
alter type task_status add value if not exists 'parked';
alter type task_status add value if not exists 'delegated';
alter type task_status add value if not exists 'skipped';

-- ── SECTION 2: Migrate existing data ─────────────────────────────
-- Run AFTER Section 1 has committed

update tasks set status = 'active' where status = 'next';
update tasks set status = 'parked' where status = 'someday';
update tasks set status = 'inbox'  where status = 'reference';

-- Verify
select status, count(*) from tasks group by status order by count desc;


-- ── SECTION 3: Add new columns to existing tables ─────────────────

-- workspaces: last_review_date (bulk review cross-device tracking)
alter table workspaces
  add column if not exists last_review_date date;

-- tasks: new fields added throughout development
alter table tasks
  add column if not exists waiting_for    text,
  add column if not exists follow_up_date date,
  add column if not exists skipped_at     timestamptz,
  add column if not exists deadline_type  text not null default 'soft',
  add column if not exists expires_on     date;

-- subtasks: due_date (#76)
alter table subtasks
  add column if not exists due_date date;

-- recurrences: skip_blackouts (#65), expires_on (#70)
alter table recurrences
  add column if not exists skip_blackouts boolean not null default false,
  add column if not exists expires_on     date;

-- categories: paused_until, pause_reason (if missing)
alter table categories
  add column if not exists paused_until date,
  add column if not exists pause_reason text;

select 'Column additions complete ✓' as status;


-- ── SECTION 4: Add new tables if missing ─────────────────────────

-- contexts table (if not created yet)
create table if not exists contexts (
  id            uuid primary key default uuid_generate_v4(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  name          text not null,
  icon          text,
  sort_order    integer not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);
create index if not exists idx_contexts_workspace on contexts(workspace_id);
alter table contexts enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='contexts' and policyname='authenticated access') then
    create policy "authenticated access" on contexts for all to authenticated using (true);
  end if;
end $$;
grant select, insert, update, delete on public.contexts to authenticated, service_role;
grant select on public.contexts to anon;

-- blackout_periods table (if not created yet)
create table if not exists blackout_periods (
  id            uuid primary key default uuid_generate_v4(),
  workspace_id  uuid not null references workspaces(id) on delete cascade,
  label         text not null,
  start_date    date not null,
  end_date      date not null,
  created_at    timestamptz not null default now(),
  constraint valid_date_range check (end_date >= start_date)
);
create index if not exists idx_blackouts_workspace on blackout_periods(workspace_id);
create index if not exists idx_blackouts_dates     on blackout_periods(start_date, end_date);
alter table blackout_periods enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='blackout_periods' and policyname='authenticated access') then
    create policy "authenticated access" on blackout_periods for all to authenticated using (true);
  end if;
end $$;
grant select, insert, update, delete on public.blackout_periods to authenticated, service_role;
grant select on public.blackout_periods to anon;

-- subtasks table (if not created yet)
create table if not exists subtasks (
  id          uuid primary key default uuid_generate_v4(),
  task_id     uuid not null references tasks(id) on delete cascade,
  name        text not null,
  is_done     boolean not null default false,
  sort_order  integer not null default 0,
  due_date    date,
  created_at  timestamptz not null default now()
);
create index if not exists idx_subtasks_task on subtasks(task_id);
alter table subtasks enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='subtasks' and policyname='authenticated access') then
    create policy "authenticated access" on subtasks for all to authenticated using (true);
  end if;
end $$;
grant select, insert, update, delete on public.subtasks to authenticated, service_role;
grant select on public.subtasks to anon;

select 'New tables ready ✓' as status;


-- ── SECTION 5: Update pg_cron jobs ───────────────────────────────

create extension if not exists pg_cron;

-- Remove old jobs
do $$
begin
  perform cron.unschedule(jobname)
  from cron.job
  where jobname in (
    'clarity-surface-recurring',
    'clarity-surface-someday',
    'clarity-surface-parked',
    'clarity-generate-reviews'
  );
exception when others then null;
end $$;

-- Schedule updated jobs
select cron.schedule('clarity-surface-recurring', '0 6 * * *', 'select surface_recurring_tasks()');
select cron.schedule('clarity-surface-parked',    '0 6 * * *', 'select surface_parked_tasks()');
select cron.schedule('clarity-generate-reviews',  '0 7 * * *', 'select generate_review_tasks()');

-- Confirm jobs
select jobname, schedule, active from cron.job where jobname like 'clarity-%';


-- ── SECTION 6: Update surface_someday → surface_parked ───────────

create or replace function surface_parked_tasks() returns void language plpgsql as $$
begin
  update tasks set status = 'inbox'
  where status = 'parked'
    and revisit_date is not null
    and revisit_date <= current_date;
end;
$$;

select 'surface_parked_tasks function updated ✓' as status;


-- ── FINAL: Verify everything ──────────────────────────────────────

select
  (select count(*) from workspaces)      as workspaces,
  (select count(*) from domains)         as domains,
  (select count(*) from categories)      as categories,
  (select count(*) from contexts)        as contexts,
  (select count(*) from tasks)           as tasks,
  (select count(*) from subtasks)        as subtasks,
  (select count(*) from blackout_periods) as blackout_periods;

select status, count(*) from tasks group by status order by count desc;

select 'Catch-up migration complete ✓' as status;
