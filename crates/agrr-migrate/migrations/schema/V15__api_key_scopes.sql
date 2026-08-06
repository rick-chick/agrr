ALTER TABLE "users" ADD COLUMN "api_key_scopes" text;

-- Preserve existing integrations: keys created before scope enforcement get read+write.
UPDATE "users"
SET "api_key_scopes" = '["masters:read","masters:write"]'
WHERE "api_key" IS NOT NULL
  AND TRIM("api_key") != ''
  AND ("api_key_scopes" IS NULL OR TRIM("api_key_scopes") = '');
