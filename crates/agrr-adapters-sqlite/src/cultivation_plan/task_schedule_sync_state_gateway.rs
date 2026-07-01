//! Persist `cultivation_plans.task_schedule_sync_*` columns.

use crate::pool::SqlitePool;
use agrr_domain::agricultural_task::gateways::TaskScheduleSyncStateGateway;
use rusqlite::params;

pub struct TaskScheduleSyncStateSqliteGateway {
    pool: SqlitePool,
}

impl TaskScheduleSyncStateSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl TaskScheduleSyncStateGateway for TaskScheduleSyncStateSqliteGateway {
    fn update_sync_state(
        &self,
        plan_id: i64,
        sync_state: &str,
        sync_error: Option<&str>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "UPDATE cultivation_plans SET task_schedule_sync_state = ?1, \
                 task_schedule_sync_error = ?2, updated_at = datetime('now') WHERE id = ?3",
                params![sync_state, sync_error, plan_id],
            )?;
            Ok(())
        })
    }

    fn find_sync_state(
        &self,
        plan_id: i64,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let state = conn.query_row(
                "SELECT COALESCE(task_schedule_sync_state, 'never') FROM cultivation_plans WHERE id = ?1",
                params![plan_id],
                |row| row.get(0),
            )?;
            Ok(state)
        })
    }
}

#[cfg(test)]
mod task_schedule_sync_state_gateway_integration_test {
    use super::TaskScheduleSyncStateSqliteGateway;
    use crate::pool::SqlitePool;
    use agrr_domain::agricultural_task::constants::task_schedule_sync_states;
    use agrr_domain::agricultural_task::gateways::TaskScheduleSyncStateGateway;
    use rusqlite::params;

    fn test_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!(
            "agrr_task_schedule_sync_state_gw_{}",
            std::process::id()
        ));
        let _ = std::fs::create_dir_all(&dir);
        let path = dir.join(format!(
            "sync_state_gw_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let pool = SqlitePool::new(path.to_str().expect("utf8 path"));
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE cultivation_plans (
                   id INTEGER PRIMARY KEY,
                   task_schedule_sync_state TEXT NOT NULL DEFAULT 'never',
                   task_schedule_sync_error TEXT,
                   updated_at TEXT
                 );",
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, task_schedule_sync_state, updated_at)
                 VALUES (1, 'never', datetime('now'))",
                [],
            )?;
            Ok(())
        })
        .expect("seed plan");
        pool
    }

    #[test]
    fn sync_state_gateway_updates_and_reads_state() {
        let pool = test_pool();
        let gateway = TaskScheduleSyncStateSqliteGateway::new(pool.clone());

        gateway
            .update_sync_state(
                1,
                task_schedule_sync_states::FAILED,
                Some("plans.task_schedules.sync_errors.generic"),
            )
            .expect("update sync state");

        assert_eq!(
            gateway.find_sync_state(1).expect("read sync state"),
            task_schedule_sync_states::FAILED
        );

        let error: Option<String> = pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT task_schedule_sync_error FROM cultivation_plans WHERE id = 1",
                    params![],
                    |row| row.get(0),
                )
            })
            .expect("read sync error");
        assert_eq!(
            error.as_deref(),
            Some("plans.task_schedules.sync_errors.generic")
        );
    }
}
