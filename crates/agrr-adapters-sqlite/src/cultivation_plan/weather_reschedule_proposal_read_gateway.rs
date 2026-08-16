//! SQLite adapter for loading weather reschedule proposal generation context.

use std::sync::Arc;

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::weather_reschedule_proposal_context::{
    WeatherRescheduleCultivationSnapshot, WeatherRescheduleProposalContext,
};
use agrr_domain::cultivation_plan::gateways::WeatherRescheduleProposalReadGateway;
use agrr_domain::cultivation_plan::helpers::parse_iso_date;
use agrr_domain::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    GddTrajectorySample, WeatherForecastDay, WeatherRescheduleTaskSchedule,
};
use agrr_domain::weather_data::dtos::PredictedWeatherScope;
use agrr_domain::weather_data::gateways::PredictedWeatherStoreGateway;
use rusqlite::params;
use serde_json::Value;

pub struct WeatherRescheduleProposalReadSqliteGateway {
    pool: SqlitePool,
    predicted_weather_store: Arc<dyn PredictedWeatherStoreGateway>,
}

impl WeatherRescheduleProposalReadSqliteGateway {
    pub fn new(
        pool: SqlitePool,
        predicted_weather_store: Arc<dyn PredictedWeatherStoreGateway>,
    ) -> Self {
        Self {
            pool,
            predicted_weather_store,
        }
    }
}

fn parse_optional_date(raw: Option<String>) -> Option<time::Date> {
    raw.as_deref().and_then(parse_iso_date)
}

fn forecast_days_from_payload(payload: &Value) -> Vec<WeatherForecastDay> {
    let data = payload
        .get("data")
        .and_then(|value| value.as_array())
        .cloned()
        .unwrap_or_default();

    let mut days = Vec::new();
    for row in data {
        let Some(obj) = row.as_object() else {
            continue;
        };
        let raw_date = obj
            .get("time")
            .or_else(|| obj.get("date"))
            .and_then(|value| value.as_str());
        let Some(raw_date) = raw_date else {
            continue;
        };
        let Some(date) = parse_iso_date(raw_date) else {
            continue;
        };
        let t_min = obj
            .get("temperature_2m_min")
            .and_then(|value| value.as_f64());
        let Some(t_min) = t_min else {
            continue;
        };
        let t_mean = obj
            .get("temperature_2m_mean")
            .and_then(|value| value.as_f64());
        days.push(WeatherForecastDay {
            date,
            t_min,
            t_mean,
        });
    }
    days.sort_by_key(|day| day.date);
    days.dedup_by_key(|day| day.date);
    days
}

impl WeatherRescheduleProposalReadGateway for WeatherRescheduleProposalReadSqliteGateway {
    fn find_context_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<WeatherRescheduleProposalContext, Box<dyn std::error::Error + Send + Sync>> {
        let tasks = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT tsi.id, ts.field_cultivation_id, tsi.scheduled_date \
                 FROM task_schedules ts \
                 INNER JOIN task_schedule_items tsi ON tsi.task_schedule_id = ts.id \
                 WHERE ts.cultivation_plan_id = ?1 \
                   AND tsi.status != 'cancelled' \
                   AND tsi.scheduled_date IS NOT NULL \
                 ORDER BY tsi.id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let scheduled_raw: String = row.get(2)?;
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, i64>(1)?,
                    scheduled_raw,
                ))
            })?;
            let mut tasks = Vec::new();
            for row in rows {
                let (item_id, field_cultivation_id, scheduled_raw) = row?;
                let Some(scheduled_date) = parse_iso_date(&scheduled_raw) else {
                    continue;
                };
                tasks.push(WeatherRescheduleTaskSchedule {
                    item_id,
                    field_cultivation_id,
                    scheduled_date,
                });
            }
            Ok::<_, rusqlite::Error>(tasks)
        })?;

        let cultivations = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT fc.id, fc.cultivation_plan_field_id, fc.start_date, fc.completion_date, \
                 c.name, cpf.name, MIN(tr.frost_threshold) \
                 FROM field_cultivations fc \
                 INNER JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
                 INNER JOIN crops c ON c.id = cpc.crop_id \
                 INNER JOIN cultivation_plan_fields cpf ON cpf.id = fc.cultivation_plan_field_id \
                 LEFT JOIN crop_stages cs ON cs.crop_id = cpc.crop_id \
                 LEFT JOIN temperature_requirements tr ON tr.crop_stage_id = cs.id \
                 WHERE fc.cultivation_plan_id = ?1 \
                 GROUP BY fc.id, fc.cultivation_plan_field_id, fc.start_date, fc.completion_date, c.name, cpf.name \
                 ORDER BY fc.id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                Ok(WeatherRescheduleCultivationSnapshot {
                    field_cultivation_id: row.get(0)?,
                    plan_field_id: row.get(1)?,
                    start_date: parse_optional_date(row.get(2)?),
                    completion_date: parse_optional_date(row.get(3)?),
                    crop_name: row.get::<_, String>(4)?,
                    field_name: row.get::<_, String>(5)?,
                    frost_threshold: row.get(6)?,
                })
            })?;
            rows.collect::<Result<Vec<_>, _>>()
        })?;

        let gdd_samples = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT fc.id, wr.actual_date, wr.gdd_at_actual, tsi.gdd_trigger \
                 FROM field_cultivations fc \
                 INNER JOIN work_records wr ON wr.field_cultivation_id = fc.id \
                 LEFT JOIN task_schedule_items tsi ON tsi.id = wr.task_schedule_item_id \
                 WHERE fc.cultivation_plan_id = ?1 \
                   AND wr.gdd_at_actual IS NOT NULL \
                 ORDER BY wr.actual_date DESC",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, Option<String>>(1)?,
                    row.get::<_, Option<f64>>(2)?,
                    row.get::<_, Option<f64>>(3)?,
                ))
            })?;
            let mut samples = Vec::new();
            for row in rows {
                let (field_cultivation_id, actual_date_raw, gdd_actual, gdd_trigger) = row?;
                let Some(actual_date_raw) = actual_date_raw else {
                    continue;
                };
                let Some(reference_date) = parse_iso_date(&actual_date_raw) else {
                    continue;
                };
                let Some(cumulative_gdd_actual) = gdd_actual else {
                    continue;
                };
                let cumulative_gdd_planned = gdd_trigger.unwrap_or(cumulative_gdd_actual);
                samples.push(GddTrajectorySample {
                    field_cultivation_id,
                    reference_date,
                    cumulative_gdd_actual,
                    cumulative_gdd_planned,
                });
            }
            Ok::<_, rusqlite::Error>(samples)
        })?;

        let payload = self
            .predicted_weather_store
            .read_payload(PredictedWeatherScope::Plan, plan_id)?
            .unwrap_or_else(|| Value::Object(Default::default()));
        let current_forecast = forecast_days_from_payload(&payload);

        Ok(WeatherRescheduleProposalContext {
            tasks,
            current_forecast,
            previous_forecast: Vec::new(),
            gdd_samples,
            cultivations,
        })
    }
}
