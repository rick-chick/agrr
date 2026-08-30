//! Ruby: `WorkRecordActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::shared::exceptions::{RecordNotFoundError, RecordStaleUpdateError};
use crate::soft_delete::{schedule_soft_delete_json, SoftDeleteJsonOutcome};
use agrr_domain::cultivation_plan::helpers::parse_iso_date;
use agrr_domain::work_record::dtos::{
    WorkRecordListInput, WorkRecordRead, WorkRecordTaskScheduleItemSummary, WorkRecordUpdateInput,
};
use agrr_domain::work_record::gateways::{
    WorkRecordCreatePersistAttrs, WorkRecordDestroyGatewayOutcome, WorkRecordGateway,
};
use rusqlite::{params, types::Value};
use rust_decimal::Decimal;
use serde_json::Value as JsonValue;
use std::str::FromStr;
use time::{format_description::well_known::Iso8601, Date, OffsetDateTime, PrimitiveDateTime};

pub struct WorkRecordSqliteGateway {
    pool: SqlitePool,
}

impl WorkRecordSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    const SELECT_COLUMNS: &'static str = "wr.id, wr.cultivation_plan_id, wr.field_cultivation_id, \
         wr.task_schedule_item_id, wr.agricultural_task_id, wr.fertilize_id, wr.pesticide_id, \
         wr.name, wr.task_type, wr.actual_date, \
         CAST(wr.amount AS TEXT), wr.amount_unit, wr.time_spent_minutes, wr.notes, \
         wr.gdd_at_actual, wr.weather_snapshot, \
         wr.created_at, wr.updated_at, \
         NULLIF(TRIM(COALESCE(cpf.name, '')), ''), \
         NULLIF(TRIM(COALESCE(cpc.name, cr.name, '')), ''), \
         tsi.id, tsi.name, tsi.scheduled_date";

    const FROM_JOIN: &'static str = " FROM work_records wr \
         LEFT JOIN field_cultivations fc ON fc.id = wr.field_cultivation_id \
         LEFT JOIN cultivation_plan_fields cpf ON cpf.id = fc.cultivation_plan_field_id \
         LEFT JOIN cultivation_plan_crops cpc ON cpc.id = fc.cultivation_plan_crop_id \
         LEFT JOIN crops cr ON cr.id = cpc.crop_id \
         LEFT JOIN task_schedule_items tsi ON tsi.id = wr.task_schedule_item_id";

    fn parse_stored_datetime(s: &str) -> Option<OffsetDateTime> {
        if let Ok(dt) = OffsetDateTime::parse(s, &Iso8601::DEFAULT) {
            return Some(dt);
        }
        const SQLITE_FORMATS: &[&[time::format_description::FormatItem<'_>]] = &[
            time::macros::format_description!("[year]-[month]-[day] [hour]:[minute]:[second]"),
            time::macros::format_description!(
                "[year]-[month]-[day] [hour]:[minute]:[second].[subsecond]"
            ),
        ];
        for format in SQLITE_FORMATS {
            if let Ok(dt) = PrimitiveDateTime::parse(s, format) {
                return Some(dt.assume_utc());
            }
        }
        None
    }

    fn parse_datetime(s: &str) -> OffsetDateTime {
        Self::parse_stored_datetime(s).unwrap_or(OffsetDateTime::UNIX_EPOCH)
    }

    fn updated_at_tokens_match(stored_raw: &str, client_token: &str) -> bool {
        if stored_raw == client_token {
            return true;
        }
        match (
            Self::parse_stored_datetime(stored_raw),
            Self::parse_stored_datetime(client_token),
        ) {
            (Some(stored), Some(client)) => stored == client,
            _ => false,
        }
    }

    fn parse_decimal(raw: Option<String>) -> Option<Decimal> {
        raw.and_then(|s| Decimal::from_str(&s).ok())
    }

    fn parse_weather_snapshot(raw: Option<String>) -> Option<JsonValue> {
        raw.and_then(|s| serde_json::from_str(&s).ok())
    }

    fn row_to_read(row: &rusqlite::Row<'_>) -> rusqlite::Result<WorkRecordRead> {
        let actual_date_raw: String = row.get(9)?;
        let actual_date = parse_iso_date(&actual_date_raw).ok_or_else(|| {
            rusqlite::Error::InvalidColumnType(
                9,
                "actual_date".into(),
                rusqlite::types::Type::Text,
            )
        })?;
        let created_at = Self::parse_datetime(&row.get::<_, String>(16)?);
        let updated_at = Self::parse_datetime(&row.get::<_, String>(17)?);
        let field_name: Option<String> = row.get(18)?;
        let crop_name: Option<String> = row.get(19)?;
        let item_id: Option<i64> = row.get(20)?;
        let task_schedule_item = item_id.map(|id| {
            let scheduled_date_raw: Option<String> = row.get(22).unwrap_or(None);
            WorkRecordTaskScheduleItemSummary {
                id,
                name: row.get(21).unwrap_or_default(),
                scheduled_date: scheduled_date_raw.as_deref().and_then(parse_iso_date),
            }
        });
        Ok(WorkRecordRead {
            id: row.get(0)?,
            cultivation_plan_id: row.get(1)?,
            field_cultivation_id: row.get(2)?,
            task_schedule_item_id: row.get(3)?,
            agricultural_task_id: row.get(4)?,
            fertilize_id: row.get(5)?,
            pesticide_id: row.get(6)?,
            name: row.get(7)?,
            task_type: row.get(8)?,
            actual_date,
            amount: Self::parse_decimal(row.get(10)?),
            amount_unit: row.get(11)?,
            time_spent_minutes: row.get(12)?,
            notes: row.get(13)?,
            gdd_at_actual: row.get(14)?,
            weather_snapshot: Self::parse_weather_snapshot(row.get(15)?),
            created_at,
            updated_at,
            field_name,
            crop_name,
            task_schedule_item,
        })
    }

    fn load_read(
        conn: &rusqlite::Connection,
        plan_id: i64,
        record_id: i64,
    ) -> rusqlite::Result<WorkRecordRead> {
        let sql = format!(
            "SELECT {} \
             {} \
             WHERE wr.cultivation_plan_id = ?1 AND wr.id = ?2 \
             LIMIT 1",
            Self::SELECT_COLUMNS,
            Self::FROM_JOIN
        );
        conn.query_row(&sql, params![plan_id, record_id], Self::row_to_read)
    }

    fn format_date(date: Date) -> String {
        date.format(&Iso8601::DATE)
            .unwrap_or_else(|_| date.to_string())
    }

    fn format_datetime(dt: OffsetDateTime) -> String {
        dt.format(&Iso8601::DEFAULT)
            .unwrap_or_else(|_| dt.to_string())
    }
}

impl WorkRecordGateway for WorkRecordSqliteGateway {
    fn create(
        &self,
        plan_id: i64,
        attrs: WorkRecordCreatePersistAttrs,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO work_records (\
                 cultivation_plan_id, field_cultivation_id, task_schedule_item_id, \
                 agricultural_task_id, fertilize_id, pesticide_id, name, task_type, actual_date, \
                 amount, amount_unit, time_spent_minutes, notes, gdd_at_actual, weather_snapshot, \
                 created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17)",
                params![
                    plan_id,
                    attrs.field_cultivation_id,
                    attrs.task_schedule_item_id,
                    attrs.agricultural_task_id,
                    attrs.fertilize_id,
                    attrs.pesticide_id,
                    attrs.name,
                    attrs.task_type,
                    Self::format_date(attrs.actual_date),
                    attrs.amount.map(|d| d.to_string()),
                    attrs.amount_unit,
                    attrs.time_spent_minutes,
                    attrs.notes,
                    attrs.gdd_at_actual,
                    attrs
                        .weather_snapshot
                        .as_ref()
                        .map(|v| v.to_string()),
                    Self::format_datetime(attrs.created_at),
                    Self::format_datetime(attrs.updated_at),
                ],
            )?;
            let id = conn.last_insert_rowid();
            Self::load_read(conn, plan_id, id)
        })
    }

    fn list_for_plan(
        &self,
        plan_id: i64,
        filter: &WorkRecordListInput,
    ) -> Result<Vec<WorkRecordRead>, Box<dyn std::error::Error + Send + Sync>> {
        let mut sql = format!(
            "SELECT {} \
             {} \
             WHERE wr.cultivation_plan_id = ?1",
            Self::SELECT_COLUMNS,
            Self::FROM_JOIN
        );
        let mut values: Vec<Value> = vec![Value::from(plan_id)];

        if let Some(from) = filter.from {
            sql.push_str(&format!(" AND wr.actual_date >= ?{}", values.len() + 1));
            values.push(Value::Text(Self::format_date(from)));
        }
        if let Some(to) = filter.to {
            sql.push_str(&format!(" AND wr.actual_date <= ?{}", values.len() + 1));
            values.push(Value::Text(Self::format_date(to)));
        }
        if let Some(fc_id) = filter.field_cultivation_id {
            sql.push_str(&format!(
                " AND wr.field_cultivation_id = ?{}",
                values.len() + 1
            ));
            values.push(Value::from(fc_id));
        }
        sql.push_str(" ORDER BY wr.actual_date DESC, wr.id DESC");

        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(&sql)?;
            let rows = stmt.query_map(rusqlite::params_from_iter(values.iter()), Self::row_to_read)?;
            rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
        })
    }

    fn find_for_plan(
        &self,
        plan_id: i64,
        record_id: i64,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_read_box(|conn| Self::load_read(conn, plan_id, record_id))
    }

    fn update(
        &self,
        plan_id: i64,
        record_id: i64,
        input: &WorkRecordUpdateInput,
        climate: Option<&agrr_domain::work_record::gateways::WorkRecordClimatePersistFields>,
        updated_at: OffsetDateTime,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>> {
        let mut sets = vec!["updated_at = ?1".to_string()];
        let mut values: Vec<Value> = vec![Value::Text(Self::format_datetime(updated_at))];

        if let Some(name) = &input.name {
            sets.push(format!("name = ?{}", values.len() + 1));
            values.push(Value::Text(name.clone()));
        }
        if let Some(date) = input.actual_date {
            sets.push(format!("actual_date = ?{}", values.len() + 1));
            values.push(Value::Text(Self::format_date(date)));
        }
        if let Some(amount) = &input.amount {
            sets.push(format!("amount = ?{}", values.len() + 1));
            values.push(Value::Text(amount.to_string()));
        }
        if let Some(unit) = &input.amount_unit {
            sets.push(format!("amount_unit = ?{}", values.len() + 1));
            values.push(Value::Text(unit.clone()));
        }
        if let Some(minutes) = input.time_spent_minutes {
            sets.push(format!("time_spent_minutes = ?{}", values.len() + 1));
            values.push(Value::from(minutes));
        }
        if let Some(notes) = &input.notes {
            sets.push(format!("notes = ?{}", values.len() + 1));
            values.push(Value::Text(notes.clone()));
        }
        if let Some(fertilize_id) = &input.fertilize_id {
            sets.push(format!("fertilize_id = ?{}", values.len() + 1));
            values.push(match fertilize_id {
                Some(id) => Value::from(*id),
                None => Value::Null,
            });
        }
        if let Some(pesticide_id) = &input.pesticide_id {
            sets.push(format!("pesticide_id = ?{}", values.len() + 1));
            values.push(match pesticide_id {
                Some(id) => Value::from(*id),
                None => Value::Null,
            });
        }
        if let Some(climate) = climate {
            sets.push(format!("gdd_at_actual = ?{}", values.len() + 1));
            values.push(match climate.gdd_at_actual {
                Some(v) => Value::Real(v),
                None => Value::Null,
            });
            sets.push(format!("weather_snapshot = ?{}", values.len() + 1));
            values.push(match &climate.weather_snapshot {
                Some(v) => Value::Text(v.to_string()),
                None => Value::Null,
            });
        }

        let expected_updated_at = input
            .expected_updated_at
            .as_deref()
            .expect("validated by interactor");

        let plan_id_param = plan_id;
        let record_id_param = record_id;
        let expected_token = expected_updated_at.to_string();

        self.pool
            .with_write_transaction(|conn| -> rusqlite::Result<Option<WorkRecordRead>> {
                let stored_raw: String = match conn.query_row(
                    "SELECT updated_at FROM work_records WHERE cultivation_plan_id = ?1 AND id = ?2",
                    params![plan_id_param, record_id_param],
                    |row| row.get(0),
                ) {
                    Ok(raw) => raw,
                    Err(rusqlite::Error::QueryReturnedNoRows) => return Ok(None),
                    Err(err) => return Err(err),
                };

                if !Self::updated_at_tokens_match(&stored_raw, &expected_token) {
                    return Ok(None);
                }

                let sql = format!(
                    "UPDATE work_records SET {} WHERE cultivation_plan_id = ?{} AND id = ?{} AND updated_at = ?{}",
                    sets.join(", "),
                    values.len() + 1,
                    values.len() + 2,
                    values.len() + 3,
                );
                values.push(Value::from(plan_id_param));
                values.push(Value::from(record_id_param));
                values.push(Value::Text(stored_raw));

                let affected = conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
                if affected > 0 {
                    return Ok(Some(Self::load_read(conn, plan_id_param, record_id_param)?));
                }
                Ok(None)
            })
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
        .and_then(|maybe_record| match maybe_record {
            Some(record) => Ok(record),
            None => {
                let exists = self.pool.with_read(|conn| {
                    conn.query_row(
                        "SELECT 1 FROM work_records WHERE cultivation_plan_id = ?1 AND id = ?2 LIMIT 1",
                        params![plan_id, record_id],
                        |_| Ok(true),
                    )
                }).is_ok();
                if exists {
                    Err(RecordStaleUpdateError.into())
                } else {
                    Err(RecordNotFoundError.into())
                }
            }
        })
    }

    fn destroy(
        &self,
        _plan_id: i64,
        record_id: i64,
        actor_id: i64,
        toast_message: &str,
    ) -> Result<WorkRecordDestroyGatewayOutcome, Box<dyn std::error::Error + Send + Sync>> {
        match schedule_soft_delete_json(
            self.pool.clone(),
            "WorkRecord",
            record_id,
            actor_id,
            toast_message,
            5000,
            None,
        ) {
            SoftDeleteJsonOutcome::Success(body) => {
                Ok(WorkRecordDestroyGatewayOutcome::Success { undo: body })
            }
            SoftDeleteJsonOutcome::Failure(error) => {
                Ok(WorkRecordDestroyGatewayOutcome::Failure(error))
            }
        }
    }
}

#[cfg(test)]
mod work_record_updated_at_token_tests {
    use super::WorkRecordSqliteGateway;

    #[test]
    fn parse_stored_datetime_accepts_iso8601_and_sqlite_formats() {
        let iso = "2026-06-12T10:00:00Z";
        let sqlite = "2026-06-12 10:00:00";
        let sqlite_subsec = "2026-06-12 10:00:00.123";

        assert!(WorkRecordSqliteGateway::parse_stored_datetime(iso).is_some());
        assert!(WorkRecordSqliteGateway::parse_stored_datetime(sqlite).is_some());
        assert!(WorkRecordSqliteGateway::parse_stored_datetime(sqlite_subsec).is_some());
    }

    #[test]
    fn parse_stored_datetime_rejects_garbage() {
        assert!(WorkRecordSqliteGateway::parse_stored_datetime("not-a-date").is_none());
    }

    #[test]
    fn updated_at_tokens_match_exact_strings() {
        let token = "2026-06-12T10:00:00Z";
        assert!(WorkRecordSqliteGateway::updated_at_tokens_match(token, token));
    }

    #[test]
    fn updated_at_tokens_match_iso_client_token_to_sqlite_stored_value() {
        assert!(WorkRecordSqliteGateway::updated_at_tokens_match(
            "2026-06-12 10:00:00",
            "2026-06-12T10:00:00Z"
        ));
    }

    #[test]
    fn updated_at_tokens_match_sqlite_subsecond_to_iso_without_fraction() {
        assert!(WorkRecordSqliteGateway::updated_at_tokens_match(
            "2026-06-12 10:00:00.500",
            "2026-06-12T10:00:00.500Z"
        ));
    }

    #[test]
    fn updated_at_tokens_reject_different_timestamps() {
        assert!(!WorkRecordSqliteGateway::updated_at_tokens_match(
            "2026-06-12 10:00:00",
            "2026-06-12T10:00:01Z"
        ));
    }

    #[test]
    fn updated_at_tokens_reject_when_either_side_unparseable() {
        assert!(!WorkRecordSqliteGateway::updated_at_tokens_match(
            "not-a-date",
            "2026-06-12T10:00:00Z"
        ));
        assert!(!WorkRecordSqliteGateway::updated_at_tokens_match(
            "2026-06-12 10:00:00",
            "still-not-a-date"
        ));
    }
}
