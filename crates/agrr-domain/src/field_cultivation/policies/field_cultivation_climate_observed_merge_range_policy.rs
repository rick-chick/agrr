use time::Date;

use crate::field_cultivation::dtos::FieldCultivationClimateObservedMergeRangeDecision;
use crate::field_cultivation::mappers::field_cultivation_climate_weather_payload_mapper::coerce_optional_date;

pub fn resolve_observed_merge_range(
    display_start_date: Option<&str>,
    display_end_date: Option<&str>,
    cultivation_start_date: Option<Date>,
    cultivation_end_date: Option<Date>,
    today: Date,
) -> FieldCultivationClimateObservedMergeRangeDecision {
    let _ = (display_start_date, display_end_date);
    let observed_start = cultivation_start_date;
    let observed_end = cultivation_end_date;

    let (Some(observed_start), Some(observed_end)) = (observed_start, observed_end) else {
        return FieldCultivationClimateObservedMergeRangeDecision::skip();
    };

    let actual_end = observed_end.min(today - time::Duration::days(1));
    if observed_start > actual_end {
        return FieldCultivationClimateObservedMergeRangeDecision::skip();
    }

    FieldCultivationClimateObservedMergeRangeDecision::range(observed_start, actual_end)
}

#[cfg(test)]
mod policies_field_cultivation_climate_observed_merge_range_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/policies_field_cultivation_climate_observed_merge_range_policy_test.rs"));
}
