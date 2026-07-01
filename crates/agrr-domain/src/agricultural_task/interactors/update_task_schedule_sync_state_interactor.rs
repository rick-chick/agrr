//! Persist and broadcast task schedule sync metadata.

use crate::agricultural_task::dtos::UpdateTaskScheduleSyncStateInput;
use crate::agricultural_task::gateways::TaskScheduleSyncStateGateway;
use crate::agricultural_task::ports::{
    TaskScheduleSyncBroadcastPort, TaskScheduleSyncStateUpdateInputPort,
};

pub struct UpdateTaskScheduleSyncStateInteractor<'a, G, B> {
    sync_state_gateway: &'a G,
    sync_broadcast_port: &'a B,
}

impl<'a, G, B> UpdateTaskScheduleSyncStateInteractor<'a, G, B>
where
    G: TaskScheduleSyncStateGateway,
    B: TaskScheduleSyncBroadcastPort,
{
    pub fn new(sync_state_gateway: &'a G, sync_broadcast_port: &'a B) -> Self {
        Self {
            sync_state_gateway,
            sync_broadcast_port,
        }
    }

    pub fn call(
        &self,
        input: UpdateTaskScheduleSyncStateInput<'_>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.sync_state_gateway.update_sync_state(
            input.plan_id,
            input.sync_state,
            input.sync_error,
        )?;
        self.sync_broadcast_port.broadcast_sync_state(
            input.plan_id,
            input.sync_state,
            input.sync_error,
        );
        Ok(())
    }
}

impl<G, B> TaskScheduleSyncStateUpdateInputPort for UpdateTaskScheduleSyncStateInteractor<'_, G, B>
where
    G: TaskScheduleSyncStateGateway,
    B: TaskScheduleSyncBroadcastPort,
{
    fn call(
        &self,
        input: UpdateTaskScheduleSyncStateInput<'_>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        UpdateTaskScheduleSyncStateInteractor::call(self, input)
    }
}

#[cfg(test)]
mod interactors_update_task_schedule_sync_state_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/interactors_update_task_schedule_sync_state_interactor_test.rs"
    ));
}
