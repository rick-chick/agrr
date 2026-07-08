pub mod crop_create_limit_policy;
pub mod crop_destroy_policy;
pub mod crop_masters_crop_edit_access;
pub mod crop_masters_nested_access;
pub mod crop_reference_record_policy;
pub mod crop_resolve_by_name_policy;
pub mod masters_crop_task_schedule_blueprint_create_policy;
pub mod masters_crop_task_schedule_blueprint_duplicate_policy;

pub use crop_destroy_policy::{blocked_reason, CropDestroyBlockedReason};

/// Ruby: `Domain::Crop::Policies::CropDestroyPolicy`
pub struct CropDestroyPolicy;

impl CropDestroyPolicy {
    pub fn blocked_reason(
        usage: &crate::crop::dtos::CropDeleteUsage,
    ) -> Option<CropDestroyBlockedReason> {
        blocked_reason(usage)
    }
}
