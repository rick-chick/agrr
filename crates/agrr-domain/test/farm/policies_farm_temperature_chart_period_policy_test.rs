use crate::farm::policies::farm_temperature_chart_period_policy::{
    normalize_period, period_days,
};

#[test]
fn normalize_period_defaults_to_90d() {
    assert_eq!(normalize_period(None), "90d");
    assert_eq!(normalize_period(Some("")), "90d");
    assert_eq!(normalize_period(Some("invalid")), "90d");
}

#[test]
fn normalize_period_accepts_allowed_values() {
    assert_eq!(normalize_period(Some("30d")), "30d");
    assert_eq!(normalize_period(Some("180d")), "180d");
    assert_eq!(normalize_period(Some("365d")), "365d");
}

#[test]
fn period_days_matches_token() {
    assert_eq!(period_days("30d"), 30);
    assert_eq!(period_days("90d"), 90);
    assert_eq!(period_days("180d"), 180);
    assert_eq!(period_days("365d"), 365);
}
