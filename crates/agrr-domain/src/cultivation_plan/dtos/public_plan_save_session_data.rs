//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveSessionData`

use std::collections::BTreeMap;

use serde_json::Value;
use time::OffsetDateTime;

use super::public_plan_save_field_datum::PublicPlanSaveFieldDatum;

/// Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveSessionData`
#[derive(Debug, Clone)]
pub struct PublicPlanSaveSessionData {
    pub plan_id: i64,
    pub farm_id: Option<i64>,
    pub field_data: Vec<PublicPlanSaveFieldDatum>,
    pub created_at: Option<OffsetDateTime>,
}

impl PublicPlanSaveSessionData {
    pub fn new(
        plan_id: i64,
        farm_id: Option<i64>,
        field_data: Vec<PublicPlanSaveFieldDatum>,
        created_at: Option<OffsetDateTime>,
    ) -> Self {
        Self {
            plan_id,
            farm_id,
            field_data,
            created_at,
        }
    }

    pub fn from_session_hash(h: Option<&BTreeMap<String, Value>>) -> Option<Self> {
        let h = h?;
        let plan_id = fetch_key(h, "plan_id")?;
        if missing_plan_id(plan_id) {
            return None;
        }
        let plan_id = plan_id.as_i64().or_else(|| plan_id.as_str()?.parse().ok())?;
        let farm_id = fetch_key(h, "farm_id").and_then(|v| v.as_i64());
        let field_data = fetch_key(h, "field_data")
            .map(|v| match v {
                Value::Array(rows) => rows
                    .iter()
                    .filter_map(PublicPlanSaveFieldDatum::from_row)
                    .collect(),
                _ => vec![],
            })
            .unwrap_or_default();
        let created_at = fetch_key(h, "created_at").and_then(parse_created_at);
        Some(Self::new(plan_id, farm_id, field_data, created_at))
    }

    pub fn to_session_hash(&self) -> BTreeMap<String, Value> {
        let mut map = BTreeMap::from([
            ("plan_id".into(), Value::from(self.plan_id)),
            (
                "field_data".into(),
                Value::Array(
                    self.field_data
                        .iter()
                        .map(|row| {
                            Value::Object(
                                row.to_session_row().into_iter().collect(),
                            )
                        })
                        .collect(),
                ),
            ),
        ]);
        if let Some(farm_id) = self.farm_id {
            map.insert("farm_id".into(), Value::from(farm_id));
        }
        if let Some(created_at) = self.created_at {
            map.insert(
                "created_at".into(),
                Value::Number(created_at.unix_timestamp().into()),
            );
        }
        map
    }
}

fn fetch_key<'a>(h: &'a BTreeMap<String, Value>, key: &str) -> Option<&'a Value> {
    h.get(key)
}

fn missing_plan_id(plan_id: &Value) -> bool {
    match plan_id {
        Value::Null => true,
        Value::String(s) => s.trim().is_empty(),
        _ => false,
    }
}

fn parse_created_at(value: &Value) -> Option<OffsetDateTime> {
    match value {
        Value::Null => None,
        Value::String(s) if s.trim().is_empty() => None,
        Value::String(s) => parse_created_at_string(s),
        _ => None,
    }
}

fn parse_created_at_string(s: &str) -> Option<OffsetDateTime> {
    if let Ok(ts) = s.parse::<i64>() {
        return OffsetDateTime::from_unix_timestamp(ts).ok();
    }
    crate::cultivation_plan::helpers::parse_iso_date(s)
        .and_then(|d| d.with_hms(0, 0, 0).ok())
        .map(|t| t.assume_utc())
}

#[cfg(test)]
mod dtos_public_plan_save_session_data_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/dtos_public_plan_save_session_data_test.rs"));
}
