CREATE TABLE IF NOT EXISTS plan_variance_learning_proposal_states (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  plan_id INTEGER NOT NULL,
  proposal_key TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT (datetime('now')),
  updated_at DATETIME NOT NULL DEFAULT (datetime('now')),
  CONSTRAINT fk_plan_variance_learning_proposal_states_plan
    FOREIGN KEY (plan_id) REFERENCES cultivation_plans(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS index_plan_variance_learning_proposal_states_on_plan_and_key
  ON plan_variance_learning_proposal_states (plan_id, proposal_key);
