use crate::field_cultivation::dtos::{
    ClimateCropEntity, FieldCultivationClimateFailure, FieldCultivationClimateFailureReason,
};
use crate::field_cultivation::errors::FieldCultivationClimateFailureError;

pub fn validate_crop_requirement_for_climate(
    crop: &ClimateCropEntity,
) -> Result<(), FieldCultivationClimateFailureError> {
    let valid_stage_count = crop
        .crop_stages
        .iter()
        .filter(|st| {
            st.temperature_requirement.is_some() && st.thermal_requirement.is_some()
        })
        .count();

    if valid_stage_count == 0 {
        return Err(FieldCultivationClimateFailureError(
            FieldCultivationClimateFailure::new(
                FieldCultivationClimateFailureReason::CropRequirementIncomplete,
                "crop has no stages with temperature and thermal requirements",
            ),
        ));
    }

    let first_stage = crop.crop_stages.iter().min_by_key(|st| st.order);
    if first_stage
        .and_then(|st| st.temperature_requirement.as_ref())
        .is_none()
    {
        return Err(FieldCultivationClimateFailureError(
            FieldCultivationClimateFailure::new(
                FieldCultivationClimateFailureReason::CropRequirementIncomplete,
                "lowest-order stage has no temperature requirement",
            ),
        ));
    }

    Ok(())
}
