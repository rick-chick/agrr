//! Output port for work hub list.

use crate::shared::dtos::Error;
use crate::work_record::dtos::WorkHubFarmRow;

pub trait WorkHubListOutputPort {
    fn on_success(&mut self, rows: Vec<WorkHubFarmRow>);
    fn on_failure(&mut self, error: Error);
}
