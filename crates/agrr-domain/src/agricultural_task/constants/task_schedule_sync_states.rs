//! Task schedule generation sync states persisted on `cultivation_plans`.

pub const GENERATING: &str = "generating";
pub const READY: &str = "ready";
pub const STALE: &str = "stale";
pub const FAILED: &str = "failed";
