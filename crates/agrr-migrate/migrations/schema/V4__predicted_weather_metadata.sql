CREATE TABLE predicted_weather_metadata (
  scope TEXT NOT NULL,
  scope_id INTEGER NOT NULL,
  prediction_start_date TEXT NOT NULL,
  prediction_end_date TEXT NOT NULL,
  target_end_date TEXT NOT NULL,
  data_end_date TEXT NOT NULL,
  generated_at TEXT NOT NULL,
  PRIMARY KEY (scope, scope_id)
);

ALTER TABLE weather_locations DROP COLUMN predicted_weather_data;
ALTER TABLE cultivation_plans DROP COLUMN predicted_weather_data;
ALTER TABLE farms DROP COLUMN predicted_weather_data;
