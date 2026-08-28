ALTER TABLE "users" ADD COLUMN "api_key_hash" text;
ALTER TABLE "users" ADD COLUMN "api_key_prefix" text;

DROP INDEX IF EXISTS "index_users_on_api_key";

CREATE UNIQUE INDEX "index_users_on_api_key_hash" ON "users" ("api_key_hash")
WHERE "api_key_hash" IS NOT NULL;
