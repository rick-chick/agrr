ALTER TABLE plan_variance_learning_orchestration_steps
  ADD COLUMN pipeline_active INTEGER NOT NULL DEFAULT 0;

ALTER TABLE plan_variance_learning_orchestration_steps
  ADD COLUMN current_phase TEXT NOT NULL DEFAULT 'idle';

ALTER TABLE plan_variance_learning_orchestration_steps
  ADD COLUMN last_error TEXT;
