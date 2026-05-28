//! Ruby: `Domain::Crop::Policies::MastersCropTaskTemplateCreatePolicy`

use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::crop::dtos::{
    AgriculturalTaskSnapshot, CropTaskTemplatePersistAttributes, MastersCropTaskTemplate,
    MastersCropTaskTemplateCreateInput,
};
use crate::crop::entities::CropTaskTemplateEntity;

pub fn duplicate(existing_link: Option<&CropTaskTemplateEntity>) -> bool {
    existing_link.is_some()
}

pub fn build_persist_attributes(
    input: &MastersCropTaskTemplateCreateInput,
    task_entity: &AgriculturalTaskEntity,
) -> CropTaskTemplatePersistAttributes {
    CropTaskTemplatePersistAttributes {
        name: input
            .name
            .clone()
            .unwrap_or_else(|| task_entity.name.clone()),
        description: input
            .description
            .clone()
            .or_else(|| task_entity.description.clone()),
        time_per_sqm: input
            .time_per_sqm
            .or_else(|| task_entity.time_per_sqm.map(rust_decimal::Decimal::from_f64_retain).flatten()),
        weather_dependency: input
            .weather_dependency
            .clone()
            .or_else(|| task_entity.weather_dependency.clone()),
        required_tools: input
            .required_tools
            .clone()
            .unwrap_or_else(|| task_entity.required_tools.clone()),
        skill_level: input
            .skill_level
            .clone()
            .or_else(|| task_entity.skill_level.clone()),
    }
}

pub fn to_masters_dto(
    template_entity: &CropTaskTemplateEntity,
    task_entity: &AgriculturalTaskEntity,
) -> MastersCropTaskTemplate {
    MastersCropTaskTemplate {
        id: template_entity.id,
        crop_id: template_entity.crop_id,
        agricultural_task_id: template_entity.agricultural_task_id,
        name: template_entity.name.clone(),
        description: template_entity.description.clone(),
        time_per_sqm: template_entity.time_per_sqm,
        weather_dependency: template_entity.weather_dependency.clone(),
        required_tools: template_entity.required_tools.clone(),
        skill_level: template_entity.skill_level.clone(),
        agricultural_task: AgriculturalTaskSnapshot {
            id: task_entity.id.unwrap_or(0),
            name: task_entity.name.clone(),
            description: task_entity.description.clone(),
            is_reference: task_entity.is_reference,
        },
        created_at: template_entity.created_at.clone(),
        updated_at: template_entity.updated_at.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agricultural_task::entities::AgriculturalTaskEntityAttrs;

    // Ruby: test "duplicate? is true when link exists"
    #[test]
    fn duplicate_when_link_exists() {
        let link = CropTaskTemplateEntity {
            id: 1,
            crop_id: 1,
            agricultural_task_id: 2,
            name: "t".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            created_at: None,
            updated_at: None,
        };
        assert!(duplicate(Some(&link)));
        assert!(!duplicate(None));
    }

    // Ruby: test "build_persist_attributes falls back to task entity fields"
    #[test]
    fn build_persist_attributes_falls_back_to_task() {
        let input = MastersCropTaskTemplateCreateInput::new(1, 1, Some(10));
        let task = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(10),
            user_id: Some(1),
            name: "Task".into(),
            description: Some("desc".into()),
            is_reference: false,
            time_per_sqm: Some(1.0),
            weather_dependency: Some("sunny".into()),
            required_tools: vec!["hoe".into()],
            skill_level: Some("basic".into()),
            ..Default::default()
        })
        .expect("valid");
        let attrs = build_persist_attributes(&input, &task);
        assert_eq!(attrs.name, "Task");
        assert_eq!(attrs.description.as_deref(), Some("desc"));
    }

    // Ruby: test "to_masters_dto embeds agricultural task snapshot"
    #[test]
    fn to_masters_dto_embeds_task_snapshot() {
        let template = CropTaskTemplateEntity {
            id: 5,
            crop_id: 1,
            agricultural_task_id: 10,
            name: "Tpl".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            created_at: None,
            updated_at: None,
        };
        let task = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(10),
            user_id: Some(1),
            name: "Task".into(),
            is_reference: true,
            ..Default::default()
        })
        .expect("valid");
        let dto = to_masters_dto(&template, &task);
        assert_eq!(dto.agricultural_task.id, 10);
        assert!(dto.agricultural_task.is_reference);
    }
}
