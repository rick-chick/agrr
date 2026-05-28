//! Ruby: `Domain::FieldCultivation::Interactors::FieldCultivationSyncInteractor`

use crate::field_cultivation::dtos::FieldCultivationSyncInput;
use crate::field_cultivation::gateways::FieldCultivationSyncGateway;
use crate::field_cultivation::mappers::{to_apply, to_target_snapshot};
use crate::field_cultivation::policies::validate_sync_input;
use crate::field_cultivation::ports::FieldCultivationSyncInputPort;
use crate::shared::ports::logger_port::LoggerPort;

pub struct FieldCultivationSyncInteractor<'a, G> {
    sync_gateway: &'a G,
    logger: &'a dyn LoggerPort,
}

impl<'a, G> FieldCultivationSyncInteractor<'a, G>
where
    G: FieldCultivationSyncGateway,
{
    pub fn new(sync_gateway: &'a G, logger: &'a dyn LoggerPort) -> Self {
        Self { sync_gateway, logger }
    }
}

impl<'a, G> FieldCultivationSyncInputPort for FieldCultivationSyncInteractor<'a, G>
where
    G: FieldCultivationSyncGateway,
{
    fn call(
        &mut self,
        plan_id: i64,
        sync_input: FieldCultivationSyncInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        validate_sync_input(&sync_input)?;

        let plan_snapshot = self.sync_gateway.find_sync_plan_snapshot_by_plan_id(plan_id)?;
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
