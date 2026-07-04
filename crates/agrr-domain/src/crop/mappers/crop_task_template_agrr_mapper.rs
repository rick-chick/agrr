use crate::crop::entities::CropTaskTemplateEntity;
use serde_json::{json, Value};

/// Ruby: `CropTaskTemplate#to_agrr_format` / `to_agrr_format_array`.
pub fn to_agrr_format(template: &CropTaskTemplateEntity) -> Value {
    let agrr_task_id = template.agricultural_task_id;
    let mut obj = json!({
        "task_id": agrr_task_id.to_string(),
        "name": template.name,
        "description": template.description,
        "weather_dependency": template.weather_dependency,
        "required_tools": template.required_tools,
        "skill_level": template.skill_level,
    });
    if let Some(t) = template.time_per_sqm {
        if let Some(obj_map) = obj.as_object_mut() {
            if let Ok(f) = t.to_string().parse::<f64>() {
                obj_map.insert("time_per_sqm".into(), json!(f));
            }
        }
    }
    omit_nulls(obj)
}

pub fn to_agrr_format_array(templates: &[CropTaskTemplateEntity]) -> Vec<Value> {
    templates.iter().map(to_agrr_format).collect()
}

fn omit_nulls(mut value: Value) -> Value {
    if let Some(obj) = value.as_object_mut() {
        obj.retain(|_, v| !v.is_null());
    }
    value
}

#[cfg(test)]
mod crop_task_template_agrr_mapper_test_inline {
    use super::*;
    use rust_decimal::Decimal;
    use std::str::FromStr;

    #[test]
    fn to_agrr_format_uses_agricultural_task_id_as_task_id() {
        let template = CropTaskTemplateEntity {
            id: 99,
            crop_id: 1,
            agricultural_task_id: 42,
            name: "除草".into(),
            description: Some("desc".into()),
            time_per_sqm: Some(Decimal::from_str("0.5").unwrap()),
            weather_dependency: Some("low".into()),
            required_tools: vec!["hoe".into()],
            skill_level: Some("beginner".into()),
            created_at: None,
            updated_at: None,
        };
        let fmt = to_agrr_format(&template);
        assert_eq!(fmt["task_id"], "42");
        assert_eq!(fmt["name"], "除草");
        assert_eq!(fmt["time_per_sqm"], 0.5_f64);
    }
}
