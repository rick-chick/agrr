//! Ruby: `Domain::PublicPlan::Dtos::EntryScheduleShowOutput`

use serde_json::Value;
use std::collections::BTreeMap;

/// Ruby: `EntryScheduleShowOutput` struct with `farm_fragment`, `prediction_fragment`, `crop_fragment`.
#[derive(Debug, Clone, PartialEq)]
pub struct EntryScheduleShowOutput {
    pub farm_fragment: BTreeMap<String, Value>,
    pub prediction_fragment: BTreeMap<String, Value>,
    pub crop_fragment: BTreeMap<String, Value>,
}

impl EntryScheduleShowOutput {
    pub fn new(
        farm_fragment: BTreeMap<String, Value>,
        prediction_fragment: BTreeMap<String, Value>,
        crop_fragment: BTreeMap<String, Value>,
    ) -> Self {
        Self {
            farm_fragment,
            prediction_fragment,
            crop_fragment,
        }
    }

    pub fn to_h(&self) -> BTreeMap<String, BTreeMap<String, Value>> {
        let mut root = BTreeMap::new();
        root.insert("farm".into(), self.farm_fragment.clone());
        root.insert("prediction".into(), self.prediction_fragment.clone());
        root.insert("crop".into(), self.crop_fragment.clone());
        root
    }
}
