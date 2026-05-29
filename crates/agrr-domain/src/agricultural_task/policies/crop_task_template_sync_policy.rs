use std::collections::HashSet;

use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::hash::blank_attr;

/// Ruby: `Domain::AgriculturalTask::Policies::CropTaskTemplateSyncPolicy`
pub struct CropTaskTemplateSyncPolicy;

impl CropTaskTemplateSyncPolicy {
    pub fn crop_associate_region_filter(region: Option<&str>) -> Option<String> {
        region.and_then(|r| {
            if blank_attr(&AttrValue::Str(r.to_string())) {
                None
            } else {
                Some(r.to_string())
            }
        })
    }

    pub fn normalize_selected_crop_ids(selected_crop_ids: &[i64]) -> Vec<i64> {
        let mut seen = HashSet::new();
        selected_crop_ids
            .iter()
            .copied()
            .filter(|id| seen.insert(*id))
            .collect()
    }

    pub fn allowed_crop_ids(scope_crop_ids: &[i64], selected_crop_ids: &[i64]) -> Vec<i64> {
        let scope: HashSet<i64> = scope_crop_ids.iter().copied().collect();
        Self::normalize_selected_crop_ids(selected_crop_ids)
            .into_iter()
            .filter(|id| scope.contains(id))
            .collect()
    }

    pub fn crops_to_add(allowed_crop_ids: &[i64], current_template_crop_ids: &[i64]) -> Vec<i64> {
        let current: HashSet<i64> = current_template_crop_ids.iter().copied().collect();
        allowed_crop_ids
            .iter()
            .copied()
            .filter(|id| !current.contains(&id))
            .collect()
    }

    pub fn crops_to_remove(allowed_crop_ids: &[i64], current_template_crop_ids: &[i64]) -> Vec<i64> {
        let allowed: HashSet<i64> = allowed_crop_ids.iter().copied().collect();
        current_template_crop_ids
            .iter()
            .copied()
            .filter(|id| !allowed.contains(&id))
            .collect()
    }

    pub fn skip_template_create(crop_found: bool, template_exists: bool) -> bool {
        !crop_found || template_exists
    }

    pub fn skip_template_remove(crop_found: bool, template_exists: bool) -> bool {
        !crop_found || !template_exists
    }

    pub fn template_attributes_from_task_entity(task: &AgriculturalTaskEntity) -> AttrMap {
        attr_map_from_task(task)
    }
}

fn attr_map_from_task(task: &AgriculturalTaskEntity) -> AttrMap {
    use crate::shared::attr::attr_map_from_pairs;
    attr_map_from_pairs([
        ("name", AttrValue::from(task.name.as_str())),
        (
            "description",
            task.description
                .as_deref()
                .map(AttrValue::from)
                .unwrap_or(AttrValue::Null),
        ),
        (
            "time_per_sqm",
            task.time_per_sqm
                .map(|v| AttrValue::Str(v.to_string()))
                .unwrap_or(AttrValue::Null),
        ),
        (
            "weather_dependency",
            task.weather_dependency
                .as_deref()
                .map(AttrValue::from)
                .unwrap_or(AttrValue::Null),
        ),
        (
            "required_tools",
            AttrValue::Str(task.required_tools.join(",")),
        ),
        (
            "skill_level",
            task.skill_level
                .as_deref()
                .map(AttrValue::from)
                .unwrap_or(AttrValue::Null),
        ),
    ])
}

#[cfg(test)]
mod policies_crop_task_template_sync_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/agricultural_task/policies_crop_task_template_sync_policy_test.rs"));
}
