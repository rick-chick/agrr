use crate::pesticide::dtos::{
    PesticideApplicationDetailSnapshot, PesticideUsageConstraintSnapshot,
};
use crate::pesticide::entities::PesticideEntity;

/// Ruby: `Domain::Pesticide::Dtos::PesticideDetailOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct PesticideDetailOutput {
    pub pesticide: PesticideEntity,
    pub crop_name: Option<String>,
    pub pest_name: Option<String>,
    pub usage_constraint_snapshot: Option<PesticideUsageConstraintSnapshot>,
    pub application_detail_snapshot: Option<PesticideApplicationDetailSnapshot>,
}

impl PesticideDetailOutput {
    pub fn new(
        pesticide: PesticideEntity,
        crop_name: Option<String>,
        pest_name: Option<String>,
        usage_constraint_snapshot: Option<PesticideUsageConstraintSnapshot>,
        application_detail_snapshot: Option<PesticideApplicationDetailSnapshot>,
    ) -> Self {
        Self {
            pesticide,
            crop_name,
            pest_name,
            usage_constraint_snapshot,
            application_detail_snapshot,
        }
    }
}
