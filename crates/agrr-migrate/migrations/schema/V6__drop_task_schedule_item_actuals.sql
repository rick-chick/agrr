-- P6: legacy actuals on task_schedule_items → work_records (backfilled in V5).
UPDATE task_schedule_items SET status = 'planned' WHERE status = 'completed';

ALTER TABLE task_schedule_items DROP COLUMN actual_date;
ALTER TABLE task_schedule_items DROP COLUMN actual_notes;
ALTER TABLE task_schedule_items DROP COLUMN completed_at;
