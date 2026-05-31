-- Tracks manually applied reference-data migrations (primary DB only).
CREATE TABLE IF NOT EXISTS data_migration_history (
    version TEXT NOT NULL PRIMARY KEY,
    region TEXT NOT NULL,
    kind TEXT NOT NULL,
    applied_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS index_data_migration_history_on_region_kind
    ON data_migration_history (region, kind);
