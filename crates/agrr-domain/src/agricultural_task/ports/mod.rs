//! Output port traits for agricultural task interactors.

pub mod agricultural_task_create_output_port;
pub mod agricultural_task_destroy_output_port;
pub mod agricultural_task_detail_output_port;
pub mod agricultural_task_list_output_port;
pub mod agricultural_task_update_output_port;

pub(crate) mod task_schedule_generate_input_port;
pub(crate) mod task_schedule_sync_broadcast_port;
pub(crate) mod task_schedule_sync_state_update_input_port;

pub use task_schedule_sync_broadcast_port::TaskScheduleSyncBroadcastPort;
pub(crate) use task_schedule_generate_input_port::TaskScheduleGenerateInputPort;
pub(crate) use task_schedule_sync_state_update_input_port::TaskScheduleSyncStateUpdateInputPort;
pub use agricultural_task_create_output_port::AgriculturalTaskCreateOutputPort;
pub use agricultural_task_destroy_output_port::{
    AgriculturalTaskDestroyOutputPort, DestroyFailure,
};
pub use agricultural_task_detail_output_port::{
    AgriculturalTaskDetailOutputPort, DetailFailure,
};
pub use agricultural_task_list_output_port::{AgriculturalTaskListOutputPort, ListFailure};
pub use agricultural_task_update_output_port::{
    AgriculturalTaskUpdateOutputPort, UpdateFailure,
};
