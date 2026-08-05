ALTER TABLE users ADD COLUMN api_key_scopes text;

UPDATE users
SET api_key_scopes = '["masters:read","masters:write"]'
WHERE api_key IS NOT NULL AND trim(api_key) != '';
