//! Ruby: `Domain::PublicPlan::Catalog::FarmSizeCatalog`

use crate::shared::hash::blank;
use serde_json::Value;

/// Ruby: `{ id:, area_sqm: }` entry
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FarmSizeEntry {
    pub id: &'static str,
    pub area_sqm: i64,
}

const ENTRIES: [FarmSizeEntry; 3] = [
    FarmSizeEntry {
        id: "home_garden",
        area_sqm: 30,
    },
    FarmSizeEntry {
        id: "community_garden",
        area_sqm: 50,
    },
    FarmSizeEntry {
        id: "rental_farm",
        area_sqm: 300,
    },
];

/// Ruby: `Domain::PublicPlan::Catalog::FarmSizeCatalog`
pub struct FarmSizeCatalog;

impl FarmSizeCatalog {
    pub fn all() -> &'static [FarmSizeEntry] {
        &ENTRIES
    }

    /// Ruby: `.find_by_id(farm_size_id)` — matches id string or area_sqm integer.
    pub fn find_by_id(farm_size_id: &str) -> Option<FarmSizeEntry> {
        if blank(&Value::String(farm_size_id.to_string())) {
            return None;
        }
        if let Ok(area) = farm_size_id.parse::<i64>() {
            if let Some(entry) = ENTRIES.iter().find(|e| e.area_sqm == area) {
                return Some(*entry);
            }
        }
        ENTRIES
            .iter()
            .find(|e| e.id == farm_size_id)
            .copied()
    }

    pub fn find_by_id_value(farm_size_id: &Value) -> Option<FarmSizeEntry> {
        match farm_size_id {
            Value::String(s) => Self::find_by_id(s),
            Value::Number(n) => n
                .as_i64()
                .and_then(|area| ENTRIES.iter().find(|e| e.area_sqm == area).copied()),
            _ => None,
        }
    }
}

/// Resolved farm size for create interactor (Ruby Hash).
#[derive(Debug, Clone, PartialEq)]
pub struct FarmSizeRecord {
    pub id: String,
    pub area_sqm: i64,
}

impl From<FarmSizeEntry> for FarmSizeRecord {
    fn from(entry: FarmSizeEntry) -> Self {
        Self {
            id: entry.id.to_string(),
            area_sqm: entry.area_sqm,
        }
    }
}

#[cfg(test)]
mod catalog_farm_size_catalog_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/public_plan/catalog_farm_size_catalog_test.rs"));
}
