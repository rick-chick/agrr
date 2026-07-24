//! Backfill initial weather fetch for farms left at `pending` before #464.

use crate::farm::gateways::PendingFarmWeatherBackfillGateway;
use crate::shared::ports::ClockPort;
use crate::weather_data::gateways::StartFarmWeatherDataFetchPort;

/// Starts weather fetch for each pending user farm with coordinates.
pub struct PendingFarmWeatherBackfillInteractor<'a> {
    list_gateway: &'a dyn PendingFarmWeatherBackfillGateway,
    start_fetch: &'a dyn StartFarmWeatherDataFetchPort,
    clock: &'a dyn ClockPort,
}

impl<'a> PendingFarmWeatherBackfillInteractor<'a> {
    pub fn new(
        list_gateway: &'a dyn PendingFarmWeatherBackfillGateway,
        start_fetch: &'a dyn StartFarmWeatherDataFetchPort,
        clock: &'a dyn ClockPort,
    ) -> Self {
        Self {
            list_gateway,
            start_fetch,
            clock,
        }
    }

    /// Returns the number of farms for which fetch was started.
    pub fn call(&self) -> Result<usize, String> {
        let farm_ids = self
            .list_gateway
            .list_user_farm_ids_pending_initial_weather_fetch()?;
        let today = self.clock.today();
        let mut started = 0usize;
        for farm_id in farm_ids {
            if self.start_fetch.call(farm_id, today).is_some() {
                started += 1;
            }
        }
        Ok(started)
    }
}

#[cfg(test)]
mod interactors_pending_farm_weather_backfill_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/farm/interactors_pending_farm_weather_backfill_interactor_test.rs"
    ));
}
