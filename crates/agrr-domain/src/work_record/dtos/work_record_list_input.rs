//! Ruby: `Domain::WorkRecord::Dtos::WorkRecordListInput`

use std::collections::BTreeMap;

use time::Date;

use crate::shared::exceptions::RecordInvalidError;
use crate::work_record::dtos::work_record_create_input::record_invalid_field;

/// Query filter for listing work records within a plan.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct WorkRecordListInput {
    pub from: Option<Date>,
    pub to: Option<Date>,
    pub field_cultivation_id: Option<i64>,
}

impl WorkRecordListInput {
    pub fn from_query(params: &BTreeMap<String, String>) -> Result<Self, RecordInvalidError> {
        let from = parse_optional_date(params.get("from"))?;
        let to = parse_optional_date(params.get("to"))?;
        let field_cultivation_id = parse_optional_i64(params.get("field_cultivation_id"))?;

        Ok(Self {
            from,
            to,
            field_cultivation_id,
        })
    }
}

fn parse_optional_date(raw: Option<&String>) -> Result<Option<Date>, RecordInvalidError> {
    match raw {
        None => Ok(None),
        Some(s) if s.trim().is_empty() => Ok(None),
        Some(s) => crate::cultivation_plan::helpers::parse_iso_date(s)
            .map(Some)
            .ok_or_else(|| record_invalid_field("from", "invalid date")),
    }
}

fn parse_optional_i64(raw: Option<&String>) -> Result<Option<i64>, RecordInvalidError> {
    match raw {
        None => Ok(None),
        Some(s) if s.trim().is_empty() => Ok(None),
        Some(s) => s
            .parse()
            .map(Some)
            .map_err(|_| record_invalid_field("field_cultivation_id", "invalid number")),
    }
}
