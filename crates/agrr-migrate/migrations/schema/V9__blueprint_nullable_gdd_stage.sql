-- Allow manual blueprint rows before AI fills GDD and stage_order.
-- SQLite cannot drop NOT NULL in place; rebuild the table.

PRAGMA foreign_keys = OFF;

CREATE TABLE crop_task_schedule_blueprints_new (
    id integer PRIMARY KEY AUTOINCREMENT NOT NULL,
    crop_id integer NOT NULL,
    agricultural_task_id integer,
    stage_order integer,
    stage_name varchar,
    gdd_trigger decimal(10,2),
    gdd_tolerance decimal(10,2),
    task_type varchar NOT NULL,
    source varchar NOT NULL,
    priority integer NOT NULL,
    amount decimal(10,3),
    amount_unit varchar,
    description text,
    weather_dependency varchar,
    time_per_sqm decimal(8,2),
    created_at datetime(6) NOT NULL,
    updated_at datetime(6) NOT NULL,
    name varchar,
    source_agricultural_task_id bigint,
    FOREIGN KEY (agricultural_task_id) REFERENCES agricultural_tasks (id),
    FOREIGN KEY (crop_id) REFERENCES crops (id)
);

INSERT INTO crop_task_schedule_blueprints_new (
    id, crop_id, agricultural_task_id, stage_order, stage_name, gdd_trigger, gdd_tolerance,
    task_type, source, priority, amount, amount_unit, description, weather_dependency,
    time_per_sqm, created_at, updated_at, name, source_agricultural_task_id
)
SELECT
    id, crop_id, agricultural_task_id, stage_order, stage_name, gdd_trigger, gdd_tolerance,
    task_type, source, priority, amount, amount_unit, description, weather_dependency,
    time_per_sqm, created_at, updated_at, name, source_agricultural_task_id
FROM crop_task_schedule_blueprints;

DROP TABLE crop_task_schedule_blueprints;

ALTER TABLE crop_task_schedule_blueprints_new RENAME TO crop_task_schedule_blueprints;

CREATE INDEX index_crop_task_schedule_blueprints_on_agricultural_task_id
    ON crop_task_schedule_blueprints (agricultural_task_id);

CREATE UNIQUE INDEX idx_on_crop_id_stage_order_agricultural_task_id
    ON crop_task_schedule_blueprints (crop_id, stage_order, agricultural_task_id)
    WHERE agricultural_task_id IS NOT NULL AND stage_order IS NOT NULL;

CREATE UNIQUE INDEX index_blueprints_on_crop_stage_and_source_task
    ON crop_task_schedule_blueprints (crop_id, stage_order, source_agricultural_task_id)
    WHERE agricultural_task_id IS NULL AND source_agricultural_task_id IS NOT NULL AND stage_order IS NOT NULL;

CREATE INDEX index_crop_task_schedule_blueprints_on_crop_id
    ON crop_task_schedule_blueprints (crop_id);

CREATE UNIQUE INDEX idx_blueprints_crop_ag_task_pending_stage
    ON crop_task_schedule_blueprints (crop_id, agricultural_task_id)
    WHERE agricultural_task_id IS NOT NULL AND stage_order IS NULL;

PRAGMA foreign_keys = ON;
