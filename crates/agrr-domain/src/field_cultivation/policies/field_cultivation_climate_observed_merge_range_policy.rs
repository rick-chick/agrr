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
    let display_start = display_start_date.and_then(coerce_optional_date);
    let display_end = display_end_date.and_then(coerce_optional_date);

    let (observed_start, observed_end) = if let (Some(s), Some(e)) = (display_start, display_end) {
        (Some(s), Some(e))
    } else {
        (cultivation_start_date, cultivation_end_date)
    };

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
mod tests {
    use super::*;
    use time::macros::date;

    #[test]
    fn caps_observed_end_at_today_minus_one() {
        let decision = resolve_observed_merge_range(
            None,
            None,
            Some(date!(2026 - 01 - 01)),
            Some(date!(2026 - 12 - 31)),
            date!(2026 - 03 - 10),
        );
        assert!(!decision.skip_merge());
        assert_eq!(decision.start_date, Some(date!(2026 - 01 - 01)));
        assert_eq!(decision.end_date, Some(date!(2026 - 03 - 09)));
    }

    #[test]
    fn skips_when_start_after_actual_end() {
        let decision = resolve_observed_merge_range(
            Some("2026-05-01"),
            Some("2026-06-01"),
            Some(date!(2026 - 01 - 01)),
            Some(date!(2026 - 12 - 31)),
            date!(2026 - 03 - 01),
        );
        assert!(decision.skip_merge());
    }
}
