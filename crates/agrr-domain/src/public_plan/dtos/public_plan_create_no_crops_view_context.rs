//! Ruby: `Domain::PublicPlan::Dtos::PublicPlanCreateNoCropsViewContext`

use crate::public_plan::catalog::FarmSizeRecord;

/// Minimal farm for no-crops view context.
#[derive(Debug, Clone, PartialEq)]
pub struct PublicPlanFarm {
    pub id: i64,
    pub name: String,
    pub region: String,
}

/// Minimal crop row for no-crops view context.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublicPlanCrop {
    pub id: i64,
    pub name: String,
}

/// Ruby: `Domain::PublicPlan::Dtos::PublicPlanCreateNoCropsViewContext`
#[derive(Debug, Clone, PartialEq)]
pub struct PublicPlanCreateNoCropsViewContext {
    pub farm: PublicPlanFarm,
    pub farm_size: FarmSizeRecord,
    pub crops: Vec<PublicPlanCrop>,
}
