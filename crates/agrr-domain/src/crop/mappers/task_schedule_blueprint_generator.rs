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
    attribute_by_blueprint_id: HashMap<i64, BlueprintAttributeSnapshot>,
    attribute_by_agricultural_task_id: HashMap<i64, BlueprintAttributeSnapshot>,
    agricultural_task_id_by_blueprint_id: HashMap<i64, i64>,
}

impl TaskScheduleBlueprintGenerator {
    pub fn new(
        crop_id: i64,
        attribute_by_blueprint_id: HashMap<i64, BlueprintAttributeSnapshot>,
        attribute_by_agricultural_task_id: HashMap<i64, BlueprintAttributeSnapshot>,
        agricultural_task_id_by_blueprint_id: HashMap<i64, i64>,
    ) -> Self {
        Self {
            crop_id,
            attribute_by_blueprint_id,
            attribute_by_agricultural_task_id,
            agricultural_task_id_by_blueprint_id,
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
        let blueprint_id = integer_value(task.get("task_id"))?;
        let agricultural_task_id = self.agricultural_task_id_by_blueprint_id.get(&blueprint_id)?;
        let snapshot = self.attribute_by_blueprint_id.get(&blueprint_id);
        Some(general_row(
            self.crop_id,
            task,
            blueprint_id,
            *agricultural_task_id,
            snapshot.and_then(|s| s.description.as_deref()),
            snapshot.and_then(|s| s.weather_dependency.as_deref()),
            snapshot.and_then(|s| s.time_per_sqm),
        ))
    }

    fn build_fertilizer_blueprint(&self, entry: &Value, index: usize) -> Option<TaskScheduleBlueprintRow> {
        let task_id = integer_value(entry.get("task_id"))?;
        let snapshot = self.attribute_by_agricultural_task_id.get(&task_id);
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
        let mut by_blueprint = HashMap::new();
        by_blueprint.insert(
            10,
            BlueprintAttributeSnapshot {
                description: Some("desc".into()),
                weather_dependency: Some("low".into()),
                time_per_sqm: Some(Decimal::from_str("1.0").unwrap()),
            },
        );
        let mut by_task = HashMap::new();
        by_task.insert(
            20,
            BlueprintAttributeSnapshot {
                description: None,
                weather_dependency: None,
                time_per_sqm: None,
            },
        );
        let mut task_by_blueprint = HashMap::new();
        task_by_blueprint.insert(10, 100);
        let gen = TaskScheduleBlueprintGenerator::new(5, by_blueprint, by_task, task_by_blueprint);
        let schedule = json!({"task_schedules": [{"task_id": "10", "stage_order": 1, "gdd_trigger": "100"}]});
        let fertilize = json!({"schedule": [{"task_id": "20", "stage_order": 2, "gdd_trigger": "200"}]});
        let rows = gen.build_from_responses(&schedule, &fertilize);
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].crop_id, 5);
        assert_eq!(rows[0].blueprint_id, Some(10));
        assert_eq!(rows[0].agricultural_task_id, 100);
        assert_eq!(rows[1].agricultural_task_id, 20);
    }

    #[test]
    fn build_from_responses_maps_multiple_field_work_slots_by_blueprint_id() {
        let mut by_blueprint = HashMap::new();
        by_blueprint.insert(
            17,
            BlueprintAttributeSnapshot {
                description: Some("slot 17".into()),
                weather_dependency: None,
                time_per_sqm: None,
            },
        );
        by_blueprint.insert(
            18,
            BlueprintAttributeSnapshot {
                description: Some("slot 18".into()),
                weather_dependency: None,
                time_per_sqm: None,
            },
        );
        let mut task_by_blueprint = HashMap::new();
        task_by_blueprint.insert(17, 100);
        task_by_blueprint.insert(18, 100);
        let gen = TaskScheduleBlueprintGenerator::new(5, by_blueprint, HashMap::new(), task_by_blueprint);
        let schedule = json!({"task_schedules": [
            {"task_id": "17", "stage_order": 2, "gdd_trigger": "120"},
            {"task_id": "18", "stage_order": 2, "gdd_trigger": "260"}
        ]});
        let rows = gen.build_from_responses(&schedule, &json!({"schedule": []}));
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].blueprint_id, Some(17));
        assert_eq!(rows[1].blueprint_id, Some(18));
        assert_eq!(rows[0].agricultural_task_id, 100);
        assert_eq!(rows[1].agricultural_task_id, 100);
    }
}
