use thiserror::Error;

/// Ruby: `Domain::FieldCultivation::Errors::NoWeatherLocationError`
#[derive(Debug, Clone, PartialEq, Eq, Error)]
#[error("no weather location")]
pub struct NoWeatherLocationError;

/// Ruby: `Domain::FieldCultivation::Errors::NoCultivationPeriodError`
#[derive(Debug, Clone, PartialEq, Eq, Error)]
#[error("no cultivation period")]
pub struct NoCultivationPeriodError;

/// Ruby: `Domain::FieldCultivation::Errors::WeatherPayloadInvalidError`
#[derive(Debug, Clone, PartialEq, Eq, Error)]
#[error("weather payload invalid")]
pub struct WeatherPayloadInvalidError;

/// agrr progress gateway failure (typed; adapter maps daemon / execution errors here).
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum ClimateProgressGatewayError {
    #[error("daemon_unavailable")]
    DaemonUnavailable,
    #[error("{0}")]
    ExecutionFailed(String),
}

use crate::field_cultivation::dtos::FieldCultivationClimateFailure;

/// Carried in `Result::Err` from climate assembly until the interactor notifies the output port.
#[derive(Debug, Error)]
#[error("{0}")]
pub struct FieldCultivationClimateFailureError(pub FieldCultivationClimateFailure);
