use time::Date;

use crate::field_cultivation::dtos::FieldCultivationClimateObservedMergeRangeDecision;

pub fn resolve_observed_merge_range(
    cultivation_start_date: Option<Date>,
    cultivation_end_date: Option<Date>,
    today: Date,
) -> FieldCultivationClimateObservedMergeRangeDecision {
    let (Some(observed_start), Some(observed_end)) = (cultivation_start_date, cultivation_end_date)
    else {
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
