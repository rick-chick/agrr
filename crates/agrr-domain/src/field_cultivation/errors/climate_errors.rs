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
