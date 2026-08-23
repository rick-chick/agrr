//! Per-plan mutexes so concurrent optimization chains do not interleave field cultivation writes.

use std::collections::HashSet;
use std::sync::{Arc, Mutex};

/// RAII guard released when the optimization chain finishes (success or abort).
pub struct PlanOptimizationChainLockGuard {
    plan_id: i64,
    active: Arc<Mutex<HashSet<i64>>>,
}

impl Drop for PlanOptimizationChainLockGuard {
    fn drop(&mut self) {
        if let Ok(mut set) = self.active.lock() {
            set.remove(&self.plan_id);
        }
    }
}

#[derive(Clone, Default)]
pub struct PlanOptimizationChainLocks {
    active: Arc<Mutex<HashSet<i64>>>,
}

impl PlanOptimizationChainLocks {
    pub fn new() -> Self {
        Self::default()
    }

    /// Returns `None` when another chain is already running for `plan_id`.
    pub fn try_acquire(&self, plan_id: i64) -> Option<PlanOptimizationChainLockGuard> {
        let mut set = self.active.lock().ok()?;
        if set.contains(&plan_id) {
            return None;
        }
        set.insert(plan_id);
        Some(PlanOptimizationChainLockGuard {
            plan_id,
            active: self.active.clone(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn try_acquire_succeeds_once_per_plan_id() {
        let locks = PlanOptimizationChainLocks::new();
        let guard = locks.try_acquire(7).expect("first acquire");
        assert!(locks.try_acquire(7).is_none());
        drop(guard);
        assert!(locks.try_acquire(7).is_some());
    }

    #[test]
    fn different_plan_ids_do_not_block_each_other() {
        let locks = PlanOptimizationChainLocks::new();
        let _guard_a = locks.try_acquire(1).expect("plan 1");
        assert!(locks.try_acquire(2).is_some());
    }
}
