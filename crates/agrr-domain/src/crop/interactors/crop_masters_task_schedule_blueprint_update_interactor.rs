use rust_decimal::Decimal;
use serde_json::Value;

use crate::crop::dtos::{
    MastersCropTaskScheduleBlueprint, MastersCropTaskScheduleBlueprintFailure,
    MastersCropTaskScheduleBlueprintFailureReason, MastersCropTaskScheduleBlueprintUpdateInput,
};
use crate::crop::gateways::{CropGateway, CropMastersTaskScheduleBlueprintGateway};
use crate::crop::policies::{
    crop_masters_crop_edit_access, masters_crop_task_schedule_blueprint_duplicate_policy,
};
use crate::crop::ports::CropMastersTaskScheduleBlueprintUpdateOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskScheduleBlueprintUpdateInteractor<'a, G, BG, O, U> {
    output_port: &'a mut O,
    crop_gateway: &'a G,
    blueprint_gateway: &'a BG,
    user_lookup: &'a U,
}

impl<'a, G, BG, O, U> CropMastersTaskScheduleBlueprintUpdateInteractor<'a, G, BG, O, U>
where
    G: CropGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    O: CropMastersTaskScheduleBlueprintUpdateOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        crop_gateway: &'a G,
        blueprint_gateway: &'a BG,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            crop_gateway,
            blueprint_gateway,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: MastersCropTaskScheduleBlueprintUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let crop_entity = match self.crop_gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                    MastersCropTaskScheduleBlueprintFailureReason::CropNotFound,
                ));
                return Ok(());
            }
            Err(e) => return Err(e),
        };
        if crop_masters_crop_edit_access::assert_edit(&access_filter, &crop_entity).is_err() {
            self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                MastersCropTaskScheduleBlueprintFailureReason::CropNotFound,
            ));
            return Ok(());
        }

        let existing = self.blueprint_gateway.list_by_crop_id(input.crop_id)?;
        let Some(current) = existing
            .iter()
            .find(|row| row.id == input.blueprint_id)
        else {
            self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                MastersCropTaskScheduleBlueprintFailureReason::BlueprintNotFound,
            ));
            return Ok(());
        };

        let agricultural_task_id = match current.agricultural_task_id {
            Some(id) if id > 0 => id,
            _ => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                    MastersCropTaskScheduleBlueprintFailureReason::BlueprintNotFound,
                ));
                return Ok(());
            }
        };

        let merged_stage_order = merge_stage_order(current, &input.attributes);
        let merged_gdd_trigger = merge_gdd_trigger(current, &input.attributes);
        if masters_crop_task_schedule_blueprint_duplicate_policy::conflicts_with_existing(
            &existing,
            Some(input.blueprint_id),
            agricultural_task_id,
            merged_stage_order,
            merged_gdd_trigger,
        ) {
            self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                MastersCropTaskScheduleBlueprintFailureReason::Duplicate,
            ));
            return Ok(());
        }

        match self.blueprint_gateway.update(
            input.crop_id,
            input.blueprint_id,
            input.attributes,
        ) {
            Ok(row) => {
                self.output_port.on_success(row);
                Ok(())
            }
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                    MastersCropTaskScheduleBlueprintFailureReason::BlueprintNotFound,
                ));
                Ok(())
            }
            Err(e) => Err(e),
        }
    }
}

fn merge_stage_order(
    current: &MastersCropTaskScheduleBlueprint,
    attributes: &Value,
) -> Option<i32> {
    if let Some(value) = attributes.get("stage_order") {
        if value.is_null() {
            return None;
        }
        return value
            .as_i64()
            .map(|order| order as i32)
            .or_else(|| value.as_str().and_then(|s| s.parse().ok()));
    }
    current.stage_order
}

fn merge_gdd_trigger(
    current: &MastersCropTaskScheduleBlueprint,
    attributes: &Value,
) -> Option<f64> {
    if let Some(value) = attributes.get("gdd_trigger") {
        if value.is_null() {
            return None;
        }
        return value
            .as_f64()
            .or_else(|| value.as_str().and_then(|s| s.parse().ok()));
    }
    current
        .gdd_trigger
        .as_ref()
        .and_then(|decimal| decimal.to_string().parse().ok())
}

#[cfg(test)]
mod interactors_crop_masters_task_schedule_blueprint_update_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/interactors_crop_masters_task_schedule_blueprint_update_interactor_test.rs"
    ));
}
