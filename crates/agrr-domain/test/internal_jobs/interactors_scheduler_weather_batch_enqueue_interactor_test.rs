// Tests for `interactors/scheduler_weather_batch_enqueue_interactor.rs`.

use std::sync::Mutex;

use crate::internal_jobs::dtos::SchedulerWeatherFarmRow;
use crate::internal_jobs::gateways::SchedulerWeatherFarmListGateway;
use crate::internal_jobs::interactors::SchedulerWeatherBatchEnqueueInteractor;
use crate::internal_jobs::ports::SchedulerWeatherFetchSchedulePort;
use crate::shared::ports::ClockPort;
use time::{Date, Month, OffsetDateTime, Time};

struct FakeClock {
    today: Date,
}

impl ClockPort for FakeClock {
    fn today(&self) -> Date {
        self.today
    }

    fn now(&self) -> OffsetDateTime {
        OffsetDateTime::new_utc(self.today, Time::MIDNIGHT)
    }
}

struct FakeListGateway {
    reference: Vec<SchedulerWeatherFarmRow>,
    user: Vec<SchedulerWeatherFarmRow>,
}

impl SchedulerWeatherFarmListGateway for FakeListGateway {
    fn list_reference_farms_for_weather_update(
        &self,
    ) -> Result<Vec<SchedulerWeatherFarmRow>, String> {
        Ok(self.reference.clone())
    }

    fn list_user_farms_for_weather_update(&self) -> Result<Vec<SchedulerWeatherFarmRow>, String> {
        Ok(self.user.clone())
    }
}

#[derive(Debug, Clone)]
struct ScheduledFetch {
    farm_id: i64,
    start: Date,
    end: Date,
    delay_secs: u64,
}

struct RecordingSchedulePort {
    calls: Mutex<Vec<ScheduledFetch>>,
    flushed: Mutex<bool>,
}

impl RecordingSchedulePort {
    fn new() -> Self {
        Self {
            calls: Mutex::new(Vec::new()),
            flushed: Mutex::new(false),
        }
    }
}

impl SchedulerWeatherFetchSchedulePort for RecordingSchedulePort {
    fn schedule_fetch(
        &self,
        farm_id: i64,
        _latitude: f64,
        _longitude: f64,
        start_date: Date,
        end_date: Date,
        delay_secs: u64,
    ) {
        self.calls.lock().expect("lock").push(ScheduledFetch {
            farm_id,
            start: start_date,
            end: end_date,
            delay_secs,
        });
    }

    fn flush(&self) {
        *self.flushed.lock().expect("lock") = true;
    }
}

#[test]
fn batch_enqueue_schedules_reference_and_user_farms_with_stagger_index() {
    let clock = FakeClock {
        today: Date::from_calendar_date(2026, Month::May, 1).expect("valid"),
    };
    let list = FakeListGateway {
        reference: vec![SchedulerWeatherFarmRow {
            farm_id: 1,
            latitude: 35.0,
            longitude: 139.0,
            latest_weather_date: None,
        }],
        user: vec![SchedulerWeatherFarmRow {
            farm_id: 2,
            latitude: 36.0,
            longitude: 140.0,
            latest_weather_date: Some(
                Date::from_calendar_date(2026, Month::April, 28).expect("valid"),
            ),
        }],
    };
    let schedule = RecordingSchedulePort::new();
    let interactor = SchedulerWeatherBatchEnqueueInteractor::new(&list, &schedule, &clock);
    interactor.call().expect("ok");

    let calls = schedule.calls.lock().expect("lock");
    assert_eq!(calls.len(), 2);
    assert_eq!(calls[0].farm_id, 1);
    assert_eq!(calls[0].delay_secs, 0);
    assert!(calls[0].start <= calls[0].end);
    assert_eq!(calls[1].farm_id, 2);
    assert_eq!(calls[1].delay_secs, 0);
    assert!(calls[1].start <= calls[1].end);
    assert!(*schedule.flushed.lock().expect("lock"));
}

#[test]
fn batch_enqueue_skips_farm_when_gap_fill_policy_returns_none() {
    let clock = FakeClock {
        today: Date::from_calendar_date(2026, Month::May, 1).expect("valid"),
    };
    let list = FakeListGateway {
        reference: vec![],
        user: vec![SchedulerWeatherFarmRow {
            farm_id: 3,
            latitude: 36.0,
            longitude: 140.0,
            latest_weather_date: Some(clock.today),
        }],
    };
    let schedule = RecordingSchedulePort::new();
    let interactor = SchedulerWeatherBatchEnqueueInteractor::new(&list, &schedule, &clock);
    interactor.call().expect("ok");
    assert!(schedule.calls.lock().expect("lock").is_empty());
}
