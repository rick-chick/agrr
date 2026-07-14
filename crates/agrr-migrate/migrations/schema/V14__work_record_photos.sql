CREATE TABLE IF NOT EXISTS "work_record_photos" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "work_record_id" integer NOT NULL,
  "cultivation_plan_id" integer NOT NULL,
  "storage_key" varchar NOT NULL,
  "content_type" varchar,
  "byte_size" integer,
  "position" integer,
  "status" varchar NOT NULL DEFAULT 'pending',
  "original_filename" varchar,
  "created_at" datetime(6) NOT NULL,
  "updated_at" datetime(6) NOT NULL,
  FOREIGN KEY ("work_record_id") REFERENCES "work_records" ("id") ON DELETE CASCADE,
  FOREIGN KEY ("cultivation_plan_id") REFERENCES "cultivation_plans" ("id")
);

CREATE INDEX IF NOT EXISTS "index_work_record_photos_on_work_record_id"
  ON "work_record_photos" ("work_record_id");

CREATE UNIQUE INDEX IF NOT EXISTS "index_work_record_photos_on_record_and_position"
  ON "work_record_photos" ("work_record_id", "position")
  WHERE "position" IS NOT NULL;
