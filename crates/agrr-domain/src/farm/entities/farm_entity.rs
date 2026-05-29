use crate::farm::calculators::FarmWeatherProgressCalculator;
use crate::shared::record_ref::RecordRef;

/// Ruby: `Domain::Farm::Entities::FarmEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct FarmEntity {
    pub id: i64,
    pub name: String,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub region: Option<String>,
    pub user_id: Option<i64>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
    pub is_reference: bool,
    pub weather_data_status: Option<String>,
    pub weather_data_fetched_years: Option<i32>,
    pub weather_data_total_years: Option<i32>,
    pub weather_data_last_error: Option<String>,
    pub weather_location_id: Option<i64>,
    pub last_broadcast_at: Option<f64>,
}

impl FarmEntity {
    pub fn weather_data_progress(&self) -> i32 {
        FarmWeatherProgressCalculator::progress_percent(
            self.weather_data_fetched_years,
            self.weather_data_total_years,
        )
    }

    pub fn coordinates(&self) -> (Option<f64>, Option<f64>) {
        (self.latitude, self.longitude)
    }

    pub fn has_coordinates(&self) -> bool {
        self.latitude.is_some() && self.longitude.is_some()
    }

    pub fn display_name(&self) -> String {
        if self.name.trim().is_empty() {
            format!("Farm {}", self.id)
        } else {
            self.name.clone()
        }
    }

    pub fn reference(&self) -> bool {
        self.is_reference
    }
}

impl RecordRef for FarmEntity {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}

#[cfg(test)]
mod entities_farm_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/entities_farm_entity_test.rs"));
}
