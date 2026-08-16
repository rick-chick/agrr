ALTER TABLE work_records ADD COLUMN fertilize_id INTEGER
  REFERENCES fertilizes(id);
ALTER TABLE work_records ADD COLUMN pesticide_id INTEGER
  REFERENCES pesticides(id);

CREATE INDEX IF NOT EXISTS index_work_records_on_fertilize_id
  ON work_records (fertilize_id);
CREATE INDEX IF NOT EXISTS index_work_records_on_pesticide_id
  ON work_records (pesticide_id);
