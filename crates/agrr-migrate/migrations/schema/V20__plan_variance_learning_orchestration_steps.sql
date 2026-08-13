CREATE TABLE IF NOT EXISTS plan_variance_learning_orchestration_steps (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  plan_id INTEGER NOT NULL UNIQUE,
  placement_complete INTEGER NOT NULL DEFAULT 0,
  regenerate_complete INTEGER NOT NULL DEFAULT 0,
  sync_verify_complete INTEGER NOT NULL DEFAULT 0,
  return_to_learn INTEGER NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT (datetime('now')),
  updated_at DATETIME NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_plan_variance_learning_orchestration_steps_plan
    FOREIGN KEY (plan_id) REFERENCES cultivation_plans(id)
);
