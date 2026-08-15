//! Output port for variance portfolio list.

use crate::shared::dtos::Error;
use crate::work_record::dtos::VariancePortfolioRow;

pub trait VariancePortfolioOutputPort {
    fn on_success(&mut self, rows: Vec<VariancePortfolioRow>);
    fn on_failure(&mut self, error: Error);
}
