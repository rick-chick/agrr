-- GCS bulk weather aggregate metadata (SQLite). Bulk payloads remain in GCS year files.
ALTER TABLE weather_locations ADD COLUMN bulk_earliest_date TEXT;
ALTER TABLE weather_locations ADD COLUMN bulk_latest_date TEXT;
ALTER TABLE weather_locations ADD COLUMN bulk_year_stats TEXT;
