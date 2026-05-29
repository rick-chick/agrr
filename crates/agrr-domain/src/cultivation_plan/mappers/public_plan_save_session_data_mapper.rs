//! Ruby: `Domain::CultivationPlan::Mappers::PublicPlanSaveSessionDataMapper`

use crate::cultivation_plan::dtos::{
    PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot, PublicPlanSaveSessionData,
};

pub fn from_snapshots(
    header: &PublicPlanSaveHeaderSnapshot,
    field_rows: &[PublicPlanSaveFieldDatum],
) -> PublicPlanSaveSessionData {
    PublicPlanSaveSessionData::new(
        header.plan_id,
        header.farm_id,
        field_rows.to_vec(),
        None,
    )
}

#[cfg(test)]
mod mappers_public_plan_save_session_data_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/mappers_public_plan_save_session_data_mapper_test.rs"));
}
