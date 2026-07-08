-- Allow multiple blueprints per (crop, stage, agricultural_task) when gdd_trigger differs.
-- Version 12 may exist only on some DBs (orphan backfill_blueprint_task_names); this migration is V13.

DROP INDEX IF EXISTS idx_on_crop_id_stage_order_agricultural_task_id;

CREATE UNIQUE INDEX idx_blueprints_crop_stage_task_gdd
    ON crop_task_schedule_blueprints (crop_id, stage_order, agricultural_task_id, gdd_trigger)
    WHERE agricultural_task_id IS NOT NULL
      AND stage_order IS NOT NULL
      AND gdd_trigger IS NOT NULL;
