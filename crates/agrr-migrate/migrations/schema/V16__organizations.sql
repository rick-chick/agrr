-- Phase 1: organizations / organization_memberships + Tier 1 organization_id (nullable).
-- Backfill is a separate migration (issue #611).

CREATE TABLE IF NOT EXISTS "organizations" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "name" varchar NOT NULL,
  "slug" varchar NOT NULL,
  "is_personal" boolean DEFAULT 0 NOT NULL,
  "created_at" datetime(6) NOT NULL,
  "updated_at" datetime(6) NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS "index_organizations_on_slug"
  ON "organizations" ("slug");

CREATE TABLE IF NOT EXISTS "organization_memberships" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "organization_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "role" varchar NOT NULL,
  "created_at" datetime(6) NOT NULL,
  "updated_at" datetime(6) NOT NULL,
  FOREIGN KEY ("organization_id") REFERENCES "organizations" ("id"),
  FOREIGN KEY ("user_id") REFERENCES "users" ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "index_organization_memberships_on_org_and_user"
  ON "organization_memberships" ("organization_id", "user_id");

CREATE INDEX IF NOT EXISTS "index_organization_memberships_on_organization_id"
  ON "organization_memberships" ("organization_id");

CREATE INDEX IF NOT EXISTS "index_organization_memberships_on_user_id"
  ON "organization_memberships" ("user_id");

ALTER TABLE "farms" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_farms_on_organization_id"
  ON "farms" ("organization_id");

ALTER TABLE "crops" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_crops_on_organization_id"
  ON "crops" ("organization_id");

ALTER TABLE "cultivation_plans" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_cultivation_plans_on_organization_id"
  ON "cultivation_plans" ("organization_id");

ALTER TABLE "fields" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_fields_on_organization_id"
  ON "fields" ("organization_id");

ALTER TABLE "agricultural_tasks" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_agricultural_tasks_on_organization_id"
  ON "agricultural_tasks" ("organization_id");

ALTER TABLE "fertilizes" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_fertilizes_on_organization_id"
  ON "fertilizes" ("organization_id");

ALTER TABLE "interaction_rules" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_interaction_rules_on_organization_id"
  ON "interaction_rules" ("organization_id");

ALTER TABLE "pests" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_pests_on_organization_id"
  ON "pests" ("organization_id");

ALTER TABLE "pesticides" ADD COLUMN "organization_id" integer;
CREATE INDEX IF NOT EXISTS "index_pesticides_on_organization_id"
  ON "pesticides" ("organization_id");
