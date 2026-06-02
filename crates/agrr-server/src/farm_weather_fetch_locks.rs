//! Per-farm mutexes so concurrent optimization chains do not fetch weather for the same farm in parallel.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[derive(Clone, Default)]
pub struct FarmWeatherFetchLocks {
    inner: Arc<Mutex<HashMap<i64, Arc<Mutex<()>>>>>,
}

impl FarmWeatherFetchLocks {
    pub fn new() -> Self {
        Self::default()
    }

    /// Runs `step` while holding the per-farm lock (blocks concurrent fetches for the same `farm_id`).
    pub fn with_farm_lock<R>(
        &self,
        farm_id: i64,
        step: impl FnOnce() -> Result<R, String>,
    ) -> Result<R, String> {
        let farm_mutex = {
            let mut map = self
                .inner
                .lock()
                .map_err(|e| format!("farm weather lock map poisoned: {e}"))?;
            map.entry(farm_id)
                .or_insert_with(|| Arc::new(Mutex::new(())))
                .clone()
        };
        let _guard = farm_mutex
            .lock()
            .map_err(|e| format!("farm weather lock poisoned farm_id={farm_id}: {e}"))?;
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
    fn same_farm_id_serializes_holders() {
        let locks = FarmWeatherFetchLocks::new();
        let entered_first = Arc::new(AtomicBool::new(false));
        let entered_second = Arc::new(AtomicBool::new(false));
        let release_first = Arc::new(AtomicBool::new(false));

        let locks_first = locks.clone();
        let entered_first_in = entered_first.clone();
        let release_first_in = release_first.clone();
        let handle_first = thread::spawn(move || {
            locks_first
                .with_farm_lock(1, || {
                    entered_first_in.store(true, Ordering::SeqCst);
                    while !release_first_in.load(Ordering::SeqCst) {
                        thread::sleep(Duration::from_millis(10));
                    }
                    Ok(())
                })
                .expect("first farm lock");
        });

        assert!(
            wait_until(Duration::from_secs(1), || entered_first.load(Ordering::SeqCst)),
            "first holder should enter"
        );

        let locks_second = locks.clone();
        let entered_second_in = entered_second.clone();
        let handle_second = thread::spawn(move || {
            locks_second
                .with_farm_lock(1, || {
                    entered_second_in.store(true, Ordering::SeqCst);
                    Ok(())
                })
                .expect("second farm lock");
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

    #[test]
    fn different_farm_ids_do_not_block_each_other() {
        let locks = FarmWeatherFetchLocks::new();
        let release_first = Arc::new(AtomicBool::new(false));
        let entered_first = Arc::new(AtomicBool::new(false));

        let locks_first = locks.clone();
        let entered_first_in = entered_first.clone();
        let release_first_in = release_first.clone();
        let _handle_first = thread::spawn(move || {
            locks_first
                .with_farm_lock(1, || {
                    entered_first_in.store(true, Ordering::SeqCst);
                    while !release_first_in.load(Ordering::SeqCst) {
                        thread::sleep(Duration::from_millis(10));
                    }
                    Ok(())
                })
                .expect("lock farm 1");
        });

        assert!(
            wait_until(Duration::from_secs(1), || entered_first.load(Ordering::SeqCst)),
            "first farm lock should be held"
        );

        let locks_second = locks.clone();
        let acquired = Arc::new(AtomicBool::new(false));
        let acquired_in = acquired.clone();
        let handle_second = thread::spawn(move || {
            locks_second
                .with_farm_lock(2, || {
                    acquired_in.store(true, Ordering::SeqCst);
                    Ok(())
                })
                .expect("lock farm 2");
        });

        assert!(
            wait_until(Duration::from_millis(200), || acquired.load(Ordering::SeqCst)),
            "different farms should not share a lock"
        );
        release_first.store(true, Ordering::SeqCst);
        handle_second.join().expect("join second");
    }
}
