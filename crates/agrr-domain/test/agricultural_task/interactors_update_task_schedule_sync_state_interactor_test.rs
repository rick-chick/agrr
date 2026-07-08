use std::sync::{Arc, Mutex};

use crate::agricultural_task::constants::task_schedule_sync_states;
use crate::agricultural_task::dtos::UpdateTaskScheduleSyncStateInput;
use crate::agricultural_task::gateways::TaskScheduleSyncStateGateway;
use crate::agricultural_task::interactors::UpdateTaskScheduleSyncStateInteractor;
use crate::agricultural_task::ports::TaskScheduleSyncBroadcastPort;

struct SpyGateway {
    updates: Arc<Mutex<Vec<(i64, String, Option<String>, Option<i64>)>>>,
}

impl TaskScheduleSyncStateGateway for SpyGateway {
    fn update_sync_state(
        &self,
        plan_id: i64,
        sync_state: &str,
        sync_error: Option<&str>,
        sync_error_crop_id: Option<i64>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.updates.lock().expect("lock").push((
            plan_id,
            sync_state.to_string(),
            sync_error.map(str::to_string),
            sync_error_crop_id,
        ));
        Ok(())
    }

    fn find_sync_state(
        &self,
        _: i64,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct SpyBroadcast {
    messages: Arc<Mutex<Vec<(i64, String, Option<String>, Option<i64>)>>>,
}

impl TaskScheduleSyncBroadcastPort for SpyBroadcast {
    fn broadcast_sync_state(
        &self,
        plan_id: i64,
        sync_state: &str,
        sync_error: Option<&str>,
        sync_error_crop_id: Option<i64>,
    ) {
        self.messages.lock().expect("lock").push((
            plan_id,
            sync_state.to_string(),
            sync_error.map(str::to_string),
            sync_error_crop_id,
        ));
    }
}

#[test]
fn update_task_schedule_sync_state_persists_and_broadcasts() {
    let updates = Arc::new(Mutex::new(Vec::new()));
    let messages = Arc::new(Mutex::new(Vec::new()));
    let gateway = SpyGateway {
        updates: updates.clone(),
    };
    let broadcast = SpyBroadcast {
        messages: messages.clone(),
    };
    let interactor = UpdateTaskScheduleSyncStateInteractor::new(&gateway, &broadcast);

    interactor
        .call(UpdateTaskScheduleSyncStateInput {
            plan_id: 7,
            sync_state: task_schedule_sync_states::FAILED,
            sync_error: Some("plans.task_schedules.sync_errors.generic"),
            sync_error_crop_id: Some(3),
        })
        .expect("update sync state");

    assert_eq!(
        updates.lock().expect("lock")[0],
        (
            7,
            task_schedule_sync_states::FAILED.to_string(),
            Some("plans.task_schedules.sync_errors.generic".to_string()),
            Some(3)
        )
    );
    assert_eq!(
        updates.lock().expect("lock").clone(),
        messages.lock().expect("lock").clone()
    );
}
