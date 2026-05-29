//! Persist predicted weather on `cultivation_plans`.

use crate::pool::SqlitePool;
use agrr_domain::field_cultivation::gateways::FieldCultivationPlanPredictedWeatherGateway;
use rusqlite::params;
use serde_json::Value;

pub struct FieldCultivationPlanPredictedWeatherSqliteGateway {
    pool: SqlitePool,
}

impl FieldCultivationPlanPredictedWeatherSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl FieldCultivationPlanPredictedWeatherGateway for FieldCultivationPlanPredictedWeatherSqliteGateway {
    fn update_predicted_weather_data(
        &self,
        plan_id: i64,
        weather_payload: Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let json = serde_json::to_string(&weather_payload)?;
        self.pool.with_write_box(|conn| {
            conn.execute(
                "UPDATE cultivation_plans SET predicted_weather_data = ?1, updated_at = datetime('now') WHERE id = ?2",
                params![json, plan_id],
            )?;
            Ok(())
        })
    }
}
