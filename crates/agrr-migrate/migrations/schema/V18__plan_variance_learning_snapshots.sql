CREATE TABLE IF NOT EXISTS plan_variance_learning_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  plan_id INTEGER NOT NULL,
  source_plan_id INTEGER NOT NULL,
  snapshot_json TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT (datetime('now')),
  updated_at DATETIME NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_plan_variance_learning_plan
    FOREIGN KEY (plan_id) REFERENCES cultivation_plans(id),
  CONSTRAINT fk_plan_variance_learning_source_plan
    FOREIGN KEY (source_plan_id) REFERENCES cultivation_plans(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS index_plan_variance_learning_on_plan_id
  ON plan_variance_learning_snapshots (plan_id);
