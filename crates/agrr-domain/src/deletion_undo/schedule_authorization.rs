//! Ruby: `Domain::DeletionUndo::ScheduleAuthorization`

use crate::shared::policies::{
    agricultural_task_policy, crop_policy, farm_policy, fertilize_policy, interaction_rule_policy,
    pest_policy, pesticide_policy,
};
use crate::shared::user::User;

/// Schedulable resource for undo authorization (Ruby: duck-typed AR record).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchedulableRecord {
    pub type_name: String,
    pub is_reference: bool,
    pub user_id: Option<i64>,
    pub farm_user_id: Option<i64>,
    pub plan_type_private: Option<bool>,
    pub plan_user_id: Option<i64>,
}

impl SchedulableRecord {
    pub fn crop(user_id: i64, is_reference: bool) -> Self {
        Self {
            type_name: "Crop".into(),
            is_reference,
            user_id: Some(user_id),
            farm_user_id: None,
            plan_type_private: None,
            plan_user_id: None,
        }
    }
}

/// Ruby: `ScheduleAuthorization.schedule_allowed?`
pub fn schedule_allowed(user: &User, record: &SchedulableRecord) -> bool {
    match record.type_name.as_str() {
        "Farm" => farm_policy::edit_allowed(user, record.is_reference, record.user_id),
        "Crop" => crop_policy::edit_allowed(user, record.is_reference, record.user_id),
        "Pest" => pest_policy::edit_allowed(user, record.is_reference, record.user_id),
        "Pesticide" => pesticide_policy::edit_allowed(user, record.is_reference, record.user_id),
        "Fertilize" => fertilize_policy::edit_allowed(user, record.is_reference, record.user_id),
        "AgriculturalTask" => {
            agricultural_task_policy::edit_allowed(user, record.is_reference, record.user_id)
        }
        "InteractionRule" => {
            interaction_rule_policy::edit_allowed(user, record.is_reference, record.user_id)
        }
        "Field" => user.admin || record.farm_user_id == Some(user.id),
        "TaskScheduleItem" => {
            user.admin
                || (record.plan_type_private == Some(true)
                    && record.plan_user_id == Some(user.id))
        }
        "CultivationPlan" => {
            user.admin
                || (record.plan_type_private == Some(true)
                    && record.user_id == Some(user.id))
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::shared::user::User;

    // Ruby: test "schedule_allowed? permits crop owner to schedule crop deletion"
    #[test]
    fn schedule_allowed_permits_crop_owner_to_schedule_crop_deletion() {
        let user = User::new(1, false);
        let record = SchedulableRecord::crop(1, false);
        assert!(schedule_allowed(&user, &record));
    }

    // Ruby: test "schedule_allowed? denies other user on non-reference crop"
    #[test]
    fn schedule_allowed_denies_other_user_on_non_reference_crop() {
        let user = User::new(1, false);
        let record = SchedulableRecord::crop(99, false);
        assert!(!schedule_allowed(&user, &record));
    }
}
