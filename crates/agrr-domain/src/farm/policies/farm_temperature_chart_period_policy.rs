//! Period normalization for farm temperature chart API.

const DEFAULT_PERIOD: &str = "90d";

/// Normalize `period` query to one of `30d` | `90d` | `180d` | `365d`.
pub fn normalize_period(period: Option<&str>) -> &'static str {
    match period.unwrap_or(DEFAULT_PERIOD) {
        "30d" => "30d",
        "90d" => "90d",
        "180d" => "180d",
        "365d" => "365d",
        _ => DEFAULT_PERIOD,
    }
}

/// Calendar-day span for a normalized period token.
pub fn period_days(period: &str) -> i64 {
    match period {
        "30d" => 30,
        "90d" => 90,
        "180d" => 180,
        "365d" => 365,
        _ => 90,
    }
}

#[cfg(test)]
mod policies_farm_temperature_chart_period_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/farm/policies_farm_temperature_chart_period_policy_test.rs"
    ));
}
