//! Gateway for listing weather-triggered reschedule proposals for a plan.

use crate::cultivation_plan::dtos::WeatherRescheduleProposalRead;

pub trait WeatherRescheduleProposalsGateway {
    fn list_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<WeatherRescheduleProposalRead>, Box<dyn std::error::Error + Send + Sync>>;
}
