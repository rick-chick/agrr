CREATE TABLE IF NOT EXISTS plan_variance_learning_handoff_states (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  plan_id INTEGER NOT NULL,
  handoff_json TEXT NOT NULL DEFAULT '{}',
  created_at DATETIME NOT NULL DEFAULT (datetime('now')),
  updated_at DATETIME NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_plan_variance_learning_handoff_plan
    FOREIGN KEY (plan_id) REFERENCES cultivation_plans(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS index_plan_variance_learning_handoff_on_plan_id
  ON plan_variance_learning_handoff_states (plan_id);
