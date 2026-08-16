//! Maps weather reschedule read context into API proposal DTOs.

use serde_json::json;
use time::{Date, Duration};

use crate::cultivation_plan::dtos::weather_reschedule_proposal_context::WeatherRescheduleProposalContext;
use crate::cultivation_plan::dtos::weather_reschedule_proposal_read::{
    WeatherRescheduleProposalRead, WeatherRescheduleTriggerType,
};
use crate::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    classify_forecast_sudden_change_triggers, classify_frost_forecast_triggers,
    classify_gdd_trajectory_delay_triggers, WeatherRescheduleTrigger,
    WeatherRescheduleTriggerKind, DEFAULT_FORECAST_SUDDEN_CHANGE_THRESHOLD,
    DEFAULT_GDD_TRAJECTORY_DELAY_THRESHOLD,
};

const DEFAULT_GDD_SHIFT_DAYS_PER_UNIT: f64 = 5.0;

pub struct WeatherRescheduleProposalMapper;

impl WeatherRescheduleProposalMapper {
    pub fn proposals_from_context(
        context: &WeatherRescheduleProposalContext,
    ) -> Vec<WeatherRescheduleProposalRead> {
        let mut proposals = Vec::new();

        for cultivation in &context.cultivations {
            let tasks_for_cultivation: Vec<_> = context
                .tasks
                .iter()
                .filter(|task| task.field_cultivation_id == cultivation.field_cultivation_id)
                .cloned()
                .collect();

            let frost_triggers = classify_frost_forecast_triggers(
                &context.current_forecast,
                cultivation.frost_threshold,
                &tasks_for_cultivation,
            );
            for trigger in frost_triggers {
                if let Some(proposal) =
                    Self::proposal_from_trigger(context, &trigger, cultivation)
                {
                    proposals.push(proposal);
                }
            }
        }

        let gdd_triggers = classify_gdd_trajectory_delay_triggers(
            &context.gdd_samples,
            DEFAULT_GDD_TRAJECTORY_DELAY_THRESHOLD,
        );
        for trigger in gdd_triggers {
            if let Some(cultivation) = context.cultivation_by_id(trigger.field_cultivation_id) {
                if let Some(proposal) =
                    Self::proposal_from_trigger(context, &trigger, cultivation)
                {
                    proposals.push(proposal);
                }
            }
        }

        if !context.previous_forecast.is_empty() {
            let sudden_change_triggers = classify_forecast_sudden_change_triggers(
                &context.previous_forecast,
                &context.current_forecast,
                DEFAULT_FORECAST_SUDDEN_CHANGE_THRESHOLD,
            );
            for trigger in sudden_change_triggers {
                if trigger.field_cultivation_id == 0 {
                    for cultivation in &context.cultivations {
                        let mut scoped = trigger.clone();
                        scoped.field_cultivation_id = cultivation.field_cultivation_id;
                        if let Some(proposal) =
                            Self::proposal_from_trigger(context, &scoped, cultivation)
                        {
                            proposals.push(proposal);
                        }
                    }
                } else if let Some(cultivation) =
                    context.cultivation_by_id(trigger.field_cultivation_id)
                {
                    if let Some(proposal) =
                        Self::proposal_from_trigger(context, &trigger, cultivation)
                    {
                        proposals.push(proposal);
                    }
                }
            }
        }

        proposals
    }

    fn proposal_from_trigger(
        context: &WeatherRescheduleProposalContext,
        trigger: &WeatherRescheduleTrigger,
        cultivation: &crate::cultivation_plan::dtos::weather_reschedule_proposal_context::WeatherRescheduleCultivationSnapshot,
    ) -> Option<WeatherRescheduleProposalRead> {
        let trigger_type = match trigger.kind {
            WeatherRescheduleTriggerKind::FrostForecast => {
                WeatherRescheduleTriggerType::FrostForecast
            }
            WeatherRescheduleTriggerKind::GddTrajectoryDelay => {
                WeatherRescheduleTriggerType::GddTrajectoryDelay
            }
            WeatherRescheduleTriggerKind::ForecastSuddenChange => {
                WeatherRescheduleTriggerType::ForecastSuddenChange
            }
        };

        let to_start_date = Self::proposed_start_date(context, trigger, cultivation)?;
        let item_id = trigger.item_id.unwrap_or(0);
        let id = format!(
            "{}:{}:{}",
            trigger.kind.as_str(),
            cultivation.field_cultivation_id,
            item_id
        );

        let severity = Self::severity_for_trigger(trigger);
        let rationale = Self::rationale_for_trigger(trigger, cultivation);
        let moves = vec![json!({
            "allocation_id": cultivation.field_cultivation_id,
            "action": "move",
            "to_field_id": cultivation.plan_field_id,
            "to_start_date": to_start_date.to_string(),
        })];

        Some(WeatherRescheduleProposalRead {
            id,
            trigger_type,
            severity,
            rationale,
            moves,
        })
    }

    fn proposed_start_date(
        context: &WeatherRescheduleProposalContext,
        trigger: &WeatherRescheduleTrigger,
        cultivation: &crate::cultivation_plan::dtos::weather_reschedule_proposal_context::WeatherRescheduleCultivationSnapshot,
    ) -> Option<Date> {
        let start_date = cultivation.start_date?;

        match trigger.kind {
            WeatherRescheduleTriggerKind::FrostForecast => {
                let threshold = trigger.frost_threshold?;
                let trigger_date = trigger.trigger_date?;
                let safe_date = context
                    .current_forecast
                    .iter()
                    .filter(|day| day.date >= trigger_date && day.t_min >= threshold)
                    .map(|day| day.date)
                    .min()?;
                Some(safe_date)
            }
            WeatherRescheduleTriggerKind::GddTrajectoryDelay => {
                let delta = trigger.gdd_delta?.abs();
                let shift_days = (delta / DEFAULT_GDD_SHIFT_DAYS_PER_UNIT).ceil() as i64;
                let shift_days = shift_days.max(1);
                start_date.checked_add(Duration::days(shift_days))
            }
            WeatherRescheduleTriggerKind::ForecastSuddenChange => {
                let trigger_date = trigger.trigger_date?;
                start_date
                    .checked_add(Duration::days(
                        (trigger_date - start_date).whole_days().max(0) + 1,
                    ))
                    .or(Some(trigger_date))
            }
        }
    }

    fn severity_for_trigger(trigger: &WeatherRescheduleTrigger) -> String {
        match trigger.kind {
            WeatherRescheduleTriggerKind::FrostForecast => {
                let threshold = trigger.frost_threshold.unwrap_or(0.0);
                let t_min = trigger.forecast_t_min.unwrap_or(threshold);
                if t_min < threshold - 2.0 {
                    "high".into()
                } else {
                    "medium".into()
                }
            }
            WeatherRescheduleTriggerKind::GddTrajectoryDelay => {
                let delta = trigger.gdd_delta.unwrap_or(0.0).abs();
                if delta > DEFAULT_GDD_TRAJECTORY_DELAY_THRESHOLD * 2.0 {
                    "high".into()
                } else {
                    "medium".into()
                }
            }
            WeatherRescheduleTriggerKind::ForecastSuddenChange => "medium".into(),
        }
    }

    fn rationale_for_trigger(
        trigger: &WeatherRescheduleTrigger,
        cultivation: &crate::cultivation_plan::dtos::weather_reschedule_proposal_context::WeatherRescheduleCultivationSnapshot,
    ) -> serde_json::Value {
        json!({
            "field_cultivation_id": cultivation.field_cultivation_id,
            "task_schedule_item_id": trigger.item_id,
            "trigger_date": trigger.trigger_date.map(|d| d.to_string()),
            "forecast_t_min": trigger.forecast_t_min,
            "frost_threshold": trigger.frost_threshold,
            "gdd_delta": trigger.gdd_delta,
            "forecast_t_min_delta": trigger.forecast_t_min_delta,
            "gdd_trajectory_delay_threshold": DEFAULT_GDD_TRAJECTORY_DELAY_THRESHOLD,
            "target_cultivation": {
                "crop_name": cultivation.crop_name,
                "field_name": cultivation.field_name,
                "start_date": cultivation.start_date.map(|d| d.to_string()),
                "completion_date": cultivation.completion_date.map(|d| d.to_string()),
            }
        })
    }
}

#[cfg(test)]
mod weather_reschedule_proposal_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/mappers_weather_reschedule_proposal_mapper_test.rs"
    ));
}
