//! Per-plan mutexes so concurrent task schedule regen jobs do not interleave writes.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[derive(Clone, Default)]
pub struct PlanTaskScheduleRegenLocks {
    inner: Arc<Mutex<HashMap<i64, Arc<Mutex<()>>>>>,
}

impl PlanTaskScheduleRegenLocks {
    pub fn new() -> Self {
        Self::default()
    }

    /// Runs `step` while holding the per-plan lock (blocks concurrent regen for the same `plan_id`).
    pub fn with_plan_lock<R>(
        &self,
        plan_id: i64,
        step: impl FnOnce() -> Result<R, String>,
    ) -> Result<R, String> {
        let plan_mutex = {
            let mut map = self
                .inner
                .lock()
                .map_err(|e| format!("plan regen lock map poisoned: {e}"))?;
            map.entry(plan_id)
                .or_insert_with(|| Arc::new(Mutex::new(())))
                .clone()
        };
        let _guard = plan_mutex
            .lock()
            .map_err(|e| format!("plan regen lock poisoned plan_id={plan_id}: {e}"))?;
        step()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::thread;
    use std::time::{Duration, Instant};

    fn wait_until(timeout: Duration, mut condition: impl FnMut() -> bool) -> bool {
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            if condition() {
                return true;
            }
            thread::sleep(Duration::from_millis(10));
        }
        false
    }

    #[test]
    fn same_plan_id_serializes_holders() {
        let locks = PlanTaskScheduleRegenLocks::new();
        let entered_first = Arc::new(AtomicBool::new(false));
        let entered_second = Arc::new(AtomicBool::new(false));
        let release_first = Arc::new(AtomicBool::new(false));

        let locks_first = locks.clone();
        let entered_first_in = entered_first.clone();
        let release_first_in = release_first.clone();
        let handle_first = thread::spawn(move || {
            locks_first
                .with_plan_lock(1, || {
                    entered_first_in.store(true, Ordering::SeqCst);
                    while !release_first_in.load(Ordering::SeqCst) {
                        thread::sleep(Duration::from_millis(10));
                    }
                    Ok(())
                })
                .expect("first plan lock");
        });

        assert!(
            wait_until(Duration::from_secs(1), || entered_first.load(Ordering::SeqCst)),
            "first holder should enter"
        );

        let locks_second = locks.clone();
        let entered_second_in = entered_second.clone();
        let handle_second = thread::spawn(move || {
            locks_second
                .with_plan_lock(1, || {
                    entered_second_in.store(true, Ordering::SeqCst);
                    Ok(())
                })
                .expect("second plan lock");
        });

        assert!(
            !wait_until(Duration::from_millis(150), || entered_second.load(Ordering::SeqCst)),
            "second holder should block until first releases"
        );
        release_first.store(true, Ordering::SeqCst);
        assert!(
            wait_until(Duration::from_secs(1), || entered_second.load(Ordering::SeqCst)),
            "second holder should enter after first releases"
        );
        handle_first.join().expect("join first");
        handle_second.join().expect("join second");
    }
}
