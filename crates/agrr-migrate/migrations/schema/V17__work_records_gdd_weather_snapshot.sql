-- Persist cumulative GDD and weather snapshot at work record actual_date (issue #802).
ALTER TABLE work_records ADD COLUMN gdd_at_actual REAL;
ALTER TABLE work_records ADD COLUMN weather_snapshot TEXT;
