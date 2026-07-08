-- Convert crop_task_templates without a matching blueprint into manual pending blueprints
-- (null stage_order / gdd_trigger) before template table removal in V11.

INSERT INTO crop_task_schedule_blueprints (
    crop_id,
    agricultural_task_id,
    stage_order,
    stage_name,
    gdd_trigger,
    gdd_tolerance,
    task_type,
    source,
    priority,
    amount,
    amount_unit,
    description,
    weather_dependency,
    time_per_sqm,
    created_at,
    updated_at,
    name,
    source_agricultural_task_id
)
SELECT
    ctt.crop_id,
    ctt.agricultural_task_id,
    NULL,
    NULL,
    NULL,
    NULL,
    COALESCE(NULLIF(TRIM(ctt.task_type), ''), NULLIF(TRIM(at.task_type), ''), 'field_work'),
    'manual',
    1,
    NULL,
    NULL,
    ctt.description,
    ctt.weather_dependency,
    ctt.time_per_sqm,
    ctt.created_at,
    ctt.updated_at,
    ctt.name,
    ctt.source_agricultural_task_id
FROM crop_task_templates ctt
LEFT JOIN agricultural_tasks at ON at.id = ctt.agricultural_task_id
WHERE ctt.agricultural_task_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM crop_task_schedule_blueprints b
      WHERE b.crop_id = ctt.crop_id
        AND b.agricultural_task_id = ctt.agricultural_task_id
  );
