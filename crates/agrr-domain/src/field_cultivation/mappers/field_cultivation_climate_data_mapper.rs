use serde_json::{json, Value};
use time::Date;

use crate::field_cultivation::helpers::parse_iso_date;
use crate::field_cultivation::dtos::{
    FieldCultivationClimateContextSnapshot, FieldCultivationClimateDataOutput,
};
use crate::shared::validation::to_array_value;

pub fn build_output(
    context: &FieldCultivationClimateContextSnapshot,
    weather_records: &[Value],
    progress_result: &Value,
) -> FieldCultivationClimateDataOutput {
    let base_temp = context.base_temperature;
    let final_cumulative_gdd_required = final_cumulative_gdd_required_from_stages(&context.stages);
    let (daily_gdd, baseline_gdd, filtered_records, progress_records) = build_daily_gdd(
        progress_result,
        weather_records,
        context.start_date,
        context.completion_date,
        base_temp,
        final_cumulative_gdd_required,
    );

    let weather_data: Vec<Value> = weather_records
        .iter()
        .map(|datum| {
            json!({
                "date": datum.get("date").cloned().unwrap_or(Value::Null),
                "temperature_max": datum.get("temperature_max").cloned().unwrap_or(Value::Null),
                "temperature_min": datum.get("temperature_min").cloned().unwrap_or(Value::Null),
                "temperature_mean": datum.get("temperature_mean").cloned().unwrap_or(Value::Null),
            })
        })
        .collect();

    FieldCultivationClimateDataOutput {
        field_cultivation: json!({
            "id": context.field_cultivation_id,
            "field_name": context.field_name,
            "crop_name": context.crop_name,
            "start_date": context.start_date.to_string(),
            "completion_date": context.completion_date.to_string(),
        }),
        farm: json!({
            "id": context.farm_id,
            "name": context.farm_name,
            "latitude": context.farm_latitude,
            "longitude": context.farm_longitude,
        }),
        crop_requirements: json!({
            "base_temperature": base_temp,
            "optimal_temperature_range": context.optimal_temperature_range,
        }),
        weather_data,
        gdd_data: daily_gdd,
        stages: context.stages.clone(),
        progress_result: progress_result.clone(),
        debug_info: json!({
            "baseline_gdd": baseline_gdd,
            "progress_records_count": progress_records.len(),
            "filtered_records_count": filtered_records.len(),
            "using_agrr_progress": !progress_records.is_empty(),
            "sample_raw_data": progress_records.iter().take(3).collect::<Vec<_>>(),
        }),
    }
}

pub fn extract_weather_records(
    weather_payload: Option<&Value>,
    start_date: Date,
    end_date: Date,
) -> Vec<Value> {
    let Some(payload) = weather_payload else {
        return vec![];
    };
    let Some(data) = payload.get("data") else {
        return vec![];
    };

    to_array_value(Some(data))
        .into_iter()
        .filter_map(|datum| {
            let time_value = datum
                .get("time")
                .or_else(|| datum.get("date"))
                .and_then(|v| v.as_str())?;
            let datum_date = parse_iso_date(time_value)?;
            if datum_date < start_date || datum_date > end_date {
                return None;
            }
            let temp_mean = datum.get("temperature_2m_mean").and_then(|v| v.as_f64()).or_else(|| {
                let max = datum.get("temperature_2m_max").and_then(|v| v.as_f64())?;
                let min = datum.get("temperature_2m_min").and_then(|v| v.as_f64())?;
                Some((max + min) / 2.0)
            });
            Some(json!({
                "date": time_value,
                "temperature_max": datum.get("temperature_2m_max").cloned().unwrap_or(Value::Null),
                "temperature_min": datum.get("temperature_2m_min").cloned().unwrap_or(Value::Null),
                "temperature_mean": temp_mean,
            }))
        })
        .collect()
}

fn final_cumulative_gdd_required_from_stages(stages: &[Value]) -> Option<f64> {
    stages
        .iter()
        .filter_map(|stage| {
            stage
                .get("cumulative_gdd_required")
                .and_then(|v| v.as_f64())
        })
        .max_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
}

fn truncate_daily_gdd_at_requirement(
    daily_gdd: &mut Vec<Value>,
    final_cumulative_gdd_required: Option<f64>,
) {
    let Some(required) = final_cumulative_gdd_required else {
        return;
    };
    if required <= 0.0 || daily_gdd.is_empty() {
        return;
    }
    let Some(completion_index) = daily_gdd.iter().position(|datum| {
        datum
            .get("cumulative_gdd")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0)
            >= required
    }) else {
        return;
    };
    daily_gdd.truncate(completion_index + 1);
}

fn build_daily_gdd(
    progress_result: &Value,
    weather_data_records: &[Value],
    start_date: Date,
    completion_date: Date,
    base_temp: f64,
    final_cumulative_gdd_required: Option<f64>,
) -> (Vec<Value>, f64, Vec<Value>, Vec<Value>) {
    let progress_records = to_array_value(progress_result.get("progress_records"));
    let mut baseline_gdd = 0.0;
    let mut filtered_records: Vec<Value> = Vec::new();
    let mut daily_gdd: Vec<Value>;

    if progress_records.is_empty() {
        daily_gdd = calculate_gdd_manually(weather_data_records, base_temp);
    } else {
        filtered_records = progress_records
            .iter()
            .filter(|record| {
                let Some(date_str) = record.get("date").and_then(|v| v.as_str()) else {
                    return false;
                };
                let Some(record_date) = parse_iso_date(date_str) else {
                    return false;
                };
                record_date >= start_date && record_date <= completion_date
            })
            .cloned()
            .collect();

        let start_index = progress_records.iter().position(|record| {
            record
                .get("date")
                .and_then(|v| v.as_str())
                .and_then(|s| {
                    parse_iso_date(s)
                })
                == Some(start_date)
        });

        baseline_gdd = if let Some(idx) = start_index {
            if idx > 0 {
                progress_records[idx - 1]
                    .get("cumulative_gdd")
                    .and_then(|v| v.as_f64())
                    .unwrap_or(0.0)
            } else {
                0.0
            }
        } else {
            0.0
        };

        let mut built = Vec::new();
        for (index, day) in filtered_records.iter().enumerate() {
            let current_cumulative_raw = day
                .get("cumulative_gdd")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0);
            let current_cumulative = current_cumulative_raw - baseline_gdd;
            let prev_cumulative = if index > 0 {
                filtered_records[index - 1]
                    .get("cumulative_gdd")
                    .and_then(|v| v.as_f64())
                    .unwrap_or(0.0)
                    - baseline_gdd
            } else {
                0.0
            };
            let daily_gdd_value = current_cumulative - prev_cumulative;
            built.push(json!({
                "date": day.get("date").cloned().unwrap_or(Value::Null),
                "gdd": (daily_gdd_value * 100.0).round() / 100.0,
                "cumulative_gdd": (current_cumulative * 100.0).round() / 100.0,
                "temperature": Value::Null,
                "current_stage": day.get("stage_name").cloned().unwrap_or(Value::Null),
            }));
        }
        daily_gdd = built;
    }

    truncate_daily_gdd_at_requirement(&mut daily_gdd, final_cumulative_gdd_required);

    (
        daily_gdd,
        baseline_gdd,
        filtered_records,
        progress_records,
    )
}

fn calculate_gdd_manually(weather_data_records: &[Value], base_temp: f64) -> Vec<Value> {
    let mut daily_gdd = Vec::new();
    let mut cumulative_gdd = 0.0;

    for datum in weather_data_records {
        let avg_temp = datum
            .get("temperature_mean")
            .and_then(|v| v.as_f64())
            .or_else(|| {
                let max = datum.get("temperature_max").and_then(|v| v.as_f64())?;
                let min = datum.get("temperature_min").and_then(|v| v.as_f64())?;
                Some((max + min) / 2.0)
            });
        let Some(avg_temp) = avg_temp else {
            continue;
        };
        let gdd_value = (avg_temp - base_temp).max(0.0);
        cumulative_gdd += gdd_value;
        daily_gdd.push(json!({
            "date": datum.get("date").cloned().unwrap_or(Value::Null),
            "gdd": (gdd_value * 100.0).round() / 100.0,
            "cumulative_gdd": (cumulative_gdd * 100.0).round() / 100.0,
            "temperature": (avg_temp * 100.0).round() / 100.0,
            "current_stage": Value::Null,
        }));
    }

    daily_gdd
}

#[cfg(test)]
mod mappers_field_cultivation_climate_data_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_climate_data_mapper_test.rs"));
}
