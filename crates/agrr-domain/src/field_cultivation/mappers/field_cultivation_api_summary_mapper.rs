//! Ruby: `Domain::FieldCultivation::Mappers::FieldCultivationApiSummaryMapper`

use crate::field_cultivation::dtos::{FieldCultivationApiSummary, FieldCultivationApiSummarySnapshot};

pub fn from_snapshot(snapshot: &FieldCultivationApiSummarySnapshot) -> FieldCultivationApiSummary {
    FieldCultivationApiSummary {
        id: snapshot.id,
        field_name: snapshot.field_name.clone(),
        crop_name: snapshot.crop_name.clone(),
        area: snapshot.area,
        start_date: snapshot.start_date,
        completion_date: snapshot.completion_date,
        cultivation_days: snapshot.cultivation_days,
        estimated_cost: snapshot.estimated_cost,
        gdd: snapshot.gdd,
        status: snapshot.status.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use time::macros::date;

    fn sample_snapshot(gdd: Option<f64>) -> FieldCultivationApiSummarySnapshot {
        FieldCultivationApiSummarySnapshot {
            id: 42,
            field_name: "North plot".into(),
            crop_name: "Tomato".into(),
            area: 120.5,
            start_date: date!(2026 - 04 - 01),
            completion_date: date!(2026 - 08 - 01),
            cultivation_days: 123,
            estimated_cost: 9_999.0,
            gdd,
            status: "completed".into(),
        }
    }

    #[test]
    fn from_snapshot_maps_required_fields() {
        let snapshot = sample_snapshot(Some(875.25));
        let dto = from_snapshot(&snapshot);

        assert_eq!(dto.id, 42);
        assert_eq!(dto.field_name, "North plot");
        assert_eq!(dto.crop_name, "Tomato");
        assert!((dto.area - 120.5).abs() < f64::EPSILON);
        assert_eq!(dto.start_date, date!(2026 - 04 - 01));
        assert_eq!(dto.completion_date, date!(2026 - 08 - 01));
        assert_eq!(dto.cultivation_days, 123);
        assert!((dto.estimated_cost - 9_999.0).abs() < f64::EPSILON);
        assert_eq!(dto.status, "completed");
    }

    #[test]
    fn from_snapshot_preserves_gdd_when_present() {
        let dto = from_snapshot(&sample_snapshot(Some(875.25)));
        assert_eq!(dto.gdd, Some(875.25));
    }

    #[test]
    fn from_snapshot_preserves_none_gdd() {
        let dto = from_snapshot(&sample_snapshot(None));
        assert_eq!(dto.gdd, None);
    }
}
