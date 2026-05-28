/// Ruby: `ApplicationDatabaseClearGateway::ApplicationDataStats`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ApplicationDataStats {
    pub users: i64,
    pub farms: i64,
    pub fields: i64,
    pub crops: i64,
    pub cultivation_plans: i64,
}

/// Ruby: `ApplicationDatabaseClearGateway::ClearResult`
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClearApplicationDataResult {
    Success {
        before_stats: ApplicationDataStats,
        after_stats: ApplicationDataStats,
    },
    Failure {
        error_message: String,
    },
}

impl ClearApplicationDataResult {
    pub fn success(before: ApplicationDataStats, after: ApplicationDataStats) -> Self {
        Self::Success {
            before_stats: before,
            after_stats: after,
        }
    }

    pub fn failure(message: impl Into<String>) -> Self {
        Self::Failure {
            error_message: message.into(),
        }
    }
}

/// Ruby: `Domain::Backdoor::Gateways::ApplicationDatabaseClearGateway`
pub trait ApplicationDatabaseClearGateway: Send + Sync {
    fn clear_application_data_preserving_anonymous_users(&self) -> ClearApplicationDataResult;
}
