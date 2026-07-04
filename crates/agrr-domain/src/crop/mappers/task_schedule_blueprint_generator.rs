use crate::crop::entities::CropTaskTemplateEntity;
use crate::crop::task_schedule_blueprint_from_agrr::{
    fertilizer_row, general_row, integer_value, TaskScheduleBlueprintRow,
};
use serde_json::Value;
use std::collections::HashMap;

/// Ruby: `Adapters::Crop::TaskScheduleBlueprintGenerator`
pub struct TaskScheduleBlueprintGenerator<'a> {
    crop_id: i64,
    template_lookup: HashMap<i64, &'a CropTaskTemplateEntity>,
}

impl<'a> TaskScheduleBlueprintGenerator<'a> {
    pub fn new(crop_id: i64, templates: &'a [CropTaskTemplateEntity]) -> Self {
        let mut template_lookup = HashMap::new();
        for template in templates {
            template_lookup.insert(template.agricultural_task_id, template);
        }
        Self {
            crop_id,
            template_lookup,
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
        let template = self.template_for_task(task_id);
        let agricultural_task_id = self.agricultural_task_id_for(task_id, template);
        Some(general_row(
            self.crop_id,
            task,
            agricultural_task_id,
            template.and_then(|t| t.description.as_deref()),
            template.and_then(|t| t.weather_dependency.as_deref()),
            template.and_then(|t| t.time_per_sqm),
        ))
    }

    fn build_fertilizer_blueprint(&self, entry: &Value, index: usize) -> Option<TaskScheduleBlueprintRow> {
        let task_id = integer_value(entry.get("task_id"))?;
        let template = self.template_for_task(task_id);
        let agricultural_task_id = self.agricultural_task_id_for(task_id, template);
        Some(fertilizer_row(
            self.crop_id,
            entry,
            index,
            agricultural_task_id,
            template.and_then(|t| t.description.as_deref()),
            template.and_then(|t| t.weather_dependency.as_deref()),
            template.and_then(|t| t.time_per_sqm),
        ))
    }

    fn template_for_task(&self, task_id: i64) -> Option<&'a CropTaskTemplateEntity> {
        self.template_lookup.get(&task_id).copied()
    }

    fn agricultural_task_id_for(
        &self,
        task_id: i64,
        template: Option<&CropTaskTemplateEntity>,
    ) -> i64 {
        template.map(|t| t.agricultural_task_id).unwrap_or(task_id)
    }
}

#[cfg(test)]
mod task_schedule_blueprint_generator_test_inline {
    use super::*;
    use rust_decimal::Decimal;
    use serde_json::json;
    use std::str::FromStr;

    fn sample_template(id: i64, ag_task_id: i64) -> CropTaskTemplateEntity {
        CropTaskTemplateEntity {
            id,
            crop_id: 1,
            agricultural_task_id: ag_task_id,
            name: format!("task-{ag_task_id}"),
            description: Some("desc".into()),
            time_per_sqm: Some(Decimal::from_str("1.0").unwrap()),
            weather_dependency: Some("low".into()),
            required_tools: vec![],
            skill_level: None,
            created_at: None,
            updated_at: None,
        }
    }

    #[test]
    fn build_from_responses_merges_schedule_and_fertilize_entries() {
        let templates = vec![sample_template(1, 10), sample_template(2, 20)];
        let gen = TaskScheduleBlueprintGenerator::new(5, &templates);
        let schedule = json!({"task_schedules": [{"task_id": "10", "stage_order": 1, "gdd_trigger": "100"}]});
        let fertilize = json!({"schedule": [{"task_id": "20", "stage_order": 2, "gdd_trigger": "200"}]});
        let rows = gen.build_from_responses(&schedule, &fertilize);
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].crop_id, 5);
        assert_eq!(rows[1].agricultural_task_id, 20);
    }
}
