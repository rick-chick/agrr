//! Ruby: `Domain::FieldCultivation::Interactors::FieldCultivationSyncInteractor`

use crate::field_cultivation::dtos::FieldCultivationSyncInput;
use crate::field_cultivation::gateways::{
    FieldCultivationSyncGateway, FieldCultivationSyncPlanReadGateway,
};
use crate::field_cultivation::mappers::{
    sync_plan_snapshot_from_snapshots, to_apply, to_target_snapshot,
};
use crate::field_cultivation::policies::validate_sync_input;
use crate::field_cultivation::ports::FieldCultivationSyncInputPort;
use crate::shared::ports::logger_port::LoggerPort;

pub struct FieldCultivationSyncInteractor<'a, W, R> {
    sync_gateway: &'a W,
    sync_plan_read_gateway: &'a R,
    logger: &'a dyn LoggerPort,
}

impl<'a, W, R> FieldCultivationSyncInteractor<'a, W, R> {
    pub fn new(
        sync_gateway: &'a W,
        sync_plan_read_gateway: &'a R,
        logger: &'a dyn LoggerPort,
    ) -> Self {
        Self {
            sync_gateway,
            sync_plan_read_gateway,
            logger,
        }
    }
}

impl<'a, W, R> FieldCultivationSyncInputPort for FieldCultivationSyncInteractor<'a, W, R>
where
    W: FieldCultivationSyncGateway,
    R: FieldCultivationSyncPlanReadGateway,
{
    fn call(
        &mut self,
        plan_id: i64,
        sync_input: FieldCultivationSyncInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        validate_sync_input(&sync_input)?;

        let plan_field_ids = self
            .sync_plan_read_gateway
            .list_sync_plan_field_ids_by_plan_id(plan_id)?;
        let plan_crop_rows = self
            .sync_plan_read_gateway
            .list_sync_plan_crop_entries_by_plan_id(plan_id)?;
        let existing_entries = self
            .sync_plan_read_gateway
            .list_sync_existing_field_cultivation_entries_by_plan_id(plan_id)?;
        let plan_snapshot = sync_plan_snapshot_from_snapshots(
            plan_id,
            plan_field_ids,
            plan_crop_rows,
            existing_entries,
        );

        let target_snapshot = to_target_snapshot(&sync_input, &plan_snapshot)?;
        let sync_apply = to_apply(&plan_snapshot, &target_snapshot);

        self.logger.info(&format!(
            "🛠️ [FieldCultivationSync] to_update: {}, to_create: {}, to_delete: {}, plan_crop_delete: {}",
            sync_apply.field_cultivations_to_update.len(),
            sync_apply.field_cultivations_to_create.len(),
            sync_apply.field_cultivation_ids_to_delete.len(),
            sync_apply.cultivation_plan_crop_ids_to_delete.len(),
        ));

        self.sync_gateway.sync_by_plan_id(plan_id, &sync_apply)
    }
}
