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
mod tests {
    use super::*;

    // Ruby: test "from_snapshots builds session dto from header and field rows"
    #[test]
    fn from_snapshots_builds_session_dto_from_header_and_field_rows() {
        let header = PublicPlanSaveHeaderSnapshot::new(99, Some(7));
        let field_rows = vec![PublicPlanSaveFieldDatum::new(
            Some("F1"),
            Some(5.0),
            vec![35.0, 139.0],
        )];

        let dto = from_snapshots(&header, &field_rows);

        assert_eq!(dto.plan_id, 99);
        assert_eq!(dto.farm_id, Some(7));
        assert_eq!(dto.field_data.len(), 1);
        assert_eq!(dto.field_data[0].name.as_deref(), Some("F1"));
    }
}
