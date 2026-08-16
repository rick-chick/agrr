// Tests for `mappers/weather_reschedule_proposal_mapper.rs`.

use time::{Date, Month};

use crate::cultivation_plan::dtos::weather_reschedule_proposal_context::{
    WeatherRescheduleCultivationSnapshot, WeatherRescheduleProposalContext,
};
use crate::cultivation_plan::dtos::weather_reschedule_proposal_read::WeatherRescheduleTriggerType;
use crate::cultivation_plan::mappers::weather_reschedule_proposal_mapper::WeatherRescheduleProposalMapper;
use crate::cultivation_plan::policies::weather_reschedule_trigger_policy::{
    GddTrajectorySample, WeatherForecastDay, WeatherRescheduleTaskSchedule,
};

fn date(y: i32, m: u8, d: u8) -> Date {
    Date::from_calendar_date(y, Month::try_from(m).unwrap(), d).unwrap()
}

fn sample_cultivation() -> WeatherRescheduleCultivationSnapshot {
    WeatherRescheduleCultivationSnapshot {
        field_cultivation_id: 100,
        plan_field_id: 7,
        start_date: Some(date(2026, 4, 1)),
        completion_date: Some(date(2026, 8, 31)),
        crop_name: "Tomato".into(),
        field_name: "North Field".into(),
        frost_threshold: Some(0.0),
    }
}

#[test]
fn frost_forecast_trigger_produces_proposal_with_rationale_and_move() {
    let context = WeatherRescheduleProposalContext {
        tasks: vec![WeatherRescheduleTaskSchedule {
            item_id: 42,
            field_cultivation_id: 100,
            scheduled_date: date(2026, 4, 10),
        }],
        current_forecast: vec![
            WeatherForecastDay {
                date: date(2026, 4, 10),
                t_min: -2.0,
                t_mean: Some(5.0),
            },
            WeatherForecastDay {
                date: date(2026, 4, 11),
                t_min: 2.0,
                t_mean: Some(8.0),
            },
        ],
        previous_forecast: vec![],
        gdd_samples: vec![],
        cultivations: vec![sample_cultivation()],
    };

    let proposals = WeatherRescheduleProposalMapper::proposals_from_context(&context);

    assert_eq!(proposals.len(), 1);
    let proposal = &proposals[0];
    assert_eq!(proposal.trigger_type, WeatherRescheduleTriggerType::FrostForecast);
    assert_eq!(proposal.id, "frost_forecast:100:42");
    assert!(!proposal.severity.is_empty());
    assert_eq!(proposal.rationale["field_cultivation_id"], 100);
    assert_eq!(proposal.rationale["task_schedule_item_id"], 42);
    assert_eq!(proposal.rationale["forecast_t_min"], -2.0);
    assert_eq!(proposal.rationale["frost_threshold"], 0.0);
    assert_eq!(proposal.rationale["target_cultivation"]["crop_name"], "Tomato");
    assert_eq!(proposal.moves.len(), 1);
    assert_eq!(proposal.moves[0]["action"], "move");
    assert_eq!(proposal.moves[0]["allocation_id"], 100);
    assert_eq!(proposal.moves[0]["to_field_id"], 7);
    assert_eq!(proposal.moves[0]["to_start_date"], "2026-04-11");
}

#[test]
fn gdd_trajectory_delay_produces_proposal_with_shift_move() {
    let context = WeatherRescheduleProposalContext {
        tasks: vec![],
        current_forecast: vec![],
        previous_forecast: vec![],
        gdd_samples: vec![GddTrajectorySample {
            field_cultivation_id: 100,
            reference_date: date(2026, 5, 1),
            cumulative_gdd_actual: 80.0,
            cumulative_gdd_planned: 100.0,
        }],
        cultivations: vec![sample_cultivation()],
    };

    let proposals = WeatherRescheduleProposalMapper::proposals_from_context(&context);

    assert_eq!(proposals.len(), 1);
    let proposal = &proposals[0];
    assert_eq!(
        proposal.trigger_type,
        WeatherRescheduleTriggerType::GddTrajectoryDelay
    );
    assert_eq!(proposal.id, "gdd_trajectory_delay:100:0");
    assert_eq!(proposal.rationale["gdd_delta"], 20.0);
    assert_eq!(proposal.moves.len(), 1);
    assert_eq!(proposal.moves[0]["action"], "move");
    assert_eq!(proposal.moves[0]["to_start_date"], "2026-04-05");
}

#[test]
fn empty_context_returns_no_proposals() {
    let context = WeatherRescheduleProposalContext {
        tasks: vec![],
        current_forecast: vec![],
        previous_forecast: vec![],
        gdd_samples: vec![],
        cultivations: vec![],
    };

    let proposals = WeatherRescheduleProposalMapper::proposals_from_context(&context);

    assert!(proposals.is_empty());
}

#[test]
fn forecast_sudden_change_skipped_without_previous_forecast() {
    let context = WeatherRescheduleProposalContext {
        tasks: vec![],
        current_forecast: vec![WeatherForecastDay {
            date: date(2026, 4, 10),
            t_min: -5.0,
            t_mean: Some(0.0),
        }],
        previous_forecast: vec![],
        gdd_samples: vec![],
        cultivations: vec![sample_cultivation()],
    };

    let proposals = WeatherRescheduleProposalMapper::proposals_from_context(&context);

    assert!(proposals.is_empty());
}
