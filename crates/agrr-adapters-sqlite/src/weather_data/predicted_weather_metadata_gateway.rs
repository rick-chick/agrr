//! SQLite metadata for predicted weather cache.

use crate::pool::SqlitePool;
use agrr_domain::weather_data::dtos::{PredictedWeatherMetadata, PredictedWeatherScope};
use agrr_domain::weather_data::gateways::PredictedWeatherMetadataGateway;
use agrr_domain::weather_data::helpers::parse_iso_date;
use rusqlite::{params, OptionalExtension};
use time::Date;

pub struct PredictedWeatherMetadataSqliteGateway {
    pool: SqlitePool,
}

impl PredictedWeatherMetadataSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn parse_ymd(s: &str) -> Option<Date> {
    parse_iso_date(s)
}

impl PredictedWeatherMetadataGateway for PredictedWeatherMetadataSqliteGateway {
    fn find(
        &self,
        scope: PredictedWeatherScope,
        scope_id: i64,
    ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let row = conn
                .query_row(
                    "SELECT prediction_start_date, prediction_end_date, target_end_date, data_end_date, generated_at \
                     FROM predicted_weather_metadata WHERE scope = ?1 AND scope_id = ?2",
                    params![scope.as_str(), scope_id],
                    |row| {
                        let start: String = row.get(0)?;
                        let end: String = row.get(1)?;
                        let target: String = row.get(2)?;
                        let data_end: String = row.get(3)?;
                        let generated_at: String = row.get(4)?;
                        Ok(PredictedWeatherMetadata {
                            scope,
                            scope_id,
                            prediction_start_date: parse_ymd(&start).ok_or_else(|| {
                                rusqlite::Error::InvalidColumnType(
                                    0,
                                    "prediction_start_date".into(),
                                    rusqlite::types::Type::Text,
                                )
                            })?,
                            prediction_end_date: parse_ymd(&end).ok_or_else(|| {
                                rusqlite::Error::InvalidColumnType(
                                    1,
                                    "prediction_end_date".into(),
                                    rusqlite::types::Type::Text,
                                )
                            })?,
                            target_end_date: parse_ymd(&target).ok_or_else(|| {
                                rusqlite::Error::InvalidColumnType(
                                    2,
                                    "target_end_date".into(),
                                    rusqlite::types::Type::Text,
                                )
                            })?,
                            data_end_date: parse_ymd(&data_end).ok_or_else(|| {
                                rusqlite::Error::InvalidColumnType(
                                    3,
                                    "data_end_date".into(),
                                    rusqlite::types::Type::Text,
                                )
                            })?,
                            generated_at,
                        })
                    },
                )
                .optional()?;
            Ok(row)
        })
    }

    fn upsert(
        &self,
        metadata: &PredictedWeatherMetadata,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO predicted_weather_metadata \
                 (scope, scope_id, prediction_start_date, prediction_end_date, target_end_date, data_end_date, generated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7) \
                 ON CONFLICT(scope, scope_id) DO UPDATE SET \
                 prediction_start_date = excluded.prediction_start_date, \
                 prediction_end_date = excluded.prediction_end_date, \
                 target_end_date = excluded.target_end_date, \
                 data_end_date = excluded.data_end_date, \
                 generated_at = excluded.generated_at",
                params![
                    metadata.scope.as_str(),
                    metadata.scope_id,
                    metadata.prediction_start_date.to_string(),
                    metadata.prediction_end_date.to_string(),
                    metadata.target_end_date.to_string(),
                    metadata.data_end_date.to_string(),
                    metadata.generated_at,
                ],
            )?;
            Ok(())
        })
    }

    fn copy_plan_metadata(
        &self,
        from_plan_id: i64,
        to_plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO predicted_weather_metadata \
                 (scope, scope_id, prediction_start_date, prediction_end_date, target_end_date, data_end_date, generated_at) \
                 SELECT scope, ?2, prediction_start_date, prediction_end_date, target_end_date, data_end_date, generated_at \
                 FROM predicted_weather_metadata WHERE scope = 'plan' AND scope_id = ?1 \
                 ON CONFLICT(scope, scope_id) DO UPDATE SET \
                 prediction_start_date = excluded.prediction_start_date, \
                 prediction_end_date = excluded.prediction_end_date, \
                 target_end_date = excluded.target_end_date, \
                 data_end_date = excluded.data_end_date, \
                 generated_at = excluded.generated_at",
                params![from_plan_id, to_plan_id],
            )?;
            Ok(())
        })
    }
}
