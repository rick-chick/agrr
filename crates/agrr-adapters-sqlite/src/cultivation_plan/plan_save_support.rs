//! Shared helpers for plan-save SQLite gateways.

use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::shared::ports::{ClockPort, LoggerPort, TranslateOptions, TranslatorPort};
use rusqlite::Connection;
use time::OffsetDateTime;

use crate::shared::attr_sql::{quote_sql_column, sql_value_from_attr};

pub(crate) trait OptionalRow<T> {
    fn optional(self) -> Result<Option<T>, rusqlite::Error>;
}

impl<T> OptionalRow<T> for Result<T, rusqlite::Error> {
    fn optional(self) -> Result<Option<T>, rusqlite::Error> {
        match self {
            Ok(v) => Ok(Some(v)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}

pub(crate) struct PlanSaveNoopLogger;

impl agrr_domain::cultivation_plan::calculators::planning_date_calculator::PlanningDateLogger
    for PlanSaveNoopLogger
{
    fn info(&self, _message: &str) {}
    fn debug(&self, _message: &str) {}
}

impl LoggerPort for PlanSaveNoopLogger {
    fn info(&self, _message: &str) {}
    fn warn(&self, _message: &str) {}
    fn error(&self, _message: &str) {}
    fn debug(&self, _message: &str) {}
}

pub(crate) struct PlanSavePassthroughTranslator;
impl TranslatorPort for PlanSavePassthroughTranslator {
    fn translate(&self, key: &str, _options: &TranslateOptions) -> String {
        key.to_string()
    }

    fn localize(
        &self,
        date: time::Date,
        _format: Option<&str>,
        _options: &TranslateOptions,
    ) -> String {
        date.to_string()
    }
}

pub(crate) struct PlanSaveClock;
impl ClockPort for PlanSaveClock {
    fn today(&self) -> time::Date {
        OffsetDateTime::now_utc().date()
    }

    fn now(&self) -> OffsetDateTime {
        OffsetDateTime::now_utc()
    }
}

pub(crate) fn insert_from_attr_map(
    conn: &Connection,
    table: &str,
    attrs: &AttrMap,
) -> Result<i64, rusqlite::Error> {
    let mut cols: Vec<&str> = attrs.keys().map(String::as_str).collect();
    cols.sort_unstable();
    if cols.is_empty() {
        return Err(rusqlite::Error::InvalidParameterName(
            "empty attributes".into(),
        ));
    }
    let placeholders: Vec<_> = (0..cols.len()).map(|_| "?").collect();
    let quoted_cols: Vec<String> = cols
        .iter()
        .map(|c| quote_sql_column(c).into_owned())
        .collect();
    let sql = format!(
        "INSERT INTO {table} ({}, created_at, updated_at) VALUES ({}, datetime('now'), datetime('now'))",
        quoted_cols.join(", "),
        placeholders.join(", ")
    );
    let values: Vec<_> = cols
        .iter()
        .map(|k| sql_value_from_attr(attrs.get(*k).unwrap_or(&AttrValue::Null)))
        .collect();
    conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
    Ok(conn.last_insert_rowid())
}

pub(crate) fn update_from_attr_map(
    conn: &Connection,
    table: &str,
    id: i64,
    attrs: &AttrMap,
) -> Result<(), rusqlite::Error> {
    if attrs.is_empty() {
        return Ok(());
    }
    let mut cols: Vec<&str> = attrs.keys().map(String::as_str).collect();
    cols.sort_unstable();
    let set_clause: String = cols
        .iter()
        .map(|c| format!("{} = ?", quote_sql_column(c)))
        .chain(std::iter::once("updated_at = datetime('now')".to_string()))
        .collect::<Vec<_>>()
        .join(", ");
    let sql = format!("UPDATE {table} SET {set_clause} WHERE id = ?");
    let mut values: Vec<_> = cols
        .iter()
        .map(|k| sql_value_from_attr(attrs.get(*k).unwrap_or(&AttrValue::Null)))
        .collect();
    values.push(rusqlite::types::Value::Integer(id));
    conn.execute(&sql, rusqlite::params_from_iter(values.iter()))?;
    Ok(())
}

pub(crate) fn insert_child_from_attr_map(
    conn: &Connection,
    table: &str,
    parent_col: &str,
    parent_id: i64,
    attrs: &AttrMap,
) -> Result<(), rusqlite::Error> {
    let mut merged = attrs.clone();
    merged.insert(parent_col.to_string(), AttrValue::Int(parent_id));
    let _ = insert_from_attr_map(conn, table, &merged)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::shared::attr::AttrValue;

    #[test]
    fn insert_from_attr_map_quotes_order_column() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(
            "CREATE TABLE pests (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                \"order\" TEXT,
                is_reference INTEGER NOT NULL DEFAULT 0,
                created_at TEXT,
                updated_at TEXT
            );",
        )
        .unwrap();

        let mut attrs = AttrMap::new();
        attrs.insert("name".into(), AttrValue::Str("Testoptera".into()));
        attrs.insert("order".into(), AttrValue::Str("Hemiptera".into()));
        attrs.insert("is_reference".into(), AttrValue::Bool(false));

        let id = insert_from_attr_map(&conn, "pests", &attrs).unwrap();
        let order: String = conn
            .query_row(
                "SELECT \"order\" FROM pests WHERE id = ?1",
                [id],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(order, "Hemiptera");
    }
}
