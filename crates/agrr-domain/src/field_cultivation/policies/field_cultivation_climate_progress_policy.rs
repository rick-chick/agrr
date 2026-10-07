use serde_json::Value;
use time::Date;

use crate::field_cultivation::dtos::{
    FieldCultivationClimateFailure, FieldCultivationClimateFailureReason,
};
use crate::field_cultivation::errors::FieldCultivationClimateFailureError;
use crate::field_cultivation::helpers::parse_iso_date;
use crate::shared::validation::to_array_value;

pub fn validate_progress_result(
    progress_result: &Value,
    start_date: Date,
    completion_date: Date,
    in_period_weather_row_count: usize,
) -> Result<(), FieldCultivationClimateFailureError> {
    let records = progress_result.get("progress_records");
    let progress_records = match records {
        Some(v) => to_array_value(Some(v)),
        None => {
            return Err(invalid_progress(
                in_period_weather_row_count,
                "progress_records is not an array",
            ));
        }
    };

    if progress_records.is_empty() {
        return Err(invalid_progress(
            in_period_weather_row_count,
            "progress_records is empty",
        ));
    }

    for record in &progress_records {
        let date_str = record.get("date").and_then(|v| v.as_str());
        let date_ok = date_str.and_then(parse_iso_date).is_some();
        let gdd_ok = record
            .get("cumulative_gdd")
            .and_then(|v| v.as_f64())
            .is_some();
        if !date_ok || !gdd_ok {
            return Err(invalid_progress(
                in_period_weather_row_count,
                "progress record missing date or cumulative_gdd",
            ));
        }
    }

    let in_period = progress_records.iter().any(|record| {
        let Some(record_date) = record
            .get("date")
            .and_then(|v| v.as_str())
            .and_then(parse_iso_date)
        else {
            return false;
        };
        record_date >= start_date && record_date <= completion_date
    });

    if !in_period {
        return Err(invalid_progress(
            in_period_weather_row_count,
            "no progress records in cultivation period",
        ));
    }

    Ok(())
}

#[cfg(test)]
mod policies_field_cultivation_climate_progress_policy_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/field_cultivation/policies_field_cultivation_climate_progress_policy_test.rs"
    ));
}

fn invalid_progress(
    in_period_weather_row_count: usize,
    detail: &str,
) -> FieldCultivationClimateFailureError {
    FieldCultivationClimateFailureError(FieldCultivationClimateFailure::new(
        FieldCultivationClimateFailureReason::ProgressResultInvalid,
        format!(
            "invalid progress result ({detail}); in_period_weather_rows={in_period_weather_row_count}"
        ),
    ))
}
