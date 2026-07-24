// Tests for `interactors/pending_farm_weather_backfill_interactor.rs`

use std::sync::Mutex;

use crate::farm::gateways::PendingFarmWeatherBackfillGateway;
use crate::weather_data::gateways::{
    StartFarmWeatherDataFetchPort, StartedFarmWeatherFetchSnapshot,
};
use time::{Date, Month};

struct StubListGateway {
    farm_ids: Vec<i64>,
}

impl PendingFarmWeatherBackfillGateway for StubListGateway {
    fn list_user_farm_ids_pending_initial_weather_fetch(&self) -> Result<Vec<i64>, String> {
        Ok(self.farm_ids.clone())
    }
}

struct SpyStartFetch {
    calls: Mutex<Vec<i64>>,
}

impl SpyStartFetch {
    fn new() -> Self {
        Self {
            calls: Mutex::new(Vec::new()),
        }
    }
}

impl StartFarmWeatherDataFetchPort for SpyStartFetch {
    fn call(&self, farm_id: i64, _as_of: Date) -> Option<StartedFarmWeatherFetchSnapshot> {
        self.calls.lock().unwrap().push(farm_id);
        Some(StartedFarmWeatherFetchSnapshot {
            weather_data_status: "fetching".into(),
            weather_data_total_years: 5,
        })
    }
}

struct FixedClock(Date);

impl crate::shared::ports::ClockPort for FixedClock {
    fn today(&self) -> Date {
        self.0
    }

    fn now(&self) -> time::OffsetDateTime {
        unimplemented!()
    }
}

#[test]
fn starts_fetch_for_each_pending_farm_id() {
    let list = StubListGateway {
        farm_ids: vec![101, 202],
    };
    let start = SpyStartFetch::new();
    let as_of = Date::from_calendar_date(2026, Month::July, 24).unwrap();
    let clock = FixedClock(as_of);
    let interactor = PendingFarmWeatherBackfillInteractor::new(&list, &start, &clock);

    let started = interactor.call().expect("backfill");
    assert_eq!(2, started);
    assert_eq!(vec![101, 202], *start.calls.lock().unwrap());
}

#[test]
fn returns_zero_when_no_pending_farms() {
    let list = StubListGateway { farm_ids: vec![] };
    let start = SpyStartFetch::new();
    let as_of = Date::from_calendar_date(2026, Month::July, 24).unwrap();
    let clock = FixedClock(as_of);
    let interactor = PendingFarmWeatherBackfillInteractor::new(&list, &start, &clock);

    let started = interactor.call().expect("backfill");
    assert_eq!(0, started);
    assert!(start.calls.lock().unwrap().is_empty());
}
