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
mod policies_masters_crop_task_template_create_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/policies_masters_crop_task_template_create_policy_test.rs"));
}
