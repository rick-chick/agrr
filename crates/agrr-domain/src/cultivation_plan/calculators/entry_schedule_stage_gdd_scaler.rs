//! Ruby: `Domain::CultivationPlan::Calculators::EntryScheduleStageGddScaler`

use serde_json::Value;

use crate::shared::helpers::deep_dup;

pub const DEFAULT_MAX_TOTAL_GDD_FOR_OPTIMIZE: f64 = 2000.0;

pub fn call(requirement_hash: &Value, max_total_gdd: Option<f64>, env_max: Option<f64>) -> Value {
    let mut max_total = max_total_gdd.or(env_max);
    if max_total.is_none() || max_total.unwrap_or(0.0) <= 0.0 {
        max_total = Some(DEFAULT_MAX_TOTAL_GDD_FOR_OPTIMIZE);
    }
    let max_total = max_total.unwrap();

    let mut req = deep_dup(requirement_hash);
    let Some(stages) = req.get_mut("stage_requirements").and_then(|v| v.as_array_mut()) else {
        return req;
    };

    let sum: f64 = stages
        .iter()
        .filter_map(|s| {
            s.get("thermal")
                .and_then(|t| t.get("required_gdd"))
                .and_then(|g| g.as_f64())
        })
        .sum();

    if sum <= 0.0 || sum <= max_total {
        return req;
    }

    let factor = max_total / sum;
    for stage in stages.iter_mut() {
        if let Some(thermal) = stage.get_mut("thermal") {
            if let Some(gdd) = thermal.get("required_gdd").and_then(|v| v.as_f64()) {
                let scaled = (gdd * factor * 100.0).round() / 100.0;
                thermal["required_gdd"] = serde_json::json!(scaled);
            }
        }
    }
    req
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    // Ruby: test "scales down stage required_gdd when sum exceeds cap"
    #[test]
    fn scales_down_stage_required_gdd_when_sum_exceeds_cap() {
        let req = json!({
            "stage_requirements": [
                { "thermal": { "required_gdd": 800.0 } },
                { "thermal": { "required_gdd": 800.0 } }
            ]
        });
        let out = call(&req, Some(1000.0), None);
        let stages = out["stage_requirements"].as_array().unwrap();
        let total: f64 = stages
            .iter()
            .filter_map(|s| s["thermal"]["required_gdd"].as_f64())
            .sum();
        assert!((total - 1000.0).abs() < 0.01);
        assert!((stages[0]["thermal"]["required_gdd"].as_f64().unwrap() - 500.0).abs() < 0.01);
    }

    // Ruby: test "returns copy unchanged when sum is within cap"
    #[test]
    fn returns_copy_unchanged_when_sum_within_cap() {
        let req = json!({
            "stage_requirements": [
                { "thermal": { "required_gdd": 100.0 } }
            ]
        });
        let out = call(&req, Some(1000.0), None);
        assert!(
            (out["stage_requirements"][0]["thermal"]["required_gdd"]
                .as_f64()
                .unwrap()
                - 100.0)
                .abs()
                < 0.01
        );
    }
}
