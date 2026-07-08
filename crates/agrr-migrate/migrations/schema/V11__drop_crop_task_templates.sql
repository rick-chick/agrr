-- Phase 4: crop task templates replaced by task schedule blueprints.

DROP INDEX IF EXISTS index_crop_task_templates_on_crop_id;
DROP INDEX IF EXISTS idx_crop_task_templates_on_crop_and_source;
DROP INDEX IF EXISTS index_crop_task_templates_on_crop_id_and_name;
DROP INDEX IF EXISTS idx_crop_task_templates_on_crop_and_agricultural_task;
DROP INDEX IF EXISTS index_crop_task_templates_on_ai_state;
DROP INDEX IF EXISTS index_crop_task_templates_on_agricultural_task_id;

DROP TABLE IF EXISTS crop_task_templates;
