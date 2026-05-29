use time::Date;

pub fn prediction_days(completion_date: Date, training_end_date: Date) -> i64 {
    (completion_date - training_end_date).whole_days()
}

pub fn use_prediction_branch(prediction_days: i64) -> bool {
    prediction_days > 0
}

#[cfg(test)]
mod policies_field_cultivation_climate_fallback_horizon_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/policies_field_cultivation_climate_fallback_horizon_policy_test.rs"));
}
