-- Task schedule generation sync state on cultivation_plans (multi-instance safe).
ALTER TABLE cultivation_plans ADD COLUMN task_schedule_sync_state varchar NOT NULL DEFAULT 'never';
ALTER TABLE cultivation_plans ADD COLUMN task_schedule_sync_error text;
