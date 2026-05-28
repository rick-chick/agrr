//! Output port traits for agricultural task interactors.

pub mod agricultural_task_create_output_port;
pub mod agricultural_task_destroy_output_port;
pub mod agricultural_task_detail_output_port;
pub mod agricultural_task_list_output_port;
pub mod agricultural_task_update_output_port;

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
