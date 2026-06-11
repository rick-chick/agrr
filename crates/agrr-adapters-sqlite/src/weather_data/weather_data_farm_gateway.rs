//! Farm gateway slice for `FetchWeatherDataPerformInteractor`.

use crate::pool::SqlitePool;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use agrr_domain::weather_data::dtos::FarmWeatherDataAccessContext;
use agrr_domain::weather_data::gateways::{FetchWeatherFarmEntity, WeatherDataFarmGateway};
use rusqlite::params;

pub struct WeatherDataFarmSqliteGateway {
    pool: SqlitePool,
}

impl WeatherDataFarmSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn context_from_farm_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<FarmWeatherDataAccessContext> {
    Ok(FarmWeatherDataAccessContext {
        farm_id: row.get(0)?,
        display_name: row.get::<_, String>(1)?,
        latitude: row.get(2)?,
        longitude: row.get(3)?,
        weather_location_id: row.get(4)?,
    })
}

impl WeatherDataFarmGateway for WeatherDataFarmSqliteGateway {
    fn farm_weather_data_access_context_for_owned_farm(
        &self,
        user_id: i64,
        farm_id: i64,
    ) -> Option<FarmWeatherDataAccessContext> {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT id, name, latitude, longitude, weather_location_id \
                     FROM farms WHERE id = ?1 AND user_id = ?2",
                    params![farm_id, user_id],
                    context_from_farm_row,
                )
            })
            .ok()
    }

    fn farm_weather_data_access_context_for_admin_lookup(
        &self,
        farm_id: i64,
    ) -> Option<FarmWeatherDataAccessContext> {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT id, name, latitude, longitude, weather_location_id \
                     FROM farms WHERE id = ?1",
                    params![farm_id],
                    context_from_farm_row,
                )
            })
            .ok()
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
