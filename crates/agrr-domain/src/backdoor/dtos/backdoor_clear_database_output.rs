use crate::backdoor::gateways::ApplicationDataStats;

/// Ruby: `Domain::Backdoor::Dtos::BackdoorClearDatabaseOutput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BackdoorClearDatabaseOutput {
    pub before_stats: ApplicationDataStats,
    pub after_stats: ApplicationDataStats,
}

impl BackdoorClearDatabaseOutput {
    pub fn new(before_stats: ApplicationDataStats, after_stats: ApplicationDataStats) -> Self {
        Self {
            before_stats,
            after_stats,
        }
    }
}
