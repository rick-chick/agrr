//! Ruby: `Domain::FieldCultivation::Mappers::FieldCultivationApiUpdateOutputMapper`

use crate::field_cultivation::dtos::FieldCultivationApiUpdateOutput;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldCultivationApiUpdateOutputWire {
    pub field_cultivation_id: i64,
    pub start_date: String,
    pub completion_date: String,
    pub cultivation_days: Option<i32>,
}

pub fn from_wire(wire: &FieldCultivationApiUpdateOutputWire) -> FieldCultivationApiUpdateOutput {
    FieldCultivationApiUpdateOutput {
        field_cultivation_id: wire.field_cultivation_id,
        start_date: wire.start_date.clone(),
        completion_date: wire.completion_date.clone(),
        cultivation_days: wire.cultivation_days,
        message: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_wire(cultivation_days: Option<i32>) -> FieldCultivationApiUpdateOutputWire {
        FieldCultivationApiUpdateOutputWire {
            field_cultivation_id: 7,
            start_date: "2026-05-01".into(),
            completion_date: "2026-07-30".into(),
            cultivation_days,
        }
    }

    #[test]
    fn from_wire_maps_schedule_fields() {
        let dto = from_wire(&sample_wire(Some(90)));

        assert_eq!(dto.field_cultivation_id, 7);
        assert_eq!(dto.start_date, "2026-05-01");
        assert_eq!(dto.completion_date, "2026-07-30");
        assert_eq!(dto.cultivation_days, Some(90));
        assert_eq!(dto.message, None);
        assert!(!dto.public_plan_response());
    }

    #[test]
    fn from_wire_preserves_none_cultivation_days() {
        let dto = from_wire(&sample_wire(None));

        assert_eq!(dto.cultivation_days, None);
    }
}
