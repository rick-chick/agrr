//! Ruby: `Domain::CultivationPlan::Policies::CultivationPlanFieldPolicy`

use crate::cultivation_plan::constants::MAX_FIELDS;

pub fn invalid_field_area(field_area: f64) -> bool {
    field_area <= 0.0
}

pub fn max_fields_reached(existing_field_count: i32) -> bool {
    existing_field_count >= MAX_FIELDS
}

pub fn cannot_remove_last_field(existing_field_count: i32) -> bool {
    existing_field_count <= 1
}

pub fn cannot_remove_with_cultivations(cultivation_count: i32) -> bool {
    cultivation_count > 0
}

#[cfg(test)]
mod tests {
    use super::*;

    // Ruby: test "invalid_field_area? when zero or negative"
    #[test]
    fn invalid_field_area_when_zero_or_negative() {
        assert!(invalid_field_area(0.0));
        assert!(invalid_field_area(-1.0));
        assert!(!invalid_field_area(0.1));
    }

    // Ruby: test "max_fields_reached? at MAX_FIELDS"
    #[test]
    fn max_fields_reached_at_max_fields() {
        assert!(max_fields_reached(MAX_FIELDS));
        assert!(!max_fields_reached(MAX_FIELDS - 1));
    }

    // Ruby: test "cannot_remove_last_field? when one field"
    #[test]
    fn cannot_remove_last_field_when_one_field() {
        assert!(cannot_remove_last_field(1));
        assert!(!cannot_remove_last_field(2));
    }

    // Ruby: test "cannot_remove_with_cultivations? when count positive"
    #[test]
    fn cannot_remove_with_cultivations_when_count_positive() {
        assert!(cannot_remove_with_cultivations(1));
        assert!(!cannot_remove_with_cultivations(0));
    }
}
