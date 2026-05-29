//! Ruby: `Domain::FieldCultivation::Mappers::FieldCultivationApiSummaryMapper`

use time::Date;

use crate::field_cultivation::dtos::FieldCultivationApiSummary;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationApiSummaryWire {
    pub id: i64,
    pub field_name: String,
    pub crop_name: String,
    pub area: f64,
    pub start_date: Date,
    pub completion_date: Date,
    pub cultivation_days: i32,
    pub estimated_cost: f64,
    pub gdd: Option<f64>,
    pub status: String,
}

pub fn from_wire(wire: &FieldCultivationApiSummaryWire) -> FieldCultivationApiSummary {
    FieldCultivationApiSummary {
        id: wire.id,
        field_name: wire.field_name.clone(),
        crop_name: wire.crop_name.clone(),
        area: wire.area,
        start_date: wire.start_date,
        completion_date: wire.completion_date,
        cultivation_days: wire.cultivation_days,
        estimated_cost: wire.estimated_cost,
        gdd: wire.gdd,
        status: wire.status.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use time::macros::date;

    fn sample_wire(gdd: Option<f64>) -> FieldCultivationApiSummaryWire {
        FieldCultivationApiSummaryWire {
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
    fn from_wire_maps_required_fields() {
        let wire = sample_wire(Some(875.25));
        let dto = from_wire(&wire);

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
    fn from_wire_preserves_gdd_when_present() {
        let dto = from_wire(&sample_wire(Some(875.25)));
        assert_eq!(dto.gdd, Some(875.25));
    }

    #[test]
    fn from_wire_preserves_none_gdd() {
        let dto = from_wire(&sample_wire(None));
        assert_eq!(dto.gdd, None);
    }
}
