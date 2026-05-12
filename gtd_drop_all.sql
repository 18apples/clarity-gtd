-- ============================================================
-- GTD CLARITY — DROP ALL
-- Run this FIRST to wipe the slate clean.
-- Order matters — dependent objects dropped before parents.
-- ============================================================

-- Drop functions first
drop function if exists generate_review_tasks() cascade;
drop function if exists generate_next_recurring_instance(uuid, date, date) cascade;
drop function if exists update_recurrence_and_future(uuid, jsonb) cascade;
drop function if exists surface_recurring_tasks() cascade;
drop function if exists calculate_next_occurrence(recur_mode, recur_pattern, integer, integer[], date, integer, integer, integer, date, uuid) cascade;
drop function if exists roll_past_blackouts(date, uuid) cascade;
drop function if exists get_task_category_ids(uuid) cascade;
drop function if exists get_project_category_ids(uuid) cascade;

-- Drop views
drop view if exists neglected_entities cascade;
drop view if exists domain_last_active cascade;
drop view if exists category_last_active cascade;
drop view if exists project_last_active cascade;

-- Drop junction tables
drop table if exists task_categories cascade;
drop table if exists project_categories cascade;
drop table if exists recurrence_categories cascade;

-- Drop main tables
drop table if exists analytics_events cascade;
drop table if exists blackout_periods cascade;
drop table if exists recurrences cascade;
drop table if exists tasks cascade;
drop table if exists projects cascade;
drop table if exists categories cascade;
drop table if exists domains cascade;
drop table if exists workspaces cascade;

-- Drop custom enum types
drop type if exists analytics_event_type cascade;
drop type if exists blackout_reason cascade;
drop type if exists entity_type cascade;
drop type if exists importance_speed cascade;
drop type if exists task_status cascade;
drop type if exists task_type cascade;
drop type if exists project_priority cascade;
drop type if exists project_status cascade;
drop type if exists recur_frequency cascade;
drop type if exists recur_mode cascade;
drop type if exists recur_pattern cascade;
drop type if exists relationship_type cascade;

-- Drop pg_cron jobs if they exist
select cron.unschedule('generate-review-tasks') where exists (select 1 from cron.job where jobname = 'generate-review-tasks');
select cron.unschedule('surface-recurring-tasks') where exists (select 1 from cron.job where jobname = 'surface-recurring-tasks');
select cron.unschedule('surface-recurring') where exists (select 1 from cron.job where jobname = 'surface-recurring');

-- Confirm
select 'Slate wiped clean. Ready to rebuild.' as status;
