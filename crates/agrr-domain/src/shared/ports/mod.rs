//! Ruby: `Domain::Shared::Ports` — trait-only port definitions.

pub mod clock_port;
pub mod crop_agrr_requirement_builder_port;
pub mod cultivation_plan_phase_broadcast_port;
pub mod farm_refresh_broadcast_port;
pub mod fetch_weather_data_enqueue_port;
pub mod interaction_rule_agrr_format_builder_port;
pub mod logger_port;
pub mod masters_api_credentials_resolve_output_port;
pub mod sql_like_sanitize_port;
pub mod translator_port;

pub use clock_port::ClockPort;
pub use crop_agrr_requirement_builder_port::{
    CropAgrrRequirementBuilderPort, CropAgrrRequirementSource,
};
pub use cultivation_plan_phase_broadcast_port::CultivationPlanPhaseBroadcastPort;
pub use farm_refresh_broadcast_port::FarmRefreshBroadcastPort;
pub use fetch_weather_data_enqueue_port::FetchWeatherDataEnqueuePort;
pub use interaction_rule_agrr_format_builder_port::{
    InteractionRuleAgrrFormatBuilderPort, InteractionRuleAgrrFormatSource,
};
pub use logger_port::LoggerPort;
pub use masters_api_credentials_resolve_output_port::MastersApiCredentialsResolveOutputPort;
pub use sql_like_sanitize_port::SqlLikeSanitizePort;
pub use translator_port::{TranslateOptions, TranslatorPort};

#[cfg(test)]
mod ports_mod_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/ports_mod_test.rs"));
}
