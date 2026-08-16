//! SQLite adapter for weather reschedule proposals.
//!
//! Returns an empty list until trigger classification (#1050) and move generation (#1051) land.

use agrr_domain::cultivation_plan::dtos::WeatherRescheduleProposalRead;
use agrr_domain::cultivation_plan::gateways::WeatherRescheduleProposalsGateway;

pub struct WeatherRescheduleProposalsSqliteGateway;

impl WeatherRescheduleProposalsSqliteGateway {
    pub fn new() -> Self {
        Self
    }
}

impl Default for WeatherRescheduleProposalsSqliteGateway {
    fn default() -> Self {
        Self::new()
    }
}

impl WeatherRescheduleProposalsGateway for WeatherRescheduleProposalsSqliteGateway {
    fn list_by_plan_id(
        &self,
        _plan_id: i64,
    ) -> Result<Vec<WeatherRescheduleProposalRead>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Vec::new())
    }
}
