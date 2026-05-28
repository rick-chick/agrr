//! Ruby: `Domain::CultivationPlan::Calculators::CultivationPlanOptimizationProgressCalculator`

use crate::cultivation_plan::entities::FieldCultivationEntity;

pub fn progress_percent(field_cultivations: &[FieldCultivationEntity]) -> i32 {
    if field_cultivations.is_empty() {
        return 0;
    }
    let completed = field_cultivations
        .iter()
        .filter(|fc| fc.status.as_deref() == Some("completed"))
        .count();
    ((completed as f64 / field_cultivations.len() as f64) * 100.0).round() as i32
}
