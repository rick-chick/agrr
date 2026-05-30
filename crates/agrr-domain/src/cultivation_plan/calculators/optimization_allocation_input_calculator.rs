//! Ruby: `CultivationPlanOptimizeInteractor#prepare_allocation_data`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::CultivationPlanCropWithAgrr;
use crate::shared::ports::LoggerPort;
use crate::weather_data::helpers::copy_and_deep_freeze;

const DEFAULT_REVENUE_PER_AREA: f64 = 5000.0;
const DAILY_FIXED_COST: f64 = 10.0;

/// Builds agrr allocate `fields` and `crops` payloads (Rails `prepare_allocation_data`).
pub struct OptimizationAllocationInputCalculator;

impl OptimizationAllocationInputCalculator {
    pub fn build(
        total_area: f64,
        plan_crops: &[CultivationPlanCropWithAgrr],
        logger: &dyn LoggerPort,
    ) -> (Vec<Value>, Vec<Value>) {
        let mut crops_collection: BTreeMap<String, CultivationPlanCropWithAgrr> = BTreeMap::new();
        for cpc in plan_crops {
            let crop_key = cpc.crop_id.to_string();
            crops_collection
                .entry(crop_key)
                .or_insert_with(|| cpc.clone());
        }

        let crop_count = crops_collection.len().max(1);
        let field_count = crop_count.max(1);
        let area_per_field = total_area / field_count as f64;

        logger.info(&format!(
            "📊 [AGRR] Total area: {total_area}㎡, Crop count: {}, Field count: {field_count} (1 field per crop)",
            crops_collection.len()
        ));
        logger.info(&format!(
            "📊 [AGRR] Area per field: {:.2}㎡",
            area_per_field
        ));

        let mut fields_data = Vec::with_capacity(field_count);
        for i in 0..field_count {
            let field_id = i + 1;
            fields_data.push(json!({
                "field_id": field_id,
                "name": format!("圃場{}", i + 1),
                "area": area_per_field,
                "daily_fixed_cost": DAILY_FIXED_COST,
            }));
        }

        let mut crops_data = Vec::with_capacity(crops_collection.len());
        for cpc in crops_collection.values() {
            let mut crop_requirement = copy_and_deep_freeze(Some(cpc.agrr_requirement.clone()))
                .unwrap_or(Value::Null);

            let revenue_per_area = cpc.revenue_per_area.unwrap_or(DEFAULT_REVENUE_PER_AREA);
            let crop_count_f = crops_collection.len() as f64;

            if let Some(crop_obj) = crop_requirement.get_mut("crop").and_then(|v| v.as_object_mut())
            {
                let original_max_revenue = crop_obj
                    .get("max_revenue")
                    .and_then(|v| v.as_f64())
                    .unwrap_or(0.0);
                let adjusted_max_revenue =
                    (revenue_per_area * total_area * 3.0) / crop_count_f;
                crop_obj.insert("max_revenue".into(), json!(adjusted_max_revenue));

                logger.info(&format!(
                    "🔧 [AGRR] Crop '{}' - revenue_per_area: ¥{}/㎡, \
                     max_revenue: ¥{:.0} → ¥{:.0} (limited to ~{:.1}㎡, 3 crops)",
                    cpc.crop_name,
                    revenue_per_area,
                    original_max_revenue,
                    adjusted_max_revenue,
                    adjusted_max_revenue / revenue_per_area
                ));
            }

            crops_data.push(crop_requirement);
        }

        (fields_data, crops_data)
    }
}

#[cfg(test)]
mod calculators_optimization_allocation_input_calculator_test_inline {
    use super::*;
    use crate::cultivation_plan::dtos::CultivationPlanCropWithAgrr;
    use crate::shared::ports::LoggerPort;
    use serde_json::json;

    struct SilentLogger;

    impl LoggerPort for SilentLogger {
        fn info(&self, _message: &str) {}
        fn warn(&self, _message: &str) {}
        fn error(&self, _message: &str) {}
        fn debug(&self, _message: &str) {}
    }

    fn sample_crop(crop_id: i64, revenue: Option<f64>) -> CultivationPlanCropWithAgrr {
        CultivationPlanCropWithAgrr::new(
            crop_id,
            format!("cpc-{crop_id}"),
            crop_id,
            json!({
                "crop": {
                    "crop_id": crop_id.to_string(),
                    "name": format!("Crop{crop_id}"),
                    "max_revenue": 1000.0,
                    "groups": []
                },
                "stage_requirements": []
            }),
            revenue,
            format!("Crop{crop_id}"),
        )
    }

    #[test]
    fn field_count_matches_unique_crop_count_with_even_area_and_daily_fixed_cost() {
        let crops = vec![sample_crop(1, Some(4000.0)), sample_crop(2, None)];
        let (fields, crops_data) =
            OptimizationAllocationInputCalculator::build(300.0, &crops, &SilentLogger);
        assert_eq!(fields.len(), 2);
        assert_eq!(crops_data.len(), 2);
        assert_eq!(fields[0]["field_id"], 1);
        assert_eq!(fields[1]["field_id"], 2);
        assert_eq!(fields[0]["name"], "圃場1");
        assert_eq!(fields[1]["name"], "圃場2");
        assert!((fields[0]["area"].as_f64().unwrap() - 150.0).abs() < 0.001);
        assert!((fields[1]["area"].as_f64().unwrap() - 150.0).abs() < 0.001);
        assert_eq!(fields[0]["daily_fixed_cost"], 10.0);
    }

    #[test]
    fn max_revenue_formula_matches_rails_prepare_allocation_data() {
        let crops = vec![sample_crop(10, Some(5000.0))];
        let total_area = 600.0;
        let (_, crops_data) =
            OptimizationAllocationInputCalculator::build(total_area, &crops, &SilentLogger);
        let max_revenue = crops_data[0]["crop"]["max_revenue"].as_f64().unwrap();
        let expected = (5000.0 * total_area * 3.0) / 1.0;
        assert!((max_revenue - expected).abs() < 0.001);
    }
}
