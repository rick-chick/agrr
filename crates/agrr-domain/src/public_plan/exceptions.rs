//! Ruby: `Domain::PublicPlan::Exceptions`

use thiserror::Error;

/// Ruby: `WeatherLocationMissingError`
#[derive(Debug, Error, Clone, PartialEq, Eq)]
#[error("weather location missing")]
pub struct WeatherLocationMissingError;

/// Ruby: `PredictionPayloadMissingError`
#[derive(Debug, Error, Clone, PartialEq, Eq)]
#[error("prediction payload missing")]
pub struct PredictionPayloadMissingError;

/// Ruby: `WeatherPredictionFailedError`
#[derive(Debug, Error, Clone, PartialEq, Eq)]
#[error("{0}")]
pub struct WeatherPredictionFailedError(pub String);
