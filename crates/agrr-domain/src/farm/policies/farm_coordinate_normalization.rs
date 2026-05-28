use crate::farm::calculators::FarmWeatherProgressCalculator;

/// Ruby: `Domain::Farm::Policies::FarmCoordinateNormalizationPolicy`
pub struct FarmCoordinateNormalizationPolicy;

impl FarmCoordinateNormalizationPolicy {
    pub fn normalized_longitude(longitude: f64) -> f64 {
        FarmWeatherProgressCalculator::normalize_longitude(longitude)
    }
}
