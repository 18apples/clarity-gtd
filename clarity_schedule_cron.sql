-- ============================================================
-- CLARITY GTD — SCHEDULE PG_CRON JOBS
-- Run in Supabase SQL Editor ONCE
-- Requires pg_cron extension to be enabled in Supabase:
--   Dashboard → Database → Extensions → search "pg_cron" → enable
-- ============================================================

-- Enable pg_cron if not already enabled
create extension if not exists pg_cron;

-- Remove any existing Clarity jobs first (safe to re-run)
do $$
begin
  perform cron.unschedule(jobname)
  from cron.job
  where jobname in (
    'clarity-surface-recurring',
    'clarity-surface-someday',
    'clarity-generate-reviews'
  );
exception when others then null;
end $$;

-- ── JOB 1: Surface recurring tasks ───────────────────────────────
-- Runs at 6:00 AM every day
-- Sets status = 'next' for recurring tasks whose next_occurrence <= today
select cron.schedule(
  'clarity-surface-recurring',
  '0 6 * * *',
  'select surface_recurring_tasks()'
);

-- ── JOB 2: Surface someday tasks ─────────────────────────────────
-- Runs at 6:00 AM every day
-- Moves tasks with revisit_date <= today back to inbox
select cron.schedule(
  'clarity-surface-someday',
  '0 6 * * *',
  'select surface_someday_tasks()'
);

-- ── JOB 3: Generate review tasks ─────────────────────────────────
-- Runs at 7:00 AM every day
-- Creates review tasks for neglected categories and projects
select cron.schedule(
  'clarity-generate-reviews',
  '0 7 * * *',
  'select generate_review_tasks()'
);

-- ── CONFIRM ──────────────────────────────────────────────────────
select
  jobname,
  schedule,
  command,
  active
from cron.job
where jobname like 'clarity-%'
order by jobname;
