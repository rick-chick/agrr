-- API keys are read-only: align keys issued before scope enforcement (V15 granted read+write).
UPDATE "users"
SET "api_key_scopes" = '["masters:read"]'
WHERE "api_key_scopes" LIKE '%"masters:write"%';
