use crate::crop::task_schedule_blueprint_from_agrr::{
    fertilizer_row, general_row, integer_value, TaskScheduleBlueprintRow,
};
use rust_decimal::Decimal;
use serde_json::Value;
use std::collections::HashMap;

/// Snapshot attributes used when merging agrr AI responses into blueprint rows.
#[derive(Debug, Clone)]
pub struct BlueprintAttributeSnapshot {
    pub description: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
}

/// Ruby: `Adapters::Crop::TaskScheduleBlueprintGenerator`
pub struct TaskScheduleBlueprintGenerator {
    crop_id: i64,
    attribute_lookup: HashMap<i64, BlueprintAttributeSnapshot>,
}

impl TaskScheduleBlueprintGenerator {
    pub fn new(crop_id: i64, attribute_lookup: HashMap<i64, BlueprintAttributeSnapshot>) -> Self {
        Self {
            crop_id,
            attribute_lookup,
        }
    }

    pub fn build_from_responses(
        &self,
        schedule_response: &Value,
        fertilize_response: &Value,
    ) -> Vec<TaskScheduleBlueprintRow> {
        let mut blueprint_attributes = Vec::new();

        if let Some(tasks) = schedule_response.get("task_schedules").and_then(|v| v.as_array()) {
            for task in tasks {
                if let Some(row) = self.build_general_blueprint(task) {
                    blueprint_attributes.push(row);
                }
            }
        }

        if let Some(entries) = fertilize_response.get("schedule").and_then(|v| v.as_array()) {
            for (index, entry) in entries.iter().enumerate() {
                if let Some(row) = self.build_fertilizer_blueprint(entry, index) {
                    blueprint_attributes.push(row);
                }
            }
        }

        blueprint_attributes
    }

    fn build_general_blueprint(&self, task: &Value) -> Option<TaskScheduleBlueprintRow> {
        let task_id = integer_value(task.get("task_id"))?;
        let snapshot = self.attribute_lookup.get(&task_id);
        Some(general_row(
            self.crop_id,
            task,
            task_id,
            snapshot.and_then(|s| s.description.as_deref()),
            snapshot.and_then(|s| s.weather_dependency.as_deref()),
            snapshot.and_then(|s| s.time_per_sqm),
        ))
    }

    fn build_fertilizer_blueprint(&self, entry: &Value, index: usize) -> Option<TaskScheduleBlueprintRow> {
        let task_id = integer_value(entry.get("task_id"))?;
        let snapshot = self.attribute_lookup.get(&task_id);
        Some(fertilizer_row(
            self.crop_id,
            entry,
            index,
            task_id,
            snapshot.and_then(|s| s.description.as_deref()),
            snapshot.and_then(|s| s.weather_dependency.as_deref()),
            snapshot.and_then(|s| s.time_per_sqm),
        ))
    }
}

#[cfg(test)]
mod task_schedule_blueprint_generator_test_inline {
    use super::*;
    use rust_decimal::Decimal;
    use serde_json::json;
    use std::str::FromStr;

    #[test]
    fn build_from_responses_merges_schedule_and_fertilize_entries() {
        let mut lookup = HashMap::new();
        lookup.insert(
            10,
            BlueprintAttributeSnapshot {
                description: Some("desc".into()),
                weather_dependency: Some("low".into()),
                time_per_sqm: Some(Decimal::from_str("1.0").unwrap()),
            },
        );
        lookup.insert(
            20,
            BlueprintAttributeSnapshot {
                description: None,
                weather_dependency: None,
                time_per_sqm: None,
            },
        );
        let gen = TaskScheduleBlueprintGenerator::new(5, lookup);
        let schedule = json!({"task_schedules": [{"task_id": "10", "stage_order": 1, "gdd_trigger": "100"}]});
        let fertilize = json!({"schedule": [{"task_id": "20", "stage_order": 2, "gdd_trigger": "200"}]});
        let rows = gen.build_from_responses(&schedule, &fertilize);
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].crop_id, 5);
        assert_eq!(rows[1].agricultural_task_id, 20);
    }
}
