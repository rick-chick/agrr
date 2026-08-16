//! Gateway for loading weather reschedule proposal generation context.

use crate::cultivation_plan::dtos::weather_reschedule_proposal_context::WeatherRescheduleProposalContext;

pub trait WeatherRescheduleProposalReadGateway {
    fn find_context_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<WeatherRescheduleProposalContext, Box<dyn std::error::Error + Send + Sync>>;
}
