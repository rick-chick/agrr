ALTER TABLE crops ADD COLUMN cultivation_method TEXT
  CHECK (cultivation_method IS NULL OR cultivation_method IN ('direct_sow', 'transplant'));
