//! Ruby: `WorkRecordActiveRecordGateway`

use crate::pool::SqlitePool;
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
use std::str::FromStr;
use time::{format_description::well_known::Iso8601, Date, OffsetDateTime};

pub struct WorkRecordSqliteGateway {
    pool: SqlitePool,
}

impl WorkRecordSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    const SELECT_COLUMNS: &'static str = "wr.id, wr.cultivation_plan_id, wr.field_cultivation_id, \
         wr.task_schedule_item_id, wr.agricultural_task_id, wr.name, wr.task_type, wr.actual_date, \
         CAST(wr.amount AS TEXT), wr.amount_unit, wr.time_spent_minutes, wr.notes, \
         wr.created_at, wr.updated_at, tsi.id, tsi.name, tsi.scheduled_date";

    fn parse_datetime(s: &str) -> OffsetDateTime {
        OffsetDateTime::parse(s, &Iso8601::DEFAULT).unwrap_or_else(|_| OffsetDateTime::now_utc())
    }

    fn parse_decimal(raw: Option<String>) -> Option<Decimal> {
        raw.and_then(|s| Decimal::from_str(&s).ok())
    }

    fn row_to_read(row: &rusqlite::Row<'_>) -> rusqlite::Result<WorkRecordRead> {
        let actual_date_raw: String = row.get(7)?;
        let actual_date = parse_iso_date(&actual_date_raw).ok_or_else(|| {
            rusqlite::Error::InvalidColumnType(
                7,
                "actual_date".into(),
                rusqlite::types::Type::Text,
            )
        })?;
        let created_at = Self::parse_datetime(&row.get::<_, String>(12)?);
        let updated_at = Self::parse_datetime(&row.get::<_, String>(13)?);
        let item_id: Option<i64> = row.get(14)?;
        let task_schedule_item = item_id.map(|id| {
            let scheduled_date_raw: Option<String> = row.get(16).unwrap_or(None);
            WorkRecordTaskScheduleItemSummary {
                id,
                name: row.get(15).unwrap_or_default(),
                scheduled_date: scheduled_date_raw.as_deref().and_then(parse_iso_date),
            }
        });
        Ok(WorkRecordRead {
            id: row.get(0)?,
            cultivation_plan_id: row.get(1)?,
            field_cultivation_id: row.get(2)?,
            task_schedule_item_id: row.get(3)?,
            agricultural_task_id: row.get(4)?,
            name: row.get(5)?,
            task_type: row.get(6)?,
            actual_date,
            amount: Self::parse_decimal(row.get(8)?),
            amount_unit: row.get(9)?,
            time_spent_minutes: row.get(10)?,
            notes: row.get(11)?,
            created_at,
            updated_at,
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
             FROM work_records wr \
             LEFT JOIN task_schedule_items tsi ON tsi.id = wr.task_schedule_item_id \
             WHERE wr.cultivation_plan_id = ?1 AND wr.id = ?2 \
             LIMIT 1",
            Self::SELECT_COLUMNS
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
                 agricultural_task_id, name, task_type, actual_date, amount, amount_unit, \
                 time_spent_minutes, notes, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
                params![
                    plan_id,
                    attrs.field_cultivation_id,
                    attrs.task_schedule_item_id,
                    attrs.agricultural_task_id,
                    attrs.name,
                    attrs.task_type,
                    Self::format_date(attrs.actual_date),
                    attrs.amount.map(|d| d.to_string()),
                    attrs.amount_unit,
                    attrs.time_spent_minutes,
                    attrs.notes,
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
             FROM work_records wr \
             LEFT JOIN task_schedule_items tsi ON tsi.id = wr.task_schedule_item_id \
             WHERE wr.cultivation_plan_id = ?1",
            Self::SELECT_COLUMNS
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

        let sql = format!(
            "UPDATE work_records SET {} WHERE cultivation_plan_id = ?{} AND id = ?{}",
            sets.join(", "),
            values.len() + 1,
            values.len() + 2,
        );
        values.push(Value::from(plan_id));
        values.push(Value::from(record_id));

        self.pool.with_write_box(|conn| {
            let affected = conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
            if affected == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Self::load_read(conn, plan_id, record_id)
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
