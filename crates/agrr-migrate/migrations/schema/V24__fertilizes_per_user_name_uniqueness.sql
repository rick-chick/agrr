-- Issue #1114: global unique on fertilizes.name caused POST 500 when another user
-- already owned the same name (e.g. E2E baseline). Align with agricultural_tasks.
DROP INDEX IF EXISTS "index_fertilizes_on_name";
CREATE INDEX IF NOT EXISTS "index_fertilizes_on_name"
  ON "fertilizes" ("name") WHERE is_reference = 1;
CREATE UNIQUE INDEX IF NOT EXISTS "index_fertilizes_on_user_id_and_name"
  ON "fertilizes" ("user_id", "name") WHERE is_reference = 0;
