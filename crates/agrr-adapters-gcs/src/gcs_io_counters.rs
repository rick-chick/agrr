//! Process-wide GCS object I/O counters for optimization-chain telemetry.
//!
//! Concurrent chains may interleave; per-step deltas are approximate under load.

use std::sync::atomic::{AtomicU64, Ordering};

static READS: AtomicU64 = AtomicU64::new(0);
static LISTS: AtomicU64 = AtomicU64::new(0);
static WRITES: AtomicU64 = AtomicU64::new(0);

pub type GcsIoDelta = (u64, u64, u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct GcsIoSnapshot {
    reads: u64,
    lists: u64,
    writes: u64,
}

impl GcsIoSnapshot {
    pub fn capture() -> Self {
        Self {
            reads: READS.load(Ordering::Relaxed),
            lists: LISTS.load(Ordering::Relaxed),
            writes: WRITES.load(Ordering::Relaxed),
        }
    }

    pub fn delta_since(&self) -> GcsIoDelta {
        let now = Self::capture();
        (
            now.reads.saturating_sub(self.reads),
            now.lists.saturating_sub(self.lists),
            now.writes.saturating_sub(self.writes),
        )
    }
}

pub(crate) fn record_read() {
    READS.fetch_add(1, Ordering::Relaxed);
}

pub(crate) fn record_list() {
    LISTS.fetch_add(1, Ordering::Relaxed);
}

pub(crate) fn record_write() {
    WRITES.fetch_add(1, Ordering::Relaxed);
}

#[cfg(test)]
pub fn reset_for_test() {
    READS.store(0, Ordering::Relaxed);
    LISTS.store(0, Ordering::Relaxed);
    WRITES.store(0, Ordering::Relaxed);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn snapshot_delta_counts_operations_since_capture() {
        reset_for_test();
        let before = GcsIoSnapshot::capture();
        record_read();
        record_read();
        record_list();
        record_write();
        assert_eq!(before.delta_since(), (2, 1, 1));
    }
}
