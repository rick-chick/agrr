CREATE TABLE IF NOT EXISTS "work_records" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "cultivation_plan_id" integer NOT NULL,
  "field_cultivation_id" integer,
  "task_schedule_item_id" integer,
  "agricultural_task_id" integer,
  "name" varchar NOT NULL,
  "task_type" varchar,
  "actual_date" date NOT NULL,
  "amount" decimal(10,3),
  "amount_unit" varchar,
  "time_spent_minutes" integer,
  "notes" text,
  "created_at" datetime(6) NOT NULL,
  "updated_at" datetime(6) NOT NULL,
  FOREIGN KEY ("cultivation_plan_id") REFERENCES "cultivation_plans" ("id"),
  FOREIGN KEY ("task_schedule_item_id") REFERENCES "task_schedule_items" ("id") ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS "index_work_records_on_plan_and_date"
  ON "work_records" ("cultivation_plan_id", "actual_date");

CREATE INDEX IF NOT EXISTS "index_work_records_on_task_schedule_item_id"
  ON "work_records" ("task_schedule_item_id");

INSERT INTO work_records (
  cultivation_plan_id, field_cultivation_id, task_schedule_item_id,
  agricultural_task_id, name, task_type, actual_date, amount, amount_unit,
  notes, created_at, updated_at
)
SELECT ts.cultivation_plan_id, ts.field_cultivation_id, i.id,
       i.agricultural_task_id, i.name, i.task_type,
       COALESCE(i.actual_date, date(i.completed_at), date(i.updated_at)),
       i.amount, i.amount_unit,
       i.actual_notes,
       COALESCE(i.completed_at, i.updated_at),
       COALESCE(i.completed_at, i.updated_at)
FROM task_schedule_items i
JOIN task_schedules ts ON ts.id = i.task_schedule_id
WHERE i.status = 'completed' OR i.completed_at IS NOT NULL;
