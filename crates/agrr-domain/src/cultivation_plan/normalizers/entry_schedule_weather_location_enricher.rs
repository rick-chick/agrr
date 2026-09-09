//! Ensures agrr optimize-period receives coordinates even when the cached slice omits them.

use serde_json::Value;

use crate::shared::hash::present;
use crate::weather_data::dtos::WeatherLocation;

/// Fills missing latitude/longitude/elevation/timezone from `WeatherLocation`.
pub fn enrich_from_location(weather_data: &mut Value, weather_location: &WeatherLocation) {
    let Some(obj) = weather_data.as_object_mut() else {
        return;
    };
    if !obj.get("latitude").map(present).unwrap_or(false) {
        obj.insert("latitude".into(), Value::from(weather_location.latitude));
    }
    if !obj.get("longitude").map(present).unwrap_or(false) {
        obj.insert("longitude".into(), Value::from(weather_location.longitude));
    }
    if !obj.get("elevation").map(present).unwrap_or(false) {
        if let Some(elevation) = weather_location.elevation {
            obj.insert("elevation".into(), Value::from(elevation));
        }
    }
    if !obj.get("timezone").map(present).unwrap_or(false) {
        if let Some(timezone) = &weather_location.timezone {
            obj.insert("timezone".into(), Value::from(timezone.as_str()));
        }
    }
}

#[cfg(test)]
mod normalizers_entry_schedule_weather_location_enricher_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/normalizers_entry_schedule_weather_location_enricher_test.rs"
    ));
}
