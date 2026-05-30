//! Farm gateway slice for `FetchWeatherDataPerformInteractor`.

use crate::pool::SqlitePool;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use agrr_domain::weather_data::dtos::FarmWeatherDataAccessContext;
use agrr_domain::weather_data::gateways::{FetchWeatherFarmEntity, WeatherDataFarmGateway};
use rusqlite::params;
use serde_json::Value;

pub struct WeatherDataFarmSqliteGateway {
    pool: SqlitePool,
}

impl WeatherDataFarmSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl WeatherDataFarmGateway for WeatherDataFarmSqliteGateway {
    fn farm_weather_data_access_context_for_owned_farm(
        &self,
        _user_id: i64,
        _farm_id: i64,
    ) -> Option<FarmWeatherDataAccessContext> {
        None
    }

    fn farm_weather_data_access_context_for_admin_lookup(
        &self,
        _farm_id: i64,
    ) -> Option<FarmWeatherDataAccessContext> {
        None
    }

    fn update_predicted_weather_data(
        &self,
        _farm_id: i64,
        _payload: Option<Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }

    fn find_by_id(
        &self,
        farm_id: i64,
    ) -> Result<FetchWeatherFarmEntity, RecordNotFoundError> {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT region FROM farms WHERE id = ?1",
                    params![farm_id],
                    |row| {
                        Ok(FetchWeatherFarmEntity {
                            region: row.get(0)?,
                        })
                    },
                )
            })
            .map_err(|_| RecordNotFoundError)
    }

    fn update_weather_location_id(
        &self,
        farm_id: i64,
        weather_location_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write(|conn| {
            conn.execute(
                "UPDATE farms SET weather_location_id = ?1, updated_at = datetime('now') WHERE id = ?2",
                params![weather_location_id, farm_id],
            )?;
            Ok(())
        })?;
        Ok(())
    }
}
