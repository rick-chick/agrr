-- Crop context for task schedule sync failures (multi-crop plan remediation links).
ALTER TABLE cultivation_plans ADD COLUMN task_schedule_sync_error_crop_id INTEGER;
