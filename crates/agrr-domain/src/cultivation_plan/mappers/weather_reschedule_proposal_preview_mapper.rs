//! Maps adjust allocation payloads into preview before/after snapshots.

use serde_json::Value;

use crate::cultivation_plan::dtos::WeatherRescheduleProposalAllocationSnapshot;

pub struct WeatherRescheduleProposalPreviewMapper;

impl WeatherRescheduleProposalPreviewMapper {
    pub fn before_from_current_allocation(current_allocation: &Value) -> WeatherRescheduleProposalAllocationSnapshot {
        WeatherRescheduleProposalAllocationSnapshot {
            field_schedules: Self::field_schedules_from_allocation(current_allocation),
        }
    }

    pub fn after_from_adjust_result(adjust_result: &Value) -> WeatherRescheduleProposalAllocationSnapshot {
        WeatherRescheduleProposalAllocationSnapshot {
            field_schedules: Self::field_schedules_from_adjust_result(adjust_result),
        }
    }

    fn field_schedules_from_allocation(allocation: &Value) -> Vec<Value> {
        allocation
            .pointer("/optimization_result/field_schedules")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default()
    }

    fn field_schedules_from_adjust_result(result: &Value) -> Vec<Value> {
        result
            .get("field_schedules")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default()
    }
}

#[cfg(test)]
mod weather_reschedule_proposal_preview_mapper_test_inline {
    use super::*;
    use serde_json::json;

    #[test]
    fn before_extracts_field_schedules_from_current_allocation() {
        let allocation = json!({
            "optimization_result": {
                "field_schedules": [{ "field_id": "1", "allocations": [] }]
            }
        });
        let before = WeatherRescheduleProposalPreviewMapper::before_from_current_allocation(&allocation);
        assert_eq!(before.field_schedules.len(), 1);
        assert_eq!(before.field_schedules[0]["field_id"], "1");
    }

    #[test]
    fn after_extracts_field_schedules_from_adjust_result() {
        let result = json!({
            "field_schedules": [{ "field_id": "1", "allocations": [{ "start_date": "2026-04-11" }] }]
        });
        let after = WeatherRescheduleProposalPreviewMapper::after_from_adjust_result(&result);
        assert_eq!(after.field_schedules.len(), 1);
        assert_eq!(after.field_schedules[0]["allocations"][0]["start_date"], "2026-04-11");
    }
}
