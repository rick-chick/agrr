ALTER TABLE plan_variance_learning_orchestration_steps
  ADD COLUMN pipeline_active INTEGER NOT NULL DEFAULT 0;

ALTER TABLE plan_variance_learning_orchestration_steps
  ADD COLUMN pipeline_phase TEXT;

ALTER TABLE plan_variance_learning_orchestration_steps
  ADD COLUMN pipeline_failed_phase TEXT;

ALTER TABLE plan_variance_learning_orchestration_steps
  ADD COLUMN pipeline_error TEXT;
