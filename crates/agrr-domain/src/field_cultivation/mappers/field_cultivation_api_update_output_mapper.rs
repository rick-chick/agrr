//! Ruby: `Domain::FieldCultivation::Mappers::FieldCultivationApiUpdateOutputMapper`

use crate::field_cultivation::dtos::{
    FieldCultivationApiUpdateOutput, FieldCultivationApiUpdateOutputSnapshot,
};

pub fn from_snapshot(
    snapshot: &FieldCultivationApiUpdateOutputSnapshot,
) -> FieldCultivationApiUpdateOutput {
    FieldCultivationApiUpdateOutput {
        field_cultivation_id: snapshot.field_cultivation_id,
        start_date: snapshot.start_date.clone(),
        completion_date: snapshot.completion_date.clone(),
        cultivation_days: snapshot.cultivation_days,
        message: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_snapshot(cultivation_days: Option<i32>) -> FieldCultivationApiUpdateOutputSnapshot {
        FieldCultivationApiUpdateOutputSnapshot {
            field_cultivation_id: 7,
            start_date: "2026-05-01".into(),
            completion_date: "2026-07-30".into(),
            cultivation_days,
        }
    }

    #[test]
    fn from_snapshot_maps_schedule_fields() {
        let dto = from_snapshot(&sample_snapshot(Some(90)));

        assert_eq!(dto.field_cultivation_id, 7);
        assert_eq!(dto.start_date, "2026-05-01");
        assert_eq!(dto.completion_date, "2026-07-30");
        assert_eq!(dto.cultivation_days, Some(90));
        assert_eq!(dto.message, None);
        assert!(!dto.public_plan_response());
    }

    #[test]
    fn from_snapshot_preserves_none_cultivation_days() {
        let dto = from_snapshot(&sample_snapshot(None));

        assert_eq!(dto.cultivation_days, None);
    }
}
