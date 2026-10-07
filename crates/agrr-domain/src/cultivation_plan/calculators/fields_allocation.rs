//! Ruby: `Domain::CultivationPlan::FieldsAllocation`

use crate::cultivation_plan::constants::MAX_FIELDS;
use crate::cultivation_plan::dtos::CultivationPlanInitCrop;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldAllocation {
    pub crop: CultivationPlanInitCrop,
    pub area: f64,
}

pub struct FieldsAllocation<'a> {
    total_area: f64,
    crops: &'a [CultivationPlanInitCrop],
}

impl<'a> FieldsAllocation<'a> {
    pub fn new(total_area: f64, crops: &'a [CultivationPlanInitCrop]) -> Self {
        Self { total_area, crops }
    }

    pub fn allocate(&self) -> Result<Vec<FieldAllocation>, &'static str> {
        if self.total_area <= 0.0 {
            return Err("invalid_total_area");
        }
        if self.crops.is_empty() {
            return Err("no_crops");
        }

        let field_count = self.field_count();
        let base_area = (self.total_area / field_count as f64).floor();
        let remainder = (self.total_area - base_area * field_count as f64).round() as i32;

        let allocations = self
            .prioritized_crops(field_count)
            .into_iter()
            .enumerate()
            .map(|(index, crop)| {
                let additional = if (index as i32) < remainder { 1.0 } else { 0.0 };
                FieldAllocation {
                    crop,
                    area: base_area + additional,
                }
            })
            .collect();
        Ok(allocations)
    }

    pub fn field_count(&self) -> usize {
        let max_count = self.crops.len().min(MAX_FIELDS as usize);
        (1..=max_count)
            .rev()
            .find(|&count| (self.total_area / count as f64) >= self.max_area_per_unit())
            .unwrap_or(1)
    }

    fn max_area_per_unit(&self) -> f64 {
        self.crops
            .iter()
            .map(|c| c.area_per_unit)
            .fold(10.0_f64, f64::max)
    }

    fn prioritized_crops(&self, field_count: usize) -> Vec<CultivationPlanInitCrop> {
        let mut sorted: Vec<_> = self.crops.to_vec();
        sorted.sort_by(|a, b| {
            b.area_per_unit
                .partial_cmp(&a.area_per_unit)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        sorted.into_iter().take(field_count).collect()
    }
}

#[cfg(test)]
mod calculators_fields_allocation_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/calculators_fields_allocation_test.rs"
    ));
}
